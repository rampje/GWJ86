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


func _ready():
	set_process_input(true)
	# Set up players
	add_child(sfx_player)
	add_child(music_player)

	sfx_player.bus = "SFX"
	music_player.bus = "Music"
	
	# Apply volumes
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


### --- SFX PLAYBACK -----------------------------------

func play_sfx(stream: AudioStream, pitch_randomize := false,
			  pitch_range := Vector2(0.85, 1.15)) -> void:
	if not stream:
		return

	sfx_player.stop()
	sfx_player.stream = stream

	if pitch_randomize:
		sfx_player.pitch_scale = randf_range(pitch_range[0], pitch_range[1])
	else:
		sfx_player.pitch_scale = 1.0

	sfx_player.play()


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
