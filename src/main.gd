extends Node3D
# Attach to the root node of src/main.tscn (whatever type that root is —
# Node3D shown here, adjust if yours is different).
# Expects a direct child named "PlayerContainer" with a MultiplayerSpawner
# elsewhere in the scene watching that path.

@onready var container := $PlayerContainer

func _ready() -> void:
	NetworkManager.spawn_existing_players(container)
