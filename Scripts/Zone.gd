extends Area2D

signal zone_enter(params: Dictionary)
signal zone_exit(params: Dictionary)

# Expose per-zone look/feel.
@export var entropy: float = 1.5
@export var sharpness: float = 80.0
@export var tint: Color   = Color(0.8, 0.5, 0.5)
@export var tint_mix: float = 0.4

func _ready() -> void:
	# Put all zones in a common group so Background can auto-connect.
	add_to_group("bg_zone")
	# Make sure the Area actually monitors bodies
	monitoring = true
	# Signals for player entering/leaving
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		print('ZONE ENTERED: ' + self.name)
		zone_enter.emit({
			"entropy": entropy,
			"sharpness": sharpness,
			"tint": tint,
			"tint_mix": tint_mix
		})

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		zone_exit.emit({})
