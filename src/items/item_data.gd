class_name ItemData
extends Resource

@export var id: String = "item"
@export var display_name: String = "Item"
@export var icon: Texture2D
@export var is_stackable: bool = false
@export var max_stack: int = 1
@export var held_mesh: Mesh
@export var world_mesh: Mesh
@export var description: String = ""
