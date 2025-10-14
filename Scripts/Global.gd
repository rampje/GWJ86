extends Node


# MASK ABILITIES
var has_sight: bool = false
var has_walljump: bool = false


func _ready() -> void:
	#reset_game()
	enable_all()


func reset_game() -> void:
	has_sight = false
	has_walljump = false
	
func enable_all() -> void:
	has_sight = true
	has_walljump = true
	
