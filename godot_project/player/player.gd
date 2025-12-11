extends CharacterBody3D

@export var walk_speed: float = 2.0
@export var crouch_speed: float = 1.0
@export var run_speed: float = 4.0
@export var gravity: float = 9.81
@export var jump_velocity: float = 2.7
@export_range(0.5, 30, 0.5) var max_zoom: float = 10.0 #TODO
@export_range(0.5, 30, 0.5) var zoom_increment: float = 10.0 #TODO
@export var sensitivity: float = 0.2 #TODO

@export_category("Enabled features")
@export var enable_jumping: bool = true
@export var enable_first_person: bool = true
@export var enable_third_person: bool = true #TODO
@export var enable_crouch: bool = true
@export var enable_run: bool = true

var first_person: bool = false
var run: bool = false
var crouch: bool = false
# var paused = Global.paused

# nodes used
@onready var first_person_cam = $first_person_cam
@onready var third_person_cam = $third_person_spring/third_person_cam
@onready var third_person_spring = $third_person_spring
@onready var player_mesh = $mesh

# Called when the node enters the scene tree for the first time.
func _ready():
	if enable_first_person:
		third_person_spring.spring_length = 0
	else:
		third_person_spring.spring_length = max_zoom / 2
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	first_person_cam.make_current()
	Global.paused = false

func _unhandled_input(event):
	
	first_person = third_person_spring.spring_length <= 0
	
	# release mouse on cancel event
	if event.is_action_pressed("ui_cancel"):
		if Global.paused:
			if first_person:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Global.paused = false
		else:
			# call to pause menu code here
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Global.paused = true
	
	# skip if paused
	if Global.paused:
		return
	
	# first person camera movement
	if event is InputEventMouseMotion and first_person:
		rotation_degrees.y -= event.relative.x * Global.sensitivity
		first_person_cam.rotation_degrees.x -= event.relative.y * Global.sensitivity
		# limits for vertical rotation
		first_person_cam.rotation_degrees.x = clamp(first_person_cam.rotation_degrees.x, -80, 80)
	
	# crouch and sprint/run
	if event.is_action_pressed("crouch"):
		crouch = true
	elif event.is_action_pressed("sprint"):
		run = true
	if event.is_action_released("crouch"):
		crouch = false
	if event.is_action_released("sprint"):
		run = false
	
	# auto switch camera
	if first_person and enable_third_person:
		if event.is_action_pressed("zoom_out"):
			# set the spring length to the smallest allowed
			third_person_spring.spring_length = Global.zoom_inc
			third_person_spring.rotation = first_person_cam.rotation
			third_person_cam.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif get_viewport().get_camera_3d() == third_person_cam:
			# set the rotation of the player to the rotation of the 3rd person cam
			rotation.y = third_person_spring.global_transform.basis.get_euler().y
			# reset the rotation of the mesh and first person cam, created by the 3rd person rotation code
			first_person_cam.global_rotation.y = rotation.y
			player_mesh.global_rotation.y = rotation.y
			# match the rotation of the 3rd person cam
			first_person_cam.rotation.x = third_person_spring.rotation.x
			first_person_cam.rotation.z = third_person_spring.rotation.z
			first_person_cam.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

# movement code
func _physics_process(delta):
	
	
	if Global.paused:
		return
	
	# more movement code or something
	# HACK: need to optimize/simplify
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction
	var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	
	# calculate direction
	if first_person:
		# gets the player rotation
		direction = transform.basis * input_direction_3D
		direction.y = 0
	else:
		# gets the spring arm rotation
		var cam_rotation = third_person_spring.global_transform.basis
		
		# only need to do forward and right
		var forward = cam_rotation.z
		var right = cam_rotation.x
		# keeps the speed the same despite the up down rotation of the camera
		forward.y = 0
		right.y = 0
		
		direction = (right * input_direction_2D.x) + (forward * input_direction_2D.y)
		
		# 3rd person rotation code
		if direction.length() > 0.001:
			var walking_direction = atan2(direction.x,direction.z) + PI
			var new_direction = lerp_angle(player_mesh.global_rotation.y, walking_direction, 4*delta)
			player_mesh.global_rotation.y = new_direction
			first_person_cam.global_rotation.y = new_direction
		
	
	# this line like prevents the player from moving faster when they are going diagonally
	direction = direction.normalized()
	
	if crouch and enable_crouch:
		velocity.x = direction.x * crouch_speed
		velocity.z = direction.z * crouch_speed
	elif run and enable_run:
		velocity.x = direction.x * run_speed
		velocity.z = direction.z * run_speed
	else:
		# apply the calculated speeds based on direction
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	
	
	# jumping code
	if enable_jumping:
		if not is_on_floor():
			velocity.y -= gravity * delta
		elif Input.is_action_just_pressed("jump") and velocity.y == 0:
			velocity.y = jump_velocity
		else:
			velocity.y = 0
	
	move_and_slide()
