class_name InteractingState
extends PlayerState

var active_ui: Node = null

func enter(msg: Dictionary = {}) -> void:
	if msg.has("ui"):
		active_ui = msg["ui"] as Node

	# Make mouse cursor visible for UI interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Stop horizontal movement
	if player:
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.is_sprinting = false

func exit() -> void:
	active_ui = null
	# Recapture mouse when leaving UI
	if player and player.has_method("is_local_authority") and player.is_local_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func physics_update(delta: float) -> void:
	if not player:
		return

	# Apply gravity if floating
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta
	else:
		player.velocity.y = 0.0

	# Ensure velocity is zero horizontally
	player.velocity.x = 0.0
	player.velocity.z = 0.0

	# Smoothly reset camera effects
	player.camera.fov = lerp(player.camera.fov, player.normal_fov, player.fov_change_speed * delta)
	player.camera.rotation.z = lerp(player.camera.rotation.z, 0.0, player.tilt_speed * delta)
	player.bob_time = 0.0

	player.move_and_slide()

func unhandled_input(_event: InputEvent) -> void:
	# All movement/combat inputs are ignored while interacting with UI
	pass
