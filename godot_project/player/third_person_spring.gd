extends SpringArm3D

var first_person: bool

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

func _unhandled_input(event: InputEvent) -> void:
	if Global.paused:
		return
	
	first_person = %third_person_spring.spring_length <= 0
	if first_person:
		return
	
	# HACK lock mouse when rotating at current position
	#var mouse_pos: Vector2
	#mouse_pos = get_viewport().get_mouse_position()
	#Input.warp_mouse(mouse_pos)
	# mouse control code
	if event.is_action_pressed("move_camera"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_released("move_camera"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# 3rd person camera rotation code
	if event is InputEventMouseMotion and Input.is_action_pressed("move_camera"):
		rotation_degrees.y -= event.relative.x * Global.sensitivity
		rotation_degrees.x -= event.relative.y * Global.sensitivity
		# limits for vertical rotation
		rotation_degrees.x = clamp(rotation_degrees.x, -80, 40)
	
	# zoom in and out
	# TODO smooth zoom movement
	if event.is_action_pressed("zoom_in"):
		%third_person_spring.spring_length -= Global.zoom_inc
	elif event.is_action_pressed("zoom_out") and %third_person_spring.spring_length <= 10:
		%third_person_spring.spring_length += Global.zoom_inc
