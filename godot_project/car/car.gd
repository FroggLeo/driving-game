extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats
# NOT kei truck!!! legal in america!!!

## using watts to be realistic and have a dynamic top speed
@export var max_power_watts: float = 135000.0
## efficiency loss from the engine to the wheels
@export var drivechain_efficiency: float = 0.88
## the max traction allowed
## so that the traction isn't infinite at 0 speed
@export var max_tractive_force: float = 12000.0
## the minimum speed that is calculated, prevents insanely large numbers
@export var min_speed: float = 1.0
## maximum force when braking
@export var max_brake_force: float = 17000.0

## natural engine brake force when the petal is lifted
## simple modeling using this function:
## force = -brake_force_max * v / (v + brake_fade_speed)
@export var engine_brake_force_max: float = 1600.0
## how much the engine braking fades out
@export var engine_brake_fade_speed: float = 25.0
## force of the roll is the mass * coef * gravity
@export var rolling_resistance_coef: float = 0.012
## aerodynamic drag constant
@export var drag_coef: float = 0.42
## drag area, part of the drag formula
@export var drag_area: float = 2.9
## density of the air to calculate drag
@export var air_density: float = 1.225

## mass of the truck in kg
@export var car_mass: float = 1700.0
## coefficient of friction of the wheels
## friction force laterally, front and back
@export var tire_lat_cof: float = 0.80
## friction force left and right
@export var tire_long_cof: float = 0.90
## lateral damping coefficient of the front tire
## not real value, just tune to vibes
@export var tire_f_lat_damping: float = 5500.0
## lateral damping coefficient of the rear tire
## not real value, just tune to vibes
@export var tire_r_lat_damping: float = 7500.0
## gravity
@export var gravity: float = 9.81

## radius of the wheel in meters
@export var wheel_radius: float = 0.33
## the length of the suspension
@export var suspension_length: float = 0.30
## spring constant per front wheel, in newtons/meter
@export var suspension_fk: float = 40000.0
## spring constant per rear wheel, in newtons/meter
@export var suspension_rk: float = 37000.0
## damping of the suspension, shock absorbers
## in newton-seconds / meter
@export var suspension_b: float = 3500.0

## when should the force of the bump be applied?
## percentage of the suspension length, 0..1
## example: 0.8, bump force starts in the last 20% compression
@export var suspension_bump_start: float = 0.78
## spring constant of the bump stop
@export var suspension_bump_k: float = 270000.0

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

# wheel stuff
# wheel raycasts
@onready var w_fl: RayCast3D = $wheels/fl
@onready var w_fr: RayCast3D = $wheels/fr
@onready var w_rl: RayCast3D = $wheels/rl
@onready var w_rr: RayCast3D = $wheels/rr
# wheel meshes
@onready var w_fl_m: MeshInstance3D = $wheels/fl/mesh_fl
@onready var w_fr_m: MeshInstance3D = $wheels/fr/mesh_fr
@onready var w_rl_m: MeshInstance3D = $wheels/rl/mesh_rl
@onready var w_rr_m: MeshInstance3D = $wheels/rr/mesh_rr

# wheel groups
var front_wheels: Array[WheelData]
var rear_wheels: Array[WheelData]
var all_wheels: Array[WheelData]
# car state
var state: CarState
# car properties
var riders: Array[CharacterBody3D] = []
var total_mass := car_mass # add item masses here too
# inputs
var i_throttle: float = 0.0
var i_reverse: float = 0.0
var i_drive: float = 0.0
var i_brake: float = 0.0
var i_steer: float = 0.0

class CarState:
	var v: Vector3
	var s: float
	var forward: Vector3
	var v_forward: float
	var right: Vector3
	var v_right: float
	var current_steer: float
	#var has_driver: bool
	func update(car: RigidBody3D) -> void:
		v = car.linear_velocity
		s = v.length()
		forward = (-car.global_transform.basis.z).normalized()
		v_forward = v.dot(forward) # speed along the forward direction, -1 to 1
		right = car.global_transform.basis.x.normalized()
		v_right = v.dot(right)
		# TODO update steering system
		current_steer = car.i_steer * deg_to_rad(car.steer_angle_max_deg)

