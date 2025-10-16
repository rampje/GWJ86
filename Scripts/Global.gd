extends Node

signal mask_picked(mask_type: String)

const ACTIVE_MAP_SCENE: PackedScene = preload("res://Scenes/Main.tscn")
const MASK_ICON_PATHS := {
	"Sight":    "res://Assets/Masks/Sight.png",
	"Movement": "res://Assets/Masks/Movement.png",
	"Attack":   "res://Assets/Masks/Attack.png",
	"Wisdom":   "res://Assets/Masks/Wisdom.png",
	"Lightness": "res://Assets/Masks/Lightness.png",
	"Companionship": "res://Assets/Masks/Companionship.png"
}

static var TOTAL_MASKS := MASK_ICON_PATHS.size()

# game state
#var main_scene = load("uid://byw3hhep7o6ne")
var player_active: bool = false
var current_mask_count: int = 0
var sight_state: bool = false # when use sight first time becomes true

# MASK ABILITIES
var has_sight: bool = false
var has_walljump: bool = false
var has_slowfall: bool = false
var has_wisdom: bool = false
var has_attack: bool = false
var has_friend: bool = false


func _ready() -> void:
	reset_game()
	#enable_all()

#func _input(event):
#	if event.is_action_pressed("reload"):
#		reset_game()
#		#enable_all()
#		get_tree().reload_current_scene()


func reset_game() -> void:
	sight_state = false
	has_sight = false
	has_walljump = false
	has_slowfall = false
	has_wisdom = false
	has_friend = false
	
func enable_all() -> void:
	sight_state = false
	has_sight = true
	has_walljump = true
	#has_slowfall = true
	
	

func on_mask_picked(mask_type: String) -> void:
	match mask_type:
		"Sight":
			has_sight = true
		"Movement":
			has_walljump = true
		"Lightness":
			has_slowfall = true
		"Wisdom":
			has_wisdom = true
		"Attack":
			has_attack = true
		"Companionship":
			has_friend = true
	
	current_mask_count += 1
	emit_signal("mask_picked", mask_type)





func get_mask_icon(mask_type: String) -> Texture2D:
	var p = MASK_ICON_PATHS.get(mask_type, "")
	return null if p == "" else load(p)
