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

var ghost: Node2D

var is_slow_falling: bool = false
var _slow_fall_cooldown: float = 0.0


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
@export var max_air_jumps: int = 1   # 1 = “double jump”
var _air_jumps_left: int = 0
var _prev_on_wall: bool = false


# Slow Fall 
@export var slow_fall_gravity_mul: float = 0.25   # scale base gravity while feathering
@export var slow_fall_max_speed: float = 180.0    # clamp downward speed while feathering
@export var slow_fall_release_cooldown: float = 0.12 # small lockout after releasing jump
@export var slow_fall_min_start_speed: float = 0.0   # optional: only allow if falling this fast+


# wall slide collider
@onready var stand_shape: CollisionShape2D = $CollisionShape2D_Stand
@onready var wall_shape:  CollisionShape2D = $CollisionShape2D_Wall
var _using_wall_shape := false
@export var wall_slide_exit_grace: float = 0.12  
var _wall_slide_grace: float = 0.0
var _was_wall_sliding: bool = false

func _near_wall(dir_sign: int) -> bool:
	# considers "almost touching" a wall within a couple pixels
	if dir_sign == 0:
		return false
	return test_move(global_transform, Vector2(dir_sign * 2.0, 0.0))






# tilemap stuff
var _pulse_shader: Shader = preload("res://Shaders/PlatformTransition.gdshader")
var _faint_shader: Shader = preload("res://Shaders/FaintOutline.gdshader")
var _did_init_visuals := false
var _active_layer: int = 3  # L3 should start fully visible
const SHADER_PATH := "res://Shaders/FaintOutline.gdshader"
var FAINT_MAT: ShaderMaterial

var _orig_mat_l2: Material
var _orig_mat_l3: Material
var _faint_mat_l2: ShaderMaterial
var _faint_mat_l3: ShaderMaterial
var _post_init_done := false

func _make_faint_mat() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _faint_shader
	sm.resource_local_to_scene = true
	sm.set_shader_parameter("outline_mode", true)
	sm.set_shader_parameter("fill_alpha", 0.1)      
	sm.set_shader_parameter("outline_px", 1.0)
	sm.set_shader_parameter("outline_color", Color(1,1,1,0.9))
	return sm

	
func _set_layer_render_order(active_layer: int) -> void:
	if active_layer == 2:
		%TileMapLayer2.z_index = 10
		%TileMapLayer3.z_index = 0
	else:
		%TileMapLayer2.z_index = 0
		%TileMapLayer3.z_index = 10


func _set_layer_visuals(active_layer: int) -> void:
	if active_layer == 2:
		%TileMapLayer2.material = _orig_mat_l2
		%TileMapLayer3.material = _faint_mat_l3
	else:
		%TileMapLayer2.material = _faint_mat_l2
		%TileMapLayer3.material = _orig_mat_l3
	%TileMapLayer2.queue_redraw()
	%TileMapLayer3.queue_redraw()


func _ready() -> void:
	# colliders
	#stand_shape.disabled = false
	#wall_shape.disabled = true
	#stand_shape.visible = true
	#wall_shape.visible = false
	#_using_wall_shape = false
	# Clean base
	%TileMapLayer2.enabled = true
	%TileMapLayer3.enabled = true
	%TileMapLayer2.material = null
	%TileMapLayer3.material = null
	%TileMapLayer2.modulate = Color(1,1,1,1)
	%TileMapLayer3.modulate = Color(1,1,1,1)

	# One shared faint material (pure outline)
	FAINT_MAT = ShaderMaterial.new()
	FAINT_MAT.shader = preload(SHADER_PATH)
	FAINT_MAT.resource_local_to_scene = true
	FAINT_MAT.set_shader_parameter("outline_mode", true)
	FAINT_MAT.set_shader_parameter("fill_alpha", 0.1)   # no interior wash
	FAINT_MAT.set_shader_parameter("outline_px", 0.0)
	FAINT_MAT.set_shader_parameter("outline_color", Color(1,1,1,0.9))

	# Start: Layer 3 ACTIVE (normal), Layer 2 INACTIVE (faint)
	_active_layer = 3
	%TileMapLayer2.material = FAINT_MAT
	%TileMapLayer3.material = null
	%TileMapLayer2.z_index = 0
	%TileMapLayer3.z_index = 10

	# Collisions to match
	%TileMapLayer2.set_deferred("collision_enabled", false)
	%TileMapLayer3.set_deferred("collision_enabled", true)
	
	# ghost stuff
	$Ghost.visible = false
	ghost = get_parent().get_node_or_null("Ghost")
	Global.mask_picked.connect(_on_mask_picked)
	
		# for debug
	if Global.has_friend == true:
		$Ghost.visible = true
	
	_air_jumps_left = (max_air_jumps if Global.has_jump else 0)
	

	