class WheelData:
	# can add new data types if needed
	var state: WheelState = WheelState.new()
	var ray: RayCast3D
	var mesh: MeshInstance3D
	var radius: float
	var spring_k: float
	var spring_b: float
	var lat_damp: float
	var max_steer_angle: float
	
	func _init(new_ray: RayCast3D, new_mesh: MeshInstance3D, new_radius: float, new_spring_k: float, 
	new_spring_b: float, new_lat_damp: float, steer_angle_deg: float):
		ray = new_ray
		mesh = new_mesh
		radius = new_radius
		spring_k = new_spring_k
		spring_b = new_spring_b
		lat_damp = new_lat_damp
		max_steer_angle = deg_to_rad(steer_angle_deg)

class WheelState:
	var on_floor: bool
	var point: Vector3
	var normal: Vector3
	var pos: Vector3
	var dist: float
	var radius: Vector3
	var velocity_point: Vector3
	var velocity_normal: float
	var forward: Vector3
	var v_forward: float
	var right: Vector3
	var v_right: float
	
	func update(car: RigidBody3D, w: WheelData, c: CarState):
		on_floor = w.ray.is_colliding()
		#if on_floor:
		point = w.ray.get_collision_point() # where the point of contact is
		normal = w.ray.get_collision_normal() # direction of the normal force
		pos = w.ray.global_transform.origin # position of the wheel hub
		dist = pos.distance_to(point) # distance from the hub to the ground
		radius = point - car.global_transform.origin # the distance from reference point to target point
		# velocity at the point in the object
		# calculated by velocity_target_point = velocity_reference_point + angular_velocity * radius
		velocity_point = c.v + car.angular_velocity.cross(radius)
		# the velocity of the normal force to the velocity of the point
		velocity_normal = velocity_point.dot(normal)
		# wheel directions, based on car unless front wheels
		forward = c.forward.rotated(normal, c.current_steer).normalized()
		right = c.right.rotated(normal, c.current_steer).normalized()
		
		v_forward = velocity_point.dot(forward) # speed along the forward direction, -1 to 1
		v_right = velocity_point.dot(right)

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mass = car_mass
	riders.resize(seat_mkrs.size())
	
	# set the raycast lengths
	for w in all_wheels:
		w.ray.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	
	front_wheels = [
		WheelData.new(w_fl, w_fl_m, wheel_radius, suspension_fk, suspension_b, tire_f_lat_damping, steer_angle_max_deg),
		WheelData.new(w_fr, w_fr_m, wheel_radius, suspension_fk, suspension_b, tire_f_lat_damping, steer_angle_max_deg)]
	rear_wheels = [
		WheelData.new(w_rl, w_rl_m, wheel_radius, suspension_rk, suspension_b, tire_r_lat_damping, 0.0),
		WheelData.new(w_rr, w_rr_m, wheel_radius, suspension_rk, suspension_b, tire_r_lat_damping, 0.0)]
	all_wheels = front_wheels + rear_wheels
	state = CarState.new()
	
	# enter area interactable
	enter_area.body_entered.connect(_body_entered)
	enter_area.body_exited.connect(_body_exited)

# movement code
func _physics_process(_delta: float):
	#if riders.size() == 0 or riders[0] == null:
	#	return
	
	state.update(self)
	for w in all_wheels:
		w.state.update(self, w, state)
	
	# REFACTORED LONGITUDINAL FORCES LOGIC
	
	if riders[0] != null:
		if i_brake > deadzone:
			# brakes
			# braking overrides throttle
			for w in all_wheels:
				_apply_brake_force(w.state, all_wheels.size(), i_brake)
		else:
			# forward and reverse throttle
			# reverse will simply apply a negative force to 'brake'
			# instead of braking then reverse
			for w in rear_wheels:
				_apply_engine_forces(state, w.state, rear_wheels.size(), i_drive)
	
	# rolling resistance and aerodynamic drag
	if state.s > 0.01:
		_apply_drag_force(state)
		for w in all_wheels:
			_apply_roll_force(w.state, all_wheels.size())
	
	# WHEEL STUFF
	
	for w in all_wheels:
		w.ray.force_raycast_update()
	for w in front_wheels:
		w.mesh.rotation.y = -state.current_steer
	
	for w in all_wheels:
		var normal_force = _apply_suspension(w, w.state)
		_apply_tire_forces(w, w.state, normal_force)

