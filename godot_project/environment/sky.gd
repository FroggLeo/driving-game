extends WorldEnvironment

# seconds in a day
@export var day_length: float = 10
# days to take the moon to do one cycle
@export var moon_length: float = 29.5

# days in a year
@export var year_length: float = 10
# moon cycle time between +-moon_axial_tilt degrees, in years
# just called it a moon season
@export var moon_season_length: float = 18.6

# tilt of the sun, axial tilt, difference between equinox and summer/winter solstice
@export var axial_tilt: float = 23.5
# tilt of the moon relative to the sun
@export var moon_axial_tilt: float = 5.0
# tilt of the equinox from the vertical, or the degree of the latitiude
# 34 degrees is around los angeles's equinox
@export var latitiude = 34

# nodes used
@onready var sun = $sun_tilt/sun
@onready var moon = $moon_tilt/moon
@onready var sun_tilt = $sun_tilt
@onready var moon_tilt = $moon_tilt

# all from 0 to 1
# this is the initial amounts when the game starts
# the initial time
@export var time: float = 0
# the moon's rotation
@export var moon_time: float = 0
# the time of the year
@export var year_time: float = 0
# time of the moon season
@export var moon_season: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# set the tilt of the equinox
	sun.rotation.x = deg_to_rad(latitiude)
	moon.rotation.x = deg_to_rad(latitiude)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.paused:
		return
	
	# calculate global time change
	var time_change = delta / day_length
	
	# calculate day time
	time += time_change
	if time >= 1.0:
		time = 0
	# calculate moon time
	moon_time += time_change / moon_length
	if moon_time >= 1.0:
		moon_time = 0
	# calculate year time
	year_time += time_change / year_length
	if year_time >= 1.0:
		year_time = 0
	# calculate moon season time
	moon_season += (time_change / year_length) / moon_season_length
	if moon_season >= 1.0:
		moon_season = 0
	
	# sun rotation
	var sun_angle = TAU * time
	sun.rotation.z = sun_angle
	
	# moon rotation
	# the extra sun angle gives it somewhat realisic feel
	# so that sometimes the moon can be seen in the day
	var moon_angle = TAU * moon_time
	moon.rotation.z = moon_angle + sun_angle
	
	# sun tilt
	# using sin so that it goes from -1 to 1 instead of 0 to 1
	# trig...
	var sun_tilt_angle = deg_to_rad(axial_tilt) * sin(year_time * TAU)
	sun_tilt.rotation.x = sun_tilt_angle
	
	# moon tilt
	# based on sun tilt but varies by +-moon_axial_tilt over a time of moon_season years
	var moon_tilt_angle = sun_tilt_angle + (deg_to_rad(moon_axial_tilt) * sin(moon_season * TAU))
	moon_tilt.rotation.x = moon_tilt_angle
