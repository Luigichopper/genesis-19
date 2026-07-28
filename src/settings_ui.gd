# res://src/settings_ui.gd
extends Control

@onready var master_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/MasterSlider
@onready var vc_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/VCSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/SFXSlider
@onready var bgm_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/BGMSlider
@onready var ui_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/UISlider

@onready var ptt_mode_button: CheckButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/PTTModeButton
@onready var input_device_option_button: OptionButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/InputDeviceOptionButton
@onready var output_device_option_button: OptionButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/OutputDeviceOptionButton

@onready var apply_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var back_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/BackButton

func _ready() -> void:
	_populate_audio_sliders()
	_populate_voice_settings()
	
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)

func _populate_audio_sliders() -> void:
	var sliders: Dictionary = {
		"Master": master_slider,
		"VC": vc_slider,
		"SFX": sfx_slider,
		"BGM": bgm_slider,
		"UI": ui_slider
	}
	
	for bus: String in sliders:
		var slider: HSlider = sliders[bus]
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = ConfigManager.audio_settings[bus]
		
		slider.value_changed.connect(func(val: float) -> void: ConfigManager.set_bus_volume(bus, val))

func _populate_voice_settings() -> void:
	ptt_mode_button.button_pressed = ConfigManager.voice_settings.get("push_to_talk", true)
	ptt_mode_button.toggled.connect(func(toggled: bool) -> void: ConfigManager.voice_settings["push_to_talk"] = toggled)
	
	# --- Populate Microphone / Input Devices ---
	input_device_option_button.clear()
	var input_devices: PackedStringArray = AudioServer.get_input_device_list()
	var current_input_device: String = AudioServer.input_device
	
	for i in range(input_devices.size()):
		var dev_name: String = input_devices[i]
		input_device_option_button.add_item(dev_name, i)
		if dev_name == current_input_device:
			input_device_option_button.select(i)
			
	input_device_option_button.item_selected.connect(_on_input_device_selected)

	# --- Populate Speaker / Output Devices ---
	output_device_option_button.clear()
	var output_devices: PackedStringArray = AudioServer.get_output_device_list()
	var current_output_device: String = AudioServer.output_device
	
	for i in range(output_devices.size()):
		var dev_name: String = output_devices[i]
		output_device_option_button.add_item(dev_name, i)
		if dev_name == current_output_device:
			output_device_option_button.select(i)
			
	output_device_option_button.item_selected.connect(_on_output_device_selected)

func _on_input_device_selected(index: int) -> void:
	var dev_name: String = input_device_option_button.get_item_text(index)
	AudioServer.input_device = dev_name
	ConfigManager.voice_settings["input_device"] = dev_name

func _on_output_device_selected(index: int) -> void:
	var dev_name: String = output_device_option_button.get_item_text(index)
	AudioServer.output_device = dev_name
	ConfigManager.voice_settings["output_device"] = dev_name

func _on_apply_pressed() -> void:
	ConfigManager.save_settings()

func _on_back_pressed() -> void:
	ConfigManager.save_settings()
	hide()
