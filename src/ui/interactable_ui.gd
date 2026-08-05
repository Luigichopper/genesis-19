class_name InteractableUI
extends Control

signal ui_closed

var active_interactable: InteractableObject = null
var bound_player: Node = null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS

func open(interactable: InteractableObject, player: Node) -> void:
	active_interactable = interactable
	bound_player = player
	show()

func close() -> void:
	if bound_player and bound_player.has_method("stop_interaction"):
		bound_player.stop_interaction()

	if active_interactable and bound_player:
		active_interactable.request_stop_interaction.rpc_id(1, bound_player.get_path())

	ui_closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		close()
		get_viewport().set_input_as_handled()
