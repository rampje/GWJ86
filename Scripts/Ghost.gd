extends Node2D

@export var target: Node2D

# placement & look
@export var rest_offset_move: Vector2 = Vector2(-20.0, -8.0)   # while moving
@export var rest_offset_idle: Vector2 = Vector2(-34.0, -10.0)  # when idle (parks farther to side)
@export var idle_offset_lerp: float = 0.18                     # seconds to ease move→idle offset
@export var shoulder_gap: float = 10.0                         # never perch directly on top

@export var side_flip_hold: float = 0.12
@export var min_move_for_trail: float = 24.0

# follow dynamics (spring PD)
@export var stiffness: float = 14.0
@export var damping: float = 2.2
@export var max_speed: float = 360.0
@export var arrive_time: float = 0.22

# prediction (lead the player a bit — keep small so lag is visible)
@export var predict_time_min: float = 0.0
@export var predict_time_max: float = 0.06

# leash
@export var leash_soft: float = 120.0
@export var leash_hard: float = 520.0

# bobbing
@export var bob_amp: float = 8.0
@export var bob_hz: float = 1.1

# pixel snapping
@export var snap_pixels_in_process: bool = true

# idle / settle
@export var idle_speed_threshold: float = 18.0
@export var idle_hold: float = 0.12
@export var settle_radius: float = 2.0
@export var settle_speed: float = 8.0

# >>> Dynamic trailing lag (NEW)
@export var drag_per_speed: float = 0.05     # px extra lag per 1 px/s of player speed
@export var drag_max: float = 24.0           # clamp so it doesn't get huge

var _vel: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _trail_sign: float = 1.0
var _pending_sign: float = 1.0
var _side_timer: float = 0.0

var _last_target_pos: Vector2 = Vector2.ZERO
var _est_target_vel: Vector2 = Vector2.ZERO
var _idle_timer: float = 0.0


func _ready() -> void:
	var s = get_node_or_null("AnimatedSprite2D")
	if s:
		s.play("default")

	if target == null:
		var g = get_tree().get_first_node_in_group("player")
		if g and g is Node2D:
			target = g
		else:
			var maybe = get_parent().get_node_or_null("Player")
			if maybe and maybe is Node2D:
				target = maybe

	if target == null:
		push_warning("Ghost: No target found. Assign 'target' or add Player to group 'player'.")
		set_physics_process(false)
		return

	_last_target_pos = target.global_position
	global_position = target.global_position + _current_trailing_offset(0.0)
	set_physics_process(true)
	set_process(true)


func _process(_dt: float) -> void:
	if not snap_pixels_in_process:
		return
	global_position = global_position.round()


