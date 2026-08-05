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
@onready var weapon_controller: WeaponController = $Camera3D/WeaponController if has_node("Camera3D/WeaponController") else null

# Components
@onready var health_component: HealthComponent = $Components/HealthComponent if has_node("Components/HealthComponent") else null
@onready var stamina_component: StaminaComponent = $Components/StaminaComponent if has_node("Components/StaminaComponent") else null
@onready var inventory: InventoryComponent = $Components/InventoryComponent if has_node("Components/InventoryComponent") else null

# State Machine
@onready var state_machine: StateMachine = $StateMachine if has_node("StateMachine") else null

# --- Dynamic State ---
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var is_crouching: bool = false
var is_sprinting: bool = false

# Head Bob & Camera state
var bob_time: float = 0.0
var camera_start_y: float = 0.8
var target_cam_y: float = 0.8

# Preload Item Scene
const ITEM_PICKUP_SCENE: PackedScene = preload("res://src/items/item_pickup_3d.tscn")

# Network state variables
@export var flashlight_enabled: bool = true:
	set(val):
		flashlight_enabled = val
		if spot_light:
			spot_light.visible = val

func _enter_tree() -> void:
	# Parse the peer ID directly from the node name ("1", "1169861027", etc.)
	var authority_id: int = name.to_int()
	if authority_id != 0:
		set_multiplayer_authority(authority_id)
		if has_node("MultiplayerSynchronizer"):
			$MultiplayerSynchronizer.set_multiplayer_authority(authority_id)

func is_local_authority() -> bool:
	if multiplayer.has_multiplayer_peer():
		return is_multiplayer_authority()
	var auth: int = get_multiplayer_authority()
	return auth == 1 or auth == 0 or name == "1"

func _exit_tree() -> void:
	if is_local_authority():
		EventBus.local_player_despawned.emit(self)

func _ready() -> void:
	var is_local: bool = is_local_authority()
	camera.current = is_local
	set_process_unhandled_input(is_local)
	set_physics_process(true)

	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if spot_light:
			spot_light.visible = flashlight_enabled
		EventBus.local_player_spawned.emit(self)
	else:
		if spot_light:
			spot_light.visible = flashlight_enabled


	camera_start_y = camera.position.y
	target_cam_y = camera_start_y

	if weapon_controller and inventory:
		weapon_controller.setup(self, inventory)

	if inventory and is_local:
		_create_starter_items()

	if state_machine:
		state_machine.init(self)

func _create_starter_items() -> void:
	# Create starter Melee weapon (Pipe Wrench)
	var wrench: WeaponData = WeaponData.new()
	wrench.id = "pipe_wrench"
	wrench.display_name = "Pipe Wrench"
	wrench.weapon_type = WeaponData.WeaponType.MELEE
	wrench.damage = 35.0
	wrench.attack_cooldown = 0.6
	wrench.attack_range = 2.5
	inventory.set_slot_item(0, wrench)

	# Create starter Ranged weapon (Pistol)
	var pistol: WeaponData = WeaponData.new()
	pistol.id = "pistol"
	pistol.display_name = "9mm Pistol"
	pistol.weapon_type = WeaponData.WeaponType.RANGED
	pistol.damage = 22.0
	pistol.attack_cooldown = 0.25
	pistol.max_ammo = 12
	pistol.reload_time = 1.6
	inventory.set_slot_item(1, pistol, 1, 12)

	# Create non-combat item (Keycard)
	var keycard: ItemData = ItemData.new()
	keycard.id = "keycard_alpha"
	keycard.display_name = "Keycard Alpha"
	inventory.set_slot_item(2, keycard)

func take_damage(amount: float, attacker: Node = null) -> void:
	if health_component:
		health_component.take_damage(amount, attacker)

func is_interacting() -> bool:
	return state_machine != null and state_machine.current_state is InteractingState

func start_interaction(interactable: InteractableObject = null, ui_scene: PackedScene = null) -> void:
	if state_machine:
		state_machine.transition_to("interacting", {"interactable": interactable, "ui_scene": ui_scene})

func stop_interaction() -> void:
	if state_machine and is_interacting():
		state_machine.transition_to("idle")

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_authority() or get_tree().paused:
		return

	if is_interacting():
		if state_machine:
			state_machine.unhandled_input(event)
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mouse_event: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_y(-mouse_event.relative.x * mouse_sensitivity)
		camera.rotate_x(-mouse_event.relative.y * mouse_sensitivity)
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

	if Input.is_action_just_pressed("drop_item"):
		_handle_drop_item()

	# Combat Inputs
	if weapon_controller:
		if Input.is_action_just_pressed("primary_attack"):
			weapon_controller.handle_primary_attack()
		elif Input.is_action_just_pressed("reload"):
			weapon_controller.handle_reload()

	if state_machine:
		state_machine.unhandled_input(event)

func _handle_drop_item() -> void:
	if not inventory:
		return

	var slot: InventoryComponent.InventorySlot = inventory.get_active_slot()
	if not slot or not slot.item:
		return

	var item_to_drop: ItemData = slot.item
	var count_to_drop: int = slot.count
	var ammo_to_drop: int = slot.current_ammo

	# Clear from inventory
	inventory.remove_active_item(count_to_drop)

	# Position & impulse calculation
	var drop_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 1.5)
	var impulse: Vector3 = -camera.global_transform.basis.z * 3.0 + Vector3.UP * 1.5

	# Request universal spawn from Main across all peers
	var main_node: Node = get_tree().current_scene
	if main_node and main_node.has_method("request_spawn_item"):
		main_node.request_spawn_item.rpc_id(1, item_to_drop.id, count_to_drop, ammo_to_drop, drop_pos, impulse)
	else:
		# Fallback local spawn if testing player scene standalone
		if ITEM_PICKUP_SCENE:
			var pickup: RigidBody3D = ITEM_PICKUP_SCENE.instantiate() as RigidBody3D
			get_parent().add_child(pickup)
			pickup.global_position = drop_pos
			if pickup.has_method("setup"):
				pickup.setup(item_to_drop, count_to_drop, ammo_to_drop)
			pickup.apply_central_impulse(impulse)


@rpc("call_local", "reliable", "any_peer")
func _toggle_flashlight() -> void:
	flashlight_enabled = not flashlight_enabled
	if spot_light:
		spot_light.visible = flashlight_enabled

func _physics_process(delta: float) -> void:
	if not is_local_authority():
		return


	if state_machine:
		state_machine.physics_update(delta)

func _handle_interaction() -> void:
	if interact_ray and interact_ray.is_colliding():
		var target: Object = interact_ray.get_collider()
		if target and target.has_method("interact"):
			target.interact(self)
