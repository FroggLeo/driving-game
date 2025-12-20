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
@onready var front_wheels: Array[RayCast3D] = [w_fl, w_fr]
@onready var rear_wheels: Array[RayCast3D] = [w_rl, w_rr]
@onready var all_wheels: Array[RayCast3D] = front_wheels + rear_wheels
@onready var wheel_meshes: Dictionary = {
	w_fl: w_fl_m,
	w_fr: w_fr_m,
	w_rl: w_rl_m,
	w_rr: w_rr_m
}

var riders: Array[CharacterBody3D] = []
var total_mass := car_mass # add item masses here too

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mass = car_mass
	riders.resize(seat_mkrs.size())
	# set the raycast lengths
	for wheel in all_wheels:
		wheel.target_position = Vector3(0, -(wheel_radius + suspension_length + 0.1), 0)
	# enter area interactable
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
	
	# temp steering code
	var steer_angle := 0.0
	if riders[0] != null:
		steer_angle = deg_to_rad(steer_angle_max_deg) * steer_input
	
	# REFACTORED LONGITUDINAL FORCES LOGIC
	
	if riders[0] != null:
		if brake_input > deadzone:
			# brakes
			# braking overrides throttle
			for wheel in all_wheels:
				_apply_brake_force(wheel, all_wheels.size(), brake_input)
		else:
			# forward and reverse throttle
			# reverse will simply apply a negative force to 'brake'
			# instead of braking then reverse
			for wheel in rear_wheels:
				_apply_engine_forces(wheel, rear_wheels.size(), drive_input)
	
	# rolling resistance and aerodynamic drag
	if s > 0.01:
		_apply_drag_force(air_density, s, drag_area, drag_coef)
		for wheel in all_wheels:
			_apply_roll_force(wheel, all_wheels.size())
	
	# WHEEL STUFF
	
	w_fl.force_raycast_update()
	w_fr.force_raycast_update()
	w_rl.force_raycast_update()
	w_rr.force_raycast_update()
	
	w_fl_m.rotation.y = -steer_angle
	w_fr_m.rotation.y = -steer_angle
	
	for wheel in all_wheels:
		var normal_force = _apply_suspension(wheel, wheel_meshes.get(wheel), )
	
	var normal_fl := _apply_suspension(w_fl, w_fl_m, suspension_fk)
	var normal_fr := _apply_suspension(w_fr, w_fr_m, suspension_fk)
	var normal_rl := _apply_suspension(w_rl, w_rl_m, suspension_rk)
	var normal_rr := _apply_suspension(w_rr, w_rr_m, suspension_rk)
	var a := _apply_tire_forces(w_fl, -steer_angle, normal_fl, tire_f_lat_damping)
	print("fl normal: ", normal_fl, " fl lateral: ", a)
	_apply_tire_forces(w_fr, -steer_angle, normal_fr, tire_f_lat_damping)
	_apply_tire_forces(w_rl, 0.0, normal_rl, tire_r_lat_damping)
	_apply_tire_forces(w_rr, 0.0, normal_rr, tire_r_lat_damping)

