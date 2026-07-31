class_name WeaponData
extends ItemData

enum WeaponType {
	MELEE,
	RANGED
}

@export var weapon_type: WeaponType = WeaponType.MELEE
@export var damage: float = 25.0
@export var attack_cooldown: float = 0.5 # Seconds between attacks
@export var attack_range: float = 2.5 # Range for melee

# Ranged specific parameters
@export var max_ammo: int = 12
@export var ammo_type: String = "9mm"
@export var recoil_kick: float = 0.05
@export var spread_angle: float = 0.02
@export var reload_time: float = 1.8
