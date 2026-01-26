extends Node


# Called when the node enters the scene tree for the first time.
func _ready():
	ProjectSettings.load_resource_pack("res://terrain.pck")
	ProjectSettings.load_resource_pack("res://graphics.pck")
	get_tree().change_scene("res://world.tscn")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
