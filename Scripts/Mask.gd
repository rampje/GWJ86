extends Node2D

signal picked_up(mask_type: String)

const MASK_TYPES := ["Sight", "Movement","Attack","Wisdom"]

@export_enum("Sight", "Movement","Attack","Wisdom") var mask_type: String = "Sight"

# bobbing anim settings
@export var bob_amplitude: float = 3.0
@export var bob_period: float = 1.2
@export var wobble_rot: float = 2.0
@export var wobble_scale: float = 0.02
@export var snap_to_pixels: bool = true

#var MASK_TEXTURES: Dictionary = {}  # Dictionary[String, Texture2D]
var _base_y: float


func _ready() -> void:
	# Use Callable to avoid ambiguities and to check is_connected.
	var cb := Callable(Global, "on_mask_picked")
	if not picked_up.is_connected(cb):
		var ok := picked_up.connect(cb)
		print("Mask connect to Global.on_mask_picked -> ", ok)
	

	# Apply texture to sprite
	_apply_mask()

	# Connect pickup signal
	$Area2D.body_entered.connect(_on_area_2d_body_entered)

	# Prepare bobbing animation
	_base_y = $Visual.position.y

	var t1 := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t1.tween_property($Visual, "position:y", _base_y + bob_amplitude, bob_period)
	t1.tween_property($Visual, "position:y", _base_y - bob_amplitude, bob_period)

	var t2 := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t2.tween_property($Visual, "rotation_degrees",  wobble_rot, bob_period)
	t2.tween_property($Visual, "rotation_degrees", -wobble_rot, bob_period)

	var t3 := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t3.tween_property($Visual, "scale", Vector2.ONE * (1.0 + wobble_scale), bob_period)
	t3.tween_property($Visual, "scale", Vector2.ONE * (1.0 - wobble_scale), bob_period)


func _process(_delta: float) -> void:
	# Snap visual to pixels (optional, helps avoid shimmer)
	if snap_to_pixels:
		$Visual.position = $Visual.position.round()


func _apply_mask() -> void:
	var tex_path = Global.MASK_ICON_PATHS.get(mask_type, "")
	if tex_path != "":
		var tex: Texture2D = load(tex_path)
		if tex:
			$Visual/Sprite2D.texture = tex
		else:
			push_warning("Failed to load texture at path: %s" % tex_path)
	else:
		push_warning("Missing texture path for mask type: %s" % mask_type)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":# and body.has_method("unlock_wall_ability"):
		#if mask_type == "Sight":
		#	Global.has_sight = true
		#	print(Global.has_sight)
		#elif mask_type == "Movement":
		#	Global.has_walljump = true
		# stop repeat triggers just in case
		$Area2D.monitoring = false
		# broadcast which mask was picked up
		picked_up.emit(mask_type)
		queue_free()
