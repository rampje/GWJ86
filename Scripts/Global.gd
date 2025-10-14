extends Node

signal mask_picked(mask_type: String)

const MASK_ICON_PATHS := {
	"Sight":    "res://Assets/Masks/Sight.png",
	"Movement": "res://Assets/Masks/Movement.png",
	"Attack":   "res://Assets/Masks/Attack.png",
}

# MASK ABILITIES
var has_sight: bool = false
var has_walljump: bool = false


func _ready() -> void:
	reset_game()
	#enable_all()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
	if event.is_action_pressed("reload"):
		reset_game()
		#enable_all()
		get_tree().reload_current_scene()


func reset_game() -> void:
	has_sight = false
	has_walljump = false
	
func enable_all() -> void:
	has_sight = true
	has_walljump = true
	
	

func on_mask_picked(mask_type: String) -> void:
	match mask_type:
		"Sight":
			has_sight = true
		"Movement":
			has_walljump = true

	emit_signal("mask_picked", mask_type)





func get_mask_icon(mask_type: String) -> Texture2D:
	var p = MASK_ICON_PATHS.get(mask_type, "")
	return null if p == "" else load(p)
