class_name PauseMenuUI
extends Control

@onready var resume_button: Button = $PanelContainer/VBoxContainer/MainHBox/LeftVBox/ResumeButton
@onready var settings_button: Button = $PanelContainer/VBoxContainer/MainHBox/LeftVBox/SettingsButton
@onready var exit_menu_button: Button = $PanelContainer/VBoxContainer/MainHBox/LeftVBox/ExitMenuButton
@onready var exit_game_button: Button = $PanelContainer/VBoxContainer/MainHBox/LeftVBox/ExitGameButton

@onready var player_list_container: VBoxContainer = $PanelContainer/VBoxContainer/MainHBox/RightVBox/PlayerListContainer
@onready var settings_ui: Control = $SettingsUI

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_menu_button.pressed.connect(_on_exit_menu_pressed)
	exit_game_button.pressed.connect(_on_exit_game_pressed)

	if NetworkManager.has_signal("player_list_changed"):
		NetworkManager.player_list_changed.connect(_update_player_list)
	if NetworkManager.has_signal("lobby_members_changed"):
		NetworkManager.lobby_members_changed.connect(_update_player_list)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if settings_ui and settings_ui.visible:
			# If settings UI is open inside pause menu, let settings close
			return

		# If local player is currently interacting with an object/chest/terminal:
		if EventBus.local_player and EventBus.local_player.has_method("is_interacting") and EventBus.local_player.is_interacting():
			EventBus.local_player.stop_interaction()
			if is_inside_tree():
				get_viewport().set_input_as_handled()
			return

		toggle_pause()
		if is_inside_tree():
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	visible = not visible

	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_player_list()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if settings_ui:
			settings_ui.hide()

func _update_player_list() -> void:
	if not player_list_container:
		return

	for child in player_list_container.get_children():
		child.queue_free()

	var members: Array = NetworkManager.get_lobby_members()
	if members.size() > 0:
		for member: Dictionary in members:
			var pname: String = member.get("name", "Operative")
			var is_host_flag: bool = member.get("is_host", false)
			var label: Label = Label.new()
			var suffix: String = " (Host)" if is_host_flag else ""
			label.text = "• " + pname + suffix
			player_list_container.add_child(label)
	else:
		# Fallback display for standalone local session
		var self_name: String = Steam.getPersonaName() if Steam.getPersonaName() != "" else "Local Operative"
		var label: Label = Label.new()
		label.text = "• " + self_name + " (Host)"
		player_list_container.add_child(label)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	if settings_ui:
		settings_ui.show()

func _on_exit_menu_pressed() -> void:
	get_tree().paused = false
	NetworkManager.leave_lobby()
	call_deferred("_deferred_exit_to_menu")

func _deferred_exit_to_menu() -> void:
	get_tree().change_scene_to_file("res://src/ui/main_menu_ui.tscn")

func _on_exit_game_pressed() -> void:
	get_tree().paused = true
	NetworkManager.leave_lobby()
	get_tree().quit()
