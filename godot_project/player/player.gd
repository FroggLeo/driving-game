extends CharacterBody3D

var first_person: bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	%third_person_spring.spring_length = 0
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	%first_person_cam.make_current()
	Global.paused = false

func _unhandled_input(event):
	
	first_person = %third_person_spring.spring_length <= 0
	
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
	
	if Global.paused:
		return
	
	# first person camera movement
	if event is InputEventMouseMotion and first_person:
		rotation_degrees.y -= event.relative.x * Global.sensitivity
		%first_person_cam.rotation_degrees.x -= event.relative.y * Global.sensitivity
		# limits for vertical rotation
		%first_person_cam.rotation_degrees.x = clamp(%first_person_cam.rotation_degrees.x, -80, 80)
	
	# auto switch camera
	# TODO match camera rotation when switching cams
	if first_person:
		if event.is_action_pressed("zoom_out"):
			%third_person_spring.spring_length = Global.zoom_inc
			%third_person_spring.rotation = %first_person_cam.rotation
			$third_person_spring/third_person_cam.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif get_viewport().get_camera_3d() == $third_person_spring/third_person_cam:
			rotation.y = %third_person_spring.global_transform.basis.get_euler().y
			%first_person_cam.rotation.x = %third_person_spring.rotation.x
			%first_person_cam.rotation.z = %third_person_spring.rotation.z
			%first_person_cam.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Don't use for tick events, will break game if framerate is not expected
#func _process(delta: float) -> void:
#	pass

# movement code
func _physics_process(delta):
	const WALK_SPEED = 2
	const GRAVITY = 9.81
	const JUMP_VELOCITY = 2.7
	
	if Global.paused:
		return
	
	# movement code or something
	# TODO rotate player in the moving direction
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction
	
	if first_person:
		var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
		direction = transform.basis * input_direction_3D
		direction.y = 0
	else:
		# gets the spring arm rotation
		var cam_rotation = %third_person_spring.global_transform.basis
		
		# only need to do forward and right
		var forward = cam_rotation.z
		forward.y = 0
		var right = cam_rotation.x
		right.y = 0
		
		direction = (right * input_direction_2D.x) + (forward * input_direction_2D.y)
	
	# this line like prevents the player from moving faster when they are going diagonally
	direction = direction.normalized()
	# apply the calculated speeds based on direction
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	
	# TODO fix this bro
	#if not first_person:
	#	var player_rotation = atan2(-direction.x, -direction.z)
	#	$Node3D.rotation.y += player_rotation
	
	# jumping code
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and velocity.y == 0:
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = 0
	
	move_and_slide()
