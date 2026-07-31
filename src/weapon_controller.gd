class_name WeaponController
extends Node3D

@onready var viewmodel_mesh: MeshInstance3D = $ViewmodelMesh
@onready var attack_raycast: RayCast3D = $AttackRaycast
@onready var muzzle_light: OmniLight3D = $MuzzleLight

var inventory: InventoryComponent
var player: CharacterBody3D

var attack_cooldown_timer: float = 0.0
var is_reloading: bool = false
var reload_timer: float = 0.0

func setup(p_player: CharacterBody3D, p_inventory: InventoryComponent) -> void:
	player = p_player
	inventory = p_inventory
	if inventory:
		inventory.active_slot_changed.connect(_on_active_slot_changed)
		_on_active_slot_changed(inventory.active_slot_index, inventory.get_active_item())

func _process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			_finish_reload()

	if muzzle_light and muzzle_light.visible:
		muzzle_light.visible = false

func _on_active_slot_changed(_slot_index: int, item: ItemData) -> void:
	is_reloading = false
	if item and item.held_mesh:
		viewmodel_mesh.mesh = item.held_mesh
		viewmodel_mesh.visible = true
	else:
		viewmodel_mesh.mesh = null
		viewmodel_mesh.visible = false

func handle_primary_attack() -> void:
	if attack_cooldown_timer > 0.0 or is_reloading:
		return

	var slot := inventory.get_active_slot() if inventory else null
	if not slot or not slot.item or not (slot.item is WeaponData):
		return

	var weapon := slot.item as WeaponData

	if weapon.weapon_type == WeaponData.WeaponType.MELEE:
		_execute_melee_attack(weapon)
	elif weapon.weapon_type == WeaponData.WeaponType.RANGED:
		_execute_ranged_attack(slot, weapon)

func handle_reload() -> void:
	var slot := inventory.get_active_slot() if inventory else null
	if not slot or not slot.item or not (slot.item is WeaponData):
		return

	var weapon := slot.item as WeaponData
	if weapon.weapon_type == WeaponData.WeaponType.RANGED:
		if slot.current_ammo < weapon.max_ammo and not is_reloading:
			is_reloading = true
			reload_timer = weapon.reload_time
			print("Reloading %s..." % weapon.display_name)

func _finish_reload() -> void:
	var slot := inventory.get_active_slot() if inventory else null
	if slot and slot.item is WeaponData:
		var weapon := slot.item as WeaponData
		slot.current_ammo = weapon.max_ammo
		if inventory:
			inventory.inventory_updated.emit()
		print("%s reloaded!" % weapon.display_name)

func _execute_melee_attack(weapon: WeaponData) -> void:
	attack_cooldown_timer = weapon.attack_cooldown
	attack_raycast.target_position = Vector3(0, 0, -weapon.attack_range)
	attack_raycast.force_raycast_update()

	print("Melee Swing with %s" % weapon.display_name)

	if attack_raycast.is_colliding():
		var collider := attack_raycast.get_collider()
		var point := attack_raycast.get_collision_point()
		print("Melee hit: %s at %s" % [collider.name, point])
		if collider.has_method("take_damage"):
			collider.take_damage(weapon.damage, player)

func _execute_ranged_attack(slot: InventoryComponent.InventorySlot, weapon: WeaponData) -> void:
	if slot.current_ammo <= 0:
		print("Click! Out of ammo.")
		handle_reload()
		return

	slot.current_ammo -= 1
	attack_cooldown_timer = weapon.attack_cooldown

	if muzzle_light:
		muzzle_light.visible = true

	attack_raycast.target_position = Vector3(0, 0, -50.0)
	attack_raycast.force_raycast_update()

	print("Fired %s! Ammo left: %d" % [weapon.display_name, slot.current_ammo])

	if attack_raycast.is_colliding():
		var collider := attack_raycast.get_collider()
		var point := attack_raycast.get_collision_point()
		print("Shot hit: %s at %s" % [collider.name, point])
		if collider.has_method("take_damage"):
			collider.take_damage(weapon.damage, player)

	if inventory:
		inventory.inventory_updated.emit()
