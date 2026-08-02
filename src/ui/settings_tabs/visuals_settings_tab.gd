# res://src/ui/settings_tabs/visuals_settings_tab.gd
class_name VisualsSettingsTab
extends Control

signal setting_changed

@onready var window_mode_option_button: OptionButton = $WindowModeOptionButton
@onready var ca_button: CheckButton = $ChromaticAberrationButton
@onready var pixel_filter_button: CheckButton = $PixelFilterButton
@onready var scanlines_button: CheckButton = $ScanlinesButton
@onready var brightness_slider: HSlider = $BrightnessSlider

func populate() -> void:
	window_mode_option_button.clear()
	window_mode_option_button.add_item("Windowed", ConfigManager.WindowMode.WINDOWED)
	window_mode_option_button.add_item("Fullscreen", ConfigManager.WindowMode.FULLSCREEN)
	window_mode_option_button.add_item("Exclusive Fullscreen", ConfigManager.WindowMode.EXCLUSIVE_FULLSCREEN)

	var current_mode: int = ConfigManager.visual_settings.get("window_mode", ConfigManager.WindowMode.WINDOWED)
	window_mode_option_button.select(current_mode)

	for c in window_mode_option_button.item_selected.get_connections():
		window_mode_option_button.item_selected.disconnect(c.callable)
	window_mode_option_button.item_selected.connect(func(idx: int) -> void:
		ConfigManager.visual_settings["window_mode"] = idx
		ConfigManager.apply_visual_settings()
		setting_changed.emit()
	)

	ca_button.button_pressed = ConfigManager.visual_settings.get("chromatic_aberration", true)
	for c in ca_button.toggled.get_connections():
		ca_button.toggled.disconnect(c.callable)
	ca_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["chromatic_aberration"] = toggled
		ConfigManager.apply_visual_settings()
		setting_changed.emit()
	)

	pixel_filter_button.button_pressed = ConfigManager.visual_settings.get("pixel_filter", false)
	for c in pixel_filter_button.toggled.get_connections():
		pixel_filter_button.toggled.disconnect(c.callable)
	pixel_filter_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["pixel_filter"] = toggled
		ConfigManager.apply_visual_settings()
		setting_changed.emit()
	)

	scanlines_button.button_pressed = ConfigManager.visual_settings.get("scanlines", true)
	for c in scanlines_button.toggled.get_connections():
		scanlines_button.toggled.disconnect(c.callable)
	scanlines_button.toggled.connect(func(toggled: bool) -> void:
		ConfigManager.visual_settings["scanlines"] = toggled
		ConfigManager.apply_visual_settings()
		setting_changed.emit()
	)

	brightness_slider.value = ConfigManager.visual_settings.get("brightness", 1.0)
	for c in brightness_slider.value_changed.get_connections():
		brightness_slider.value_changed.disconnect(c.callable)
	brightness_slider.value_changed.connect(func(val: float) -> void:
		ConfigManager.visual_settings["brightness"] = val
		ConfigManager.apply_visual_settings()
		setting_changed.emit()
	)
