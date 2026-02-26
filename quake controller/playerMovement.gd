extends CharacterBody3D
class_name PlayerMovement

var speed : float = 15
var gravity : float = 22
var jump : float = 11

var cam_accel : float = 40
var mouse_sense : float = 0.1

var direction : Vector3
var gravity_vec : Vector3

## Speed label
@onready var speed_label: Label = $HUD/Control/speed_label

@onready var head : Node3D = $Head
@onready var cameraHolder : Node3D = $Head/CameraHolder
@onready var collider : CollisionShape3D = $CollisionShape3D


enum MOVESTATES {GROUND, AIR, SLIDING, WALLRUNNING}
var currentState : MOVESTATES = MOVESTATES.AIR
var previousState : MOVESTATES = MOVESTATES.AIR

#Ground State
const floorSnapLength : float = 0.4
const floorAccel : float = 7
const floorDrag : float = 8

#Air State
const airSnapLength : float = 0.1
const airAccel : float = 1.2
const airSpeed : float = 16.0
const airDrag : float = 0.1

#Air Strafing
@export var airStrafeCurve : Curve
const minStrafeAngle : float = 0.0
const maxStrafeAngle : float = 180.0
const airStrafeModifier : float = 1.0

#Jumping
var canJump : bool = true
var hasJumped : bool = false
var coyoteTime : float = 0.2
var jumpQueued : bool = false

#Crouching
@onready var fullHeight : float = collider.shape.height
@onready var crouchHeight : float = fullHeight / 2.0
@onready var ceilingCheck: ShapeCast3D = $CeilingCheck
const heightLerpSpeed : float = 10.0
@onready var headOffset : float = head.position.y
var isCrouching : bool = false
const crouchSpeed : float = 6; const crouchAccel : float = 4

#Sliding
@export var slideDragCurve : Curve
@export var slopeAngleDragCurve : Curve
const slideAccel : float = 0.8
var slideCurvePoint : float = 0.0
const slideDragTime : float = .6
const startSlideThresh : float = 13
const endSlideSpeed : float = 11
const slideBoostForce : float = 4.0
const slideBoostTime : float = 2.0
var canSlideBoost : bool = true
const maxSlideSlopeSpeed : float = 25.0
const slideSlopeForce : float = 4.0

#Walljumping
@onready var wallJumpCast : ShapeCast3D = $Head/wallJumpCast
const wallJumpForce : float = 12.0
const wallJumpUpForce : float = 0.8
const wallJumpAwayForce : float = 0.6
const wallJumpForwardForce : float = 0.8
const wallJumpDetectionDistance : float = 1.5
#Prevent jumping against the same wall over and over
var lastWallJumpNormal : Vector3 = Vector3.ZERO
const wallJumpCooldownAngle : float = 0.1 # radians, ~5.7 degrees

#Wallrunning
@export var wallrunCurve : Curve
const wallrunHeight : float = 4.0
var wallrunStartVel : Vector3
var wallrunPoint : float = 0.0
const wallrunTime : float = 2.0
const wallRunResetTime : float = 1.0
var hasLeftWallRun : bool = false; var hasRightWallRun : bool = false
var leftWallRun : bool = true
var prevWallNormal : Vector3
var prevWallRunPoint : Vector3 = Vector3(-INF, -INF, -INF)

@onready var cameraShaker: ShakerComponent3D = $Head/CameraHolder/CameraShaker/ShakerComponent3D
@export var shakeMaxSpeed : float = 20.0
@onready var realCamera: Camera3D = $Head/CameraHolder/CameraShaker/Camera
@export var fov : float = 95.0
@export var speedFovIncrease : float = 5.0
@export var fovLerpSpeed : float = 5.0
@onready var headBobShaker: ShakerComponent3D = $Head/CameraHolder/CameraShaker/ShakerComponent3D2


#Signals
signal justJumped; 
signal justLanded;
signal startSlide; 
signal endSlide;
signal startWallRun(isLeft : bool); 
signal endWallRun(isLeft : bool);


