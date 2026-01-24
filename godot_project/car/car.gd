extends RigidBody3D

# tuned to a compact pickup truck w/ 1 row of seats
# NOT kei truck!!! legal in america!!!

## using watts to be realistic and have a dynamic top speed
@export var max_power_watts: float = 135000.0
## efficiency loss from the engine to the wheels
@export var drivechain_efficiency: float = 0.88
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
@export var wheel_radius: float = 0.45
## the length of the suspension
@export var suspension_length: float = 0.127
## spring constant per front wheel, in newtons/meter
@export var suspension_fk: float = 78000.0
## spring constant per rear wheel, in newtons/meter
@export var suspension_rk: float = 52000.0
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
## maximum torque the driver can put on the steering wheel
## in N * m
@export var steer_driver_max_torque: float = 60.2
## power assist level gain
## 0 is none, 1 is normal, >1 is easy to turn
@export var steer_power_assist: float = 1.0
## rotational intertia of the steering wheel and column
## in kg * meter^2
@export var steer_inertia: float = 0.04
## steering damping coefficient in Newton-meters * second / rad
@export var steer_damping: float = 0.5
## stiffness of the spring, the force that self centers
## Newton-meters / rad
@export var steer_stiffness: float = 8

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
# steering state
var steer_angle: float = 0.0
var steer_angle_vel: float = 0.0
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
	var vel_world: Vector3 # velocity in the world
	var speed: float # speed in the world
	var dir_long: Vector3 # forward/longitude direction
	var dir_lat: Vector3 # side to side/latitude direction
	var axis_long: float # longitude component of the velocity
	var axis_lat: float # latitiude component of the velocity
	var current_steer: float # current steer angle
	#var has_driver: bool
	func update(car: RigidBody3D) -> void:
		vel_world = car.linear_velocity
		speed = vel_world.length()
		dir_long = (-car.global_transform.basis.z).normalized()
		axis_long = vel_world.dot(dir_long) # speed along the forward direction, -1 to 1
		dir_lat = car.global_transform.basis.x.normalized()
		axis_lat = vel_world.dot(dir_lat)
		# TODO update steering system
		current_steer = car.steer_angle

class WheelData:
	# can add new data types if needed
	var state: WheelState = WheelState.new() # the wheel state object
	var ray: RayCast3D # the raycast node of the wheel
	var mesh: MeshInstance3D # the mesh node of the wheel
	var wheel_radius: float # the radius of the wheel
	var spring_k: float # the spring constant k of the suspension
	var damper_b: float # the damper constant b of the suspension
	var lat_damping: float # the lateral damping value of the tire
	var max_steer_angle: float # the max steer angle of the wheel in radians
	var spin_angle: float # the angle of the wheel rotation
	
	func _init(new_ray: RayCast3D, new_mesh: MeshInstance3D, new_radius: float, new_spring_k: float, 
	new_damper_b: float, new_lat_damping: float, steer_angle_deg: float):
		ray = new_ray
		mesh = new_mesh
		wheel_radius = new_radius
		spring_k = new_spring_k
		damper_b = new_damper_b
		lat_damping = new_lat_damping
		max_steer_angle = deg_to_rad(steer_angle_deg)

