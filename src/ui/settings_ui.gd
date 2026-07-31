# res://src/ui/settings_ui.gd
extends Control

@onready var master_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/MasterSlider
@onready var vc_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/VCSlider
@onready var sfx_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/SFXSlider
@onready var bgm_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/BGMSlider
@onready var ui_slider: HSlider = $PanelContainer/VBoxContainer/TabContainer/AudioTab/UISlider

@onready var ptt_mode_button: CheckButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/PTTModeButton
@onready var input_device_option_button: OptionButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/InputDeviceOptionButton
@onready var output_device_option_button: OptionButton = $PanelContainer/VBoxContainer/TabContainer/VoiceTab/OutputDeviceOptionButton

@onready var window_mode_option_button: OptionButton = $PanelContainer/VBoxContainer/TabContainer/VisualsTab/WindowModeOptionButton
@onready var ca_button: CheckButton = $PanelContainer/VBoxContainer/TabContainer/VisualsTab/ChromaticAberrationButton
@onready var pixel_filter_button: CheckButton = $PanelContainer/VBoxContainer/TabContainer/VisualsTab/PixelFilterButton
@onready var scanlines_button: CheckButton = $PanelContainer/VBoxContainer/TabContainer/VisualsTab/ScanlinesButton

@onready var keybinds_container: VBoxContainer = $PanelContainer/VBoxContainer/TabContainer/KeybindsTab/KeybindsContainer

@onready var apply_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var back_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/BackButton

@onready var exit_prompt_container: PanelContainer = $ExitPromptContainer
@onready var yes_save_button: Button = $ExitPromptContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_save_button: Button = $ExitPromptContainer/VBoxContainer/HBoxContainer/NoButton

var has_unsaved_changes: bool = false
var currently_rebinding_action: String = ""
var currently_rebinding_button: Button = null

func _ready() -> void:
	_populate_audio_sliders()
	_populate_voice_settings()
	_populate_visual_settings()
	_populate_keybind_settings()
	
	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	yes_save_button.pressed.connect(_on_yes_save_pressed)
	no_save_button.pressed.connect(_on_no_save_pressed)
	
	visibility_changed.connect(_on_visibility_changed)

func _unhandled_input(event: InputEvent) -> void:
	if currently_rebinding_action != "" and currently_rebinding_button != null:
		if event is InputEventKey or event is InputEventMouseButton:
			if event.is_pressed():
				# Avoid registering mouse click on the rebind button itself
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
					return
					
				InputMap.action_erase_events(currently_rebinding_action)
				InputMap.action_add_event(currently_rebinding_action, event)
				ConfigManager.keybind_settings[currently_rebinding_action] = event
				
				_mark_unsaved()
				_update_keybind_button_text(currently_rebinding_button, event)
				
				currently_rebinding_action = ""
				currently_rebinding_button = null
				get_viewport().set_input_as_handled()

func _on_visibility_changed() -> void:
	if visible:
		has_unsaved_changes = false
		currently_rebinding_action = ""
		currently_rebinding_button = null
		_populate_audio_sliders()
		_populate_voice_settings()
		_populate_visual_settings()
		_populate_keybind_settings()


func _mark_unsaved() -> void:
	has_unsaved_changes = true

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
		
		# Disconnect previous handlers to avoid duplicate connections
		for c in slider.value_changed.get_connections():
			slider.value_changed.disconnect(c.callable)
			
		slider.value_changed.connect(func(val: float) -> void:
			ConfigManager.set_bus_volume(bus, val)
			_mark_unsaved()
		)

func _populate_voice_settings() -> void:
	ptt_mode_button.button_pressed = ConfigManager.voice_settings.get("push_to_talk", true)
	for c in ptt_mode_button.toggled.get_connections():
		ptt_mode_button.toggled.disconnect(c.callable)
	ptt_mode_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.voice_settings["push_to_talk"] = toggled
		_mark_unsaved()
	)
	
	# --- Populate Microphone / Input Devices ---
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

	# --- Populate Speaker / Output Devices ---
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