func _ready() -> void:
    #hides the cursor
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event : InputEvent) -> void:
    #get mouse input for camera rotation
    if event is InputEventMouseMotion:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sense))
        head.rotate_x(deg_to_rad(-event.relative.y * mouse_sense))
        head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _process(delta : float) -> void:
    #camera physics interpolation to reduce physics jitter on high refresh-rate monitors
    if Engine.get_frames_per_second() > Engine.physics_ticks_per_second:
        cameraHolder.top_level = true
        cameraHolder.global_transform.origin = lerp(cameraHolder.global_transform.origin, head.global_transform.origin, cam_accel * delta)
        cameraHolder.rotation.y = rotation.y
        cameraHolder.rotation.x = head.rotation.x
    else:
        cameraHolder.top_level = false
        cameraHolder.global_transform = head.global_transform
    
    
    if !is_on_floor():
        cameraShaker.intensity = clamp(velocity.length() / shakeMaxSpeed, 0, 1)
    else:
        cameraShaker.intensity = lerp(cameraShaker.intensity, 0.0, 10.0 * delta)
    
    if (is_on_floor() and currentState != MOVESTATES.SLIDING) or is_on_wall():
        headBobShaker.intensity = clamp(velocity.length() / shakeMaxSpeed, 0, 1)
    else:
        headBobShaker.intensity = lerp(headBobShaker.intensity, 0.0, 10.0 * delta)
    
    var targetFov = lerp(fov, fov + speedFovIncrease, min(velocity.length() / shakeMaxSpeed, 1.0) )
    realCamera.fov = lerp(realCamera.fov, targetFov, fovLerpSpeed * delta)


func _physics_process(delta : float) -> void:	
    match currentState:
        MOVESTATES.GROUND:
            ground(delta)
        MOVESTATES.AIR:
            air(delta)
        MOVESTATES.SLIDING:
            slide(delta)
        MOVESTATES.WALLRUNNING:
            wallrun(delta)
    
    
    if (Input.is_action_just_pressed("jump") or jumpQueued) and canJump:
        canJump = false
        hasJumped = true
        jumpQueued = false
        emit_signal("justJumped")
        
        if currentState != MOVESTATES.AIR:
            changeState(MOVESTATES.AIR)
            
    #SPEED LABEL
    var horizontal_velocity = velocity
    horizontal_velocity.y = 0
    var speed = Vector3(velocity.x, 0, velocity.z).length()
    speed_label.text = "Speed: %.2f" % speed

#WALLJUMP HELPER FUNCTION    
func canWallJump() -> bool:
    if is_on_wall() or wallJumpCast.is_colliding():
        var wall_normal : Vector3
        if is_on_wall():
            wall_normal = get_wall_normal()
        else:
            wall_normal = wallJumpCast.get_collision_normal(0)
        
        # Only allow jump if wall is different enough from last wall
        if lastWallJumpNormal == Vector3.ZERO or wall_normal.angle_to(lastWallJumpNormal) > wallJumpCooldownAngle:
            return true
            
    return false

#WALLJUMP
func performWallJump():
    var wall_normal : Vector3
    if is_on_wall():
        wall_normal = get_wall_normal()
    else:
        wall_normal = wallJumpCast.get_collision_normal(0)

    # Camera forward direction
    var cam_forward := -head.global_transform.basis.z
    cam_forward.y = 0
    cam_forward = cam_forward.normalized()

    var wall_forward := cam_forward.slide(wall_normal).normalized()

    # Build jump vector
    var jump_vector : Vector3 = Vector3.ZERO
    jump_vector += wall_normal * wallJumpAwayForce
    jump_vector += wall_forward * wallJumpForwardForce
    jump_vector += Vector3.UP * wallJumpUpForce

    # Normalize and scale
    jump_vector = jump_vector.normalized() * wallJumpForce

    # Add to velocity if current component is smaller
    for axis in ["x", "y", "z"]:
        if abs(jump_vector[axis]) > abs(velocity[axis]):
            velocity[axis] = jump_vector[axis]
        else:
            velocity[axis] += 0.35 * jump_vector[axis]

    # Remember last wall jumped
    lastWallJumpNormal = wall_normal

    resetWallRun()
    changeState(MOVESTATES.AIR)
        
func ground(delta : float) -> void:
    isCrouching = handleCrouch(delta)
    
    floor_snap_length = floorSnapLength
    gravity_vec = Vector3.ZERO
    
    if !isCrouching or (isCrouching and velocity.length() > startSlideThresh):
        move(delta, floorAccel, floorDrag)
        if isCrouching:
            toSlide()
    else:
        move(delta, crouchAccel, floorDrag)
    
    groundToAir()


