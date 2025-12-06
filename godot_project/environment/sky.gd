extends WorldEnvironment

# seconds in a day
@export var day_length: float = 10
# days to take the moon to do one cycle
@export var moon_cycle: float = 8

# from 0 to 1
# 0 is midnight, 0.5 is noon, 1 is midnight
# this is the initial time when the game starts
var time: float = 0
# the moon's rotation
var moon_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# calculate the correct time
	time += delta / day_length
	if time >= 1.0:
		time = 0
	
	# sun rotation
	var sun_angle = TAU * time
	$sun.rotation.x = sun_angle
	
	# TODO moon cycles
	# so the moon rises at different times of the day
	# over an entire month, 
	moon_time += delta / day_length / moon_cycle
	# the extra sun angle gives it somewhat realisic feel
	# so that sometimes the moon can be seen in the day
	$moon.rotation.x = moon_time * TAU + sun_angle
	
