extends CharacterBody2D

@export var waypoint_offsets: Array[Vector2] = []
@export var speed: float = 90.0          # cruise speed (px/s)
@export var accel: float = 800.0         # how fast it ramps (px/s^2)
@export var wait_time: float = 0.3
@export var ping_pong: bool = true
@export var snap_to_pixels: bool = true  # good for pixel art
@export var arrive_epsilon: float = 0.6  # snap radius at waypoint
@export_enum("Layer1", "Layer2", "Layer3")
var platform_layer: String = "Layer1"

var _idx := 0
var _direction := 1
var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var platform_velocity := Vector2.ZERO    # for rider carry
var _enabled: bool

enum { MOVING, WAITING }
var _state := MOVING
var _wait_t := 0.0



func _ready() -> void:
	remove_from_group("Layer1")
	remove_from_group("Layer2")
	remove_from_group("Layer3")
	add_to_group(platform_layer)
	if self.is_in_group("Layer2"):
		set_platform_enabled(false)
	else:
		set_platform_enabled(true)
	
	_origin = global_position
	_target = _origin + (waypoint_offsets[0] if waypoint_offsets.size() > 0 else Vector2.ZERO)
	process_priority = -1   # move before player
	
	

func _physics_process(delta: float) -> void:
	if waypoint_offsets.is_empty():
		velocity = Vector2.ZERO
		platform_velocity = Vector2.ZERO
		move_and_slide()
		return

	match _state:
		MOVING:
			_move_toward_target(delta)
		WAITING:
			velocity = Vector2.ZERO
			platform_velocity = Vector2.ZERO
			move_and_slide()
			_wait_t -= delta
			if _wait_t <= 0.0:
				_advance_target()
				_state = MOVING

	# Optional pixel snap to kill any sub-pixel shimmer (helps camera too)
	if snap_to_pixels:
		global_position = global_position.round()

func _move_toward_target(delta: float) -> void:
	var to_target := _target - global_position
	var dist := to_target.length()

	# Arrive cleanly
	if dist <= arrive_epsilon:
		global_position = _target
		velocity = Vector2.ZERO
		platform_velocity = Vector2.ZERO
		move_and_slide()
		_wait_t = wait_time
		_state = WAITING
		return

	# Smooth acceleration toward cruise speed
	var dir := to_target / dist
	var target_vel := dir * speed
	velocity = velocity.move_toward(target_vel, accel * delta)

	# Don’t overshoot the target this frame
	var max_step = dist / max(delta, 1e-6)
	if velocity.length() > max_step:
		velocity = dir * max_step

	platform_velocity = velocity
	move_and_slide()

func _advance_target() -> void:
	if ping_pong:
		if _idx == waypoint_offsets.size() - 1:
			_direction = -1
		elif _idx == 0:
			_direction = 1
		_idx += _direction
	else:
		_idx = (_idx + 1) % waypoint_offsets.size()
	_target = _origin + waypoint_offsets[_idx]


# Call this from Player to show/hide and enable/disable collision
func set_platform_enabled(on: bool) -> void:
	_enabled = on
	self.visible = on
	# visuals (adjust if you use a Visual node)
	#if has_node("Visual"):
	#	$Visual.visible = on
	#elif has_node("Sprite2D"):
	#	$Sprite2D.visible = on
	# collision: disable all CollisionShape2D children
	for shape in get_children():
		_disable_shapes_recursive(shape, !on)

func _disable_shapes_recursive(node: Node, disabled: bool) -> void:
	if node is CollisionShape2D:
		node.disabled = disabled
	for c in node.get_children():
		_disable_shapes_recursive(c, disabled)
