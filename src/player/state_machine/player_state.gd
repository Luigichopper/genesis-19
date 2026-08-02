class_name PlayerState
extends Node

var player: CharacterBody3D
var state_machine: StateMachine

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func unhandled_input(_event: InputEvent) -> void:
	pass
