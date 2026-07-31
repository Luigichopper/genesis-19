class_name ItemPickup3D
extends RigidBody3D

@export var item_data: ItemData
@export var count: int = 1
@export var ammo: int = -1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D

func _ready() -> void:
	# Enable custom collision & prompt text setup
	_update_visuals()

func setup(p_item: ItemData, p_count: int = 1, p_ammo: int = -1) -> void:
	item_data = p_item
	count = p_count
	ammo = p_ammo
	_update_visuals()

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if item_data:
		if item_data.world_mesh:
			mesh_instance.mesh = item_data.world_mesh
		elif item_data.held_mesh:
			mesh_instance.mesh = item_data.held_mesh
		
		if label_3d:
			var txt := item_data.display_name
			if count > 1:
				txt += " x%d" % count
			if ammo >= 0:
				txt += " [%d]" % ammo
			label_3d.text = "[E] Pick Up %s" % txt

func interact(player: CharacterBody3D) -> void:
	if not player or not item_data:
		return

	var inventory: InventoryComponent = player.get_node_or_null("InventoryComponent")
	if inventory:
		var current_ammo := ammo
		if item_data is WeaponData and current_ammo < 0:
			current_ammo = (item_data as WeaponData).max_ammo

		var added := inventory.add_item(item_data, count)
		if added:
			# If we picked up a ranged weapon, update the ammo count on the active/target slot
			if item_data is WeaponData and (item_data as WeaponData).weapon_type == WeaponData.WeaponType.RANGED:
				for slot in inventory.slots:
					if slot.item == item_data:
						slot.current_ammo = current_ammo
						break
				inventory.inventory_updated.emit()
			queue_free()
