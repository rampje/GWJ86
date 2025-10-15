extends CharacterBody2D

@export var max_speed: float = 200.0
@export var jump_speed: float = -280.0
@export var gravity: float = 900.0
@export var gravity_fall: float = 1200.0         # stronger gravity when falling for snappier arcs
@export var max_fall_speed: float = 1200.0

@export var accel_ground: float = 3000.0         # px/s^2
@export var decel_ground: float = 3500.0         # px/s^2
@export var accel_air: float = 1500.0
@export var decel_air: float = 1800.0

@export var jump_buffer_time: float = 0.12       # seconds input can be buffered before landing
@export var coyote_time: float = 0.10            # seconds you can still jump after walking off an edge
@export var cut_jump_gravity_mul: float = 2.2    # released jump early? increase gravity to "cut" the jump

@export var wall_slide_max_speed: float = 120.0  # downward clamp while sliding
@export var wall_jump_push: float = 180.0        # horizontal push on wall jump

# --- State ---
var _jump_buffer: float = 0.0
var _coyote_timer: float = 0.0
var _facing: int = 1
var attacking: bool = false
var is_wall_sliding: bool = false
var _carry: Vector2 = Vector2.ZERO
var _prev_on_floor: bool = false
#var _sight_mask_on: bool = false
var respawn_position: Vector2

func _ready():
	floor_snap_length = 8.0   # slightly less than half your tile size
	floor_max_angle = deg_to_rad(46)
	
	%TileMapLayer2.enabled = false
	%TileMapLayer3.enabled = true


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right") 
	
	if _prev_on_floor:
		velocity += _carry       # -1,0,1
	
	#debug	
	#if is_on_floor():
	#	for i in get_slide_collision_count():
	#		var c := get_slide_collision(i)
	#		if c:
	#			print("n=", c.get_normal(), " carry=", _carry)


	# Buffer jump so it can't be missed between frames
	if Input.is_action_just_pressed("ui_accept"):
		_jump_buffer = jump_buffer_time

	# Track coyote timer when leaving ground
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	# --- HORIZONTAL MOVE (frame-rate independent) ---
	var target_speed := dir * max_speed
	var on_ground := is_on_floor()
	var moving = abs(target_speed) > 0.0

	var accel := (accel_ground if on_ground and moving else decel_ground)
	if !on_ground:
		accel = (accel_air if moving else decel_air)

	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	# Face sprite
	if dir != 0:
		_facing = -1 if dir < 0 else 1
		$AnimatedSprite2D.flip_h = _facing < 0

	# --- VERTICAL MOVE (better gravity & variable jump height) ---
	var g := gravity
	# falling or moving upward but jump released? make gravity stronger
	if velocity.y > 0.0:
		g = gravity_fall
	elif velocity.y < 0.0 and !Input.is_action_pressed("ui_accept"):
		g *= cut_jump_gravity_mul

	velocity.y = min(velocity.y + g * delta, max_fall_speed)

	# --- WALL SLIDE DETECTION (only if ability unlocked) ---
	is_wall_sliding = Global.has_walljump and is_on_wall() and !is_on_floor() and dir != 0
	if is_wall_sliding:
		velocity.y = min(velocity.y, wall_slide_max_speed)

	# --- JUMP RESOLUTION (uses buffer + coyote) ---
	if _try_jump():
		# handled inside
		pass

	move_and_slide()
	
	if !is_on_floor():
		_carry = Vector2.ZERO

	var carry_next := Vector2.ZERO
	if is_on_floor():
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c and c.get_normal().dot(Vector2.UP) > 0.7:
				var col := c.get_collider()
				if col is AnimatableBody2D:
					carry_next = col.constant_linear_velocity
					break
	
	# If we *just* landed, suppress one frame of horizontal carry
	var just_landed := is_on_floor() and !_prev_on_floor
	if just_landed:
		_carry = Vector2.ZERO
	else:
		_carry = carry_next

	_prev_on_floor = is_on_floor()
	
	
	# --- ANIMATION (kept simple; consider a proper state machine later) ---
	if !attacking:
		if is_wall_sliding:
			$AnimatedSprite2D.play("wall_slide")
		elif !is_on_floor():
			$AnimatedSprite2D.play("jump")
		elif abs(velocity.x) > 5.0:
			$AnimatedSprite2D.play("run")  
		else:
			$AnimatedSprite2D.play("default")

	# Extra abilities
	_sight_mask()


