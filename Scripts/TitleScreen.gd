extends CanvasLayer


@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider:  HSlider = %MusicSlider
@onready var sfx_slider:    HSlider = %SfxSlider

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if Global.game_active == true:
			self.visible = !self.visible

func _ready() -> void:
	%OptionsWidgets.visible = false
	init_game()
	#start_game()
	
	#OPTIONS MENU
	# sliders operate in 0..1 with step 0.01
	for s in [master_slider, music_slider, sfx_slider]:
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.1
		s.value = 0.6
		s.ticks_on_borders = true

	# initialize from SoundManager
	master_slider.value = SoundManager.get_master_volume()
	music_slider.value  = SoundManager.get_music_volume()
	sfx_slider.value    = SoundManager.get_sfx_volume()

	# connect signals
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)


func _on_start_pressed() -> void:
	start_game()


func _on_quit_pressed() -> void:
	get_tree().quit()


func init_game() -> void:
	Global.player_active = false 
	$"../ActiveMap".visible = false
	$"../ActiveMap".modulate = Color(1, 1, 1, 0)

func start_game() -> void:
	Global.game_active = true
	self.visible = false
	%MenuButtons/Start.visible = false
	%MenuButtons/Resume.visible = true
	#%MenuButtons/Reset.visible = true
	$"../ActiveMap".visible = true
	var tween = get_tree().create_tween()
	tween.tween_property($"../ActiveMap", "modulate", Color(1, 1, 1, 1), 3)
	Global.player_active = true
	# find cleaner way to do this
	$"../HUD/TopCenter/MovementKeys".visible = true
	$"../HUD/TopCenter/Timer".start(3)
	GameTimer.start()
	
	#queue_free()


func _on_options_pressed() -> void:
	%MenuButtons.visible = false
	%OptionsWidgets.visible = true


func _on_back_button_pressed() -> void:
	%MenuButtons.visible = true
	%OptionsWidgets.visible = false
	
	
	
	
func _on_master_changed(v: float) -> void:
	SoundManager.set_master_volume(v)

func _on_music_changed(v: float) -> void:
	SoundManager.set_music_volume(v)

func _on_sfx_changed(v: float) -> void:
	SoundManager.set_sfx_volume(v)


func _on_resume_pressed() -> void:
	self.visible = false


func _on_reset_pressed() -> void:
	pass
	#Global.reset_game()
	#get_tree().change_scene_to_packed(Global.ACTIVE_MAP_SCENE)
	#get_tree().reload_current_scene()


func end_menu():
	%Resume.visible = false
	%Reset.visible = false
	%Options.visible = false
	%Quit.text = "EXIT GAME"
	%EndSpace.visible = true
	