# Reassert twice; this reliably beats any late writes from other _ready/_enter_tree
#func _post_init_visuals() -> void:
	#await get_tree().process_frame
	#_set_layer_visuals(_active_layer)
	#_set_layer_render_order(_active_layer)
	#await get_tree().process_frame
	#_set_layer_visuals(_active_layer)
	#_set_layer_render_order(_active_layer)
	#_post_init_done = true
	#_debug_render_state("post-init")

#func _process(_delta: float) -> void:
	#if _active_layer == 3 and Engine.get_frames_drawn() == 1:
		#_apply_mask_visuals_now(_active_layer)
#


func _physics_process(delta: float) -> void:
	# snap pixels to avoid the jitteries
	$Camera2D.global_position = self.global_position.round()
	
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

	# slowfall Cooldown ticks down every frame
	if _slow_fall_cooldown > 0.0:
		_slow_fall_cooldown = max(0.0, _slow_fall_cooldown - delta)

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

	#ghost code 
	if ghost and ghost.has_method("set"):
		# assume ghost has a script with a 'rest_offset' export
		if _facing < 0:
			ghost.rest_offset.x = abs(ghost.rest_offset.x)  * -1.0
		else:
			ghost.rest_offset.x = abs(ghost.rest_offset.x)
			
	# --- VERTICAL MOVE (better gravity & variable jump height) ---
	var g := gravity
	var max_down := max_fall_speed

	# Default fall gravity when moving downward
	if velocity.y > 0.0:
		g = gravity_fall
	# Going up AND jump released? cut the jump (stronger gravity)
	elif velocity.y < 0.0 and !Input.is_action_pressed("ui_accept"):
		g *= cut_jump_gravity_mul

	# Slow fall override (takes precedence while falling)
	var was_slow_falling := is_slow_falling
	is_slow_falling = _is_slow_fall_active()
	if is_slow_falling:
		# Use base gravity scaled down so it feels floaty, and cap fall speed lower
		# (Using base gravity here keeps it gentle; switch to gravity_fall * mul if you want stronger pull.)
		g = max(gravity * slow_fall_gravity_mul, 1.0)
		max_down = min(max_down, slow_fall_max_speed)

	# Apply gravity with cap
	velocity.y = clamp(velocity.y + g * delta, -INF, max_down)

	# If player releases jump while feathering, add a tiny cooldown to avoid rapid re-entry in the same frame
	if was_slow_falling and !Input.is_action_pressed("ui_accept"):
		_slow_fall_cooldown = slow_fall_release_cooldown


	# --- WALL SLIDE with latch + near-wall check ---
	var dir_sign = sign(dir)

	# Conditions to ENTER slide (strict)
	var can_enter_slide = (
		Global.has_walljump
		and !is_on_floor()
		and velocity.y > 0.0          # falling
		and dir_sign != 0             # pressing a direction
		and (is_on_wall() or _near_wall(dir_sign)) # touching or almost touching
	)

	# If we can enter, refresh the grace fully; otherwise tick it down only when we're truly away
	if can_enter_slide:
		_wall_slide_grace = wall_slide_exit_grace
	else:
		# are we still effectively next to a wall in the direction we're pressing?
		var still_near := (is_on_wall() or _near_wall(dir_sign))
		if !still_near:
			_wall_slide_grace = max(0.0, _wall_slide_grace - delta)

	# Latch: once sliding, we stay sliding until grace fully runs out or we land
	var was_sliding := is_wall_sliding
	is_wall_sliding = (_wall_slide_grace > 0.0) and !is_on_floor()

	# Clamp fall speed while sliding
	if is_wall_sliding:
		velocity.y = min(velocity.y, wall_slide_max_speed)

	# Swap colliders ONLY on transitions (enter/exit)
	if is_wall_sliding != _was_wall_sliding:
		#_use_wall_shape(is_wall_sliding)
		_was_wall_sliding = is_wall_sliding


	
	# --- JUMP RESOLUTION (uses buffer + coyote) ---
	if _try_jump():
		# handled inside
		pass
	
	if Global.player_active == true:
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
		_wall_slide_grace = 0.0
		is_wall_sliding = false
		_use_wall_shape(false)
		_carry = Vector2.ZERO
		_air_jumps_left = (max_air_jumps if Global.has_jump else 0)
	else:
		_carry = carry_next
		var on_wall := is_on_wall()
		# Reset when you FIRST touch a wall (prevents infinite recharge while hugging)
		if Global.has_walljump and on_wall and !_prev_on_wall:
			_air_jumps_left = (max_air_jumps if Global.has_jump else 0)
		_prev_on_wall = on_wall

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
		
	if Global.has_jump and _air_jumps_left > 0:
		velocity.y = jump_speed
		_air_jumps_left -= 1
		_jump_buffer = 0.0
		return true


	return false



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
	$AnimatedSprite2D.modulate.a = 0.7
	$RespawnTimer.start(0.25)
	Global.player_active = false
	global_position = respawn_position
	velocity = Vector2.ZERO
	if ghost:
		ghost.global_position = (global_position + ghost.rest_offset).round() 




