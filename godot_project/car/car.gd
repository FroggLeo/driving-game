extends CharacterBody3D

@export var max_speed: float = 20.0
@export var acceleration_decel: float = 12.0
@export var braking_decel: float = 8.0
@export var rolling_decel: float = 3.0

@export var gravity: float = 9.81
@export_range(0.5, 30, 0.5) var third_person_zoom: float = 10.0

var driver: Node = null
var current_speed: float = 0.0
var steer_input: float = 0.0
var first_person: bool = false
var throttle: bool = false
var brake: bool = false

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
	add_to_group("interactable")
	third_person_spring.spring_length = third_person_zoom
	driver_cam.current = false
	third_person_cam.current = false

func _unhandled_input(event):
	# skip if paused
	if Global.paused:
		return
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass

# movement code
func _physics_process(delta):
	if Global.paused:
		return
	
	
	move_and_slide()
