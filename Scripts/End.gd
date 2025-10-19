extends Node2D



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		body.set_script(null) 
		#body.gravity = 0.0
		#body.max_fall_speed = 0.0
		SoundManager.fade_music_bus(12)
		Global.player_active = false
		Global.game_active = false
		GameTimer.stop()

		var ghost = body.get_node_or_null("Ghost")
		var parts = body.get_node_or_null("CPUParticles2D")
		#if ghost: ghost.queue_free()
		if parts: parts.queue_free()

		var sprite = body.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.play("jump")
		
		
		

		$"../../HUD".on_global_mask_picked("   ")
		await get_tree().create_timer(3.5).timeout
		$"../../HUD".on_global_mask_picked("    ")
		
		_fade_sprite(ghost.get_node("AnimatedSprite2D"), 3, 0.22)	
		await get_tree().create_timer(5).timeout
		
		$MaskBarrier7/CPUParticles2D.emitting = false
		$"../../HUD".on_global_mask_picked("     ")
		_fade_sprite(sprite, 4.0)
		await get_tree().create_timer(7).timeout
		
		var title_screen = $"../../TitleScreen"
		title_screen.end_menu()
		title_screen.visible = true
		var mc = title_screen.get_node("MarginContainer") as CanvasItem
		var c: Color = mc.modulate
		c.a = 0.0
		mc.modulate = c
		mc.visible = true
		
		sprite.visible = false
		_fade_title(title_screen, 5.0)


func _fade_sprite(sprite: CanvasItem, seconds: float, start_alpha: float = 1.0) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var col := sprite.modulate
		col.a = start_alpha - clamp(t / seconds, 0.0, 1.0)
		sprite.modulate = col
		
		
# Fade IN the MarginContainer inside a CanvasLayer
func _fade_title(title: CanvasLayer, seconds: float) -> void:
	var mc := title.get_node_or_null("MarginContainer")
	if mc == null: 
		return
	var t: float = 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var col: Color = (mc as CanvasItem).modulate
		col.a = clamp(t / seconds, 0.0, 1.0)  # 0 → 1
		(mc as CanvasItem).modulate = col
