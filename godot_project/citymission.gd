extends Area3D

func _ready() -> void:
	self.body_entered.connect(_body_entered)

func _body_entered(body: Node) -> void:
	if body.has_method("win"):
		body.win()
