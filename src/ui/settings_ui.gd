# res://src/ui/settings_ui.gd
extends Control

@onready var audio_tab: AudioSettingsTab = $PanelContainer/VBoxContainer/TabContainer/AudioTab
@onready var voice_tab: VoiceSettingsTab = $PanelContainer/VBoxContainer/TabContainer/VoiceTab
@onready var visuals_tab: VisualsSettingsTab = $PanelContainer/VBoxContainer/TabContainer/VisualsTab
@onready var keybinds_tab: KeybindsSettingsTab = $PanelContainer/VBoxContainer/TabContainer/KeybindsTab

@onready var apply_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/ApplyButton
@onready var back_button: Button = $PanelContainer/VBoxContainer/ButtonContainer/BackButton

@onready var exit_prompt_container: PanelContainer = $ExitPromptContainer
@onready var yes_save_button: Button = $ExitPromptContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_save_button: Button = $ExitPromptContainer/VBoxContainer/HBoxContainer/NoButton

var has_unsaved_changes: bool = false
var tabs: Array[Control]

func _ready() -> void:
	tabs = [audio_tab, voice_tab, visuals_tab, keybinds_tab]

	apply_button.pressed.connect(_on_apply_pressed)
	back_button.pressed.connect(_on_back_pressed)
	yes_save_button.pressed.connect(_on_yes_save_pressed)
	no_save_button.pressed.connect(_on_no_save_pressed)

	for tab in tabs:
		tab.setting_changed.connect(_mark_unsaved)

	visibility_changed.connect(_on_visibility_changed)

func _mark_unsaved() -> void:
	has_unsaved_changes = true

func _on_visibility_changed() -> void:
	if visible:
		has_unsaved_changes = false
		for tab in tabs:
			tab.populate()

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
	ConfigManager.load_settings()
	has_unsaved_changes = false
	exit_prompt_container.hide()
	hide()
