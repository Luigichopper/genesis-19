extends Control

@onready var slot_container: HBoxContainer = $HBoxContainer

var slots_ui: Array[PanelContainer] = []
var labels_ui: Array[Label] = []

func _ready() -> void:
	slots_ui.clear()
	labels_ui.clear()
	for child in slot_container.get_children():
		if child is PanelContainer:
			slots_ui.append(child as PanelContainer)
			var label: Label = child.get_node_or_null("Label")
			if label:
				labels_ui.append(label)

func update_hotbar(inventory: InventoryComponent) -> void:
	if not inventory:
		return

	for i in range(slots_ui.size()):
		var slot_panel := slots_ui[i]
		var label := labels_ui[i] if i < labels_ui.size() else null

		var is_active := (i == inventory.active_slot_index)
		
		# Active slot highlight styling
		if is_active:
			slot_panel.modulate = Color(1.3, 1.2, 0.4, 1.0) # Yellowish highlight
		else:
			slot_panel.modulate = Color(0.7, 0.7, 0.7, 0.8)

		if label:
			var slot := inventory.slots[i] if i < inventory.slots.size() else null
			if slot and slot.item:
				if slot.item is WeaponData and (slot.item as WeaponData).weapon_type == WeaponData.WeaponType.RANGED:
					label.text = "%d: %s\n[%d/%d]" % [i + 1, slot.item.display_name, slot.current_ammo, (slot.item as WeaponData).max_ammo]
				elif slot.count > 1:
					label.text = "%d: %s x%d" % [i + 1, slot.item.display_name, slot.count]
				else:
					label.text = "%d: %s" % [i + 1, slot.item.display_name]
			else:
				label.text = "%d: [EMPTY]" % [i + 1]
