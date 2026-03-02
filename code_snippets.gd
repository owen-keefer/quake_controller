extends Node


## Camera ##

# Add global variables at the top of file
var yaw_acc: float
var pitch_acc: float
var yaw_current: float
var pitch_current: float
var camera_smoothing: float = 0.003


func _input(event: InputEvent) -> void:
	
	# Camera
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw_acc -= event.relative.x * mouse_sense
		pitch_acc -= event.relative.y * mouse_sense
		pitch_acc = clampf(pitch_acc, deg_to_rad(-89.9), deg_to_rad(89.9))

func camera_rotation(delta) -> void:
	# Interoplate accumulators
	yaw_current = lerp(yaw_current, yaw_acc, camera_smoothing * delta)
	pitch_current = lerp(pitch_current, pitch_acc, camera_smoothing * delta)
	
	# reset basis
	transform.basis = Basis()
	cameraHolder.transform.basis = Basis()

	rotate_object_local(Vector3.UP, yaw_current)
	cameraHolder.rotate_object_local(Vector3.RIGHT, pitch_current)
	

## Air Strafe

func move(delta : float, accel : float, drag : float, speed : float = speed) -> void:
	
	# ^ kind of pointless to call speed: float = speed; speed is a global var
	# for you already so you don't need to pass it into this function as an argument
	
	
	#get keyboard input
	var input_dir: Vector2 = Input.get_vector("left", "right", "forward", "backward")
	direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var wish_velocity : Vector3 = direction * speed
	
	#Airstrafing
	match currentState:
		MOVESTATES.AIR:
				var wish_speed = wish_velocity.length()
				wish_velocity = wish_velocity.normalized()
				
				if wish_speed > speed / 10: # Can replace with any constant for air control speed
					wish_speed = speed / 10
				
				
				# The two lines that make airstraffing possible
				# Current speed (inaplty named tbh) is zero when wish_velocity
				# is 90 deg to velocity, so you get the boost of wish_speed, which
				# is capped to 30 in Quake, but speed / 10 here for unit parity
				
				var current_speed = velocity.dot(wish_velocity)
				var add_speed = wish_speed - current_speed
				
				if !(add_speed <= 0):
					printt(wish_speed, add_speed)
					
					var sv_accelerate = 10
					var grounded_wish_speed = wish_velocity.length()
					
					var accel_speed = sv_accelerate * grounded_wish_speed * delta
					
					if accel_speed > add_speed:
						accel_speed = add_speed
					
					velocity += accel_speed * wish_velocity