# when a body enters the enter area
# underscore is for internal function
func _body_entered(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.set_interactable(self, enter_orig, "car", "Enter")

# when a body exits the enter area
func _body_exited(body: Node) -> void:
	if body is CharacterBody3D and body.has_method("set_interactable"):
		body.clear_interactable(self)

func _apply_suspension(wheel: RayCast3D, mesh: MeshInstance3D, spring_constant: float) -> float:
	if not wheel.is_colliding():
		# no force applied
		mesh.position.y = -suspension_length + wheel_radius
		return 0.0
	
	var point := wheel.get_collision_point() # where the point of contact is
	var normal := wheel.get_collision_normal() # direction of the normal force
	var pos := wheel.global_transform.origin # position of the wheel hub
	var dist := pos.distance_to(point) # distance from the hub to the ground
	
	# the current spring length should be the total distance - wheel radius
	var spring_length := dist - wheel_radius
	
	mesh.position.y = -spring_length + wheel_radius
	
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
	var spring_force := x * spring_constant
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
	DebugDraw3D.draw_arrow_ray(point, total_force * normal * 0.001, 1,Color(0.75, 0.423, 0.94, 1.0),0.1)
	return total_force # returns the final normal force essentially

func _apply_tire_forces(wheel: RayCast3D, steer_angle: float, normal_force: float, tire_lat_damping: float) -> float:
	if not wheel.is_colliding():
		return 0.0
	
	# where the point of contact is
	var point := wheel.get_collision_point() 
	# direction of the normal force
	var normal := wheel.get_collision_normal() 
	# the hub of the wheel
	#var hub := wheel.global_transform.origin
	# the vector from the center of mass to the hub or point of contact
	# or also the distance from reference point to target point
	# can use point or hub
	var radius := point - global_transform.origin
	# velocity at the point in the object
	# calculated by velocity_target_point = velocity_reference_point + angular_velocity * radius
	var velocity_point := linear_velocity + angular_velocity.cross(radius)
	# remove any components, only forces in ground plane
	velocity_point -= normal * velocity_point.dot(normal)
	
	# wheel directions, based on car unless front wheels
	var forward := (-global_transform.basis.z).normalized()
	var right := global_transform.basis.x.normalized()
	
	forward = forward.rotated(normal, steer_angle).normalized()
	right = right.rotated(normal, steer_angle).normalized()
	
	#var v_forward := velocity_point.dot(forward) # speed along the forward direction, -1 to 1
	var v_right := velocity_point.dot(right)
	
	# calculated grip force of the tire itself
	var tire_grip_force := -v_right * tire_lat_damping
	# the max grip force allowed, which is the force of friction
	var tire_friction_force := tire_lat_cof * normal_force
	# final force calculated
	var total_lat_force: float = clamp(tire_grip_force, -tire_friction_force, tire_friction_force)
	
	apply_force(right * total_lat_force, radius)
	
	# debug
	DebugDraw3D.draw_arrow_ray(point, total_lat_force * right * 0.001, 1,Color(0.776, 0.94, 0.423, 1.0),0.1)
	
	return total_lat_force

func _apply_engine_forces(wheel: RayCast3D, num_wheels: int, drive_input: float) -> float:
	var velocity := linear_velocity
	var speed = velocity.length()
	var forward := (-global_transform.basis.z).normalized()
	var v_forward := velocity.dot(forward) # speed along the forward direction, -1 to 1
	# where the point of contact is
	var point := wheel.get_collision_point() 
	# the vector from the center of mass to the hub or point of contact
	# or also the distance from reference point to target point
	# can use point or hub
	var radius := point - global_transform.origin
	
	if drive_input > deadzone:
		var total_power = max_power_watts * drivechain_efficiency
		# using formula engine_force = (power * input) / velocity
		var throttle_force = (total_power * drive_input) / max(min_speed, speed)
		throttle_force /= num_wheels # split force amongst all wheels
		apply_force(throttle_force * forward, radius)
		return throttle_force
	else:
		# coasting force, no pedals down
		var engine_force = -engine_brake_force_max * speed / (speed + engine_brake_fade_speed) * sign(v_forward)
		engine_force /= num_wheels # split force amongst all wheels
		apply_force(engine_force * forward, radius)
		return engine_force

func _apply_drag_force(air_density: float, speed: float, drag_area: float, drag_coefficient: float) -> float:
	var velocity := linear_velocity
	var forward := (-global_transform.basis.z).normalized()
	var v_forward := velocity.dot(forward) # speed along the forward direction, -1 to 1
	var drag_force := air_density * speed * speed * drag_area * drag_coef / 2
	apply_central_force(forward * drag_force * -sign(v_forward))
	return drag_force

func _apply_roll_force(wheel: RayCast3D, num_wheels: int) -> float:
	# where the point of contact is
	var point := wheel.get_collision_point() 
	# the vector from the center of mass to the hub or point of contact
	# or also the distance from reference point to target point
	# can use point or hub
	var radius := point - global_transform.origin
	var roll_force = rolling_resistance_coef * total_mass * gravity
	var velocity := linear_velocity
	var forward := (-global_transform.basis.z).normalized()
	var v_forward := velocity.dot(forward) # speed along the forward direction, -1 to 1
	roll_force /= num_wheels
	apply_force(roll_force * -sign(v_forward), radius)
	return roll_force

func _apply_brake_force(wheel: RayCast3D, num_wheels: int, brake_input: float) -> float:
	# where the point of contact is
	var point := wheel.get_collision_point() 
	# the vector from the center of mass to the hub or point of contact
	# or also the distance from reference point to target point
	# can use point or hub
	var radius := point - global_transform.origin
	var velocity := linear_velocity
	var forward := (-global_transform.basis.z).normalized()
	var v_forward := velocity.dot(forward) # speed along the forward direction, -1 to 1
	var brake_force = max_brake_force * brake_input
	brake_force /= num_wheels
	apply_force(brake_force * -sign(v_forward), radius)
	return brake_force

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
