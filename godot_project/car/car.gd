extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats
# NOT kei truck!!! legal in america!!!

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
@onready var seat_mkrs: Array[Marker3D] = [$markers/seat_0]
@onready var exit_mkrs: Array[Marker3D] = [$markers/exit_0]
@onready var fcam_mkrs: Array[Marker3D] = [$markers/fcam_0]
@onready var tcam_mkrs: Array[Marker3D] = [$markers/tcam_0]
@onready var enter_area = $enter_area
@onready var enter_orig = $enter_area/enter_origin
#@onready var car_mesh = $mesh

var riders: Array[CharacterBody3D] = []

# Called when the node enters the scene tree for the first time.
func _ready():
	riders.resize(seat_mkrs.size())
	enter_area.body_entered.connect(_body_entered)
	enter_area.body_exited.connect(_body_exited)

# movement code
func _physics_process(delta):
	if riders.size() == 0 or riders[0] == null:
		return
	# NOTE
	# driving input maps are: throttle, reverse, steer_left, steer_right, brake
	# other include: interact
	# these should all go from 0 to 1
	var throttle_input = Input.get_action_strength("throttle")
	var reverse_input = Input.get_action_strength("reverse")
	var steer_input = Input.get_axis("steer_left", "steer_right")
	var brake_input = Input.get_action_strength("brake")
	
	var current_velocity := linear_velocity
	var current_speed := current_velocity.length()
	var car_direction := -global_transform.basis.z
	
	# forward throttle
	if throttle_input > deadzone:
		pass
	
	# reverse throttle
	# reverse will simply apply a negative force to 'brake'
	# instead of braking then reverse
	if reverse_input > deadzone:
		pass
	
	# steer
	if abs(steer_input) > deadzone:
		pass
	
	# brake
	if brake_input > deadzone:
		pass

func _body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.set_interactable(self, enter_orig, "car", "Enter")

func _body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.clear_interactable(self)

# gets an open seat in the car, if there is any
# returns -1 for full car
func get_open_seat() -> int:
	for i in riders.size():
		if riders[i] == null:
			return i
	return -1

# lets a player enter the car at the specified seat number
func enter(player: CharacterBody3D, seat: int) -> bool:
	# if seat is in range
	if seat < 0 or seat >= riders.size():
		return false
	if riders[seat] != null:
		return false
	
	riders[seat] = player
	return true

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
	return seat_mkrs[seat]
# gets the marker of the first person camera
func get_fcam(seat: int) -> Marker3D:
	return fcam_mkrs[seat]
# gets the marker of the third person camera
func get_tcam(seat: int) -> Marker3D:
	return tcam_mkrs[seat]
# gets the marker of the exit location
func get_exit(seat: int) -> Marker3D:
	return exit_mkrs[seat]
