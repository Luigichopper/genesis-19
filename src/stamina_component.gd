class_name StaminaComponent
extends Node

signal stamina_changed(current: float, max_stamina: float, is_exhausted: bool)

@export var max_stamina: float = 100.0
@export var drain_rate: float = 25.0       # per second while sprinting
@export var regen_rate: float = 15.0       # per second while not sprinting
@export_range(0.1, 1.0, 0.05) var recovery_percent: float = 0.35 # Requires 35% stamina refill before sprinting again

var current_stamina: float
var is_exhausted: bool = false

func _ready() -> void:
	current_stamina = max_stamina

func drain(delta: float) -> void:
	if is_exhausted:
		return

	current_stamina = max(current_stamina - drain_rate * delta, 0.0)
	if current_stamina <= 0.0:
		is_exhausted = true
	
	stamina_changed.emit(current_stamina, max_stamina, is_exhausted)

func regen(delta: float) -> void:
	var required_recovery: float = max_stamina * recovery_percent
	current_stamina = min(current_stamina + regen_rate * delta, max_stamina)

	if is_exhausted and current_stamina >= required_recovery:
		is_exhausted = false

	stamina_changed.emit(current_stamina, max_stamina, is_exhausted)

func can_sprint() -> bool:
	return not is_exhausted and current_stamina > 0.0
