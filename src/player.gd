extends CharacterBody3D

# --- Movement Constants ---
@export_group("Movement Speeds")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.5
@export var crouch_speed: float = 2.2
@export var jump_velocity: float = 4.5
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var air_control: float = 3.0

@export_group("Look Settings")
@export var mouse_sensitivity: float = 0.003
@export var max_pitch: float = 1.4

@export_group("Stamina System")
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 25.0
@export var stamina_regen: float = 15.0
@export_range(0.1, 1.0, 0.05) var stamina_recovery_percent: float = 0.35 # Requires 35% stamina refill before sprinting again


@export_group("Camera Effects")
@export var normal_fov: float = 75.0
@export var sprint_fov: float = 85.0
@export var fov_change_speed: float = 8.0
@export var tilt_angle: float = 0.03
@export var tilt_speed: float = 6.0
@export var head_bob_frequency: float = 10.0
@export var head_bob_amplitude: float = 0.05

@export_group("Crouch Settings")
@export var standing_height: float = 2.0
@export var crouching_height: float = 1.2
@export var crouch_transition_speed: float = 10.0

# --- Nodes ---
@onready var camera: Camera3D = $Camera3D
@onready var spot_light: SpotLight3D = $Camera3D/SpotLight3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var ceiling_check: RayCast3D = $CeilingCheck
@onready var interact_ray: RayCast3D = $Camera3D/InteractRayCast
@onready var hud: CanvasLayer = $HUD if has_node("HUD") else null
@onready var inventory: InventoryComponent = $InventoryComponent if has_node("InventoryComponent") else null
@onready var weapon_controller: WeaponController = $Camera3D/WeaponController if has_node("Camera3D/WeaponController") else null

# --- Dynamic State ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Movement state
var current_speed: float = 4.5
var is_crouching: bool = false
var is_sprinting: bool = false
var is_exhausted: bool = false
var stamina: float = 100.0

# Head Bob & Camera state
var bob_time: float = 0.0
var camera_start_y: float = 0.8
var target_cam_y: float = 0.8

# Network state variables
@export var flashlight_enabled: bool = true:
	set(val):
		flashlight_enabled = val
		if spot_light:
			spot_light.visible = val

func _enter_tree() -> void:
	# Parse the peer ID directly from the node name ("1", "1169861027", etc.)
	var authority_id := name.to_int()
	if authority_id != 0:
		set_multiplayer_authority(authority_id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)

func _ready() -> void:
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	set_process_unhandled_input(is_local)
	set_physics_process(true)

	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if spot_light:
			spot_light.visible = flashlight_enabled
	else:
		if spot_light:
			spot_light.visible = flashlight_enabled

	camera_start_y = camera.position.y
	target_cam_y = camera_start_y
	stamina = max_stamina

	if weapon_controller and inventory:
		weapon_controller.setup(self, inventory)

	if inventory:
		inventory.inventory_updated.connect(_on_inventory_updated)
		inventory.active_slot_changed.connect(_on_active_slot_changed)
		_create_starter_items()
		_on_inventory_updated()

func _create_starter_items() -> void:
	# Create starter Melee weapon (Pipe Wrench)
	var wrench := WeaponData.new()
	wrench.id = "pipe_wrench"
	wrench.display_name = "Pipe Wrench"
	wrench.weapon_type = WeaponData.WeaponType.MELEE
	wrench.damage = 35.0
	wrench.attack_cooldown = 0.6
	wrench.attack_range = 2.5
	inventory.set_slot_item(0, wrench)

	# Create starter Ranged weapon (Pistol)
	var pistol := WeaponData.new()
	pistol.id = "pistol"
	pistol.display_name = "9mm Pistol"
	pistol.weapon_type = WeaponData.WeaponType.RANGED
	pistol.damage = 22.0
	pistol.attack_cooldown = 0.25
	pistol.max_ammo = 12
	pistol.reload_time = 1.6
	inventory.set_slot_item(1, pistol, 1, 12)

	# Create non-combat item (Keycard)
	var keycard := ItemData.new()
	keycard.id = "keycard_alpha"
	keycard.display_name = "Keycard Alpha"
	inventory.set_slot_item(2, keycard)

func _on_inventory_updated() -> void:
	if hud and inventory and hud.has_method("update_hotbar"):
		hud.update_hotbar(inventory)

