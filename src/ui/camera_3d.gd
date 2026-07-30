# Attach to Camera3D or a parent Pivot Node3D
extends Node3D

@export var rotation_speed: float = 0.01

func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)
	rotate_z(rotation_speed/-2 * delta)
