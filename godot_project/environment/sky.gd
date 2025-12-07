extends WorldEnvironment

# seconds in a day
@export var day_length: float = 0.05
# days to take the moon to do one cycle
@export var moon_cycle: float = 29.5
# days in a year
@export var year_length: float = 10
# tilt of the sun, axial tilt
@export var axial_tilt: float = 23.5

# nodes used
@onready var sun = $sun_tilt/sun
@onready var moon = $moon_tilt/moon
@onready var sun_tilt = $sun_tilt
@onready var moon_tilt = $moon_tilt

# from 0 to 1
# 0 is midnight, 0.5 is noon, 1 is midnight
# this is the initial time when the game starts
var time: float = 0
# the moon's rotation
var moon_time: float = 0
# the time of the year
var year_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# global time change
	var time_change = delta / day_length
	
	# calculate year time
	year_time += time_change / year_length
	if year_time >= 1.0:
		year_time = 0
	# sun tilt
	# using sin so that it goes from -1 to 1 instead of 0 to 1
	# trig...
	var sun_tilt_angle = deg_to_rad(axial_tilt) * sin(year_time * TAU)
	sun_tilt.rotation.x = sun_tilt_angle
	
	# calculate day time
	time += time_change
	if time >= 1.0:
		time = 0
	# sun rotation
	var sun_angle = TAU * time
	sun.rotation.z = sun_angle
	
	# calculate moon time
	moon_time += time_change / moon_cycle
	if moon_time >= 1.0:
		moon_time = 0
	# the extra sun angle gives it somewhat realisic feel
	# so that sometimes the moon can be seen in the day
	moon.rotation.z = moon_time * TAU + sun_angle
	
	
	
