class_name InteractingState
extends PlayerState

var active_ui: Node = null
var active_interactable: InteractableObject = null

func enter(msg: Dictionary = {}) -> void:
	if msg.has("interactable"):
		active_interactable = msg["interactable"] as InteractableObject

	var ui_scene: PackedScene = msg.get("ui_scene", null) as PackedScene
	if not ui_scene and msg.has("ui"):
		active_ui = msg["ui"] as Node
	elif ui_scene:
		active_ui = ui_scene.instantiate()
		var canvas_layer: Node = player.get_tree().current_scene.get_node_or_null("HUDUI")
		if canvas_layer:
			canvas_layer.add_child(active_ui)
		else:
			player.get_tree().current_scene.add_child(active_ui)

		if active_ui.has_method("open") and active_interactable:
			active_ui.open(active_interactable, player)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if player:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.is_sprinting = false

func exit() -> void:
	if active_interactable and player:
		active_interactable.request_stop_interaction.rpc_id(1, player.get_path())

	if active_ui and is_instance_valid(active_ui):
		active_ui.queue_free()

	active_ui = null
	active_interactable = null

	if player and player.has_method("is_local_authority") and player.is_local_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func physics_update(delta: float) -> void:
	if not player:
		return

	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	else:
		player.velocity.y = 0.0

	player.velocity.x = 0.0
	player.velocity.z = 0.0

	player.camera.fov = lerp(player.camera.fov, player.normal_fov, player.fov_change_speed * delta)
	player.camera.rotation.z = lerp(player.camera.rotation.z, 0.0, player.tilt_speed * delta)
	player.bob_time = 0.0

	player.move_and_slide()

func unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		state_machine.transition_to("idle")
		if is_inside_tree():
			get_viewport().set_input_as_handled()
