# res://src/config_manager.gd
extends Node

const SAVE_PATH := "user://settings.cfg"

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

# ---------- Save & Load Config ----------

func save_settings() -> void:
	var config := ConfigFile.new()
	
	for bus: String in audio_settings:
		config.set_value("Audio", bus, audio_settings[bus])
		
	for key: String in voice_settings:
		config.set_value("Voice", key, voice_settings[key])
		
	config.save(SAVE_PATH)
	print("Settings saved")

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		apply_all_audio_settings()
		apply_device_settings()
		return

	for bus: String in audio_settings:
		audio_settings[bus] = config.get_value("Audio", bus, audio_settings[bus])
		
	for key: String in voice_settings:
		voice_settings[key] = config.get_value("Voice", key, voice_settings[key])
		
	apply_all_audio_settings()
	apply_device_settings()
	print("Settings loaded")
