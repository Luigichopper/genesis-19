class_name IdleState
extends PlayerState

func physics_update(delta: float) -> void:
	if not player:
		return

	# 1. Check for directional movement -> transition to Walking
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length_squared() > 0.01:
		state_machine.transition_to("walking")
		return

	# 2. Gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta

	# 3. Jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and not player.is_crouching:
		player.velocity.y = player.jump_velocity

	# 4. Crouching while idle
	_handle_crouch(delta)

	# 5. Deceleration/Friction
	var decel_rate: float = player.deceleration if player.is_on_floor() else (player.air_control * 0.5)
	player.velocity.x = lerp(player.velocity.x, 0.0, decel_rate * delta)
	player.velocity.z = lerp(player.velocity.z, 0.0, decel_rate * delta)

	# 6. Stamina Regeneration while idle
	if player.stamina_component:
		player.stamina_component.regen(delta)

	# 7. Camera Effects (returning to center while standing/idle)
	_handle_camera(delta)

	player.move_and_slide()

func _handle_crouch(delta: float) -> void:
	var wants_crouch: bool = Input.is_action_pressed("crouch") and player.is_on_floor()
	if wants_crouch:
		player.is_crouching = true
	elif player.is_crouching:
		if player.ceiling_check and not player.ceiling_check.is_colliding():
			player.is_crouching = false

	var target_height: float = player.crouching_height if player.is_crouching else player.standing_height
	player.target_cam_y = (player.crouching_height * 0.4) if player.is_crouching else player.camera_start_y

	player.camera.position.y = lerp(player.camera.position.y, player.target_cam_y, player.crouch_transition_speed * delta)

	if player.collision_shape and player.collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = player.collision_shape.shape as CapsuleShape3D
		capsule.height = lerp(capsule.height, target_height, player.crouch_transition_speed * delta)
		player.collision_shape.position.y = capsule.height * 0.5 - player.standing_height * 0.5

func _handle_camera(delta: float) -> void:
	# Reset tilt & FOV smoothly while idle
	player.camera.fov = lerp(player.camera.fov, player.normal_fov, player.fov_change_speed * delta)
	player.camera.rotation.z = lerp(player.camera.rotation.z, 0.0, player.tilt_speed * delta)
	player.bob_time = 0.0
