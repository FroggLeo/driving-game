extends CharacterBody3D

var sensitivity = Global.sensitivity
var first_person = true

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$first_person_cam.make_current()
	Global.paused = false

# mouse movement code
func _unhandled_input(event):
	# release mouse on cancel event
	if event.is_action_pressed("ui_cancel"):
		if Global.paused:
			# call to pause menu code here
			if first_person:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Global.paused = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			Global.paused = true
	
	if Global.paused:
		return
	
	# first person camera movement
	if event is InputEventMouseMotion and first_person:
		rotation_degrees.y -= event.relative.x * sensitivity
		$first_person_cam.rotation_degrees.x -= event.relative.y * sensitivity
		# limits for vertical rotation
		$first_person_cam.rotation_degrees.x = clamp($first_person_cam.rotation_degrees.x, -80, 80)
	
	# switch camera
	if event.is_action_pressed("switch_camera"):
		if first_person:
			first_person = false
			$third_person_spring/third_person_cam.make_current()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			first_person = true
			$first_person_cam.make_current()
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
	# TODO 
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	var direction = transform.basis * input_direction_3D
	direction.y = 0
	direction = direction.normalized()
	
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	
	# jumping code
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and velocity.y == 0:
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = 0
	
	move_and_slide()
