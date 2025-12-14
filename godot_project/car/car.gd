extends RigidBody3D

@export var max_speed: float = 20.0

@export var throttle_force: float = 2000.0
@export var reverse_force: float = 700.0
@export var braking_force: float = 1000.0
@export var rolling_force: float = 400.0

@export var deadzone: float = 0.01

# change in steering per second, steering goes from -1 to 1
@export var steering_speed: float = 4.0

@export var gravity: float = 9.81

var driver: Node = null

# nodes used
@onready var driver_cam = $markers/driver_cam
@onready var player_mesh = $mesh
@onready var exit_location = $markers/exit_loc
@onready var driver_location = $markers/driver_loc
@onready var enter_area = $enter_area

# Called when the node enters the scene tree for the first time.
func _ready():
	# add to a group so it can be interacted by the player
	add_to_group("interactable")

# movement code
func _physics_process(delta):
	if Global.paused or driver == null:
		return
	
	# exit the car
	if Input.is_action_just_pressed("interact"):
		exit()
		return
	
	# NOTE
	# driving input maps are: throttle, reverse, steer_left, steer_right, brake
	# other include: interact
	# these should all go from 0 to 1
	var throttle_input = Input.get_action_strength("throttle")
	var reverse_input = Input.get_action_strength("brake")
	var steer_input = Input.get_axis("steer_left", "steer_right")
	var brake_input = Input.get_action_strength("brake")
	
	var current_velocity := linear_velocity
	var current_speed := current_velocity.length()
	var forward := -global_transform.basis.z
	
	if throttle_input > deadzone and current_speed < max_speed:
		apply_central_force(forward * throttle_input * throttle_force)
		
	

func get_open_seat() -> int:
	if driver == null:
		return 0
	return -1

# TODO make it work
func enter(player: CharacterBody3D, seat: int) -> bool:
	# if driver is free
	if driver == null and seat == 0:
		driver = player
		return true
	
	# implement passenger code here
	# return false for unable to enter/already full
	
	
	
	return false

func get_seat(seat: int) -> Marker3D:
	if seat == 0:
		return driver_location
	else:
		return driver_location

func get_fcamera(seat: int) -> Marker3D:
	if seat == 0:
		return driver_cam
	else:
		return driver_cam

func get_tcamera(seat: int) -> Marker3D:
	if seat == 0:
		return driver_cam
	else:
		return driver_cam

func exit() -> void:
	# set driver to nothing
	driver = null
