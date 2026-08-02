extends Node3D

@onready var player_container: Node3D = %PlayerContainer

func _ready() -> void:
	# Tell the host that THIS peer has finished loading main.tscn
	_client_ready_for_spawning.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _client_ready_for_spawning() -> void:
	# Only the host handles actual spawning once client is ready
	if not multiplayer.is_server():
		return
	
	var sender_id := multiplayer.get_remote_sender_id()
	NetworkManager.spawn_player(sender_id, player_container)