# when a body enters the enter area
# underscore is for internal function
func _body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.set_interactable(self, enter_orig, "car", "Enter")

# when a body exits the enter area
func _body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.clear_interactable(self)

func _apply_suspension(w: WheelData, ws: WheelState) -> float:
	if not ws.on_floor:
		# no force applied
		w.mesh.position.y = -suspension_length + w.radius
		return 0.0
	
	# the current spring length should be the total distance - wheel radius
	var spring_length := ws.dist - w.radius
	
	w.mesh.position.y = spring_length # not working uh oh
	
	# how much the spring is compressed
	var x := suspension_length - spring_length
	x = max(x, 0.0)
	
	# hookes law, force = spring_constant * displacement_x
	var spring_force := x * w.spring_k
	# damping force formula, force = damping_coefficient * velocity
	var damper_force := w.spring_b * -ws.velocity_normal
	
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
	apply_force(ws.normal * total_force, ws.radius)
	DebugDraw3D.draw_arrow_ray(ws.point, total_force * ws.normal * 0.001, 1,Color(0.75, 0.423, 0.94, 1.0),0.1)
	return total_force # returns the final normal force essentially

func _apply_tire_forces(w: WheelData, ws: WheelState, normal_force: float) -> float:
	if not ws.on_floor:
		return 0.0
	
	# calculated grip force of the tire itself
	var tire_grip_force := -ws.v_right * w.lat_damp
	# the max grip force allowed, which is the force of friction
	var tire_friction_force := tire_lat_cof * normal_force
	# final force calculated
	var total_lat_force: float = clamp(tire_grip_force, -tire_friction_force, tire_friction_force)
	
	apply_force(ws.right * total_lat_force, ws.radius)
	
	# debug
	DebugDraw3D.draw_arrow_ray(ws.point, total_lat_force * ws.right * 0.001, 1,Color(0.776, 0.94, 0.423, 1.0),0.1)
	
	return total_lat_force

func _apply_engine_forces(car: CarState, ws: WheelState, num_wheels: int, drive_input: float) -> float:
	if drive_input > deadzone:
		var total_power = max_power_watts * drivechain_efficiency
		# using formula engine_force = (power * input) / velocity
		var throttle_force = (total_power * drive_input) / max(min_speed, car.s)
		throttle_force /= num_wheels # split force amongst all wheels
		apply_force(throttle_force * ws.forward, ws.radius)
		return throttle_force
	else:
		# coasting force, no pedals down
		var engine_force = -engine_brake_force_max * car.s / (car.s + engine_brake_fade_speed) * sign(ws.v_forward)
		engine_force /= num_wheels # split force amongst all wheels
		apply_force(engine_force * ws.forward, ws.radius)
		return engine_force

func _apply_drag_force(car: CarState) -> float:
	var drag_force: float = air_density * car.s * car.s * drag_area * drag_coef / 2
	apply_central_force(car.forward * drag_force * -sign(car.v_forward))
	return drag_force

func _apply_roll_force(ws: WheelState, num_wheels: int) -> float:
	var roll_force = rolling_resistance_coef * total_mass * gravity
	roll_force /= num_wheels
	apply_force(ws.forward * roll_force * -sign(ws.v_forward), ws.radius)
	return roll_force

func _apply_brake_force(ws: WheelState, num_wheels: int, brake_input: float) -> float:
	var brake_force = max_brake_force * brake_input
	brake_force /= num_wheels
	apply_force(brake_force * -sign(ws.v_forward), ws.radius)
	return brake_force

## driving input maps are: throttle, reverse, steer_left, steer_right, brake
## these should all go from 0 to 1
func update_input(throttle: float, reverse: float, brake: float, steer: float) -> bool:
	i_throttle = throttle
	i_reverse = reverse
	i_brake = brake
	i_drive = i_throttle - i_reverse # the overall throttle or reverse input
	i_steer = steer
	return true # inputs accepted

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
