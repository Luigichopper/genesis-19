class_name TerminalUI
extends InteractableUI

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/TitleLabel
@onready var logs_text_edit: TextEdit = $PanelContainer/MarginContainer/VBoxContainer/LogsTextEdit
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HeaderHBox/CloseButton

func open(interactable: InteractableObject, player: Node) -> void:
	super.open(interactable, player)

	if interactable:
		var data: Dictionary = interactable.get_custom_data()
		if title_label:
			title_label.text = data.get("title", interactable.object_name).to_upper()
		if logs_text_edit:
			logs_text_edit.text = data.get("logs", "NO DATA LOGGED.")

	if close_button:
		close_button.pressed.connect(close)
