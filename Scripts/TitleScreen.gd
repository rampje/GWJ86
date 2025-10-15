extends CanvasLayer


func _ready() -> void:
	Global.player_active = false
	$"../ActiveMap".visible = false
	$"../ActiveMap".modulate = Color(1, 1, 1, 0)


func _on_start_pressed() -> void:
	$"../ActiveMap".visible = true
	var tween = get_tree().create_tween()
	tween.tween_property($"../ActiveMap", "modulate", Color(1, 1, 1, 1), 3)
	Global.player_active = true
	queue_free()




func _on_quit_pressed() -> void:
	get_tree().quit()
