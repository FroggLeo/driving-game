extends Control

var faild := false

func _on_button_button_up() -> void:
	$fail.visible = false

func _on_message_button_up() -> void:
	$message.visible = false

func _on_win_button_up() -> void:
	$win.visible = false

func fail() -> void:
	$fail.visible = true
	faild = true

func win() -> void:
	if not faild:
		$win.visible = true
