extends CharacterBody3D

@export var walk_speed: float = 2.0
@export var crouch_speed: float = 1.0
@export var run_speed: float = 4.0
@export var gravity: float = 9.81
@export var jump_velocity: float = 2.7
@export var player_turn_speed: float = 4.0
@export_range(0.5, 30, 0.5) var max_zoom: float = 10.0
@export_range(0.5, 10, 0.5) var min_zoom: float = 2.0
@export_range(0.5, 5, 0.025) var zoom_increment: float = 1.0
@export_range(0.01, 1, 0.01) var sensitivity: float = 0.2

@export_category("Enabled features")
@export var enable_jumping: bool = true
@export var enable_first_person: bool = true
@export var enable_third_person: bool = true
@export var enable_crouch: bool = true
@export var enable_run: bool = true

# can add more cam modes if needed
enum CamMode {FIRST, THIRD}
var cam_mode: CamMode = CamMode.FIRST

# interacting stuff
var i_object: Node = null
var i_origin: Marker3D = null
var i_type: String = ""
var i_message: String = ""

# drivng stuff
var v_driving: bool = false # if in driving mode
var v_driven_car: Node3D = null # the driven vehicle
var v_driven_seat: int = -1 # seat number
var v_seat_mkr: Marker3D = null # seat marker
var v_fcam_mkr: Marker3D = null # first person cam marker
var v_tcam_mkr: Marker3D = null # third person cam marker
var v_exit_mkr: Marker3D = null # exit location marker

# nodes used
@onready var fcam = $fcam_pivot/first_person_cam
@onready var fcam_pivot = $fcam_pivot

@onready var tcam = $tcam_pivot/third_person_spring/third_person_cam
@onready var tcam_spring = $tcam_pivot/third_person_spring
@onready var tcam_pivot = $tcam_pivot

@onready var player_mesh = $mesh
@onready var player_collision = $CollisionShape3D
@onready var camera_origin = $cam_origin

# Called when the node enters the scene tree for the first time.
func _ready():
	if enable_first_person:
		set_fcam()
	else:
		set_tcam(Vector3.ZERO, max_zoom / 2)
	
	Global.paused = false

func _unhandled_input(event):
	# release mouse on cancel event
	# should make this work with multiplayer, reduce global file as much as possible
	if Input.is_action_just_pressed("ui_cancel"):
		if Global.paused:
			# unpause
			if cam_mode == CamMode.FIRST:
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
	if event is InputEventMouseMotion and cam_mode == CamMode.FIRST:
		fcam.rotation_degrees.y -= event.relative.x * sensitivity
		fcam.rotation_degrees.x -= event.relative.y * sensitivity
		# limits for vertical rotation
		fcam.rotation_degrees.x = clamp(fcam.rotation_degrees.x, -80, 80)
		# match up mesh rotation
		player_mesh.global_rotation.y = fcam.global_rotation.y

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.paused:
		return
	
	if v_driving:
		fcam_pivot.global_transform = v_fcam_mkr.global_transform
		tcam_pivot.global_transform = v_tcam_mkr.global_transform
	
	if Input.is_action_just_pressed("zoom_out") and cam_mode == CamMode.FIRST:
		switch_ftcam()

# movement code
func _physics_process(delta):
	if Global.paused:
		return
	
	if v_driving:
		global_transform = v_seat_mkr.global_transform
		v_driven_car.update_input(Input.get_action_strength("throttle"), Input.get_action_strength("reverse"),
		Input.get_action_strength("brake"), Input.get_axis("steer_right", "steer_left"))
		if Input.is_action_just_pressed("interact"):
			exit_vehicle(v_driven_car)
		return
	
	if i_type == "car" and Input.is_action_just_pressed("interact"):
		enter_vehicle(i_object)
		return
	
	# more movement code or something
	# HACK: need to optimize/simplify
	var input_direction_2D := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3
	var input_direction_3D := Vector3(input_direction_2D.x, 0.0, input_direction_2D.y)
	
	# calculate direction 
	if cam_mode == CamMode.FIRST:
		# gets the player rotation
		direction = fcam.global_transform.basis * input_direction_3D
		direction.y = 0
	else:
		direction = tcam_spring.global_transform.basis * input_direction_3D
		direction.y = 0
		
		# 3rd person rotation code
		if direction.length() > 0.001:
			var walking_direction = atan2(direction.x,direction.z) + PI
			var new_direction = lerp_angle(player_mesh.global_rotation.y, walking_direction, player_turn_speed * delta)
			player_mesh.global_rotation.y = new_direction
			fcam.global_rotation.y = new_direction
		
	
	# normalize to 0..1 for diagonal directions
	direction = direction.normalized()
	
	if Input.is_action_pressed("crouch") and enable_crouch:
		velocity.x = direction.x * crouch_speed
		velocity.z = direction.z * crouch_speed
	elif Input.is_action_pressed("sprint") and enable_run:
		velocity.x = direction.x * run_speed
		velocity.z = direction.z * run_speed
	else:
		# apply the calculated speeds based on direction
		velocity.x = direction.x * walk_speed
		velocity.z = direction.z * walk_speed
	
	# jumping and gravity code
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_pressed("jump") and velocity.y == 0 and enable_jumping:
		velocity.y = jump_velocity
	else:
		velocity.y = 0
	
	move_and_slide()

