class_name ChestUI
extends InteractableUI

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/TitleLabel
@onready var chest_grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/ChestSection/ChestGrid
@onready var player_grid: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/PlayerSection/PlayerGrid
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/CloseButton

var active_chest: InteractableChest = null

# Selection tracking for slot-to-slot transfer: {"is_chest": bool, "slot_idx": int}
var selected_source: Dictionary = {}

var chest_buttons: Array[Button] = []
var player_buttons: Array[Button] = []

func open(interactable: InteractableObject, player: Node) -> void:
	super.open(interactable, player)
	active_chest = interactable as InteractableChest

	if active_chest:
		title_label.text = active_chest.object_name.to_upper()
		if not active_chest.chest_inventory_updated.is_connected(refresh_ui):
			active_chest.chest_inventory_updated.connect(refresh_ui)

	if bound_player and bound_player.has_node("Components/InventoryComponent"):
		var inv: InventoryComponent = bound_player.get_node("Components/InventoryComponent")
		if not inv.inventory_updated.is_connected(refresh_ui):
			inv.inventory_updated.connect(refresh_ui)

	if close_button:
		if not close_button.pressed.is_connected(close):
			close_button.pressed.connect(close)

	_setup_button_pools()
	refresh_ui()

func _setup_button_pools() -> void:
	# Clear any design placeholder children completely
	if chest_grid:
		for child in chest_grid.get_children():
			chest_grid.remove_child(child)
			child.queue_free()

	if player_grid:
		for child in player_grid.get_children():
			player_grid.remove_child(child)
			child.queue_free()

	chest_buttons.clear()
	player_buttons.clear()

	var chest_cap: int = active_chest.capacity if active_chest else 8
	for i in range(chest_cap):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(110, 80)
		btn.clip_text = true
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_slot_clicked(true, idx))
		chest_grid.add_child(btn)
		chest_buttons.append(btn)

	var p_slots_count: int = InventoryComponent.MAX_SLOTS
	for i in range(p_slots_count):
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(110, 80)
		btn.clip_text = true
		var idx: int = i
		btn.pressed.connect(func() -> void: _on_slot_clicked(false, idx))
		player_grid.add_child(btn)
		player_buttons.append(btn)

func refresh_ui() -> void:
	_update_chest_buttons()
	_update_player_buttons()

func _update_chest_buttons() -> void:
	if not active_chest:
		return

	var custom_data: Dictionary = active_chest.get_custom_data()
	var slots: Array = custom_data.get("items", [])

	for i in range(chest_buttons.size()):
		var btn: Button = chest_buttons[i]
		var slot_data: Dictionary = slots[i] if i < slots.size() else {}
		var item_id: String = slot_data.get("item_id", "")
		var count: int = slot_data.get("count", 0)
		var ammo: int = slot_data.get("ammo", -1)

		var is_selected: bool = not selected_source.is_empty() and selected_source.get("is_chest") == true and selected_source.get("slot_idx") == i

		if is_selected:
			btn.modulate = Color(1.5, 1.3, 0.3, 1.0) # Yellow highlight
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

		if item_id != "":
			var item_data: ItemData = ItemRegistry.get_item_by_id(item_id)
			var display: String = item_data.display_name if item_data else item_id.capitalize()
			var text_str: String = display
			if ammo >= 0:
				text_str += "\n[%d]" % ammo
			elif count > 1:
				text_str += " x%d" % count
			btn.text = text_str
		else:
			btn.text = "[EMPTY]"
			btn.modulate = Color(0.6, 0.6, 0.6, 0.7)

func _update_player_buttons() -> void:
	if not bound_player or not bound_player.has_node("Components/InventoryComponent"):
		return

	var inv: InventoryComponent = bound_player.get_node("Components/InventoryComponent")
	for i in range(player_buttons.size()):
		var btn: Button = player_buttons[i]
		var inv_slot: InventoryComponent.InventorySlot = inv.slots[i] if i < inv.slots.size() else null

		var is_selected: bool = not selected_source.is_empty() and selected_source.get("is_chest") == false and selected_source.get("slot_idx") == i

		if is_selected:
			btn.modulate = Color(1.5, 1.3, 0.3, 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, 1.0)

		if inv_slot and inv_slot.item:
			var display: String = inv_slot.item.display_name
			var text_str: String = display
			if inv_slot.item is WeaponData and (inv_slot.item as WeaponData).weapon_type == WeaponData.WeaponType.RANGED:
				text_str += "\n[%d]" % inv_slot.current_ammo
			elif inv_slot.count > 1:
				text_str += " x%d" % inv_slot.count
			btn.text = text_str
		else:
			btn.text = "[EMPTY]"
			btn.modulate = Color(0.6, 0.6, 0.6, 0.7)

func _on_slot_clicked(is_chest: bool, slot_idx: int) -> void:
	if selected_source.is_empty():
		# First click: only select if the slot contains an item
		var has_item: bool = false
		if is_chest and active_chest:
			var custom_data: Dictionary = active_chest.get_custom_data()
			var slots: Array = custom_data.get("items", [])
			if slot_idx >= 0 and slot_idx < slots.size():
				has_item = slots[slot_idx].get("item_id", "") != ""
		elif not is_chest and bound_player and bound_player.has_node("Components/InventoryComponent"):
			var inv: InventoryComponent = bound_player.get_node("Components/InventoryComponent")
			if slot_idx >= 0 and slot_idx < inv.slots.size():
				has_item = inv.slots[slot_idx].item != null

		if has_item:
			selected_source = {"is_chest": is_chest, "slot_idx": slot_idx}
			refresh_ui()
	else:
		var from_is_chest: bool = selected_source["is_chest"]
		var from_slot_idx: int = selected_source["slot_idx"]
		var to_is_chest: bool = is_chest
		var to_slot_idx: int = slot_idx

		# Clear selection
		selected_source.clear()

		# If user clicks the exact same slot twice, just deselect
		if from_is_chest == to_is_chest and from_slot_idx == to_slot_idx:
			refresh_ui()
			return

		# Execute transfer request on host/server
		if active_chest and bound_player:
			active_chest.request_transfer_item.rpc_id(1, from_is_chest, from_slot_idx, to_is_chest, to_slot_idx, bound_player.get_path())

		refresh_ui()
