extends RigidBody3D

@export var max_speed: float = 20.0

@export var throttle_force: float = 2000.0
@export var braking_force: float = 10.0
@export var rolling_force: float = 4.0


# change in steering per second, steering goes from -1 to 1
@export var steering_speed: float = 4.0

@export var gravity: float = 9.81

var driver: Node = null

# nodes used
@onready var driver_cam = $driver_cam
@onready var third_person_cam = $third_person_spring/third_person_cam
@onready var third_person_spring = $third_person_spring
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
	var throttle_input = Input.get_action_strength("throttle")
	var reverse_input = Input.get_action_strength("brake")
	var steer_input = Input.get_axis("steer_left", "steer_right")
	var brake_input = Input.get_action_strength("brake")
	
	var current_velocity := linear_velocity
	var current_speed := current_velocity.length()
	
	

func enter(player: CharacterBody3D) -> void:
	# TODO set driver to a player?
	# if driver is not occupied
	# considering multiplayer
	if driver == null:
		driver = player

func exit() -> void:
	# set driver to nothing
	driver = null
