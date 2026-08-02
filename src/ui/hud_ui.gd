extends CanvasLayer

@onready var stamina_label: Label = $UIContainer/VBoxContainer/StaminaLabel
@onready var health_label: Label = $UIContainer/VBoxContainer/HealthLabel
@onready var post_processing_overlay: ColorRect = $PostProcessingOverlay
@onready var hotbar_ui: Control = $UIContainer/HotbarUI

const BAR_BLOCKS: int = 10

var bound_player: Node = null

func _ready() -> void:
	if ConfigManager.has_signal("visual_settings_changed"):
		ConfigManager.visual_settings_changed.connect(_update_shader_parameters)
	_update_shader_parameters()

	EventBus.local_player_spawned.connect(_on_local_player_spawned)
	EventBus.local_player_despawned.connect(_on_local_player_despawned)

func _on_local_player_spawned(player: Node) -> void:
	_unbind_player()
	bound_player = player

	# Bind display handlers to local player component signals
	if player.has_node("Components/StaminaComponent"):
		var stam: StaminaComponent = player.get_node("Components/StaminaComponent")
		stam.stamina_changed.connect(_on_stamina_changed)
		update_stamina(stam.current_stamina, stam.max_stamina, stam.is_exhausted)

	if player.has_node("Components/HealthComponent"):
		var hp: HealthComponent = player.get_node("Components/HealthComponent")
		hp.health_changed.connect(_on_health_changed)
		update_health(hp.current_health, hp.max_health)

	if player.has_node("Components/InventoryComponent"):
		var inv: InventoryComponent = player.get_node("Components/InventoryComponent")
		inv.inventory_updated.connect(func() -> void: update_hotbar(inv))
		inv.active_slot_changed.connect(func(_idx: int, _item: ItemData) -> void: update_hotbar(inv))
		update_hotbar(inv)

func _on_local_player_despawned(player: Node) -> void:
	if bound_player == player:
		_unbind_player()

func _unbind_player() -> void:
	if not bound_player:
		return

	if bound_player.has_node("Components/StaminaComponent"):
		var stam: StaminaComponent = bound_player.get_node("Components/StaminaComponent")
		if stam.stamina_changed.is_connected(_on_stamina_changed):
			stam.stamina_changed.disconnect(_on_stamina_changed)

	if bound_player.has_node("Components/HealthComponent"):
		var hp: HealthComponent = bound_player.get_node("Components/HealthComponent")
		if hp.health_changed.is_connected(_on_health_changed):
			hp.health_changed.disconnect(_on_health_changed)

	bound_player = null

func _on_stamina_changed(current: float, max_stamina: float, is_exhausted: bool) -> void:
	update_stamina(current, max_stamina, is_exhausted)

func _on_health_changed(current: float, max_health: float) -> void:
	update_health(current, max_health)

func update_hotbar(inventory: InventoryComponent) -> void:
	if hotbar_ui and hotbar_ui.has_method("update_hotbar"):
		hotbar_ui.update_hotbar(inventory)

func _update_shader_parameters() -> void:
	if not is_instance_valid(post_processing_overlay) or not post_processing_overlay.material:
		return
	var mat: ShaderMaterial = post_processing_overlay.material as ShaderMaterial
	if not mat:
		return
	var ca_enabled: bool = ConfigManager.visual_settings.get("chromatic_aberration", true)
	var scanlines_enabled: bool = ConfigManager.visual_settings.get("scanlines", true)
	var brightness: float = ConfigManager.visual_settings.get("brightness", 1.0)
	
	mat.set_shader_parameter("chromatic_aberration", 1.8 if ca_enabled else 0.0)
	mat.set_shader_parameter("scanline_opacity", 0.15 if scanlines_enabled else 0.0)
	mat.set_shader_parameter("brightness", brightness)

func update_stamina(current_stamina: float, max_stamina: float, is_exhausted: bool = false) -> void:
	if not stamina_label:
		return
	
	var ratio: float = clampf(current_stamina / max(max_stamina, 1.0), 0.0, 1.0)
	var filled_blocks: int = int(round(ratio * BAR_BLOCKS))
	var empty_blocks: int = BAR_BLOCKS - filled_blocks
	
	var bar_str: String = "[" + "/".repeat(filled_blocks) + ".".repeat(empty_blocks) + "]"
	
	if is_exhausted:
		stamina_label.text = "EXHAUSTED " + bar_str
	else:
		stamina_label.text = "STAMINA " + bar_str

func update_health(current_health: float, max_health: float) -> void:
	if not health_label:
		return

	var ratio: float = clampf(current_health / max(max_health, 1.0), 0.0, 1.0)
	var filled_blocks: int = int(round(ratio * BAR_BLOCKS))
	var empty_blocks: int = BAR_BLOCKS - filled_blocks

	health_label.text = "HEALTH [" + "/".repeat(filled_blocks) + ".".repeat(empty_blocks) + "]"
