extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats

# using watts to be realistic and have a dynamic top speed
@export var max_power_watts: float = 35000.0
# efficiency loss from the engine to the wheels
@export var drivechain_efficiency: float = 0.85
# the max traction allowed
# so that the traction isn't infinite at 0 speed
@export var max_tractive_force = 4500.0
# maximum force when braking
@export var max_brake_force: float = 9000.0
# natural engine brake force when the petal is lifted
@export var engine_brake_force: float = 300.0

# force of the roll is the mass of the car * coef * gravity
@export var rolling_resistance_coef: float = 200.0
# aerodynamic drag constant
@export var drag_coef: float = 0.6

# mass of the truck in kg
@export var car_mass: float = 1700.0
# coefficient of friction of the wheels
# force laterally, front and back
@export var lat_cof: float = 0.75
# force left and right
@export var long_cof: float = 0.85
# gravity
@export var gravity: float = 9.81

# change in steering per second, steering goes from -1 to 1
# steering speed when the car is stopped
@export var steering_speed_00: float = 1.0
# steering speed at 30m/s
@export var steering_speed_30: float = 0.4

# dedzone of the input
@export var deadzone: float = 0.01

# nodes used
# arrays should be same length
@onready var seats: Array[Marker3D] = [$markers/seat_0]
@onready var fcams: Array[Marker3D] = [$markers/fcam_0]
@onready var tcams: Array[Marker3D] = [$markers/tcam_0]
#@onready var car_mesh = $mesh
@onready var exit_location = $markers/exit_loc
@onready var enter_area = $enter_area

var riders: Array[CharacterBody3D] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	# add to a group so it can be interacted by the player
	add_to_group("interactable")

# movement code
func _physics_process(delta):
	if Global.paused:
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
	
	# forward throttle
	if throttle_input > deadzone:
		apply_central_force(forward * throttle_input)
	
	

# gets an open seat in the car, if there is any
# returns -1 for full car
func get_open_seat() -> int:
	if riders[0] == null:
		return 0
	
	return -1

# lets a player enter the car at the specified seat number
func enter(player: CharacterBody3D, seat: int) -> bool:
	# if seat is in range
	if seat < 0 or seat >= riders.size():
		return false
	if riders[seat] == null:
		return false
	
	# NOTE seat locking should be on car or player side?
	
	# TODO implement passenger code here
	# return false for unable to enter/already full
	
	return false

# drops the player at specified seat
func exit(seat: int) -> bool:
	if seat < 0 or seat >= riders.size():
		return false
	if riders[seat] == null:
		return false
	
	riders[seat] = null
	return true

# gets the marker of the specified seat
func get_seat(seat: int) -> Marker3D:
	return seats[seat]
# gets the marker of the first person camera
func get_fcam(seat: int) -> Marker3D:
	return fcams[seat]
# gets the marker of the third person camera
func get_tcam(seat: int) -> Marker3D:
	return tcams[seat]
