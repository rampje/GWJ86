extends Area2D

@export var one_shot: bool = false
@export var set_facing_to_right: bool = true

# How big the particle node looks when idle vs active
@export var idle_particle_scale: Vector2 = Vector2(0.8, 0.8)
@export var active_particle_scale: Vector2 = Vector2(1.6, 1.6)
@export var tween_time: float = 0.18  # seconds

@onready var marker: Marker2D = $Marker2D
@onready var fx: CPUParticles2D = $CPUParticles2D

func _ready() -> void:
	add_to_group("SpawnPoints")
	body_entered.connect(_on_body_entered)

	if fx:
		fx.emitting = true
		_set_spawn_active()  # start idle, set instantly

func _on_body_entered(body: Node) -> void:
	if !(body is CharacterBody2D) or !body.is_in_group("Player"):
		return

	# update player's respawn
	body.respawn_position = marker.global_position
	if set_facing_to_right and ("_facing" in body):
		body._facing = 1

	# flip all spawns to idle, then this one to active
	get_tree().call_group("SpawnPoints", "_set_spawn_active", false, true)
	_set_spawn_active()

	if one_shot:
		monitoring = false
		set_deferred("monitorable", false)

# Called on each SpawnPoint to set its visual state
func _set_spawn_active() -> void:
	#var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	#tw.tween_property(fx, "scale", target, tween_time)
	$CPUParticles2D.scale_amount_min = 2.0
	$CPUParticles2D.scale_amount_max = 2.0
	
	for z in get_tree().get_nodes_in_group("spawn_points"):
		if z.name != self.name:
			z.set_spawn_inactive()
	

func set_spawn_inactive() -> void:
	$CPUParticles2D.scale_amount_min = 1
	$CPUParticles2D.scale_amount_max = 1
