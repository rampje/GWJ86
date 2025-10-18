# Background.gd
extends ColorRect

@export var smooth_speed := 8.0

# defaults for when you're in no zone:
@export var default_entropy := 2
@export var default_sharp   := 200
@export var default_tint    := Color(0, 0, 0)
@export var default_tint_mix := 0.0

# current values (what shader is using)
var _entropy := default_entropy
var _sharp   := default_sharp
var _tint    := default_tint
var _tint_mix := default_tint_mix

# target values (what active zone asks for)
var _t_entropy := default_entropy
var _t_sharp   := default_sharp
var _t_tint    := default_tint
var _t_tint_mix := default_tint_mix

# track how many zones you're inside (simple fallback logic)
var _active_zone_count := 0

func _ready() -> void:
	# Use a unique material instance
	material = material.duplicate()

	# EITHER: auto-connect by group…
	for z in get_tree().get_nodes_in_group("bg_zone"):
		_connect_zone(z)

	# …and catch zones added later
	get_tree().node_added.connect(_on_node_added)

	# OR (alternative): connect only children under BackgroundZones
	# for z in $"BackgroundZones".get_children():
	# 	if z is Area2D:
	# 		_connect_zone(z)

func _on_node_added(n: Node) -> void:
	if n.is_in_group("bg_zone"):
		_connect_zone(n)

func _connect_zone(z: Node) -> void:
	if z.has_signal("zone_enter"):
		z.zone_enter.connect(_on_zone_enter)
	if z.has_signal("zone_exit"):
		z.zone_exit.connect(_on_zone_exit)

func _on_zone_enter(params: Dictionary) -> void:
	_active_zone_count += 1
	_t_entropy = params.get("entropy", _t_entropy)
	_t_sharp   = params.get("sharpness", _t_sharp)
	_t_tint    = params.get("tint", _t_tint)
	_t_tint_mix = params.get("tint_mix", _t_tint_mix)

func _on_zone_exit(_params: Dictionary) -> void:
	_active_zone_count = max(0, _active_zone_count - 1)
	if _active_zone_count == 0:
		# revert to defaults if you're not in any zone
		_t_entropy = default_entropy
		_t_sharp   = default_sharp
		_t_tint    = default_tint
		_t_tint_mix = default_tint_mix

func _process(delta: float) -> void:
	var k := 1.0 - pow(0.001, smooth_speed * delta)  # framerate-independent ease
	_entropy = lerpf(_entropy, _t_entropy, k)
	_sharp   = lerpf(_sharp,   _t_sharp,   k)
	_tint    = _tint.lerp(_t_tint, k)
	_tint_mix = lerpf(_tint_mix, _t_tint_mix, k)

	material.set_shader_parameter("entropyFactor", _entropy)
	material.set_shader_parameter("sharpness", _sharp)
	material.set_shader_parameter("zone_tint", Vector3(_tint.r, _tint.g, _tint.b))
	material.set_shader_parameter("zone_tint_mix", _tint_mix)
