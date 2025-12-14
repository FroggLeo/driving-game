extends SpringArm3D

@onready var player: CharacterBody3D = get_parent()

var first_person
var sensitivity
var last_mouse_pos: Vector2

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.paused:
		return
	
	first_person = player.first_person
	sensitivity = player.sensitivity
	
	if first_person or not player.enable_third_person:
		return
	
	# zoom in and out
	# TODO smooth zoom movement
	var zoom_increment = player.zoom_increment
	var max_zoom = player.max_zoom
	var min_zoom = player.min_zoom
	
	if Input.is_action_just_pressed("zoom_in") and spring_length >= min_zoom:
		spring_length -= zoom_increment
	elif Input.is_action_just_pressed("zoom_out") and spring_length < max_zoom:
		spring_length += zoom_increment
	
	# mouse control code
	if Input.is_action_just_pressed("move_camera"):
		last_mouse_pos = get_viewport().get_mouse_position()
	elif Input.is_action_pressed("move_camera"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif Input.is_action_just_released("move_camera"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Input.warp_mouse(last_mouse_pos)
	

func _unhandled_input(event: InputEvent) -> void:
	if Global.paused:
		return
	if first_person or not player.enable_third_person:
		return
	
	# 3rd person camera rotation code
	if event is InputEventMouseMotion and Input.is_action_pressed("move_camera"):
		rotation_degrees.y -= event.relative.x * sensitivity
		rotation_degrees.x -= event.relative.y * sensitivity
		# limits for vertical rotation
		rotation_degrees.x = clamp(rotation_degrees.x, -80, 40)
	
