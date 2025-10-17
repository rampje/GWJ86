extends Node2D


func _ready() -> void:
#	 Listen to Global for pickups
	Global.mask_picked.connect(on_mask_picked)
	

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":# and body.has_method("unlock_wall_ability"):
		SoundManager.play_sfx(
					SoundManager.mask_pickup_sound,  # stream
					false,                           # pitch_randomize
					Vector2(0.85, 1.15),             # pitch_range
					0.0,                             # cooldown_sec
					-9.0                             # gain_db
				)

		#$Area2D.monitoring = false
		# broadcast which mask was picked up
		#picked_up.emit(mask_type)
		#queue_free()

func on_mask_picked(mask_type: String) -> void:
	if mask_type == "Companionship":
		var t := create_tween()
		# fade to green (full alpha) over 1 second
		t.tween_property($CPUParticles2D, "modulate", Color(0.288, 0.505, 0.677, 1.0), 1.0)
		
		# free AFTER tween finishes
		#t.tween_callback(func(): $CharacterBody2D.queue_free())
		$CharacterBody2D.queue_free()
