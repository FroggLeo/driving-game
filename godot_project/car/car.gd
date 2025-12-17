extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats
# NOT kei truck!!! legal in america!!!

# using watts to be realistic and have a dynamic top speed
@export var max_power_watts: float = 35000.0
# efficiency loss from the engine to the wheels
@export var drivechain_efficiency: float = 0.85
# the max traction allowed
# so that the traction isn't infinite at 0 speed
@export var max_tractive_force: float = 4500.0
# the minimum speed that is calculated, prevents insanely large numbers
@export var min_speed: float = 1.0
# maximum force when braking
@export var max_brake_force: float = 9000.0

# natural engine brake force when the petal is lifted
# simple modeling using this function:
# force = -brake_force_max * v / (v + brake_fade_speed)
@export var engine_brake_force_max: float = 1000.0
@export var engine_brake_fade_speed: float = 25.0
# force of the roll is the mass * coef * gravity
@export var rolling_resistance_coef: float = 0.012
# aerodynamic drag constant
@export var drag_coef: float = 0.55
@export var air_density: float = 1.225

# mass of the truck in kg
@export var car_mass: float = 1700.0
# coefficient of friction of the wheels
# force laterally, front and back
@export var lat_cof: float = 0.75
# force left and right
@export var long_cof: float = 0.85
# gravity
@export var gravity: float = 9.81

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
var total_mass := car_mass # add item masses here too

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mass = car_mass
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
	var throttle_input := Input.get_action_strength("throttle")
	var reverse_input := Input.get_action_strength("reverse")
	var steer_input := Input.get_axis("steer_left", "steer_right")
	var brake_input := Input.get_action_strength("brake")
	
	var v := linear_velocity
	var s := v.length()
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	# speed along the forward direction, -1 to 1
	var v_forward := v.dot(forward)
	
	# the overall drive input
	var drive_input := throttle_input - reverse_input
	
	# steer
	if abs(steer_input) > deadzone and abs(v_forward) > 0.1:
		pass
		
	
	# forward and reverse throttle
	# reverse will simply apply a negative force to 'brake'
	# instead of braking then reverse
	var drive_force: float = 0.0
	if abs(drive_input) > deadzone:
		# using formula engine_force = (power * input) / velocity
		var total_power = max_power_watts * drivechain_efficiency
		drive_force = (total_power * drive_input) / max(min_speed, s)
		#print("calculated drive input: " + str(drive_input))
		#print("calculated drive force: " + str(drive_force))
	
	# brakes
	var brake_force: float = 0.0
	if brake_input > deadzone:
		brake_force = max_brake_force * brake_input * -sign(v_forward)
	
	# coasting force, no pedals down
	var engine_force: float = 0.0
	if abs(drive_input) <= deadzone and abs(v_forward) > 0.01:
		engine_force = -engine_brake_force_max * s / (s + engine_brake_fade_speed)
	
	# rolling resistance and aerodynamic drag
	var resist_force: float = 0.0
	if s > 0.01:
		# drag calculation based on the formula
		var drag_force = air_density * s * s * 4 * drag_coef / 2
		var roll_force = rolling_resistance_coef * total_mass * gravity
		# -sign(v_forward) allows us to apply the force in the opposite direction of the movement
		resist_force = (drag_force + roll_force) * -sign(v_forward)
	
	# add all da forces
	var total_long_force = drive_force + brake_force + engine_force + resist_force
	# apply the force
	apply_central_force(forward * total_long_force)

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