func _populate_visual_settings() -> void:
	# Window Mode Options
	window_mode_option_button.clear()
	window_mode_option_button.add_item("Windowed", ConfigManager.WindowMode.WINDOWED)
	window_mode_option_button.add_item("Fullscreen", ConfigManager.WindowMode.FULLSCREEN)
	window_mode_option_button.add_item("Exclusive Fullscreen", ConfigManager.WindowMode.EXCLUSIVE_FULLSCREEN)

	var current_mode: int = ConfigManager.visual_settings.get("window_mode", ConfigManager.WindowMode.WINDOWED)
	window_mode_option_button.select(current_mode)

	for c in window_mode_option_button.item_selected.get_connections():
		window_mode_option_button.item_selected.disconnect(c.callable)
	window_mode_option_button.item_selected.connect(func(idx: int) -> void:
		ConfigManager.visual_settings["window_mode"] = idx
		ConfigManager.apply_visual_settings()
		_mark_unsaved()
	)

	# Chromatic Aberration
	ca_button.button_pressed = ConfigManager.visual_settings.get("chromatic_aberration", true)
	for c in ca_button.toggled.get_connections():
		ca_button.toggled.disconnect(c.callable)
	ca_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["chromatic_aberration"] = toggled
		ConfigManager.apply_visual_settings()
		_mark_unsaved()
	)

	# Texture Pixel Filtering
	pixel_filter_button.button_pressed = ConfigManager.visual_settings.get("pixel_filter", false)
	for c in pixel_filter_button.toggled.get_connections():
		pixel_filter_button.toggled.disconnect(c.callable)
	pixel_filter_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["pixel_filter"] = toggled
		ConfigManager.apply_visual_settings()
		_mark_unsaved()
	)

	# Scanlines
	scanlines_button.button_pressed = ConfigManager.visual_settings.get("scanlines", true)
	for c in scanlines_button.toggled.get_connections():
		scanlines_button.toggled.disconnect(c.callable)
	scanlines_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["scanlines"] = toggled
		ConfigManager.apply_visual_settings()
		_mark_unsaved()
	)

func _on_input_device_selected(index: int) -> void:
	var dev_name: String = input_device_option_button.get_item_text(index)
	AudioServer.input_device = dev_name
	ConfigManager.voice_settings["input_device"] = dev_name
	_mark_unsaved()

func _on_output_device_selected(index: int) -> void:
	var dev_name: String = output_device_option_button.get_item_text(index)
	AudioServer.output_device = dev_name
	ConfigManager.voice_settings["output_device"] = dev_name
	_mark_unsaved()

func _populate_keybind_settings() -> void:
	if not keybinds_container:
		return

	# Clear previous children
	for child in keybinds_container.get_children():
		child.queue_free()

	var action_labels: Dictionary = {
		"move_forward": "Move Forward",
		"move_back": "Move Back",
		"move_left": "Move Left",
		"move_right": "Move Right",
		"jump": "Jump",
		"sprint": "Sprint",
		"crouch": "Crouch",
		"flashlight": "Flashlight",
		"interact": "Interact",
		"primary_attack": "Primary Attack",
		"secondary_attack": "Secondary Attack",
		"reload": "Reload",
		"push_to_talk": "Push To Talk"
	}

	for action in ConfigManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = action_labels.get(action, action.capitalize())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 28)
		
		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			_update_keybind_button_text(btn, events[0])
		else:
			btn.text = "[ NONE ]"

		var current_action := action
		btn.pressed.connect(func() -> void:
			currently_rebinding_action = current_action
			currently_rebinding_button = btn
			btn.text = "< Press Key >"
		)

		row.add_child(btn)
		keybinds_container.add_child(row)

func _update_keybind_button_text(btn: Button, event: InputEvent) -> void:
	if event is InputEventKey:
		btn.text = OS.get_keycode_string(event.physical_keycode) if event.physical_keycode != 0 else OS.get_keycode_string(event.keycode)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: btn.text = "Mouse Left"
			MOUSE_BUTTON_RIGHT: btn.text = "Mouse Right"
			MOUSE_BUTTON_MIDDLE: btn.text = "Mouse Middle"
			MOUSE_BUTTON_XBUTTON1: btn.text = "Mouse Button 4"
			MOUSE_BUTTON_XBUTTON2: btn.text = "Mouse Button 5"
			_: btn.text = "Mouse %d" % event.button_index
	else:
		btn.text = event.as_text()

func _on_apply_pressed() -> void:
	ConfigManager.save_settings()
	has_unsaved_changes = false

func _on_back_pressed() -> void:
	if not has_unsaved_changes:
		hide()
	else:
		exit_prompt_container.show()

func _on_yes_save_pressed() -> void:
	ConfigManager.save_settings()
	has_unsaved_changes = false
	exit_prompt_container.hide()
	hide()

func _on_no_save_pressed() -> void:
	# Reload original settings from disk to undo previewed changes
	ConfigManager.load_settings()
	has_unsaved_changes = false
	exit_prompt_container.hide()
	hide()