func _sight_mask() -> void:
	if !Global.has_sight:
		return
	if Input.is_action_just_pressed("Mask1") and Global.game_active == true:
		Global.sight_state = !Global.sight_state
		SoundManager.play_sight_sfx()

		_active_layer = 2 if _active_layer == 3 else 3
		var l2_active := (_active_layer == 2)

		# visuals: active=null (normal), inactive=faint; put active on top
		%TileMapLayer2.material = null if l2_active else FAINT_MAT
		%TileMapLayer3.material = FAINT_MAT if l2_active else null
		%TileMapLayer2.z_index = 10 if l2_active else 0
		%TileMapLayer3.z_index = 0 if l2_active else 10

		# collisions to match
		%TileMapLayer2.set_deferred("collision_enabled", l2_active)
		%TileMapLayer3.set_deferred("collision_enabled", !l2_active)

		# your platform groups (unchanged)
		for p in get_tree().get_nodes_in_group("Layer2"):
			if "set_platform_enabled" in p:
				p.set_platform_enabled(l2_active)
		for p in get_tree().get_nodes_in_group("Layer3"):
			if "set_platform_enabled" in p:
				p.set_platform_enabled(!l2_active)

		# (optional) pulse block...




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


func _is_slow_fall_active() -> bool:
	# Must have the ability
	if !"has_slowfall" in Global or !Global.has_slowfall:
		return false
	# Only in air and not wall-sliding
	if is_on_floor() or is_wall_sliding:
		return false
	# Must be falling
	if velocity.y <= 0.0:
		return false
	# Optional: only when already falling at least this fast
	if abs(slow_fall_min_start_speed) > 0.0 and velocity.y < slow_fall_min_start_speed:
		return false
	# Holding jump, and not in a brief lockout window
	if _slow_fall_cooldown > 0.0:
		return false
	return Input.is_action_pressed("ui_accept")


func _on_mask_picked(mask_type: String) -> void:
	if mask_type == "Companionship":
		$Ghost.visible = true


func _on_respawn_timer_timeout() -> void:
	Global.player_active = true
	$AnimatedSprite2D.modulate.a = 1
	


func _set_tilemap_collisions(tml: Node, enabled: bool, layer_bits: int, mask_bits: int) -> void:
	if "collision_enabled" in tml:
		tml.collision_enabled = enabled
		return

	# Fallback: zero out layers/masks when off; restore when on
	if enabled:
		tml.collision_layer = layer_bits
		tml.collision_mask  = mask_bits
	else:
		tml.collision_layer = 0
		tml.collision_mask  = 0
		
#func _apply_mask_collisions(active_layer: int) -> void:
	#var l2_active := (active_layer == 2)
	#var l3_active := (active_layer == 3)
	#
	##var l2_active = !Global.sight_state
	##var l3_active = !l2_active
	## Defer to avoid flipping physics shapes mid-step
	#%TileMapLayer2.set_deferred("collision_enabled", l2_active)
	#%TileMapLayer3.set_deferred("collision_enabled", l3_active)
#


#func _ensure_unique_faint_mat(ci: CanvasItem) -> ShaderMaterial:
	#if ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader == _faint_shader:
		#var sm := ci.material as ShaderMaterial
		## Only duplicate if this material might be shared
		#if !sm.resource_local_to_scene:
			#sm = sm.duplicate(true) as ShaderMaterial
			#ci.material = sm
		#sm.resource_local_to_scene = true
		#return sm
	#var sm := ShaderMaterial.new()
	#sm.shader = _faint_shader
	#sm.resource_local_to_scene = true
	#ci.material = sm
	#return sm

