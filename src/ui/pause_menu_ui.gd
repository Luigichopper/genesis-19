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

	if NetworkManager.players.size() > 0:
		for steam_id in NetworkManager.players:
			var player_info: Dictionary = NetworkManager.players[steam_id]
			var pname: String = player_info.get("name", "Player %s" % steam_id)
			var label := Label.new()
			label.text = "• " + pname
			player_list_container.add_child(label)
	else:
		# Fallback display for current local session
		var self_name := Steam.getPersonaName() if Steam.getPersonaName() != "" else "Local Operative"
		var label := Label.new()
		label.text = "• " + self_name
		player_list_container.add_child(label)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_settings_pressed() -> void:
	if settings_ui:
		settings_ui.show()

func _on_exit_menu_pressed() -> void:
	get_tree().paused = false
	NetworkManager.leave_lobby()
	get_tree().change_scene_to_file("res://src/ui/main_menu_ui.tscn")

func _on_exit_game_pressed() -> void:
	get_tree().paused = true
	NetworkManager.leave_lobby()
	get_tree().quit()
