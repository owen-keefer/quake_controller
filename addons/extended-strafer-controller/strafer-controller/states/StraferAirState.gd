extends BaseMovementState
class_name StraferAirState

## QUAKE SHIT
@export var AIR_ACCEL : float = 3.0
@export var AIR_MAX_SPEED : float = 12.5
@export var AIR_CONTROL : float = 0.3

## CAMERA SHIT

## Original direction of jump
var jump_dir : Vector3

## Boolean for if a jump has occured
var has_jumped : bool = false

## Magnitude of speed of player when on the ground to cap insane speed increases
var jump_force : float = 0.0

## Amount of directional control when in air. 
## Increase air drag by tiny amounts to make strafing faster
@export var AIR_DRAG : float = 0.95

## Speed at which the jump direction is lerped towards [code]airhvel[/code]
@export var AIR_LERP_SPEED : float = 0.0

## Set jump direction and jump force using a given velocity [Vector3]
func set_jump_dir(controller : BaseController3D, new_dir : Vector3):
    jump_dir = new_dir


## Handle the air state
func process_state(delta : float, controller : BaseController3D) -> void:
    # Get the current slide state if it exists
    var slide_state : StraferSlideState = controller.get_state(StraferSlideState.new())
    
    # Decrement the coyoteTimer by deltaTime
    controller.coyoteTimer -= delta
    
    # If the timer is not below 0 and jump is pressed and the player hasn't jumped, then make the player jump
    if controller.coyoteTimer > 0 and Input.is_action_just_pressed("ui_accept") and !has_jumped:
        controller.velocity.y = controller.settings.JUMP_FORCE
        jump_dir = controller.velocity
        controller.coyoteTimer = 0
    
    # Velocity
    controller.process_vel(delta, AIR_DRAG)
    # Crouching
    controller.process_crouch(delta)
    # Bounds
    controller.process_bounds()
    # Headbob
    controller.process_steps(delta)
    
    # Check state exit
    if controller.is_on_floor():
        if slide_state != null \
            and Input.is_action_just_pressed("crouch") \
            and controller.velocity.length() > slide_state.VEL_TRANS_THRESHOLD \
            and controller.slide_cooldown_timer <= 0.0:
                StraferGroundState.to_slide(controller, true)
        else:
            StraferAirState.to_ground(controller)


func process_vel(delta : float, controller : BaseController3D) -> void:
    # --- Gravity ---
    controller.velocity.y -= controller.settings.GRAVITY * delta

    # --- Get horizontal velocity ---
    var vel : Vector3 = Vector3(controller.velocity.x, 0, controller.velocity.z)

    # Apply drag
    vel *= AIR_DRAG
    
    # --- Get camera basis (typed) ---
    var cam_basis : Basis = controller.camera.global_transform.basis

# Flatten forward and right vectors (camera-relative)
    var forward : Vector3 = cam_basis.z   # <- changed from -cam_basis.z
    forward.y = 0
    forward = forward.normalized()

    var right : Vector3 = cam_basis.x
    right.y = 0
    right = right.normalized()

# Map input to world direction
    var wish_dir : Vector3 = forward * controller.inputAxis.y + right * controller.inputAxis.x

    var wish_speed : float = wish_dir.length()

    if wish_speed > 0:
        wish_dir = wish_dir / wish_speed
    else:
        wish_dir = Vector3.ZERO

# Clamp wish speed to max
    wish_speed = min(wish_speed * AIR_MAX_SPEED, AIR_MAX_SPEED)

    # --- Quake-style air acceleration ---
    var current_speed : float = vel.dot(wish_dir)
    var add_speed : float = wish_speed - current_speed

    if add_speed > 0 and wish_dir != Vector3.ZERO:
        var accel_speed : float = AIR_ACCEL * wish_speed * delta
        accel_speed = min(accel_speed, add_speed)
        vel += wish_dir * accel_speed

    # --- Optional air control for smoother strafing ---
    if wish_dir != Vector3.ZERO:
        var dot : float = vel.normalized().dot(wish_dir)
        if dot > 0:
            var control : float = AIR_CONTROL * dot * dot * delta * 32.0
            var new_dir : Vector3 = vel.normalized().lerp(wish_dir, control)
            var speed : float = vel.length()
            vel = new_dir.normalized() * speed

    var horizontal_speed = vel.length()
    if horizontal_speed > AIR_MAX_SPEED:
        vel = vel.normalized() * AIR_MAX_SPEED
    # --- Apply horizontal velocity ---
    controller.velocity.x = vel.x
    controller.velocity.z = vel.z

## Handle headbob
func process_steps(delta : float, controller : BaseController3D, target : Vector2) -> Vector2:
    return Vector2.ZERO


## Transition to ground dstate
static func to_ground(controller : BaseController3D) -> bool:
    var ground_state : StraferGroundState = controller.change_state(StraferGroundState.new())
    var air_state : StraferAirState = controller.get_state(StraferAirState.new())

    if ground_state != null:
        # Set the snap length back to the original snap length
        controller.floor_snap_length = controller.settings.SNAP_LENGTH
        if air_state != null:
            # Reset the state's variables
            air_state.jump_dir = Vector3.ZERO
            air_state.has_jumped = false
        return true
    else:
        return false
