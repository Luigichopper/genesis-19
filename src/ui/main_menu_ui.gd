extends Control

@onready var start_game_button : Button = $MarginContainer/ButtonContainer/StartGameButton
@onready var settings_button : Button = $MarginContainer/ButtonContainer/SettingsButton
@onready var exit_game_button : Button = $MarginContainer/ButtonContainer/ExitGameButton

@onready var settings_ui : Control = $SettingsUI

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_game_button.pressed.connect(_on_start_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_game_button.pressed.connect(_on_exit_game_pressed)


func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://src/ui/lobby_ui.tscn")


func _on_settings_pressed() -> void:
	settings_ui.show()


func _on_exit_game_pressed() -> void:
	get_tree().quit()
