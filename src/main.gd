extends Node3D

const ITEM_PICKUP_SCENE: PackedScene = preload("res://src/items/item_pickup_3d.tscn")

@onready var player_container: Node3D = %PlayerContainer
@onready var item_container: Node3D = %ItemContainer
@onready var item_spawner: MultiplayerSpawner = %ItemSpawner

func _ready() -> void:
	if item_spawner:
		item_spawner.spawn_function = _spawn_item_pickup

	# Tell the host that THIS peer has finished loading main.tscn
	_client_ready_for_spawning.rpc_id(1)

func _spawn_item_pickup(data: Dictionary) -> Node:
	var pickup: ItemPickup3D = ITEM_PICKUP_SCENE.instantiate() as ItemPickup3D
	var item_id: String = data.get("item_id", "")
	var count: int = data.get("count", 1)
	var ammo: int = data.get("ammo", -1)
	var item_data: ItemData = ItemRegistry.get_item_by_id(item_id)
	
	pickup.position = data.get("position", Vector3.ZERO)
	var impulse: Vector3 = data.get("impulse", Vector3.ZERO)
	pickup.setup(item_data, count, ammo, impulse)

	return pickup

@rpc("any_peer", "call_local", "reliable")
func request_spawn_item(item_id: String, count: int, ammo: int, pos: Vector3, impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	if item_spawner:
		var data: Dictionary = {
			"item_id": item_id,
			"count": count,
			"ammo": ammo,
			"position": pos,
			"impulse": impulse
		}
		item_spawner.spawn(data)

@rpc("any_peer", "call_local", "reliable")
func request_despawn_item(item_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var pickup: Node = get_node_or_null(item_path)
	if pickup and is_instance_valid(pickup):
		pickup.queue_free()

@rpc("any_peer", "call_local", "reliable")
func _client_ready_for_spawning() -> void:
	# Only the host handles actual spawning once client is ready
	if not multiplayer.is_server():
		return
	
	var sender_id: int = multiplayer.get_remote_sender_id()
	NetworkManager.spawn_player(sender_id, player_container)
