class_name InteractableTerminal
extends InteractableObject

@export var terminal_title: String = "SECURITY TERMINAL ALPHA"
@export_multiline var terminal_logs: String = "SYSTEM INITIALIZED.\nSECURITY LOG: Unauthorized access detected in Sector 4.\nSTATUS: All bulkheads locked."
@export var security_level: int = 2
@export var is_unlocked: bool = false

func _ready() -> void:
	super._ready()
	object_name = "Access Terminal"
	prompt_text = "Press E to Access Terminal"
	if not interaction_ui_scene:
		interaction_ui_scene = load("res://src/ui/terminal_ui.tscn")

func get_custom_data() -> Dictionary:
	return {
		"title": terminal_title,
		"logs": terminal_logs,
		"security_level": security_level,
		"is_unlocked": is_unlocked
	}
