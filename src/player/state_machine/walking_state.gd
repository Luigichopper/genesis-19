class_name WalkingState
extends PlayerState

func physics_update(delta: float) -> void:
	if not player:
		return

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length_squared() <= 0.01:
		player.is_sprinting = false
		state_machine.transition_to("idle")
		return

	# 1. Gravity
	if not player.is_on_floor():
		player.velocity.y -= player.gravity * delta

	# 2. Jump
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and not player.is_crouching:
		player.velocity.y = player.jump_velocity

	# 3. Crouching
	_handle_crouch(delta)

	# 4. Sprinting & Stamina
	var wants_sprint: bool = Input.is_action_pressed("sprint") and not player.is_crouching and player.is_on_floor()
	if wants_sprint and player.stamina_component and player.stamina_component.can_sprint():
		player.is_sprinting = true
		player.stamina_component.drain(delta)
	else:
		player.is_sprinting = false
		if player.stamina_component:
			player.stamina_component.regen(delta)

	# 5. Speed Selection
	var current_speed: float
	if player.is_crouching:
		current_speed = player.crouch_speed
	elif player.is_sprinting:
		current_speed = player.sprint_speed
	else:
		current_speed = player.walk_speed

	# 6. Direction & Velocity Interpolation
	var direction: Vector3 = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var accel_rate: float = player.acceleration if player.is_on_floor() else player.air_control
	var decel_rate: float = player.deceleration if player.is_on_floor() else (player.air_control * 0.5)

	if direction != Vector3.ZERO:
		player.velocity.x = lerp(player.velocity.x, direction.x * current_speed, accel_rate * delta)
		player.velocity.z = lerp(player.velocity.z, direction.z * current_speed, accel_rate * delta)
	else:
		player.velocity.x = lerp(player.velocity.x, 0.0, decel_rate * delta)
		player.velocity.z = lerp(player.velocity.z, 0.0, decel_rate * delta)

	# 7. Camera Effects (Head bobbing, tilt, FOV kick)
	_handle_camera_effects(delta, input_dir)

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

func _handle_camera_effects(delta: float, input_dir: Vector2) -> void:
	# 1. FOV Kick
	var target_fov: float = player.sprint_fov if player.is_sprinting else player.normal_fov
	player.camera.fov = lerp(player.camera.fov, target_fov, player.fov_change_speed * delta)

	# 2. Camera Tilt on Strafe
	var target_tilt: float = -input_dir.x * player.tilt_angle
	player.camera.rotation.z = lerp(player.camera.rotation.z, target_tilt, player.tilt_speed * delta)

	# 3. Head Bobbing
	var horizontal_velocity: Vector3 = Vector3(player.velocity.x, 0, player.velocity.z)
	var speed_length: float = horizontal_velocity.length()

	if player.is_on_floor() and speed_length > 0.5:
		var current_freq: float = player.head_bob_frequency * (1.4 if player.is_sprinting else 1.0)
		var current_amp: float = player.head_bob_amplitude * (1.3 if player.is_sprinting else 0.7 if player.is_crouching else 1.0)
		player.bob_time += delta * speed_length
		var bob_offset: float = sin(player.bob_time * current_freq) * current_amp
		player.camera.position.y = player.target_cam_y + bob_offset
	else:
		player.bob_time = 0.0
		player.camera.position.y = lerp(player.camera.position.y, player.target_cam_y, player.crouch_transition_speed * delta)
