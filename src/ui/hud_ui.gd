extends CanvasLayer

@onready var stamina_label: Label = $UIContainer/VBoxContainer/StaminaLabel
@onready var health_label: Label = $UIContainer/VBoxContainer/HealthLabel
@onready var post_processing_overlay: ColorRect = $PostProcessingOverlay
@onready var hotbar_ui: Control = $UIContainer/HotbarUI


const BAR_BLOCKS: int = 10

func _ready() -> void:
	# Hide overlay for non-local peers if instanced
	var parent = get_parent()
	if parent and parent.has_method("is_multiplayer_authority"):
		if not parent.is_multiplayer_authority():
			hide()

	if ConfigManager.has_signal("visual_settings_changed"):
		ConfigManager.visual_settings_changed.connect(_update_shader_parameters)
	_update_shader_parameters()

func update_hotbar(inventory: InventoryComponent) -> void:
	if hotbar_ui and hotbar_ui.has_method("update_hotbar"):
		hotbar_ui.update_hotbar(inventory)


func _update_shader_parameters() -> void:
	if not is_instance_valid(post_processing_overlay) or not post_processing_overlay.material:
		return
	var mat := post_processing_overlay.material as ShaderMaterial
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
	
	var ratio := clampf(current_stamina / max(max_stamina, 1.0), 0.0, 1.0)
	var filled_blocks := int(round(ratio * BAR_BLOCKS))
	var empty_blocks := BAR_BLOCKS - filled_blocks
	
	var bar_str := "[" + "/".repeat(filled_blocks) + ".".repeat(empty_blocks) + "]"
	
	if is_exhausted:
		stamina_label.text = "EXHAUSTED " + bar_str
	else:
		stamina_label.text = "STAMINA " + bar_str

func update_health(current_health: float, max_health: float) -> void:
	if not health_label:
		return

	var ratio := clampf(current_health / max(max_health, 1.0), 0.0, 1.0)
	var filled_blocks := int(round(ratio * BAR_BLOCKS))
	var empty_blocks := BAR_BLOCKS - filled_blocks

	health_label.text = "HEALTH [" + "/".repeat(filled_blocks) + ". ".repeat(empty_blocks) + "]"
