extends Node2D

@export_enum("Layer1","Layer2","Layer3") var layer_name: String = "Layer1"

@export var one_shot: bool = true   # only activate once?
@onready var marker := $Marker2D

func _ready() -> void:
	$Area2D.body_entered.connect(_on_area_2d_body_entered)

func _on_area_2d_body_entered(body: Node) -> void:
	if body == null or !body.is_in_group("Player"):
		return
	
	if layer_name == "Layer1"\
	 or (layer_name == "Layer3" and Global.sight_state == false)\
	 or (layer_name == "Layer2" and Global.sight_state == true):
		# Safely check if the body has the respawn_position property
		
		body.respawn()
		#if "respawn_position" in body:
			#body.global_position = body.respawn_position
		#else:
		#	push_warning("%s entered death area but has no respawn_position!" % body.name)

		# Optional: prevent re-triggering
		if one_shot:
			$Area2D.monitoring = false
			set_deferred("monitorable", false)
			
	
		
