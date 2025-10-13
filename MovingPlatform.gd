extends AnimatableBody2D

@export var waypoint_offsets: Array[Vector2] = []  # local offsets from starting position
@export var speed: float = 90.0
@export var wait_time: float = 0.3
@export var one_way: bool = false                  # jump-through platform

var _idx: int = 0
var _last_pos: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO                # starting position in world space

func _ready():
	_origin = global_position                       # capture starting position

	if one_way:
		var cs := $CollisionShape2D
		if cs and cs.shape is Shape2D:
			cs.one_way_collision = true

	_last_pos = global_position
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if waypoint_offsets.is_empty():
		self.constant_linear_velocity = Vector2.ZERO
		return

	# compute target as offset from origin
	var target: Vector2 = _origin + waypoint_offsets[_idx]
	var to_target: Vector2 = target - global_position
	var dist: float = to_target.length()

	if dist < 1.0:
		# arrived
		global_position = target
		self.constant_linear_velocity = Vector2.ZERO
		await get_tree().create_timer(wait_time, true).timeout
		_idx = (_idx + 1) % waypoint_offsets.size()
	else:
		var step: float = minf(speed * delta, dist)
		var new_pos: Vector2 = global_position + to_target.normalized() * step

		# tell characters how the floor moved
		self.constant_linear_velocity = (new_pos - global_position) / delta
		global_position = new_pos

	_last_pos = global_position
