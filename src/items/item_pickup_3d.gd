class_name ItemPickup3D
extends RigidBody3D

@export var item_data: ItemData
@export var count: int = 1
@export var ammo: int = -1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var label_3d: Label3D = $Label3D

var initial_impulse: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Enable custom collision & prompt text setup
	_update_visuals()
	if initial_impulse != Vector3.ZERO:
		apply_central_impulse.call_deferred(initial_impulse)

func setup(p_item: ItemData, p_count: int = 1, p_ammo: int = -1, p_impulse: Vector3 = Vector3.ZERO) -> void:
	item_data = p_item
	count = p_count
	ammo = p_ammo
	initial_impulse = p_impulse
	_update_visuals()
	if is_inside_tree() and initial_impulse != Vector3.ZERO:
		apply_central_impulse.call_deferred(initial_impulse)

func _update_visuals() -> void:
	if not is_node_ready():
		return

	if item_data:
		if item_data.world_mesh:
			mesh_instance.mesh = item_data.world_mesh
		elif item_data.held_mesh:
			mesh_instance.mesh = item_data.held_mesh
		
		if label_3d:
			var txt: String = item_data.display_name
			if count > 1:
				txt += " x%d" % count
			if ammo >= 0:
				txt += " [%d]" % ammo
			label_3d.text = "[E] Pick Up %s" % txt

func interact(player: CharacterBody3D) -> void:
	if not player or not item_data:
		return

	var inventory: InventoryComponent = null
	if "inventory" in player and player.inventory:
		inventory = player.inventory as InventoryComponent
	elif player.has_node("Components/InventoryComponent"):
		inventory = player.get_node("Components/InventoryComponent") as InventoryComponent
	elif player.has_node("InventoryComponent"):
		inventory = player.get_node("InventoryComponent") as InventoryComponent

	if inventory:
		var current_ammo: int = ammo
		if item_data is WeaponData and current_ammo < 0:
			current_ammo = (item_data as WeaponData).max_ammo

		var added: bool = inventory.add_item(item_data, count)
		if added:
			# If we picked up a ranged weapon, update the ammo count on the active/target slot
			if item_data is WeaponData and (item_data as WeaponData).weapon_type == WeaponData.WeaponType.RANGED:
				for slot: InventoryComponent.InventorySlot in inventory.slots:
					if slot.item and slot.item.id == item_data.id:
						slot.current_ammo = current_ammo
						break
				inventory.inventory_updated.emit()

			# Request despawn from host across network
			var main_node: Node = get_tree().current_scene
			if main_node and main_node.has_method("request_despawn_item"):
				main_node.request_despawn_item.rpc_id(1, get_path())
			else:
				queue_free()
