# res://src/ui/settings_tabs/audio_settings_tab.gd
class_name AudioSettingsTab
extends Control

signal setting_changed

@onready var master_slider: HSlider = $MasterSlider
@onready var vc_slider: HSlider = $VCSlider
@onready var sfx_slider: HSlider = $SFXSlider
@onready var bgm_slider: HSlider = $BGMSlider
@onready var ui_slider: HSlider = $UISlider

func populate() -> void:
	var sliders: Dictionary = {
		"Master": master_slider,
		"VC": vc_slider,
		"SFX": sfx_slider,
		"BGM": bgm_slider,
		"UI": ui_slider
	}

	for bus: String in sliders:
		var slider: HSlider = sliders[bus]
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = ConfigManager.audio_settings[bus]

		for c in slider.value_changed.get_connections():
			slider.value_changed.disconnect(c.callable)

		slider.value_changed.connect(func(val: float) -> void:
			ConfigManager.set_bus_volume(bus, val)
			setting_changed.emit()
		)
