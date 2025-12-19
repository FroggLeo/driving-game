extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats
# NOT kei truck!!! legal in america!!!

## using watts to be realistic and have a dynamic top speed
@export var max_power_watts: float = 35000.0
## efficiency loss from the engine to the wheels
@export var drivechain_efficiency: float = 0.85
## the max traction allowed
## so that the traction isn't infinite at 0 speed
@export var max_tractive_force: float = 4500.0
## the minimum speed that is calculated, prevents insanely large numbers
@export var min_speed: float = 1.0
## maximum force when braking
@export var max_brake_force: float = 9000.0

## natural engine brake force when the petal is lifted
## simple modeling using this function:
## force = -brake_force_max * v / (v + brake_fade_speed)
@export var engine_brake_force_max: float = 1000.0
@export var engine_brake_fade_speed: float = 25.0
## force of the roll is the mass * coef * gravity
@export var rolling_resistance_coef: float = 0.012
## aerodynamic drag constant
@export var drag_coef: float = 0.55
## drag area, part of the drag formula
@export var drag_area: float = 4.0
## density of the air to calculate drag
@export var air_density: float = 1.225

## mass of the truck in kg
@export var car_mass: float = 1700.0
## coefficient of friction of the wheels
## friction force laterally, front and back
@export var lat_cof: float = 0.75
## friction force left and right
@export var long_cof: float = 0.85
## gravity
@export var gravity: float = 9.81

## radius of the wheel in meters
@export var wheel_radius: float = 0.25
## the length of the suspension
@export var suspension_length: float = 0.35
## spring constant per wheel, in newtons/meter
@export var suspension_k: float = 30000.0
## damping of the suspension, shock absorbers
## in newton-seconds / meter
@export var suspension_b: float = 3000.0

## when should the force of the bump be applied?
## percentage of the suspension length, 0..1
## example: 0.8, bump force starts in the last 20% compression
@export var suspension_bump_start: float = 0.8
## spring constant of the bump stop
@export var suspension_bump_k: float = 300000.0

## maximum steer angle of the car
@export var steer_angle_max_deg: float = 30.0

## dedzone of the input
## amounts below this will not be considered
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
# wheels
@onready var w_fl: RayCast3D = $wheels/fl
@onready var w_fr: RayCast3D = $wheels/fr
@onready var w_rl: RayCast3D = $wheels/rl
@onready var w_rr: RayCast3D = $wheels/rr

var riders: Array[CharacterBody3D] = []
var total_mass := car_mass # add item masses here too

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mass = car_mass
	riders.resize(seat_mkrs.size())
	w_fl.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	w_fr.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	w_rl.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	w_rr.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	enter_area.body_entered.connect(_body_entered)
	enter_area.body_exited.connect(_body_exited)

# movement code
func _physics_process(delta):
	#if riders.size() == 0 or riders[0] == null:
	#	return
	# NOTE
	# driving input maps are: throttle, reverse, steer_left, steer_right, brake
	# other include: interact
	# these should all go from 0 to 1
	# HACK need to move controls to player side
	var throttle_input := Input.get_action_strength("throttle")
	var reverse_input := Input.get_action_strength("reverse")
	var brake_input := Input.get_action_strength("brake")
	var drive_input := throttle_input - reverse_input # the overall throttle or reverse input
	var steer_input := Input.get_axis("steer_left", "steer_right")
	
	var v := linear_velocity
	var s := v.length()
	var forward := (-global_transform.basis.z).normalized()
	var v_forward := v.dot(forward) # speed along the forward direction, -1 to 1
	var right := global_transform.basis.x.normalized()
	var v_right := v.dot(right)
	
	var steer_angle := deg_to_rad(steer_angle_max_deg) * steer_input
	
	# WHEEL STUFF
	
	w_fl.force_raycast_update()
	w_fr.force_raycast_update()
	w_rl.force_raycast_update()
	w_rr.force_raycast_update()
	
	# THROTTLE STUFF
	
	# forward and reverse throttle
	# reverse will simply apply a negative force to 'brake'
	# instead of braking then reverse
	var drive_force: float = 0.0
	if abs(drive_input) > deadzone and riders[0] != null:
		# using formula engine_force = (power * input) / velocity
		var total_power = max_power_watts * drivechain_efficiency
		drive_force = (total_power * drive_input) / max(min_speed, s)
		#print("calculated drive input: " + str(drive_input))
		#print("calculated drive force: " + str(drive_force))
	
	# brakes
	var brake_force: float = 0.0
	if brake_input > deadzone and riders[0] != null:
		brake_force = max_brake_force * brake_input * -sign(v_forward)
	
	# coasting force, no pedals down
	var engine_force: float = 0.0
	if (abs(drive_input) <= deadzone or riders[0] == null) and abs(v_forward) > 0.01:
		engine_force = -engine_brake_force_max * s / (s + engine_brake_fade_speed) * sign(v_forward)
	
	# rolling resistance and aerodynamic drag
	var resist_force: float = 0.0
	if s > 0.01:
		# drag calculation based on the formula
		var drag_force = air_density * s * s * drag_area * drag_coef / 2
		var roll_force = rolling_resistance_coef * total_mass * gravity
		# -sign(v_forward) allows us to apply the force in the opposite direction of the movement
		resist_force = (drag_force + roll_force) * -sign(v_forward)
	
	# add all da forces
	var total_long_force = drive_force + brake_force + engine_force + resist_force
	# apply the force
	apply_central_force(forward * total_long_force)
	_apply_suspension(w_fl, delta)
	_apply_suspension(w_fr, delta)
	_apply_suspension(w_rl, delta)
	_apply_suspension(w_rr, delta)

# when a body enters the enter area
# underscore is for internal function
func _body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.set_interactable(self, enter_orig, "car", "Enter")

# when a body exits the enter area
func _body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.clear_interactable(self)

func _apply_suspension(wheel: RayCast3D, delta: float) -> float:
	if not wheel.is_colliding():
		# no force applied
		return 0.0
	
	var point := wheel.get_collision_point() # where the point of contact is
	var normal := wheel.get_collision_normal() # direction of the normal force
	var pos := wheel.global_transform.origin # position of the wheel hub
	var dist := pos.distance_to(point) # distance from the hub to the ground
	
	# the current spring length should be the total distance - wheel radius
	var spring_length := dist - wheel_radius
	
	# how much the spring is compressed
	var x := suspension_length - spring_length
	x = max(x, 0.0)
	
	# the vector from the center of mass to the point of contact
	# or also the distance from reference point to target point
	var radius := point - global_transform.origin
	# velocity at the point in the object
	# calculated by velocity_target_point = velocity_reference_point + angular_velocity * radius
	var velocity_point := linear_velocity + angular_velocity.cross(radius)
	# the velocity of the normal force to the velocity of the point
	var velocity_normal := velocity_point.dot(normal)
	
	# hookes law, force = spring_constant * displacement_x
	var spring_force := x * suspension_k
	# damping force formula, force = damping_coefficient * velocity
	var damper_force := suspension_b * -velocity_normal
	
	# the bump / really stiff spring
	var bump_force := 0.0
	var bump_start := suspension_length * suspension_bump_start
	if x > bump_start:
		var bump_x := x - bump_start
		#var bump_percent := bump_x / (suspension_length - bump_start)
		bump_force = suspension_bump_k * bump_x * bump_x
	
	var total_force : float = max(0.0, spring_force + damper_force + bump_force)
	
	# applies the force at normal direction, with the total force
	# at the distance away from center of gravity (radius)
	apply_force(normal * total_force, radius)
	return total_force

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
