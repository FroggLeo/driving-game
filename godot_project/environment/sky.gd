extends WorldEnvironment

# seconds in a day
@export var day_length: float = 10

# from 0 to 1
# 0 is midnight, 0.5 is noon, 1 is midnight
# this is the initial time when the game starts
var time = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# calculate the correct time
	time = delta / day_length + time
	if time >= 1.0:
		time = 0
	
	# sun rotation
	var sun_angle = TAU * time
	$sun.rotation.x = sun_angle
	
	# TODO moon cycles
	