func air(delta : float) -> void:
    isCrouching = handleCrouch(delta, false, true)
    
    floor_snap_length = airSnapLength
    
    if hasJumped:
        gravity_vec = (get_floor_normal() + Vector3.UP).normalized() * jump
        hasJumped = false
    else:
        gravity_vec = Vector3.DOWN * gravity * delta
    
    move(delta, airAccel, airDrag)
    
    #WALLJUMPING IN AIR
    if !is_on_floor() and canWallJump() and Input.is_action_just_pressed("jump"):
        performWallJump()
        return
        
    # Prevent bounce when holding jump against a wall
    if is_on_wall() and Input.is_action_pressed("jump"):
        var wall_normal := get_wall_normal()
        
        # Remove velocity component pushing into wall
        if velocity.dot(wall_normal) < 0:
            velocity = velocity.slide(wall_normal)
            
    #reset wall jump ability
    if is_on_floor():
        lastWallJumpNormal = Vector3.ZERO
        canJump = true
        hasLeftWallRun = false
        hasRightWallRun = false
        wallrunPoint = 0.0
        emit_signal("justLanded")
            
    if is_on_floor():
        if isCrouching and velocity.length() > startSlideThresh:
            toSlide()
        else:
            changeState(MOVESTATES.GROUND)
            hasLeftWallRun = false; hasRightWallRun = false
            emit_signal("justLanded")
        canJump = true
        
    
    if Input.is_action_just_pressed("jump"):
        queueJump()
    
    ##WALLRUN START
    if is_on_wall_only() and Input.is_action_pressed("crouch"):
        if wallrunPoint >= 1.0:
            return
        
        var leftWall : bool = isWallRunningLeft(get_last_slide_collision().get_position())
        if not ((leftWall and hasLeftWallRun) or (!leftWall and hasRightWallRun)):
            wallrunPoint = 0.0
            if leftWall:
                hasLeftWallRun = true
                hasRightWallRun = false
            else:
                hasLeftWallRun = false
                hasRightWallRun = true
        elif position.y > prevWallRunPoint.y:
            return
        
        changeState(MOVESTATES.WALLRUNNING)
        wallrunStartVel = velocity


func slide(delta : float) -> void:
    # Check if player is still holding crouch
    var holdingSlide := Input.is_action_pressed("crouch")

    # Allow exiting slide by releasing crouch
    if !holdingSlide:
        slideCurvePoint = 0.0
        changeState(MOVESTATES.GROUND)
        return

    # Continue slide logic
    isCrouching = handleCrouch(delta, true)

    if slideCurvePoint < 1.0:
        slideCurvePoint += delta / slideDragTime
    else:
        slideCurvePoint = 1.0

    floor_snap_length = floorSnapLength
    gravity_vec = Vector3.ZERO

    var isSlideDownward : bool = velocity.dot(get_floor_normal()) > 0
    var angleCurveSamplePoint := get_floor_angle() / floor_max_angle if isSlideDownward else 0.0

    if isSlideDownward and velocity.length() < maxSlideSlopeSpeed:
        applyForce(velocity.normalized() * delta * slideSlopeForce)

    var slideDrag : float = slideDragCurve.sample(slideCurvePoint) * slopeAngleDragCurve.sample(angleCurveSamplePoint)

    move(delta, slideAccel, slideDrag)

    # Optional: still exit if too slow
    if velocity.length() < endSlideSpeed:
        slideCurvePoint = 0.0
        changeState(MOVESTATES.GROUND)
        return

    if groundToAir():
        slideCurvePoint = 0.0


func wallrun(delta : float):
    var leftWallNormal : Vector3 = get_wall_normal().rotated(Vector3.UP, PI/2)
    var rightWallNormal : Vector3 = get_wall_normal().rotated(Vector3.UP, -PI/2)
    var newDir : Vector3 = leftWallNormal if leftWallNormal.angle_to(wallrunStartVel) < rightWallNormal.angle_to(wallrunStartVel) else rightWallNormal
    
    velocity = newDir.normalized() * clamp(wallrunStartVel.length(), speed/2, speed * 2.0)
    if prevWallNormal != get_wall_normal():
        velocity -= get_wall_normal() * 2
    else:
        velocity -= get_wall_normal() * 2
    velocity += Vector3.UP * (wallrunCurve.sample(wallrunPoint) * wallrunHeight)
    move_and_slide()
    
    if wallrunPoint < 1.0 and is_on_wall_only():
        wallrunPoint += delta / wallrunTime
    else:
        changeState(MOVESTATES.AIR)
        resetWallRun()
    
    if Input.is_action_pressed("jump"):
        prevWallRunPoint = position
        changeState(MOVESTATES.AIR)
        performWallJump()
        return
        resetWallRun()
    
    prevWallNormal = get_wall_normal()


func changeState(newState : MOVESTATES) -> void:
    previousState = currentState
    currentState = newState
    
    if previousState == MOVESTATES.SLIDING:
        emit_signal("endSlide")
    if currentState == MOVESTATES.SLIDING:
        emit_signal("startSlide")
    if currentState == MOVESTATES.WALLRUNNING:
        emit_signal("startWallRun", leftWallRun)
    if previousState == MOVESTATES.WALLRUNNING:
        emit_signal("endWallRun", leftWallRun)
    


