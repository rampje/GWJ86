extends Node2D


func _ready() -> void:
#	 Listen to Global for pickups
	Global.mask_picked.connect(on_mask_picked)
	
	if Global.has_friend == true:
		$CharacterBody2D.queue_free()
	

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":# and body.has_method("unlock_wall_ability"):
		SoundManager.play_sfx(
					SoundManager.mask_barrier_cross,  # stream
					false,                           # pitch_randomize
					Vector2(0.85, 1.15),             # pitch_range
					1.5,                             # cooldown_sec
					-7.0                             # gain_db
				)

		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(self, "modulate:a", 0.2, 2)  # fade down
		t.tween_property(self, "modulate:a", 1.0, 2)  # fade up


		 # free AFTER tween finishes
		#t.tween_callback(func(): $CharacterBody2D.queue_free())
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
