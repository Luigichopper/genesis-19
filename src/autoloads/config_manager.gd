# res://src/config_manager.gd
extends Node

signal visual_settings_changed

const SAVE_PATH := "user://settings.cfg"

enum WindowMode {
	WINDOWED,
	FULLSCREEN,
	EXCLUSIVE_FULLSCREEN
}

# Default audio bus volumes (0.0 to 1.0 linear)
var audio_settings: Dictionary = {
	"Master": 1.0,
	"VC": 1.0,
	"SFX": 1.0,
	"BGM": 0.8,
	"UI": 1.0
}

# Voice Chat / Audio Device settings
var voice_settings: Dictionary = {
	"push_to_talk": true,
	"input_device": "Default",
	"output_device": "Default"
}

# Visual / Graphics settings
var visual_settings: Dictionary = {
	"window_mode": WindowMode.WINDOWED,
	"chromatic_aberration": true,
	"pixel_filter": false, # false = Nearest (PSX low-res pixelated), true = Linear (Smooth)
	"scanlines": true,
	"brightness": 1.0
}

func _ready() -> void:
	load_settings()

func set_bus_volume(bus_name: String, linear_value: float) -> void:
	audio_settings[bus_name] = clamp(linear_value, 0.0, 1.0)
	
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db := linear_to_db(audio_settings[bus_name])
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, audio_settings[bus_name] <= 0.001)

func apply_all_audio_settings() -> void:
	for bus: String in audio_settings:
		set_bus_volume(bus, audio_settings[bus])

func apply_device_settings() -> void:
	var saved_input: String = voice_settings.get("input_device", "Default")
	var saved_output: String = voice_settings.get("output_device", "Default")
	
	var input_devices: PackedStringArray = AudioServer.get_input_device_list()
	if saved_input in input_devices:
		AudioServer.input_device = saved_input

	var output_devices: PackedStringArray = AudioServer.get_output_device_list()
	if saved_output in output_devices:
		AudioServer.output_device = saved_output

func apply_visual_settings() -> void:
	# 1. Window Mode
	var mode: int = visual_settings.get("window_mode", WindowMode.WINDOWED)
	match mode:
		WindowMode.WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
		WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		WindowMode.EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

	# 2. Texture Filter (Pixel Filter Toggle)
	var pixel_filter: bool = visual_settings.get("pixel_filter", false)
	var filter_mode := Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR if pixel_filter else Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	get_tree().root.canvas_item_default_texture_filter = filter_mode

	# 3. Signal subscribers (e.g. HUD overlay shader) to refresh parameters
	visual_settings_changed.emit()

# Keybind settings (action_name -> InputEvent)
var keybind_settings: Dictionary = {}

const REBINDABLE_ACTIONS: Array[String] = [
	"pause_game",
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"jump",
	"sprint",
	"crouch",
	"flashlight",
	"interact",
	"drop_item",
	"primary_attack",
	"secondary_attack",
	"reload",
	"push_to_talk"
]



func apply_keybind_settings() -> void:
	for action in REBINDABLE_ACTIONS:
		if keybind_settings.has(action):
			var event: InputEvent = keybind_settings[action]
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)

# ---------- Save & Load Config ----------

func save_settings() -> void:
	var config := ConfigFile.new()
	
	for bus: String in audio_settings:
		config.set_value("Audio", bus, audio_settings[bus])
		
	for key: String in voice_settings:
		config.set_value("Voice", key, voice_settings[key])
		
	for key: String in visual_settings:
		config.set_value("Visuals", key, visual_settings[key])

	for action in REBINDABLE_ACTIONS:
		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			config.set_value("Keybinds", action, events[0])

	config.save(SAVE_PATH)
	apply_visual_settings()
	apply_keybind_settings()
	print_debug("Settings saved")

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		apply_all_audio_settings()
		apply_device_settings()
		apply_visual_settings()
		return

	for bus: String in audio_settings:
		audio_settings[bus] = config.get_value("Audio", bus, audio_settings[bus])
		
	for key: String in voice_settings:
		voice_settings[key] = config.get_value("Voice", key, voice_settings[key])
		
	for key: String in visual_settings:
		visual_settings[key] = config.get_value("Visuals", key, visual_settings[key])

	for action in REBINDABLE_ACTIONS:
		if config.has_section_key("Keybinds", action):
			var event: InputEvent = config.get_value("Keybinds", action)
			if event:
				keybind_settings[action] = event

	apply_all_audio_settings()
	apply_device_settings()
	apply_visual_settings()
	apply_keybind_settings()
	print_debug("Settings loaded")
