class_name InteractableChest
extends InteractableObject

signal chest_inventory_updated

@export var capacity: int = 8
@export var default_items: Array[String] = ["pipe_wrench", "pistol", "keycard_alpha"]

# Array of dictionaries: {"item_id": String, "count": int, "ammo": int}
var chest_slots: Array[Dictionary] = []

func _ready() -> void:
	super._ready()
	object_name = "Storage Container"
	prompt_text = "Press E to Open Storage"
	if not interaction_ui_scene:
		interaction_ui_scene = load("res://src/ui/chest_ui.tscn")

	_initialize_slots()

func _initialize_slots() -> void:
	chest_slots.clear()
	for i in range(capacity):
		chest_slots.append({"item_id": "", "count": 0, "ammo": -1})

	if default_items.size() > 0:
		for i in range(mini(default_items.size(), capacity)):
			var item_id: String = default_items[i]
			var item_data: ItemData = ItemRegistry.get_item_by_id(item_id)
			if item_data:
				var ammo: int = (item_data as WeaponData).max_ammo if item_data is WeaponData and (item_data as WeaponData).weapon_type == WeaponData.WeaponType.RANGED else -1
				chest_slots[i] = {"item_id": item_id, "count": 1, "ammo": ammo}

func get_custom_data() -> Dictionary:
	return {
		"capacity": capacity,
		"items": chest_slots
	}

# Universal transfer RPC executed on the server/host
@rpc("any_peer", "call_local", "reliable")
func request_transfer_item(from_is_chest: bool, from_slot_idx: int, to_is_chest: bool, to_slot_idx: int, player_path: NodePath) -> void:
	if not multiplayer.is_server():
		return

	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if current_occupant_id != sender_id and current_occupant_id != 0:
		return # Not authorized

	var player: Node = get_node_or_null(player_path)
	if not player or not player.has_node("Components/InventoryComponent"):
		return

	var inventory: InventoryComponent = player.get_node("Components/InventoryComponent") as InventoryComponent

	if from_is_chest and to_is_chest:
		# Chest -> Chest slot swap
		if from_slot_idx >= 0 and from_slot_idx < chest_slots.size() and to_slot_idx >= 0 and to_slot_idx < chest_slots.size():
			var temp: Dictionary = chest_slots[from_slot_idx].duplicate()
			chest_slots[from_slot_idx] = chest_slots[to_slot_idx].duplicate()
			chest_slots[to_slot_idx] = temp

	elif from_is_chest and not to_is_chest:
		# Chest -> Player Hotbar slot
		if from_slot_idx >= 0 and from_slot_idx < chest_slots.size() and to_slot_idx >= 0 and to_slot_idx < InventoryComponent.MAX_SLOTS:
			var chest_slot: Dictionary = chest_slots[from_slot_idx]
			if chest_slot.get("item_id", "") != "":
				var item_id: String = chest_slot.get("item_id", "")
				var count: int = chest_slot.get("count", 1)
				var ammo: int = chest_slot.get("ammo", -1)
				var item_data: ItemData = ItemRegistry.get_item_by_id(item_id)

				var player_slot: InventoryComponent.InventorySlot = inventory.slots[to_slot_idx]
				var prev_p_item: ItemData = player_slot.item
				var prev_p_count: int = player_slot.count
				var prev_p_ammo: int = player_slot.current_ammo

				# Place chest item into player inventory
				inventory.set_slot_item(to_slot_idx, item_data, count, ammo)

				# Place previous player item into chest slot
				if prev_p_item:
					chest_slots[from_slot_idx] = {"item_id": prev_p_item.id, "count": prev_p_count, "ammo": prev_p_ammo}
				else:
					chest_slots[from_slot_idx] = {"item_id": "", "count": 0, "ammo": -1}

	elif not from_is_chest and to_is_chest:
		# Player Hotbar -> Chest slot
		if from_slot_idx >= 0 and from_slot_idx < InventoryComponent.MAX_SLOTS and to_slot_idx >= 0 and to_slot_idx < chest_slots.size():
			var player_slot: InventoryComponent.InventorySlot = inventory.slots[from_slot_idx]
			if player_slot.item:
				var item_data: ItemData = player_slot.item
				var count: int = player_slot.count
				var ammo: int = player_slot.current_ammo

				var chest_slot: Dictionary = chest_slots[to_slot_idx]
				var prev_c_item_id: String = chest_slot.get("item_id", "")
				var prev_c_count: int = chest_slot.get("count", 0)
				var prev_c_ammo: int = chest_slot.get("ammo", -1)

				# Place player item into chest slot
				chest_slots[to_slot_idx] = {"item_id": item_data.id, "count": count, "ammo": ammo}

				# Place previous chest item into player inventory
				if prev_c_item_id != "":
					var prev_c_item: ItemData = ItemRegistry.get_item_by_id(prev_c_item_id)
					inventory.set_slot_item(from_slot_idx, prev_c_item, prev_c_count, prev_c_ammo)
				else:
					inventory.set_slot_item(from_slot_idx, null, 0, 0)

	elif not from_is_chest and not to_is_chest:
		# Player Hotbar -> Player Hotbar slot swap
		if from_slot_idx >= 0 and from_slot_idx < InventoryComponent.MAX_SLOTS and to_slot_idx >= 0 and to_slot_idx < InventoryComponent.MAX_SLOTS:
			var slot_a: InventoryComponent.InventorySlot = inventory.slots[from_slot_idx]
			var slot_b: InventoryComponent.InventorySlot = inventory.slots[to_slot_idx]

			var item_a: ItemData = slot_a.item
			var count_a: int = slot_a.count
			var ammo_a: int = slot_a.current_ammo

			var item_b: ItemData = slot_b.item
			var count_b: int = slot_b.count
			var ammo_b: int = slot_b.current_ammo

			inventory.set_slot_item(from_slot_idx, item_b, count_b, ammo_b)
			inventory.set_slot_item(to_slot_idx, item_a, count_a, ammo_a)

	# Broadcast sync to all clients (use duplicate(true) to avoid local RPC reference alias)
	_sync_chest_inventory.rpc(chest_slots.duplicate(true))

@rpc("authority", "call_local", "reliable")
func _sync_chest_inventory(new_slots: Array) -> void:
	var incoming_slots: Array = new_slots.duplicate(true)
	chest_slots.clear()
	for slot in incoming_slots:
		if typeof(slot) == TYPE_DICTIONARY or slot is Dictionary:
			var d: Dictionary = slot as Dictionary
			chest_slots.append({
				"item_id": String(d.get("item_id", "")),
				"count": int(d.get("count", 0)),
				"ammo": int(d.get("ammo", -1))
			})

	# Guarantee chest_slots size matches capacity
	while chest_slots.size() < capacity:
		chest_slots.append({"item_id": "", "count": 0, "ammo": -1})

	chest_inventory_updated.emit()
