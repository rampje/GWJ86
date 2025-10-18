extends Node

var sfx_player := AudioStreamPlayer.new()
var music_player := AudioStreamPlayer.new()

var current_music: AudioStream = null
var is_muted := false

var is_fading_music: bool = false


# volumes need to normalize
var master_volume := 0.7
var music_volume  := 0.5
var sfx_volume    := 0.5

# Buses (ensure these exist in Project > Audio > Bus Layout)
const BUS_MASTER := "Master"
const BUS_MUSIC  := "Music"
const BUS_SFX    := "SFX"

# Sounds/Audio
var music_sound: AudioStream = load("uid://c5le2hwmrhk5v")
var sight_sound: AudioStream = load("uid://bxqcxooo62ixm")
var mask_pickup_sound: AudioStream = load("uid://b3yihbrydmrs4")
var mask_barrier_cross: AudioStream = load("uid://cj7xavuppnu5k")

var _last_play_times: Dictionary = {}


func _ready():
	add_child(sfx_player)
	add_child(music_player)
	sfx_player.bus = BUS_SFX
	music_player.bus = BUS_MUSIC

	#_load_settings()
	_apply_volumes()
	play_music(music_sound)
	
	print(get_master_volume())
	print(get_music_volume())
	print(get_sfx_volume())
	

func _input(event):
	if event.is_action_pressed("toggle_mute"):
		SoundManager.toggle_mute()


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



### --- SFX PLAYBACK -----------------------------------
func play_sfx(stream: AudioStream, pitch_randomize := false,
			  pitch_range := Vector2(0.85, 1.15),
			  cooldown_sec := 0.0,
			  gain_db := 0.0) -> void:
	if not stream or not _can_play(stream, cooldown_sec):
		return
	sfx_player.stop()
	sfx_player.stream = stream
	sfx_player.pitch_scale = (randf_range(pitch_range.x, pitch_range.y)
							  if pitch_randomize else 1.0)
	# Player stays at 0 dB by default; only apply the per-clip offset:
	sfx_player.volume_db = gain_db
	if not sfx_player.finished.is_connected(_on_sfx_finished_reset):
		sfx_player.finished.connect(_on_sfx_finished_reset, CONNECT_ONE_SHOT)
	sfx_player.play()

func _on_sfx_finished_reset() -> void:
	sfx_player.volume_db = 0.0   # reset to neutral

### --- MUSIC PLAYBACK ---------------------------------
func play_music(stream: AudioStream) -> void:
	if current_music == stream:
		return
	music_player.stop()
	music_player.stream = stream
	music_player.volume_db = 5.0
	current_music = stream
	music_player.play()


func stop_music() -> void:
	music_player.stop()
	current_music = null


#helper functions 
# Called by player
func play_sight_sfx() -> void:
	play_sfx(sight_sound, true, Vector2(0.95, 1.05), 1.0, -4.0)




# Map 0..1 slider -> dB with 0.5 = 0 dB
func _slider_to_db(v: float, down_db := -40.0, up_db := 6.0, curve := 1.0) -> float:
	v = clamp(v, 0.0, 1.0)
	if v < 0.5:
		# below mid: fade from down_db up to 0 dB
		var t := pow(v / 0.5, curve)          # perceptual curve; 1.0 = linear in dB
		return lerp(down_db, 0.0, t)
	else:
		# above mid: rise from 0 dB up to +up_db
		var t := pow((v - 0.5) / 0.5, curve)
		return lerp(0.0, up_db, t)

func _apply_volumes() -> void:
	var i_master := AudioServer.get_bus_index(BUS_MASTER)
	var i_music  := AudioServer.get_bus_index(BUS_MUSIC)
	var i_sfx    := AudioServer.get_bus_index(BUS_SFX)

	var master_db := _slider_to_db(master_volume)
	var music_db  := _slider_to_db(music_volume)
	var sfx_db    := _slider_to_db(sfx_volume)

	if is_muted:
		AudioServer.set_bus_volume_db(i_master, -80.0)
	else:
		AudioServer.set_bus_volume_db(i_master, master_db)
		# ⬇️ skip changing the Music bus during a fade
		if not is_fading_music:
			AudioServer.set_bus_volume_db(i_music, music_db)
		AudioServer.set_bus_volume_db(i_sfx, sfx_db)
		
		
# --- Public setters/getters for the UI ---
func set_master_volume(v: float) -> void:
	master_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()
	#_save_settings()

func set_music_volume(v: float) -> void:
	if is_fading_music:
		# Ignore UI while fading to avoid stomping the fade
		music_volume = clamp(v, 0.0, 1.0)
		return
	music_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()

func set_sfx_volume(v: float) -> void:
	sfx_volume = clamp(v, 0.0, 1.0)
	_apply_volumes()
	#_save_settings()

func get_master_volume() -> float: return master_volume
func get_music_volume()  -> float: return music_volume
func get_sfx_volume()    -> float: return sfx_volume

func toggle_mute():
	is_muted = !is_muted
	_apply_volumes()

func fade_music_bus(seconds: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx == -1: return
	is_fading_music = true
	var start_db: float = AudioServer.get_bus_volume_db(idx)
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
		var u = clamp(t / seconds, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)  # smoothstep
		AudioServer.set_bus_volume_db(idx, lerp(start_db, -60.0, u))
	# snap & stop
	AudioServer.set_bus_volume_db(idx, -60.0)
	if music_player.playing: music_player.stop()
	is_fading_music = false