class WheelState:
	var is_grounded: bool # if the wheel is touching the ground
	var contact_point: Vector3 # point of contact of the wheel
	var contact_normal: Vector3 # normal vector from the point of contact
	var hub_pos: Vector3 # position of the hub / ray origin
	var hub_contact_dist: float # distance from the hub origin to the contact point
	var r_com_to_contact: Vector3 # radius from center of mass (com) to contact point
	var vel_contact_world: Vector3 # world velocity at contact point
	var vel_contact_normal: float # normal vector component of the world velocity at contact
	var dir_forward: Vector3 # forward and back direction of the wheel / rolling side
	var axis_forward: float # forward and back component of velocity at contact point
	var dir_side: Vector3 # side to side direction of the wheel
	var axis_side: float # side to side component of velocity at contact point
	var normal_force: float # the current normal force of the wheel
	
	func update(car: RigidBody3D, w: WheelData, c: CarState):
		is_grounded = w.ray.is_colliding()
		if not is_grounded:
			axis_forward = 0.0
			axis_side = 0.0
			vel_contact_normal = 0.0
			return
		contact_point = w.ray.get_collision_point() # where the point of contact is
		contact_normal = w.ray.get_collision_normal() # direction of the normal force
		hub_pos = w.ray.global_transform.origin # position of the wheel hub
		hub_contact_dist = hub_pos.distance_to(contact_point) # distance from the hub to the ground
		r_com_to_contact = contact_point - car.global_transform.origin # the distance from reference point to target point
		# velocity at the point in the object
		# calculated by velocity_target_point = velocity_reference_point + angular_velocity * radius
		vel_contact_world = c.vel_world + car.angular_velocity.cross(r_com_to_contact)
		# the velocity of the normal force to the velocity of the point
		vel_contact_normal = vel_contact_world.dot(contact_normal)
		# wheel directions, based on car unless front wheels
		var steer: float = clamp(c.current_steer, -w.max_steer_angle, w.max_steer_angle)
		# negative steer because its inverse
		dir_forward = c.dir_long.rotated(contact_normal, steer).normalized()
		dir_side = c.dir_lat.rotated(contact_normal, steer).normalized()
		
		axis_forward = vel_contact_world.dot(dir_forward) # speed along the forward direction, -1 to 1
		axis_side = vel_contact_world.dot(dir_side)
	
	func update_normal_force(new_normal_force: float) -> void:
		normal_force = new_normal_force

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mass = car_mass
	riders.resize(seat_mkrs.size())
	
	front_wheels = [
		WheelData.new(w_fl, w_fl_m, wheel_radius, suspension_fk, suspension_b, tire_f_lat_damping, steer_angle_max_deg),
		WheelData.new(w_fr, w_fr_m, wheel_radius, suspension_fk, suspension_b, tire_f_lat_damping, steer_angle_max_deg)]
	rear_wheels = [
		WheelData.new(w_rl, w_rl_m, wheel_radius, suspension_rk, suspension_b, tire_r_lat_damping, 0.0),
		WheelData.new(w_rr, w_rr_m, wheel_radius, suspension_rk, suspension_b, tire_r_lat_damping, 0.0)]
	all_wheels = front_wheels + rear_wheels
	state = CarState.new()
	# set the raycast lengths
	for w in all_wheels:
		w.ray.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	
	# enter area interactable
	enter_area.body_entered.connect(_body_entered)
	enter_area.body_exited.connect(_body_exited)

# movement code
func _physics_process(delta: float):
	state.update(self) # update car state
	_update_steering(delta) # update steering
	for w in all_wheels: # update all wheel rays and states
		w.ray.force_raycast_update()
		w.state.update(self, w, state)
	# update driver status
	var has_driver: bool = riders.size() > 0 and riders[0] != null
	
	for w in all_wheels:
		var normal_force = _apply_suspension(w, w.state)
		w.state.update_normal_force(normal_force) # update wheel state with the new normal force
		_apply_tire_forces(w, w.state) # apply the basic tire grip and stuff
		var steer: float = clamp(state.current_steer, -w.max_steer_angle, w.max_steer_angle)
		var omega := 0.0 # angular velocity from rolling
		if w.state.is_grounded:
			omega = w.state.axis_forward / max(0.001, w.wheel_radius)
		w.spin_angle = wrapf(w.spin_angle + omega * delta, -TAU, TAU)
		w.mesh.rotation = Vector3(-w.spin_angle, steer, PI/2)
	
	if has_driver:
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
	if state.speed > 0.01:
		_apply_drag_force(state)
		for w in all_wheels:
			_apply_roll_force(w.state, all_wheels.size())

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
	if not ws.is_grounded:
		# no force applied
		w.mesh.position.y = -suspension_length
		return 0.0
	
	# the current spring length should be the total distance - wheel radius
	var spring_length := ws.hub_contact_dist - w.wheel_radius
	
	w.mesh.position.y = -spring_length
	
	# how much the spring is compressed
	var x := suspension_length - spring_length
	x = max(x, 0.0)
	
	# hookes law, force = spring_constant * displacement_x
	var spring_force := x * w.spring_k
	# damping force formula, force = damping_coefficient * velocity
	var damper_force := w.damper_b * -ws.vel_contact_normal
	
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
	apply_force(ws.contact_normal * total_force, ws.r_com_to_contact)
	DebugDraw3D.draw_arrow_ray(ws.contact_point, total_force * ws.contact_normal * 0.001, 1,Color(0.75, 0.423, 0.94, 1.0),0.1)
	return total_force # returns the final normal force essentially

