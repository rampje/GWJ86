extends Node

var sfx_player := AudioStreamPlayer.new()
var music_player := AudioStreamPlayer.new()

var current_music: AudioStream = null
var is_muted := false

# Volume control (0.0 to 1.0)
var music_volume := 0.5
var sfx_volume := 0.5

# Sounds/Audio
var sight_sound: AudioStream = load("uid://bxqcxooo62ixm")
var mask_pickup_sound: AudioStream = load("uid://b3yihbrydmrs4")

# remember last time each stream played (in seconds)
var _last_play_times: Dictionary = {}   # key -> float(seconds)

func _ready():
	set_process_input(true)
	add_child(sfx_player)
	add_child(music_player)

	sfx_player.bus = "SFX"
	music_player.bus = "Music"

	sfx_player.volume_db = linear_to_db(sfx_volume)
	music_player.volume_db = linear_to_db(music_volume)

func _input(event):
	if event.is_action_pressed("toggle_mute"):
		SoundManager.toggle_mute()

func toggle_mute():
	is_muted = !is_muted
	var target_db = -80 if is_muted else 0

	var sfx_index = AudioServer.get_bus_index("SFX")
	var music_index = AudioServer.get_bus_index("Music")
	print("SFX bus index:", sfx_index, " Music bus index:", music_index)

	AudioServer.set_bus_volume_db(sfx_index, target_db)
	AudioServer.set_bus_volume_db(music_index, target_db)

# helper for cooldown control
func _stream_key(stream: AudioStream) -> String:
	if stream == null:
		return ""
	var path := stream.resource_path
	return path if path != "" else str(stream.get_instance_id())

func _can_play(stream: AudioStream, cooldown_sec: float) -> bool:
	if cooldown_sec <= 0.0:
		return true
	var key := _stream_key(stream)
	if key == "":
		return true
	var now := Time.get_ticks_msec() / 1000.0
	var last = _last_play_times.get(key, -1e9)
	if (now - float(last)) < cooldown_sec:
		return false
	_last_play_times[key] = now
	return true

# add a small helper
func _sfx_base_db() -> float:
	return linear_to_db(sfx_volume)

### --- SFX PLAYBACK -----------------------------------
# add optional gain_db
func play_sfx(stream: AudioStream, pitch_randomize := false,
			  pitch_range := Vector2(0.85, 1.15),
			  cooldown_sec := 0.0,
			  gain_db := 0.0) -> void:
	if not stream:
		return
	if not _can_play(stream, cooldown_sec):
		return

	sfx_player.stop()
	sfx_player.stream = stream

	# per-sound pitch
	if pitch_randomize:
		sfx_player.pitch_scale = randf_range(pitch_range.x, pitch_range.y)
	else:
		sfx_player.pitch_scale = 1.00

	# apply per-sound loudness (relative to global sfx_volume)
	sfx_player.volume_db = _sfx_base_db() + gain_db

	# reset to base after it finishes so the next SFX isn't too loud
	if not sfx_player.finished.is_connected(_on_sfx_finished_reset):
		sfx_player.finished.connect(_on_sfx_finished_reset, CONNECT_ONE_SHOT)

	sfx_player.play()

func _on_sfx_finished_reset() -> void:
	sfx_player.volume_db = _sfx_base_db()


### --- MUSIC PLAYBACK ---------------------------------

func play_music(stream: AudioStream, loop := true) -> void:
	if current_music == stream:
		return  # Already playing
	music_player.stop()
	music_player.stream = stream
	music_player.loop = loop
	current_music = stream
	music_player.play()

func stop_music() -> void:
	music_player.stop()
	current_music = null

### --- VOLUME CONTROL ---------------------------------

func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)
	if not is_muted:
		music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)
	if not is_muted:
		sfx_player.volume_db = linear_to_db(sfx_volume)

#helper functions 

# Called by player
func play_sight_sfx() -> void:
	play_sfx(sight_sound, true, Vector2(0.85, 1.15), 1.0, 10)
