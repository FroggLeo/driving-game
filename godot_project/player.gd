extends CharacterBody3D

var sensitivity = 0.5
var paused

# Called when the node enters the scene tree for the first time.
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	paused = false

# mouse movement code
func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_degrees.y -= event.relative.x * sensitivity
		$Camera3D.rotation_degrees.x -= event.relative.y * sensitivity
		# limits for vertical rotation
		$Camera3D.rotation_degrees.x = clamp($Camera3D.rotation_degrees.x, -80, 80)
	# release mouse on cancel event
	elif event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# call to pause menu code here
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			paused = true
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			paused = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
# Don't use for tick events, will break game if framerate is not expected
func _process(delta: float) -> void:
	pass

# movement code
func _physics_process(delta):
	const WALK_SPEED = 2
	const GRAVITY = 9.81
	const JUMP_VELOCITY = 2.7
	
	# more movement code or something
	var input_direction_2D = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_direction_3D = Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	var direction = transform.basis * input_direction_3D
	direction.y = 0
	direction = direction.normalized()
	
	if not paused:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = 0
	
	move_and_slide()
