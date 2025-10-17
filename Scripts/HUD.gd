extends CanvasLayer

@onready var mask_pickup: CanvasItem = %BottomCenter
@onready var mask_name: Label       = %MaskName
@onready var mask_icon: TextureRect = %MaskIcon
@export var fade_duration: float = 1.0

const MASK_DESCRIPTIONS := {
	"Sight":    "You can make some walls vanish and others appear by pressing SHIFT",
	"Movement": "You can now wall jump and slide down walls",
	"Wisdom":   "You now know how many masks you need",
	"Attack": "(NOT ADDED YET) You can now destroy weak walls ... and possibly foes?",
	"Lightness": "You can now slow fall by holding JUMP while in air",
	"Companionship": "You feel less alone",
	"Movement #2": "You can now jump again while in the air",
	"" : "Use the upward momentum of the moving platform to launch you",
	" ": "Time: "
}

func _ready() -> void:
	%MovementKeys.visible = false
	%MaskCount.visible = false
	%MaskDescription.text = ""
	mask_pickup.modulate.a = 0.0
	# Listen to Global for pickups
	Global.mask_picked.connect(on_global_mask_picked)
	
	# update mask count
	%MaskCountLabel.text = str(Global.current_mask_count)\
	 + " / " + str(Global.TOTAL_MASKS)

func on_global_mask_picked(mask_type: String) -> void:
	# Update HUD text + icon
	mask_name.text = mask_type.to_upper()
	
	var mask_description = MASK_DESCRIPTIONS[mask_type]
	if mask_type != " ":
		%MaskDescription.text = mask_description
	else: 
		%MaskDescription.text = mask_description + GameTimer.format_elapsed()
	
	if mask_type not in [""," "]:
		var tex = Global.get_mask_icon(mask_type)
		if tex:
			mask_icon.texture = tex
	else:
		mask_icon.texture = null
		
	# update mask count
	%MaskCountLabel.text = str(Global.current_mask_count)\
	 + " / " + str(Global.TOTAL_MASKS)
	
	# mask specific UI stuff
	if mask_type == "Sight":
		%SightKeys.visible = true
		%SightKeys/Timer.start(4)
	
	
	if mask_type == "Wisdom":
		%MaskCount.visible = true

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


func _on_move_keys_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(%MovementKeys, "modulate:a", 0.0, 1.5)


func _on_sight_key_timer_timeout() -> void:
	var tween := create_tween()
	tween.tween_property(%SightKeys, "modulate:a", 0.0, 1.5)
