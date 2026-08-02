extends Node
# Autoload this as "NetworkManager"
# Handles GodotSteam P2P lobby creation/joining and wires the
# SteamMultiplayerPeer into Godot's high-level multiplayer API.

signal lobby_joined(lobby_id: int)
signal lobby_members_changed
signal player_list_changed
signal game_starting

const MAX_PLAYERS := 4
const PLAYER_SCENE := preload("res://src/player.tscn")
const GAME_SCENE := "res://src/main.tscn"

var lobby_id: int = 0
var players: Dictionary = {} # steam_id -> { "name": String }

func _ready() -> void:
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.join_requested.connect(_on_join_requested)

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _process(delta: float) -> void:
	Steam.run_callbacks()

# ---------- Hosting ----------

func host_game() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, MAX_PLAYERS)

func _on_lobby_created(connect_result: int, lobby: int) -> void:
	if connect_result != 1:
		push_error("Failed to create Steam lobby: %s" % connect_result)
		return

	lobby_id = lobby
	Steam.setLobbyJoinable(lobby_id, true)
	Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s station")

	var peer := SteamMultiplayerPeer.new()
	var host_result := peer.create_host(0) # 0 = pick a free virtual port
	if host_result != OK:
		push_error("Failed to create Steam host peer: %s" % host_result)
		return

	multiplayer.multiplayer_peer = peer
	# Host is always peer id 1 in Godot's high-level API.
	_register_player(Steam.getSteamID(), Steam.getPersonaName())
	lobby_joined.emit(lobby_id)

# ---------- Joining ----------

func join_lobby(target_lobby_id: int) -> void:
	Steam.joinLobby(target_lobby_id)

# NetworkManager.gd
func _on_lobby_joined(lobby: int, _perm: int, _locked: bool, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		push_error("Failed to join lobby: %s" % response)
		return

	lobby_id = lobby
	var host_steam_id := Steam.getLobbyOwner(lobby_id)

	if host_steam_id == Steam.getSteamID():
		return # Host path handled in _on_lobby_created

	var peer := SteamMultiplayerPeer.new()
	var client_result := peer.create_client(host_steam_id, 0)
	if client_result != OK:
		push_error("Failed to create Steam client peer: %s" % client_result)
		return

	multiplayer.multiplayer_peer = peer
	# NOTE: Do NOT emit lobby_joined here for clients yet if you want to ensure 
	# P2P setup is fully ready; wait for _on_connected_to_server.


func _on_join_requested(lobby: int, _friend_id: int) -> void:
	join_lobby(lobby)

func _on_lobby_match_list(lobbies: Array) -> void:
	# Populate a lobby browser UI with `lobbies` (array of lobby ids) if wanted.
	pass

func _on_lobby_chat_update(_lobby: int, _changed_id: int, _making_change_id: int, _chat_state: int) -> void:
	# Fires whenever someone joins/leaves the Steam lobby itself (this is
	# independent of Godot's multiplayer peer connection, so it updates the
	# UI immediately even before the P2P handshake finishes).
	lobby_members_changed.emit()

# ---------- Lobby UI helpers ----------
# These read straight from the Steam lobby, not the Godot MultiplayerAPI,
# so a lobby screen can show member names before anyone's `Player` node exists.

func is_host() -> bool:
	return lobby_id != 0 and Steam.getLobbyOwner(lobby_id) == Steam.getSteamID()

func get_lobby_members() -> Array:
	var result: Array = []
	if lobby_id == 0:
		return result
	var count := Steam.getNumLobbyMembers(lobby_id)
	for i in range(count):
		var steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		result.append({
			"steam_id": steam_id,
			"name": Steam.getFriendPersonaName(steam_id),
			"is_host": steam_id == Steam.getLobbyOwner(lobby_id),
		})
	return result

func leave_lobby() -> void:
	if lobby_id != 0:
		Steam.leaveLobby(lobby_id)
		lobby_id = 0

	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	players.clear()
	player_list_changed.emit()


func invite_friends() -> void:
	# Opens Steam's built-in overlay invite picker for the current lobby.
	# Steam handles the friend list UI, sending the invite, and (on their
	# end) triggering join_requested if they accept — nothing further
	# needed here for the happy path.
	if lobby_id == 0:
		push_warning("Can't invite: not in a lobby yet.")
		return
	Steam.activateGameOverlayInviteDialog(lobby_id)

# ---------- Starting the game ----------
# Only the host calls start_game(); the RPC below propagates the scene
# change to every connected client at the same moment.

func start_game() -> void:
	if not is_host():
		return
	_change_scene.rpc(GAME_SCENE)

@rpc("authority", "call_local", "reliable")
func _change_scene(scene_path: String) -> void:
	game_starting.emit()
	get_tree().change_scene_to_file(scene_path)

# ---------- Connection lifecycle (networking only, no spawn logic) ----------

func _on_connected_to_server() -> void:
	# Client P2P handshake complete!
	lobby_joined.emit(lobby_id)

func _on_connection_failed() -> void:
	push_error("Connection to host failed.")

func _on_server_disconnected() -> void:
	push_warning("Host disconnected.")
	get_tree().change_scene_to_file("res://src/ui/lobby_ui.tscn")

func _on_peer_connected(_id: int) -> void:
	# Purely informational (e.g. for a HUD player list) — spawning is
	# main.gd's responsibility, not this file's. See spawn_player() below.
	player_list_changed.emit()

func _on_peer_disconnected(_id: int) -> void:
	player_list_changed.emit()

# ---------- Player spawning ----------
# The host owns spawning; MultiplayerSpawner replicates the node creation
# to clients automatically as long as it's watching the container's path.
# main.gd is responsible for CALLING these at the right times, and for
# providing the container node — this file only knows how to spawn given
# a container, not where that container lives.

func spawn_existing_players(container: Node) -> void:
	if not multiplayer.is_server():
		return
	spawn_player(1, container) # host
	for peer_id in multiplayer.get_peers():
		spawn_player(peer_id, container)

func spawn_player(peer_id: int, container: Node) -> void:
	if container.has_node(str(peer_id)):
		return
	
	var player := PLAYER_SCENE.instantiate()
	# Set the name BEFORE add_child so the spawner uses this string across the network
	player.name = str(peer_id)
	container.add_child(player, true)

func despawn_player(peer_id: int, container: Node) -> void:
	if container.has_node(str(peer_id)):
		container.get_node(str(peer_id)).queue_free()

func _register_player(steam_id: int, player_name: String) -> void:
	players[steam_id] = { "name": player_name }
