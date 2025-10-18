# GameTimer.gd (pause-aware)
extends Node

@export var ignore_pause := true  # set true so this keeps processing while the game is paused
var _running := false
var _elapsed_s := 0.0

func _ready() -> void:
	if ignore_pause:
		process_mode = Node.PROCESS_MODE_ALWAYS  # keeps _process running even when paused

func _process(delta: float) -> void:
	if _running:
		_elapsed_s += delta

func start() -> void:
	_running = true

func stop() -> float:
	_running = false
	return _elapsed_s

func reset() -> void:
	_running = false
	_elapsed_s = 0.0

func get_elapsed() -> float:
	return _elapsed_s

func format_elapsed() -> String:
	var t := _elapsed_s
	var minutes := int(t) / 60
	var seconds := int(t) % 60
	return "%02d:%02d" % [minutes, seconds]
	#var millis  := int(round((t - int(t)) * 1000.0))
	#return "%02d:%02d.%03d" % [minutes, seconds, millis]
