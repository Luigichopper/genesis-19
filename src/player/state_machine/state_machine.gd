class_name StateMachine
extends Node

@export var initial_state: PlayerState

var current_state: PlayerState
var states: Dictionary = {}

func init(player: CharacterBody3D) -> void:
	for child in get_children():
		if child is PlayerState:
			var state: PlayerState = child as PlayerState
			states[state.name.to_lower()] = state
			state.player = player
			state.state_machine = self

	if initial_state:
		current_state = initial_state
		current_state.enter()
	elif get_child_count() > 0 and get_child(0) is PlayerState:
		current_state = get_child(0) as PlayerState
		current_state.enter()

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.unhandled_input(event)

func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	var key: String = target_state_name.to_lower()
	if not states.has(key):
		push_warning("StateMachine: state '%s' does not exist." % target_state_name)
		return

	if current_state:
		current_state.exit()

	current_state = states[key]
	current_state.enter(msg)
