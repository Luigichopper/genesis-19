class_name ItemRegistry
extends Node

static func get_item_by_id(id: String) -> ItemData:
	match id:
		"pipe_wrench":
			var wrench: WeaponData = WeaponData.new()
			wrench.id = "pipe_wrench"
			wrench.display_name = "Pipe Wrench"
			wrench.weapon_type = WeaponData.WeaponType.MELEE
			wrench.damage = 35.0
			wrench.attack_cooldown = 0.6
			wrench.attack_range = 2.5
			return wrench
		"pistol":
			var pistol: WeaponData = WeaponData.new()
			pistol.id = "pistol"
			pistol.display_name = "9mm Pistol"
			pistol.weapon_type = WeaponData.WeaponType.RANGED
			pistol.damage = 22.0
			pistol.attack_cooldown = 0.25
			pistol.max_ammo = 12
			pistol.reload_time = 1.6
			return pistol
		"keycard_alpha":
			var keycard: ItemData = ItemData.new()
			keycard.id = "keycard_alpha"
			keycard.display_name = "Keycard Alpha"
			return keycard
		_:
			var generic: ItemData = ItemData.new()
			generic.id = id
			generic.display_name = id.capitalize()
			return generic
