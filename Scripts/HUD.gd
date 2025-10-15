extends CanvasLayer

@onready var mask_pickup: CanvasItem = %MaskPickup
@onready var mask_name: Label       = %MaskName
@onready var mask_icon: TextureRect = %MaskIcon
@export var fade_duration: float = 1.0

const MASK_DESCRIPTIONS := {
	"Sight":    "Press SHIFT to make some walls vanish and others appear",
	"Movement": "You can now wall jump and slide down walls",
	"Wisdom":   "You now know how many masks you need",
}

func _ready() -> void:
	%MaskDescription.text = ""
	mask_pickup.modulate.a = 0.0
	# Listen to Global for pickups
	Global.mask_picked.connect(_on_global_mask_picked)

func _on_global_mask_picked(mask_type: String) -> void:
	# Update HUD text + icon
	mask_name.text = mask_type.to_upper()
	%MaskDescription.text = MASK_DESCRIPTIONS[mask_type]
	var tex = Global.get_mask_icon(mask_type)
	if tex:
		mask_icon.texture = tex

	# Re-show the pickup banner and (re)start timer
	for t in get_tree().get_processed_tweens():
		# Optional: kill any existing HUD tweens so we can replay the animation cleanly
		if t.is_valid():
			t.kill()

	mask_pickup.modulate.a = 0.0
	
	fade_in()

func fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(mask_pickup, "modulate:a", 1.0, fade_duration)
	tween.finished.connect(_on_fade_in_finished)

func _on_fade_in_finished() -> void:
	$MaskTimer.start(5.0)

func _on_mask_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(mask_pickup, "modulate:a", 0.0, 3.0)
