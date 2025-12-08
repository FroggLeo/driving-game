@tool
extends WorldEnvironment

@export_category("Time lengths")
# seconds in a day
@export var day_length: float = 10
# days to take the moon to do one cycle, from full moon to full moon
@export var moon_length: float = 29.5
# days in a year
@export var year_length: float = 10
# moon cycle time between +-moon_axial_tilt degrees, in years
# just called it a moon season
@export var moon_season_length: float = 18.6

@export_category("Tilt of the sun and moon")
# tilt of the sun, axial tilt, difference between equinox and summer/winter solstice
@export var axial_tilt: float = 23.5:
	set (value):
		axial_tilt = value
		_update_sun_moon()
# tilt of the moon relative to the sun
@export var moon_axial_tilt: float = 5.0:
	set (value):
		moon_axial_tilt = value
		_update_sun_moon()
# tilt of the equinox from the vertical, or the degree of the latitude
# 34 degrees is around los angeles's equinox
@export_range(-90,90,0.01) var latitude: float = 34:
	set (value):
		latitude = value
		_update_sun_moon()

@export_category("Sun and moon energy")
# energy of the sunlight
@export var sun_energy: float = 1.0
# moonlight
# max fraction of the reflected sunlight @ full moon, 0 to 1
@export var moon_energy: float = 0.136

@export_category("Initial time")
# all from 0 to 1
# this is the initial amounts when the game starts
# the initial time
@export_range(0,1,0.001) var time: float = 0:
	set (value):
		time = value
		_update_sun_moon()
# the moon's rotation
@export_range(0,1,0.001) var moon_time: float = 0:
	set (value):
		moon_time = value
		_update_sun_moon()
# the time of the year
@export_range(0,1,0.001) var year_time: float = 0:
	set (value):
		year_time = value
		_update_sun_moon()
# time of the moon season
@export_range(0,1,0.001) var moon_season: float = 0:
	set (value):
		moon_season = value
		_update_sun_moon()

# nodes used
@onready var sun = $sun_tilt/sun
@onready var moon = $moon_tilt/moon
@onready var sun_tilt = $sun_tilt
@onready var moon_tilt = $moon_tilt
@onready var sun_light = $sun_tilt/sun/sun_light
@onready var moon_light = $moon_tilt/moon/moon_light

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# set the tilt of the equinox
	sun.rotation.x = deg_to_rad(latitude)
	moon.rotation.x = deg_to_rad(latitude)
	# set the initial sun energy
	sun_light.light_energy = sun_energy

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if Global.paused:
		return
	
	# calculate global time change
	var time_change = delta / day_length
	_update_clock(time_change)
	
	_update_sun_moon()

func _update_clock(time_change) -> void:
	# calculate day/sun time
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

func _update_sun_moon() -> void:
	if sun == null or moon == null or sun_tilt == null or moon_tilt == null or sun_light == null or moon_light == null:
		return
	
	# sun rotation
	var sun_angle = TAU * time
	sun.rotation.z = sun_angle
	# sun tilt
	# using sin so that it goes from 1 to -1 to 1 instead of 0 to 1
	# trig...
	var sun_tilt_angle = deg_to_rad(axial_tilt) * -sin((year_time - 0.25) * TAU)
	sun_tilt.rotation.x = sun_tilt_angle
	
	# moon rotation
	# the extra sun angle gives it somewhat realisic feel
	# so that sometimes the moon can be seen in the day
	var moon_angle = TAU * moon_time
	moon.rotation.z = moon_angle + sun_angle
	# moon light energy
	# make sure to place the sun and moon meshes opposite of each other
	moon_light.light_energy = sun_energy * moon_energy * absf(2 * (0.5 - moon_time))
	# moon tilt
	# based on sun tilt but varies by +-moon_axial_tilt over a time of moon_season years
	var moon_tilt_angle = sun_tilt_angle + (deg_to_rad(moon_axial_tilt) * sin(moon_season * TAU))
	moon_tilt.rotation.x = moon_tilt_angle
