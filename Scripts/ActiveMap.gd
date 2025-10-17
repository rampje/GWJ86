extends Node2D

var entered_launch_zone: bool = false



func _on_launchzone_body_entered(body: Node2D) -> void:
	if entered_launch_zone == false:
		entered_launch_zone = true
		$"../HUD".on_global_mask_picked("")