func _try_jump() -> bool:
	if _jump_buffer <= 0.0:
		return false

	# consume buffer if a jump becomes valid
	# ground / coyote jump
	if is_on_floor() or _coyote_timer > 0.0:
		velocity.y = jump_speed
		_jump_buffer = 0.0
		_coyote_timer = 0.0
		return true

	# wall jump (only if ability unlocked)
	if Global.has_walljump and is_on_wall() and !is_on_floor():
		var wall_normal := get_wall_normal()
		velocity.y = jump_speed
		velocity.x = wall_normal.x * wall_jump_push
		_jump_buffer = 0.0
		return true


	return false


func _process(delta: float) -> void:
	# Optional: purely cosmetic (particles, bob, UI) if needed
	pass







func _on_animated_sprite_2d_animation_finished():
	if attacking:
		attacking = false

func _on_animated_sprite_2d_animation_changed():
	if $AnimatedSprite2D.animation == "attack":
		attacking = true
		
		
func get_floor_motion() -> Vector2:
	if !is_on_floor():
		return Vector2.ZERO
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c and c.get_normal().dot(Vector2.UP) > 0.7:
			var col := c.get_collider()
			if col and "platform_velocity" in col:
				return col.platform_velocity
	return Vector2.ZERO


func respawn() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO






var _pulse_shader: Shader = preload("res://Shaders/PlatformTransition.gdshader")


func _sight_mask():
	if !Global.has_sight:
		return
	if Input.is_action_just_pressed("Mask1"):
		SoundManager.play_sight_sfx()

		%TileMapLayer2.enabled = !%TileMapLayer2.enabled
		%TileMapLayer3.enabled = !%TileMapLayer3.enabled

		var show_layer2 = %TileMapLayer2.enabled
		var show_layer3 = %TileMapLayer3.enabled

		for p in get_tree().get_nodes_in_group("Layer2"):
			if "set_platform_enabled" in p:
				p.set_platform_enabled(show_layer2)
		for p in get_tree().get_nodes_in_group("Layer3"):
			if "set_platform_enabled" in p:
				p.set_platform_enabled(show_layer3)

		#  Collect nodes that just became visible and pulse them
		var to_pulse: Array = []

		if show_layer2:
			to_pulse.append(%TileMapLayer2)
			for p in get_tree().get_nodes_in_group("Layer2"):
				# prefer the visual node; fall back to p if it *is* the Sprite2D
				var s := p.get_node_or_null("Sprite2D")
				to_pulse.append(s if s else p)
		if show_layer3:
			to_pulse.append(%TileMapLayer3)
			for p in get_tree().get_nodes_in_group("Layer3"):
				var s := p.get_node_or_null("Sprite2D")
				to_pulse.append(s if s else p)

		_play_pulse_on_nodes(to_pulse, 0.25)


func _ensure_pulse_material(ci: CanvasItem) -> ShaderMaterial:
	if ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader == _pulse_shader:
		return ci.material
	var sm := ShaderMaterial.new()
	sm.shader = _pulse_shader
	sm.resource_local_to_scene = true
	ci.material = sm
	return sm

func _play_pulse_on_nodes(nodes: Array, duration := 0.5) -> void:
	if nodes.is_empty():
		return
	var tw := create_tween().set_parallel(true)
	for n in nodes:
		if n is CanvasItem:
			var sm := _ensure_pulse_material(n)
			sm.set_shader_parameter("pulse", 1.5)  # start at peak
			sm.set_shader_parameter("wobble_freq", 300)  # start at peak
			sm.set_shader_parameter("wobble_amp_px", 1)  # start at peak
			tw.tween_property(sm, "shader_parameter/pulse", 0.35, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(sm, "shader_parameter/wobble_freq", 10, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(sm, "shader_parameter/wobble_amp_px", 0.6, duration)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
