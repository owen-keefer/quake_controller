extends Resource
class_name ProceduralCurve

@export var curve : Curve
@export var length : float
var position : float = 0.0
var changeMinThreshold : float = 0.8
var targets = {"min" : 0.0, "max" : 1.0, "defaultMin" : 0.0, "snap" : 0.0}
var stopped = true
var playBackwards = false


func step(delta : float) -> Variant:
	if playBackwards:
		position -= delta / length
	else:
		position += delta / length
	var curveSample : float = curve.sample(position)
	var lerped_value = lerp(targets["min"], targets["max"], curveSample)
	if (position >= 1.0 and !playBackwards) or (position <= 0.0 and playBackwards):
		position = 0.0
		stopped = true
		#print(targets["snap"] if !playBackwards else targets["defaultMin"])
		return targets["snap"] if !playBackwards else targets["defaultMin"]
	if curveSample > changeMinThreshold and targets["min"] != targets["defaultMin"]:
		targets["min"] = targets["defaultMin"]
	return lerped_value


func start(min : Variant = null) -> void:
	if min != null:
		targets["min"] = min
	stopped = false
	playBackwards = false
	position = 0.0


func start_backwards(min : Variant = null) -> void:
	if min == null:
		targets["min"] = min
	stopped = false
	playBackwards = true
	position = 1.0


func is_running() -> bool:
	return not stopped


func set_targets(min : Variant, max : Variant, snap : Variant = max) -> void:
	targets["min"] = min
	targets["defaultMin"] = min
	targets["max"] = max
	targets["snap"] = snap


func force_stop() -> void:
	stopped = true
	position = 0.0