func queueJump() -> void:
    jumpQueued = true
    await get_tree().create_timer(coyoteTime).timeout
    jumpQueued = false


func groundToAir() -> bool:
    if !is_on_floor():
        changeState(MOVESTATES.AIR)
        if canJump:
            executeAfterTime(coyoteTime, func() : if !is_on_floor(): canJump = false)
        return true
    return false


func toSlide() -> bool:
    if canSlideBoost:
        applyForce(velocity.normalized() * slideBoostForce)
        canSlideBoost = false
        executeAfterTime(slideBoostTime, func(): canSlideBoost = true)
    changeState(MOVESTATES.SLIDING)
    return true


func executeAfterTime(time : float, function : Callable) -> void:
    await get_tree().create_timer(time).timeout
    function.call()


func applyForce(force : Vector3) -> void:
    velocity += force


func slowMovement(amount : float) -> void:
    velocity *= amount


func handleCrouch(delta : float, forceCrouch : bool = false, forceUncrouch : bool = false) -> bool:
    var height : float = collider.shape.height
    var crouching : bool = Input.is_action_pressed("crouch") or (height < fullHeight - 0.1 and ceilingCheck.is_colliding()) or forceCrouch
    crouching = false if forceUncrouch else crouching 
    
    if height != fullHeight or height != crouchHeight:
        collider.shape.height = lerp(collider.shape.height, crouchHeight if crouching else fullHeight, delta * heightLerpSpeed)
        head.position.y = lerp(head.position.y, headOffset if !crouching else headOffset/2, delta * heightLerpSpeed)
    
    return crouching


func move(delta : float, accel : float, drag : float, speed : float = speed) -> void:
    #get keyboard input
    direction = Vector3.ZERO
    var h_rot : float = global_transform.basis.get_euler().y
    var f_input : float = Input.get_axis("forward", "backward")
    var h_input : float = Input.get_action_strength("right") - Input.get_action_strength("left")
    direction = Vector3(h_input, 0, f_input).rotated(Vector3.UP, h_rot).normalized()
    
    var wish_vel : Vector3 = direction * speed
    
    #Airstrafing
    match currentState:
        MOVESTATES.AIR:
                var angle_diff : float = rad_to_deg(getHorizontalAngle(velocity, wish_vel))
                var samplePoint := (angle_diff - minStrafeAngle) / maxStrafeAngle
                #velocity += wish_vel.normalized() * delta * airStrafeCurve.sample(samplePoint) * airSpeed
                wish_vel *= 1.0 + (airStrafeCurve.sample(samplePoint) * airStrafeModifier)
    
    #Crouching
    if currentState == MOVESTATES.GROUND and isCrouching:
        wish_vel = direction * crouchSpeed
    
    # Determine if decellerating or accellerating
    if direction.length() > 0:
        match currentState:
            MOVESTATES.SLIDING:
                var newVelLength : float = lerp(velocity, Vector3.ZERO, drag * delta).length()
                var newVelDir : Vector3 = lerp(velocity.normalized(), wish_vel.normalized(), accel * delta)
                velocity = newVelDir.normalized() * newVelLength
            _:
                velocity = lerp(velocity, wish_vel, accel * delta)
    
    else:
        #if not currentState == MOVESTATES.SLIDING:
        velocity = lerp(velocity, wish_vel, drag * delta)
        #else:
            #velocity = lerp(velocity, wish_vel, (slideDragCurve.sample(slideCurvePoint) * drag) * delta)
    
    velocity += gravity_vec
    move_and_slide()


func isWallRunningLeft(collisionPoint : Vector3) -> bool:
    var localCollision : Vector3 = head.to_local(collisionPoint)
    leftWallRun = not localCollision.x >= 0
    return localCollision.x >= 0


func resetWallRun() -> void:
    if hasLeftWallRun:
        executeAfterTime(wallRunResetTime, func(): hasLeftWallRun = false)
    if hasRightWallRun:
        executeAfterTime(wallRunResetTime, func(): hasRightWallRun = false)
    if currentState != MOVESTATES.WALLRUNNING:
        wallrunPoint = 0.0
    prevWallNormal = Vector3.UP


func getHorizontalAngle(vec1 : Vector3, vec2 : Vector3) -> float:
    vec1.y = 0
    vec2.y = 0
    return abs(vec1.angle_to(vec2))
