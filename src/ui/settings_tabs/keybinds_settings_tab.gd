# res://src/ui/settings_tabs/keybinds_settings_tab.gd
class_name KeybindsSettingsTab
extends Control

signal setting_changed

@onready var keybinds_container: VBoxContainer = $KeybindsContainer

var currently_rebinding_action: String = ""
var currently_rebinding_button: Button = null

const ACTION_LABELS: Dictionary = {
	"pause_game": "Pause Menu / Escape",
	"move_forward": "Move Forward",
	"move_back": "Move Back",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"sprint": "Sprint",
	"crouch": "Crouch",
	"flashlight": "Flashlight",
	"interact": "Interact / Pick Up",
	"drop_item": "Drop Item",
	"primary_attack": "Primary Attack",
	"secondary_attack": "Secondary Attack",
	"reload": "Reload",
	"push_to_talk": "Push To Talk"
}

func _unhandled_input(event: InputEvent) -> void:
	if currently_rebinding_action == "" or currently_rebinding_button == null:
		return

	if event is InputEventKey or event is InputEventMouseButton:
		if event.is_pressed():
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				return

			InputMap.action_erase_events(currently_rebinding_action)
			InputMap.action_add_event(currently_rebinding_action, event)
			ConfigManager.keybind_settings[currently_rebinding_action] = event

			_update_keybind_button_text(currently_rebinding_button, event)
			setting_changed.emit()

			currently_rebinding_action = ""
			currently_rebinding_button = null
			if is_inside_tree():
				get_viewport().set_input_as_handled()

func populate() -> void:
	currently_rebinding_action = ""
	currently_rebinding_button = null

	if not keybinds_container:
		return

	for child in keybinds_container.get_children():
		child.queue_free()

	for action in ConfigManager.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = ACTION_LABELS.get(action, action.capitalize())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 28)

		var events := InputMap.action_get_events(action)
		if events.size() > 0:
			_update_keybind_button_text(btn, events[0])
		else:
			btn.text = "[ NONE ]"

		var current_action := action
		btn.pressed.connect(func() -> void:
			currently_rebinding_action = current_action
			currently_rebinding_button = btn
			btn.text = "< Press Key >"
		)

		row.add_child(btn)
		keybinds_container.add_child(row)

func _update_keybind_button_text(btn: Button, event: InputEvent) -> void:
	if event is InputEventKey:
		btn.text = OS.get_keycode_string(event.physical_keycode) if event.physical_keycode != 0 else OS.get_keycode_string(event.keycode)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: btn.text = "Mouse Left"
			MOUSE_BUTTON_RIGHT: btn.text = "Mouse Right"
			MOUSE_BUTTON_MIDDLE: btn.text = "Mouse Middle"
			MOUSE_BUTTON_XBUTTON1: btn.text = "Mouse Button 4"
			MOUSE_BUTTON_XBUTTON2: btn.text = "Mouse Button 5"
			_: btn.text = "Mouse %d" % event.button_index
	else:
		btn.text = event.as_text()
