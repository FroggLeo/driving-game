extends SpringArm3D

var sensitivity = Global.sensitivity
var paused = Global.paused

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

func _unhandled_input(event: InputEvent) -> void:
	if paused:
		pass
	elif event is InputEventMouseMotion:
		rotation_degrees.y -= event.relative.x * sensitivity
		$third_person_cam.rotation_degrees.x -= event.relative.y * sensitivity
		# limits for vertical rotation
		$third_person_cam.rotation_degrees.x = clamp($third_person_cam.rotation_degrees.x, -80, 80)
