extends RigidBody3D

@export var max_speed: float = 20.0
@export var acceleration: float = 12.0
@export var braking_decel: float = 8.0
@export var rolling_decel: float = 3.0

@export var gravity: float = 9.81
@export_range(0.5, 30, 0.5) var third_person_zoom: float = 10.0

var driver: Node = null
var current_speed: float
var first_person: bool = false

# nodes used
@onready var driver_cam = $driver_cam
@onready var third_person_cam = $third_person_spring/third_person_cam
@onready var third_person_spring = $third_person_spring
@onready var player_mesh = $mesh
@onready var exit_location = $exit_loc
@onready var driver_location = $driver_loc
@onready var enter_area = $enter_area

# Called when the node enters the scene tree for the first time.
func _ready():
	# make it a group to be interacted with in the world
	add_to_group("interactable")
	third_person_spring.spring_length = third_person_zoom
	# don't set current camera to the car
	driver_cam.current = false
	third_person_cam.current = false

# NOTE
# steering input maps are: throttle, reverse, steer_left, steer_right, brake
# other include: interact

# movement code
func _physics_process(delta):
	if Global.paused or driver == null:
		return
	
	if Input.is_action_just_pressed("interact"):
		exit()
		return
	
	var throttle_input = Input.get_action_strength("throttle")
	var reverse_input = Input.get_action_strength("brake")
	var steer_input = Input.get_axis("steer_left", "steer_right")
	var brake_input = Input.get_action_strength("brake")
	
	

func enter(player: CharacterBody3D) -> void:
	# TODO set driver to a player?
	# if driver is not occupied
	# considering multiplayer
	if driver == null:
		driver = player

func exit() -> void:
	# set driver to nothing
	driver = null