#
#func _apply_mask_visuals_now(active_layer: int) -> void:
	#var sm2 := _ensure_unique_faint_mat(%TileMapLayer2)
	#var sm3 := _ensure_unique_faint_mat(%TileMapLayer3)
#
	## Inactive = outline_mode = true; Active = outline_mode = false
	#var l2_inactive := (active_layer != 2)
	#var l3_inactive := (active_layer != 3)
#
	## Shared faint look parameters
	#const FAINT_FILL := 0.06      # 0.0..0.10; lower = more ghosty
	#const OUTLINE_PX := 1.0       # >= 1.0 to actually draw an edge
	#const OUTLINE_COL := Color(1, 1, 1, 0.75)
#
	#for sm in [sm2, sm3]:
		#sm.set_shader_parameter("fill_alpha", FAINT_FILL)
		#sm.set_shader_parameter("outline_px", OUTLINE_PX)
		#sm.set_shader_parameter("outline_color", OUTLINE_COL)
#
	#sm2.set_shader_parameter("outline_mode", l2_inactive)
	#sm3.set_shader_parameter("outline_mode", l3_inactive)
#
	#%TileMapLayer2.queue_redraw()
	#%TileMapLayer3.queue_redraw()
	#
	#var smat3 := %TileMapLayer3.material as ShaderMaterial
	#print("L3 outline_mode=", smat3.get_shader_parameter("outline_mode"),
		  #" fill_alpha=", smat3.get_shader_parameter("fill_alpha"),
		  #" outline_px=", smat3.get_shader_parameter("outline_px"))


#
#func _apply_mask_visuals(active_layer: int) -> void:
	## Apply immediately so frame 0 is correct
	#_apply_mask_visuals_now(active_layer)
	## Also re-apply next frame to override any late changes
	#call_deferred("_apply_mask_visuals_now", active_layer)
	#
	#print("L2 uses faint? ", %TileMapLayer2.material == _faint_mat_l2,
	  #" | L3 uses faint? ", %TileMapLayer3.material == _faint_mat_l3,
	  #" | active=", _active_layer)
	
	
func _capture_original_material(ci: CanvasItem) -> Material:
	if ci.material is ShaderMaterial and (ci.material as ShaderMaterial).shader == _faint_shader:
		ci.material = null
		return null
	return ci.material


func _debug_tileset_materials():
	var l3_ts = %TileMapLayer3.tile_set
	if l3_ts == null:
		print("L3 tileset is null")
		return
	for i in l3_ts.get_source_count():
		var sid = l3_ts.get_source_id(i)
		var src = l3_ts.get_source(sid)
		var mat = null
		# Atlas sources have get_material(); other source types vary
		if src and src.has_method("get_material"):
			mat = src.get_material()
		if mat:
			var is_faint := (mat is ShaderMaterial and (mat as ShaderMaterial).shader == _faint_shader)
			print("TileSet source id=", sid, " has material. is_faint_shader? ", is_faint, " type=", mat)
		# if src is TileSetAtlasSource:
		#     for tid in src.get_tiles_ids():
		#         var tmat := src.get_tile_data(tid, 0).material
		#         if tmat:
		#             var t_is_faint := (tmat is ShaderMaterial and (tmat as ShaderMaterial).shader == _faint_shader)
		#             print("  tile id ", tid, " has material. faint? ", t_is_faint)


func _debug_render_state(tag := "") -> void:
	var l2 := %TileMapLayer2
	var l3 := %TileMapLayer3
	

	var p2 := first_tinting_parent(l2)
	var p3 := first_tinting_parent(l3)

	print("[%s] L2 faint? ", tag,
		l2.material == _faint_mat_l2, "  L3 faint? ", l3.material == _faint_mat_l3,
		" | z L2=", l2.z_index, " z L3=", l3.z_index)
	if p2: print("   L2 tinted by parent: ", p2.name, " mat? ", p2.material != null, " mod=", (p2 as CanvasItem).modulate)
	if p3: print("   L3 tinted by parent: ", p3.name, " mat? ", p3.material != null, " mod=", (p3 as CanvasItem).modulate)

func first_tinting_parent(n: CanvasItem) -> Node:
		var p := n.get_parent()
		while p:
			if p is CanvasItem:
				var ci := p as CanvasItem
				if ci.material or ci.modulate != Color(1,1,1,1):
					return ci
			p = p.get_parent()
		return null


func _use_wall_shape(enable: bool) -> void:
	if _using_wall_shape == enable:
		return
	_using_wall_shape = enable
	stand_shape.set_deferred("disabled", enable)   
	wall_shape.set_deferred("disabled", !enable) 
