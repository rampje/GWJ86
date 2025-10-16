extends Node2D

@export var target: Node2D
@export var rest_offset := Vector2(-7.0, -8.0)    # base offset magnitude; x will be mirrored
@export var smooth_time := 0.1
@export var max_speed := 900.0                     # was 1.0 — too small to catch up
@export var dead_zone := 0.5
@export var bob_amp := 8.0
@export var bob_hz := 1.1
@export var min_move_for_trail := 5.0              # px/s threshold to decide “moving left/right”

var _vel: Vector2 = Vector2.ZERO           # ghost’s follow velocity (for smoothing)
var _t := 0.0
var _last_target_pos := Vector2.ZERO
var _trail_sign := 1.0                     # +1 means player moving right last; -1 means left

func _ready() -> void:
	if target == null:
		var g := get_tree().get_first_node_in_group("player")
		if g and g is Node2D: target = g
		else:
			var maybe := get_parent().get_node_or_null("Player")
			if maybe and maybe is Node2D: target = maybe

	if target == null:
		push_warning("Ghost: No target found. Assign 'target' or add Player to group 'player'.")
		return

	_last_target_pos = target.global_position
	global_position = (target.global_position + _current_trailing_offset()).round()
	set_physics_process(true)

func _physics_process(dt: float) -> void:
	if target == null: return

	# 1) Decide trailing side from target motion (prefers velocity if CharacterBody2D)
	var sign_now := _trail_sign
	if target is CharacterBody2D:
		var vx := (target as CharacterBody2D).velocity.x
		if abs(vx) >= min_move_for_trail:
			var sx := signf(vx)     # -1.0, 0.0, or 1.0
			if sx != 0.0:
				sign_now = sx
	else:
		# Fallback: estimate velocity from position change
		var dx = (target.global_position.x - _last_target_pos.x) / max(dt, 0.00001)
		if abs(dx) >= min_move_for_trail:
			var sx := signf(dx)
			if sx != 0.0:
				sign_now = sx

	# Remember last non-zero direction so we keep trailing when the player stops
	_trail_sign = sign_now
	_last_target_pos = target.global_position

	# 2) Build desired trailing offset + bob
	_t += dt
	var bob := Vector2(0.0, sin(_t * TAU * bob_hz) * bob_amp)
	var desired := target.global_position + _current_trailing_offset() + bob

	# SmoothDamp toward desired
	var delta_vec := desired - global_position
	if delta_vec.length() <= dead_zone:
		global_position = global_position.round()
		return

	var out := _smooth_damp_vec2(global_position, desired, _vel, smooth_time, max_speed, dt)
	var new_pos = out[0]
	_vel = out[1]
	global_position = new_pos.round()

	# Flip sprite to look toward the player (optional: looks “back” at you)
	var s := get_node_or_null("AnimatedSprite2D")
	if s != null:
		# Face the player: if ghost is to the left of player, face right, else face left
		s.set("flip_h", global_position.x > target.global_position.x)

# Mirror rest_offset.x to the trailing side: moving right => ghost on left (negative x)
func _current_trailing_offset() -> Vector2:
	return Vector2(-_trail_sign * abs(rest_offset.x), rest_offset.y)

# Returns [new_position: Vector2, new_velocity: Vector2]
func _smooth_damp_vec2(current: Vector2, target: Vector2, current_vel: Vector2, smooth_time: float, max_speed: float, dt: float) -> Array:
	smooth_time = max(0.0001, smooth_time)
	var omega := 2.0 / smooth_time
	var x := omega * dt
	var exp := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change := current - target
	var max_change := max_speed * smooth_time
	var change_len := change.length()
	if change_len > max_change:
		change *= (max_change / change_len)

	var temp := (current_vel + omega * change) * dt
	var new_vel := (current_vel - omega * temp) * exp
	var new_pos := target + (change + temp) * exp
	return [new_pos, new_vel]
