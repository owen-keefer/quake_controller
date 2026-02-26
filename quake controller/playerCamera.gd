extends Camera3D

var defaultFOV : float = fov
#@export var runFOV : float = 98
@export var player : PlayerMovement

@export var jumpRotation : Vector3 = Vector3(-1.0, -0.5, 0.2)
@export var jumpAnimation : ProceduralCurve

@export var landPosition : Vector3 = Vector3(0, -0.15, 0)
@export var landPosAnimation : ProceduralCurve

@export var landRotation : Vector3 = Vector3(-0.5, 0, 0)
@export var landRotAnimation : ProceduralCurve

@onready var rotationAnims = [jumpAnimation, landRotAnimation]
@onready var posAnims = [landPosAnimation]
@onready var tiltAnims = [slideAnimation, wallRunAnimation]

@export var slideTilt : float = -1.0
@export var slideAnimation : ProceduralCurve

@export var wallRunTilt : float = -3.0
@export var wallRunAnimation : ProceduralCurve

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    player.justJumped.connect(startJumpAnimation)
    player.justLanded.connect(startLandAnimation)
    player.startSlide.connect(startSlide)
    player.endSlide.connect(endSlide)
    player.startWallRun.connect(startWallRun)
    player.endWallRun.connect(endWallRun)
    
    jumpAnimation.set_targets(Vector3.ZERO, jumpRotation, Vector3.ZERO)
    landPosAnimation.set_targets(Vector3.ZERO, landPosition, Vector3.ZERO)
    landRotAnimation.set_targets(Vector3.ZERO, landRotation, Vector3.ZERO)
    slideAnimation.set_targets(0.0, slideTilt, slideTilt)
    wallRunAnimation.set_targets(0.0, wallRunTilt, wallRunTilt)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    #fov = lerp(defaultFOV, runFOV, player.velocity.length()/player.speed)
    for anim in rotationAnims:
        if anim.is_running():
            rotation_degrees = anim.step(delta)
    
    for anim in posAnims:
        if anim.is_running():
            position = anim.step(delta)
    
    for anim in tiltAnims:
        if anim.is_running():
            rotation_degrees.z = anim.step(delta)


func startJumpAnimation() -> void:
    landPosAnimation.force_stop()
    landRotAnimation.force_stop()
    jumpAnimation.start(rotation_degrees)
    
func startLandAnimation() -> void:
    jumpAnimation.force_stop()
    landPosAnimation.start(position)
    landRotAnimation.start(rotation_degrees)

func startTilt(anim : ProceduralCurve) -> void:
    for i in rotationAnims:
        i.force_stop()
        
    if anim.targets["min"] is Vector3:
        anim.start(rotation_degrees)
    else:
        anim.start(rotation_degrees.z)

func endTilt(anim : ProceduralCurve) -> void:
    for i in rotationAnims:
        if i.is_running():
            pass
    
    if anim.targets["min"] is Vector3:
        anim.start_backwards(rotation_degrees)
    else:
        anim.start_backwards(rotation_degrees.z)

func startWallRun(left : bool) -> void:
    wallRunTilt = -wallRunTilt if (wallRunTilt < 0 and !left) or (wallRunTilt > 0 and left) else wallRunTilt
    wallRunAnimation.targets["max"] = wallRunTilt
    wallRunAnimation.targets["snap"] = wallRunTilt
    startTilt(wallRunAnimation)

func endWallRun(left : bool) -> void:
    endTilt(wallRunAnimation)

func startSlide() -> void:
    startTilt(slideAnimation)

func endSlide() -> void:
    endTilt(slideAnimation)
