class_name InventoryComponent
extends Node

signal active_slot_changed(slot_index: int, item: ItemData)
signal inventory_updated

const MAX_SLOTS: int = 4

class InventorySlot:
	var item: ItemData = null
	var count: int = 0
	var current_ammo: int = 0

var slots: Array[InventorySlot] = []
var active_slot_index: int = 0

func _ready() -> void:
	slots.clear()
	for i in range(MAX_SLOTS):
		slots.append(InventorySlot.new())

func set_active_slot(index: int) -> void:
	var clamped_index := posmod(index, MAX_SLOTS)
	if active_slot_index != clamped_index:
		active_slot_index = clamped_index
		active_slot_changed.emit(active_slot_index, get_active_item())

func get_active_slot() -> InventorySlot:
	if active_slot_index >= 0 and active_slot_index < slots.size():
		return slots[active_slot_index]
	return null

func get_active_item() -> ItemData:
	var slot := get_active_slot()
	return slot.item if slot else null

func set_slot_item(slot_index: int, item: ItemData, count: int = 1, current_ammo: int = -1) -> void:
	if slot_index < 0 or slot_index >= MAX_SLOTS:
		return
		
	var slot := slots[slot_index]
	slot.item = item
	slot.count = count
	if item is WeaponData and (item as WeaponData).weapon_type == WeaponData.WeaponType.RANGED:
		slot.current_ammo = current_ammo if current_ammo >= 0 else (item as WeaponData).max_ammo
	else:
		slot.current_ammo = 0
		
	inventory_updated.emit()
	if slot_index == active_slot_index:
		active_slot_changed.emit(active_slot_index, get_active_item())

func add_item(item: ItemData, count: int = 1) -> bool:
	if not item:
		return false
		
	# Try stacking
	if item.is_stackable:
		for slot in slots:
			if slot.item and slot.item.id == item.id and slot.count < item.max_stack:
				slot.count += count
				inventory_updated.emit()
				active_slot_changed.emit(active_slot_index, get_active_item())
				return true

	# Find empty slot
	for i in range(MAX_SLOTS):
		if slots[i].item == null:
			set_slot_item(i, item, count)
			return true

	return false # Inventory full

func remove_active_item(amount: int = 1) -> void:
	var slot := get_active_slot()
	if not slot or not slot.item:
		return
		
	slot.count -= amount
	if slot.count <= 0:
		slot.item = null
		slot.count = 0
		slot.current_ammo = 0

	inventory_updated.emit()
	active_slot_changed.emit(active_slot_index, get_active_item())
