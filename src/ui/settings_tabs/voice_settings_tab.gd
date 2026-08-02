# res://src/ui/settings_tabs/voice_settings_tab.gd
class_name VoiceSettingsTab
extends Control

signal setting_changed

@onready var ptt_mode_button: CheckButton = $PTTModeButton
@onready var input_device_option_button: OptionButton = $InputDeviceOptionButton
@onready var output_device_option_button: OptionButton = $OutputDeviceOptionButton

func populate() -> void:
	ptt_mode_button.button_pressed = ConfigManager.voice_settings.get("push_to_talk", true)
	for c in ptt_mode_button.toggled.get_connections():
		ptt_mode_button.toggled.disconnect(c.callable)
	ptt_mode_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.voice_settings["push_to_talk"] = toggled
		setting_changed.emit()
	)

	input_device_option_button.clear()
	var input_devices: PackedStringArray = AudioServer.get_input_device_list()
	var current_input_device: String = AudioServer.input_device

	for i in range(input_devices.size()):
		var dev_name: String = input_devices[i]
		input_device_option_button.add_item(dev_name, i)
		if dev_name == current_input_device:
			input_device_option_button.select(i)

	for c in input_device_option_button.item_selected.get_connections():
		input_device_option_button.item_selected.disconnect(c.callable)
	input_device_option_button.item_selected.connect(_on_input_device_selected)

	output_device_option_button.clear()
	var output_devices: PackedStringArray = AudioServer.get_output_device_list()
	var current_output_device: String = AudioServer.output_device

	for i in range(output_devices.size()):
		var dev_name: String = output_devices[i]
		output_device_option_button.add_item(dev_name, i)
		if dev_name == current_output_device:
			output_device_option_button.select(i)

	for c in output_device_option_button.item_selected.get_connections():
		output_device_option_button.item_selected.disconnect(c.callable)
	output_device_option_button.item_selected.connect(_on_output_device_selected)

func _on_input_device_selected(index: int) -> void:
	var dev_name: String = input_device_option_button.get_item_text(index)
	AudioServer.input_device = dev_name
	ConfigManager.voice_settings["input_device"] = dev_name
	setting_changed.emit()

func _on_output_device_selected(index: int) -> void:
	var dev_name: String = output_device_option_button.get_item_text(index)
	AudioServer.output_device = dev_name
	ConfigManager.voice_settings["output_device"] = dev_name
	setting_changed.emit()
