# res://src/ui/lobby_ui.gd
extends Control
# Attach to the root Control of lobby_ui.tscn.
# Expected child nodes (see scene tree notes):
#   HostJoinPanel/HostButton         (Button)
#   HostJoinPanel/JoinIDInput        (LineEdit)
#   HostJoinPanel/JoinButton         (Button)
#   LobbyPanel                       (Control, hidden until in a lobby)
#   LobbyPanel/LobbyIDLabel          (Label)
#   LobbyPanel/PlayerListContainer   (VBoxContainer)
#   LobbyPanel/StartButton           (Button, host-only)
#   LobbyPanel/LeaveButton           (Button)
#   StatusLabel                      (Label, for errors/waiting text)

@onready var host_join_panel: Control = $HostJoinPanel
@onready var host_button: Button = $HostJoinPanel/HostButton
@onready var join_id_input: LineEdit = $HostJoinPanel/JoinIDInput
@onready var join_button: Button = $HostJoinPanel/JoinButton

@onready var lobby_panel: Control = $LobbyPanel
@onready var lobby_id_label: Label = $LobbyPanel/LobbyIDLabel
@onready var player_list_container: VBoxContainer = $LobbyPanel/PlayerListContainer
@onready var invite_button: Button = $LobbyPanel/InviteButton
@onready var start_button: Button = $LobbyPanel/StartButton
@onready var leave_button: Button = $LobbyPanel/LeaveButton

@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	invite_button.pressed.connect(_on_invite_pressed)
	start_button.pressed.connect(_on_start_pressed)
	leave_button.pressed.connect(_on_leave_pressed)

	NetworkManager.lobby_joined.connect(_on_lobby_joined)
	NetworkManager.lobby_members_changed.connect(_refresh_player_list)

	lobby_panel.hide()
	status_label.text = ""

func _on_host_pressed() -> void:
	status_label.text = "Creating lobby..."
	NetworkManager.host_game()

func _on_join_pressed() -> void:
	var text := join_id_input.text.strip_edges()
	if not text.is_valid_int():
		status_label.text = "Enter a valid lobby ID."
		return
	status_label.text = "Joining..."
	NetworkManager.join_lobby(text.to_int())

func _on_lobby_joined(lobby_id: int) -> void:
	status_label.text = ""
	host_join_panel.hide()
	lobby_panel.show()
	lobby_id_label.text = "Lobby ID: %s  (share this with friends to join manually)" % lobby_id
	start_button.visible = NetworkManager.is_host()
	_refresh_player_list()

func _refresh_player_list() -> void:
	for child in player_list_container.get_children():
		child.queue_free()

	for member in NetworkManager.get_lobby_members():
		var label := Label.new()
		var suffix := " (Host)" if member["is_host"] else ""
		label.text = "%s%s" % [member["name"], suffix]
		player_list_container.add_child(label)

	# Only the host can start, and only once at least one player is present.
	start_button.disabled = not NetworkManager.is_host()

func _on_start_pressed() -> void:
	NetworkManager.start_game()

func _on_invite_pressed() -> void:
	NetworkManager.invite_friends()

func _on_leave_pressed() -> void:
	NetworkManager.leave_lobby()
	lobby_panel.hide()
	host_join_panel.show()
	for child in player_list_container.get_children():
		child.queue_free()