func _physics_process(dt: float) -> void:
	if target == null:
		return

	_t += dt

	# 1) estimate velocity + choose trail side
	var tpos: Vector2 = target.global_position
	var tvel: Vector2 = _get_target_velocity(dt)
	_debounced_trail_side(tvel.x, dt)

	# idle tracking
	var target_speed: float = tvel.length()
	if target_speed < idle_speed_threshold:
		_idle_timer += dt
	else:
		_idle_timer = 0.0

	# blend factor for idle perch offset
	var idle_mix: float = 0.0
	if _idle_timer > 0.0:
		idle_mix = clamp(_idle_timer / max(idle_offset_lerp, 0.001), 0.0, 1.0)

	# 2) prediction (lowered when idle)
	var to_ghost: Vector2 = global_position - tpos
	var dist: float = to_ghost.length()
	var predict_t: float = lerp(predict_time_min, predict_time_max, clamp(dist / leash_soft, 0.0, 1.0))
	if _idle_timer >= idle_hold:
		predict_t = 0.0
	var predicted: Vector2 = tpos + tvel * predict_t

	# 3) bob scaled by motion and distance
	var bob_speed_mix: float = clamp(remap(target_speed, 0.0, 120.0, 0.0, 1.0), 0.0, 1.0)
	var bob_dist_mix: float = clamp(1.0 - smoothstep(0.0, leash_soft, dist), 0.0, 1.0)
	var bob_mix: float = bob_speed_mix * bob_dist_mix
	var bob: Vector2 = Vector2(0.0, sin(_t * TAU * bob_hz) * bob_amp * bob_mix)

	# 4) dynamic trailing lag (NEW): extra offset behind player grows with |tvel.x|
	var lag_extra: Vector2 = _speed_trailing_offset(tvel)

	# desired position
	var desired: Vector2 = predicted + _current_trailing_offset(idle_mix) + lag_extra + bob

	# 5) settle snap when parked and already close/slow
	if _idle_timer >= idle_hold:
		var delta_settle: Vector2 = desired - global_position
		if delta_settle.length() <= settle_radius and _vel.length() <= settle_speed:
			if snap_pixels_in_process:
				global_position = desired.round()
			else:
				global_position = desired
			_vel = Vector2.ZERO

	# 6) leash logic
	if dist > leash_hard:
		global_position = predicted + _current_trailing_offset(idle_mix) + lag_extra
		_vel = Vector2.ZERO
		_face_player(tpos)
		_last_target_pos = tpos
		return

	# 7) PD spring
	var k: float = stiffness
	if dist > leash_soft:
		k = k * 1.6

	var c: float = damping
	if _idle_timer >= idle_hold:
		c = c * 1.2

	var delta: Vector2 = global_position - desired
	var accel: Vector2 = -k * delta - c * _vel
	_vel += accel * dt

	# arrive behavior
	var arrive_speed_cap: float = dist / max(arrive_time, 0.001)
	var speed_cap: float = min(max_speed, arrive_speed_cap)
	if _vel.length() > speed_cap:
		_vel = _vel.normalized() * speed_cap

	global_position += _vel * dt

	_face_player(tpos)
	_last_target_pos = tpos


func _face_player(tpos: Vector2) -> void:
	var s = get_node_or_null("AnimatedSprite2D")
	if s:
		s.set("flip_h", global_position.x > tpos.x)


func _get_target_velocity(dt: float) -> Vector2:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).velocity

	# estimate from position delta (smoothed) + decay toward zero near idle
	var raw: Vector2 = (target.global_position - _last_target_pos) / max(dt, 1e-5)
	_est_target_vel = lerp(_est_target_vel, raw, 0.35)

	var spd: float = _est_target_vel.length()
	if spd < idle_speed_threshold * 0.75:
		var decay: float = clamp(6.0 * dt, 0.0, 1.0)
		_est_target_vel = _est_target_vel.move_toward(Vector2.ZERO, spd * decay)

	return _est_target_vel


func _debounced_trail_side(vx: float, dt: float) -> void:
	# keep shoulder while parked idle
	if _idle_timer >= idle_hold:
		_side_timer = 0.0
		return

	var speed: float = abs(vx)
	if speed >= min_move_for_trail:
		if vx != 0.0:
			_pending_sign = signf(vx)
		_side_timer += dt
		if _side_timer >= side_flip_hold and _trail_sign != _pending_sign:
			_trail_sign = _pending_sign
			_side_timer = 0.0
	else:
		_side_timer = 0.0


func _current_trailing_offset(idle_mix: float) -> Vector2:
	# blend move→idle offsets and mirror by trailing side
	var off: Vector2 = rest_offset_move.lerp(rest_offset_idle, idle_mix)
	off.x = -_trail_sign * abs(off.x)

	# enforce minimal shoulder gap
	var absx: float = abs(off.x)
	if absx < shoulder_gap:
		off.x = signf(off.x) * shoulder_gap

	return off


# Dynamic lag based on player horizontal speed
func _speed_trailing_offset(tvel: Vector2) -> Vector2:
	var extra_x: float = clamp(abs(tvel.x) * drag_per_speed, 0.0, drag_max)
	return Vector2(-_trail_sign * extra_x, 0.0)


static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clamp((x - edge0) / max(edge1 - edge0, 1e-5), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
