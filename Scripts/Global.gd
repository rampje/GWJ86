extends Node


# MASK ABILITIES
var has_sight: bool = false
var has_walljump: bool = false


func _ready() -> void:
	#reset_game()
	enable_all()

func _input(event):
	# Keep "system/UI" stuff in _input; movement in _physics_process is correct.
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event.is_action_pressed("reload"):
		#reset_game()
		enable_all()
		get_tree().reload_current_scene()


func reset_game() -> void:
	has_sight = false
	has_walljump = false
	
func enable_all() -> void:
	has_sight = true
	has_walljump = true
	