func _on_active_slot_changed(_idx: int, _item: ItemData) -> void:
	_on_inventory_updated()

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -max_pitch, max_pitch)

	if Input.is_action_just_pressed("flashlight"):
		_toggle_flashlight.rpc()

	if Input.is_action_just_pressed("interact"):
		_handle_interaction()

	# Hotbar Slot selection
	if inventory:
		if Input.is_action_just_pressed("slot_1"):
			inventory.set_active_slot(0)
		elif Input.is_action_just_pressed("slot_2"):
			inventory.set_active_slot(1)
		elif Input.is_action_just_pressed("slot_3"):
			inventory.set_active_slot(2)
		elif Input.is_action_just_pressed("slot_4"):
			inventory.set_active_slot(3)
		elif Input.is_action_just_pressed("slot_next"):
			inventory.set_active_slot(inventory.active_slot_index + 1)
		elif Input.is_action_just_pressed("slot_prev"):
			inventory.set_active_slot(inventory.active_slot_index - 1)

	# Combat Inputs
	if weapon_controller:
		if Input.is_action_just_pressed("primary_attack"):
			weapon_controller.handle_primary_attack()
		elif Input.is_action_just_pressed("reload"):
			weapon_controller.handle_reload()


@rpc("call_local", "reliable", "any_peer")
func _toggle_flashlight() -> void:
	flashlight_enabled = not flashlight_enabled
	if spot_light:
		spot_light.visible = flashlight_enabled

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	_update_stamina(delta)
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_camera_effects(delta)
	move_and_slide()

func _update_stamina(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_moving := input_dir.length_squared() > 0.1
	var sprint_requested := Input.is_action_pressed("sprint") and is_moving and not is_crouching and is_on_floor()

	var required_recovery_stamina := max_stamina * stamina_recovery_percent

	if is_exhausted:
		is_sprinting = false
		if stamina >= required_recovery_stamina:
			is_exhausted = false
	else:
		is_sprinting = sprint_requested and stamina > 0.0

	if is_sprinting:
		stamina = max(stamina - stamina_drain * delta, 0.0)
		if stamina <= 0.0:
			is_exhausted = true
			is_sprinting = false
	else:
		stamina = min(stamina + stamina_regen * delta, max_stamina)

	if hud and hud.has_method("update_stamina"):
		hud.update_stamina(stamina, max_stamina, is_exhausted)


func _handle_crouch(delta: float) -> void:
	var wants_crouch := Input.is_action_pressed("crouch") and is_on_floor()
	
	if wants_crouch:
		is_crouching = true
	elif is_crouching:
		# Check if space above allows standing
		if ceiling_check and not ceiling_check.is_colliding():
			is_crouching = false

	# Target camera height and collision shape adjustment
	var target_height := crouching_height if is_crouching else standing_height
	target_cam_y = (crouching_height * 0.4) if is_crouching else camera_start_y

	# Smooth camera local Y height
	camera.position.y = lerp(camera.position.y, target_cam_y, crouch_transition_speed * delta)
	
	# Adjust capsule collider shape
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.height = lerp(capsule.height, target_height, crouch_transition_speed * delta)
		collision_shape.position.y = capsule.height * 0.5 - standing_height * 0.5

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching:
		velocity.y = jump_velocity

	# Speed selection
	if is_crouching:
		current_speed = crouch_speed
	elif is_sprinting:
		current_speed = sprint_speed
	else:
		current_speed = walk_speed

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var accel_rate := acceleration if is_on_floor() else air_control
	var decel_rate := deceleration if is_on_floor() else (air_control * 0.5)

	if direction != Vector3.ZERO:
		velocity.x = lerp(velocity.x, direction.x * current_speed, accel_rate * delta)
		velocity.z = lerp(velocity.z, direction.z * current_speed, accel_rate * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, decel_rate * delta)
		velocity.z = lerp(velocity.z, 0.0, decel_rate * delta)

func _handle_camera_effects(delta: float) -> void:
	# 1. FOV Kick
	var target_fov := sprint_fov if is_sprinting else normal_fov
	camera.fov = lerp(camera.fov, target_fov, fov_change_speed * delta)

	# 2. Camera Tilt on Strafe
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var target_tilt := -input_dir.x * tilt_angle
	camera.rotation.z = lerp(camera.rotation.z, target_tilt, tilt_speed * delta)

	# 3. Head Bobbing
	var horizontal_velocity := Vector3(velocity.x, 0, velocity.z)
	var speed_length := horizontal_velocity.length()

	if is_on_floor() and speed_length > 0.5:
		var current_freq := head_bob_frequency * (1.4 if is_sprinting else 1.0)
		var current_amp := head_bob_amplitude * (1.3 if is_sprinting else 0.7 if is_crouching else 1.0)
		bob_time += delta * speed_length
		var bob_offset := sin(bob_time * current_freq) * current_amp
		camera.position.y = target_cam_y + bob_offset
	else:
		bob_time = 0.0
		camera.position.y = lerp(camera.position.y, target_cam_y, crouch_transition_speed * delta)

func _handle_interaction() -> void:
	if interact_ray and interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target and target.has_method("interact"):
			target.interact(self)
