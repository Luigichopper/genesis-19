class_name InteractableObject
extends StaticBody3D

signal occupancy_changed(is_occupied: bool, occupant_peer_id: int)

@export var object_name: String = "Interactable Object"
@export var prompt_text: String = "Press E to Interact"
@export var interaction_ui_scene: PackedScene
@export var max_interaction_distance: float = 3.5

# 0 means unoccupied; otherwise holds the peer_id of the active interacting player
var current_occupant_id: int = 0:
	set(val):
		var old_val: int = current_occupant_id
		current_occupant_id = val
		if old_val != val:
			occupancy_changed.emit(current_occupant_id != 0, current_occupant_id)

func _ready() -> void:
	# Ensure object collision layer is detectable by raycast
	collision_layer = 1 | 2

func is_occupied() -> bool:
	return current_occupant_id != 0

func get_custom_data() -> Dictionary:
	return {}

func interact(player: Node) -> void:
	if not player or not player.has_method("is_local_authority") or not player.is_local_authority():
		return

	var dist: float = global_position.distance_to(player.global_position)
	if dist > max_interaction_distance:
		return

	# Request interaction lock from server
	request_start_interaction.rpc_id(1, player.get_path())

@rpc("any_peer", "call_local", "reliable")
func request_start_interaction(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if current_occupant_id == 0 or current_occupant_id == sender_id:
		current_occupant_id = sender_id
		_sync_occupant_state.rpc(current_occupant_id)
		_notify_interaction_granted.rpc_id(sender_id, player_path)
	else:
		_notify_interaction_denied.rpc_id(sender_id, player_path, "Object is currently in use by another operative.")

@rpc("any_peer", "call_local", "reliable")
func request_stop_interaction(player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if current_occupant_id == sender_id or sender_id == 1:
		current_occupant_id = 0
		_sync_occupant_state.rpc(0)

@rpc("authority", "call_local", "reliable")
func _sync_occupant_state(occupant_id: int) -> void:
	current_occupant_id = occupant_id

@rpc("authority", "call_local", "reliable")
func _notify_interaction_granted(player_path: NodePath) -> void:
	var player: Node = get_node_or_null(player_path)
	if player and player.has_method("start_interaction"):
		player.start_interaction(self, interaction_ui_scene)

@rpc("authority", "call_local", "reliable")
func _notify_interaction_denied(_player_path: NodePath, reason: String) -> void:
	print_rich("[color=yellow]Interaction Denied:[/color] %s" % reason)
