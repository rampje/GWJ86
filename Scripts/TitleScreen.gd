extends CanvasLayer


func _ready() -> void:
	init_game()
	#start_game()


func _on_start_pressed() -> void:
	start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func init_game() -> void:
	Global.player_active = false 
	$"../ActiveMap".visible = false
	$"../ActiveMap".modulate = Color(1, 1, 1, 0)

func start_game() -> void:
	$"../ActiveMap".visible = true
	var tween = get_tree().create_tween()
	tween.tween_property($"../ActiveMap", "modulate", Color(1, 1, 1, 1), 3)
	Global.player_active = true
	# find cleaner way to do this
	$"../HUD/TopCenter/MovementKeys".visible = true
	$"../HUD/TopCenter/Timer".start(3)
	queue_free()
