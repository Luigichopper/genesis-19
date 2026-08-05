extends Node

signal local_player_spawned(player: Node)
signal local_player_despawned(player: Node)
signal interaction_prompt_changed(prompt_text: String)

var local_player: Node = null

func _ready() -> void:
	local_player_spawned.connect(_on_local_player_spawned)
	local_player_despawned.connect(_on_local_player_despawned)

func _on_local_player_spawned(player: Node) -> void:
	local_player = player

func _on_local_player_despawned(player: Node) -> void:
	if local_player == player:
		local_player = null
