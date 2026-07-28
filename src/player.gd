extends CharacterBody3D
# Attach to the root CharacterBody3D of player.tscn.
# Node also needs a MultiplayerSynchronizer child (see notes below).

# Set by NetworkManager.spawn_player() right after instantiate(), BEFORE
# add_child(). Authority must be set here in _enter_tree() rather than
# externally after instantiation — doing it from outside (even right before
# add_child) races against MultiplayerSpawner's replication setup and
# throws "unable to process the pending spawn since it has no network ID."
var peer_id: int = 1

func _enter_tree() -> void:
	# 1. Set authority on the character body itself
	set_multiplayer_authority(peer_id)
	
	# 2. ALSO explicitly set authority on the synchronizer before it enters the tree completely
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.set_multiplayer_authority(peer_id)

const SPEED := 6.0
const JUMP_VELOCITY := 4.5
const MOUSE_SENSITIVITY := 0.003

@onready var camera: Camera3D = $Camera3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	# Only the owning peer gets an active camera and processes input.
	var is_local := is_multiplayer_authority()
	camera.current = is_local
	set_process_unhandled_input(is_local)
	set_physics_process(true) # everyone simulates physics; only the
							   # authority's input actually drives it

	if is_local:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Don't let remote copies fight the synced transform with their own
		# leftover collision response; MultiplayerSynchronizer overwrites
		# position each tick, physics processing here is effectively idle.
		pass

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return # remote instances just receive position via the synchronizer

	if not is_on_floor():
		velocity.y -= gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
