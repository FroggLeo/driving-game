extends WorldEnvironment

# seconds in a day
@export var day_length: float = 600.0
# days that take for the moon to go through half a cycle
# example: new moon to full moon
@export var moon_cycle: float = 8.0

# from 0 to 1
# 0 is midnight, 0.5 is noon, 1 is midnight
var time = 0.5
var moon_phase = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	time = delta / day_length + time
	if time == 1:
		time = 0
	var sun_angle = 360 * time
	$sun.rotation.x = sun_angle