func _apply_tire_forces(w: WheelData, ws: WheelState) -> float:
	if not ws.is_grounded:
		return 0.0
	
	# calculated grip force of the tire itself
	var tire_grip_force := -ws.axis_side * w.lat_damping
	# the max grip force allowed, which is the force of friction
	var tire_friction_force := tire_lat_cof * ws.normal_force
	# final force calculated
	var total_lat_force: float = clamp(tire_grip_force, -tire_friction_force, tire_friction_force)
	
	apply_force(ws.dir_side * total_lat_force, ws.r_com_to_contact)
	
	# debug
	DebugDraw3D.draw_arrow_ray(ws.contact_point, total_lat_force * ws.dir_side * 0.001, 1,Color(0.776, 0.94, 0.423, 1.0),0.1)
	
	return total_lat_force

func _apply_engine_forces(car: CarState, ws: WheelState, num_wheels: int, drive_input: float) -> float:
	if not ws.is_grounded:
		return 0.0
	if abs(drive_input) > deadzone:
		var total_power = max_power_watts * drivechain_efficiency
		# using formula engine_force = (power * input) / velocity
		var throttle_force = (total_power * drive_input) / max(min_speed, car.speed)
		throttle_force /= num_wheels # split force amongst all wheels
		var max_force = tire_long_cof * ws.normal_force
		throttle_force = clamp(throttle_force, -max_force, max_force)
		apply_force(throttle_force * ws.dir_forward, ws.r_com_to_contact)
		return throttle_force
	else:
		# coasting force, no pedals down
		var engine_force = -engine_brake_force_max * car.speed / (car.speed + engine_brake_fade_speed) * sign(ws.axis_forward)
		engine_force /= num_wheels # split force amongst all wheels
		apply_force(engine_force * ws.dir_forward, ws.r_com_to_contact)
		return engine_force

func _apply_drag_force(car: CarState) -> float:
	var drag_force: float = air_density * car.speed * car.speed * drag_area * drag_coef / 2
	apply_central_force(car.dir_long * drag_force * -sign(car.axis_long))
	return drag_force

func _apply_roll_force(ws: WheelState, num_wheels: int) -> float:
	if not ws.is_grounded:
		return 0.0
	var roll_force = rolling_resistance_coef * total_mass * gravity
	roll_force /= num_wheels
	apply_force(ws.dir_forward * roll_force * -sign(ws.axis_forward), ws.r_com_to_contact)
	return roll_force

func _apply_brake_force(ws: WheelState, num_wheels: int, brake_input: float) -> float:
	if not ws.is_grounded:
		return 0.0
	var brake_force = max_brake_force * brake_input
	brake_force /= num_wheels
	apply_force(ws.dir_forward * brake_force * -sign(ws.axis_forward), ws.r_com_to_contact)
	return brake_force

func _update_steering(delta: float) -> void:
	var max_angle := deg_to_rad(steer_angle_max_deg)
	var input: float = clamp(i_steer, -1.0, 1.0)
	# the target angle that the player wants
	var target_angle := input * max_angle
	# the steering curve, so that steering is heavier at speed
	var speed_gain := 1.0 / (1.0 + state.speed / 18.0)
	# difference between current angle and target angle
	var error := target_angle - steer_angle
	var driver_torque := steer_stiffness * error - steer_damping * steer_angle_vel
	# still self center when no input 
	var assist_floor := 0.35
	var authority: float = lerp(assist_floor, 1.0, abs(input))
	# max amount of torque on the steering wheel
	var max_torque := steer_driver_max_torque * steer_power_assist * speed_gain * authority
	var total_torque: float = clamp(driver_torque, -max_torque, max_torque)
	# calculate steer angle and steer angle velocity
	var s_inertia: float = max(steer_inertia, 1e-4)
	var ang_accel := total_torque / s_inertia
	
	steer_angle_vel += ang_accel * delta
	steer_angle += steer_angle_vel * delta
	
	if steer_angle > max_angle:
		steer_angle = max_angle
		# no more velocity if we are pushing to the max angle already
		if steer_angle_vel > 0.0:
			steer_angle_vel = 0.0
	elif steer_angle < -max_angle:
		steer_angle = -max_angle
		# no more velocity if we are pushing to the max angle already
		if steer_angle_vel < 0.0:
			steer_angle_vel = 0.0

## driving input maps are: throttle, reverse, steer_left, steer_right, brake
## these should all go from 0 to 1
func update_input(throttle: float, reverse: float, brake: float, steer: float) -> bool:
	i_throttle = clamp(throttle, 0.0, 1.0)
	i_reverse = clamp(reverse, 0.0, 1.0)
	i_brake = clamp(brake, 0.0, 1.0)
	i_drive = clamp(i_throttle - i_reverse, -1.0, 1.0) # the overall throttle or reverse input
	i_steer = clamp(steer, -1.0, 1.0)
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
