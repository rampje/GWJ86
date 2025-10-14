extends Area2D

@export var one_shot: bool = true   # only activate once?
@export var set_facing_to_right := true  # optional: face direction

@onready var marker := $Marker2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if !body or !body.is_in_group("Player"):   # or: if !(body is CharacterBody2D)
		return

	print(self.name)
	# Write respawn info on the player
	#if body.has_variable("respawn_position"):
	body.respawn_position = marker.global_position
	#if body.has_variable("_facing") and set_facing_to_right:
	#	body._facing = 1   # optional, if you track facing


	# Optional: prevent re-triggering
	if one_shot:
		monitoring = false
		set_deferred("monitorable", false)  # stop anyone else from reading it
		# or queue_free() if you want it to disappear
