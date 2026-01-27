extends RigidBody3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func set_interactable(object: Node, origin: Marker3D, type: String, message: String) -> void:
	pass

func clear_interactable(object: Node) -> void:
	get_parent().get_node("mission").fail()

func win() -> void:
	get_parent().get_node("mission").win()