func switch_ftcam(sync_rotation: bool = true):
	# call set_cam() to set the manually
	if sync_rotation:
		if cam_mode == CamMode.FIRST:
			# set to 3rd person
			set_tcam(fcam.global_rotation)
		else: 
			# set to 1st person
			set_fcam(tcam.global_rotation)
	else:
		if cam_mode == CamMode.FIRST:
			# set to 3rd person
			set_tcam()
		else: 
			# set to 1st person
			set_fcam()

# set to first person camera
func set_fcam(rot: Vector3 = fcam.global_rotation):
	cam_mode = CamMode.FIRST
	fcam.global_rotation = rot
	player_mesh.global_rotation.y = rot.y
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	fcam.make_current()

# set to third person camera
func set_tcam(rot: Vector3 = tcam_spring.global_rotation, length: float = min_zoom):
	cam_mode = CamMode.THIRD
	tcam_spring.global_rotation = rot
	tcam_spring.spring_length = length
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tcam.make_current()

# set the thing that player that can interact with
func set_interactable(object: Node, origin: Marker3D, type: String, message: String) -> void:
	if i_object == object:
		print("skipped setting object! type: " + i_type)
		return
	if i_object == null:
		i_object = object
		i_origin = origin
		i_type = type
		i_message = message
		print("successfully set object! type: " + type)
		return
	# pick the closest interactable
	var original_distance := global_transform.origin.distance_to(i_origin.global_transform.origin)
	var new_distance := global_transform.origin.distance_to(origin.global_transform.origin)
	if new_distance < original_distance:
		i_object = object
		i_origin = origin
		i_type = type
		i_message = message
		print("successfully set new object! type: " + i_type)

func clear_interactable(object: Node) -> void:
	if i_object == object:
		i_object = null
		i_origin = null
		i_type = ""
		i_message = ""
		print("successfully cleared object!")

# entering a vehicle
func enter_vehicle(car: RigidBody3D) -> void:
	if v_driving:
		return
	
	var seat_id: int = car.get_open_seat()
	# can't enter car if returned -1
	if seat_id < 0:
		return
	
	# try entering
	if not car.enter(self, seat_id):
		return # if returned false, cannot enter
	
	v_driving = true
	v_driven_car = car
	v_driven_seat = seat_id
	
	v_seat_mkr = car.get_seat(v_driven_seat)
	v_fcam_mkr = car.get_fcam(v_driven_seat)
	v_tcam_mkr = car.get_tcam(v_driven_seat)
	v_exit_mkr = car.get_exit(v_driven_seat)
	
	# no more moving
	velocity = Vector3.ZERO
	player_collision.disabled = true
	global_transform = v_seat_mkr.global_transform
	#player_mesh.visible = false # hide mesh

# exiting a vehicle
func exit_vehicle(car: RigidBody3D) -> void:
	if not v_driving:
		return
	
	# try exiting
	if not car.exit(v_driven_seat):
		return # if returned false, cannot exit
	
	global_position = v_exit_mkr.global_position
	global_rotation = Vector3.ZERO
	
	v_driving = false
	v_driven_car = null
	v_driven_seat = -1
	
	v_seat_mkr = null
	v_fcam_mkr = null
	v_tcam_mkr = null
	v_exit_mkr = null
	
	player_collision.disabled = false
	fcam_pivot.global_transform = camera_origin.global_transform
	tcam_pivot.global_transform = camera_origin.global_transform
	#player_mesh.visible = true # show mesh
