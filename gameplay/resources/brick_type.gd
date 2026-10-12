class_name BrickType
extends Resource
## Shared definition for one kind of brick.

@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export_range(1, 10) var hit_points: int = 1
@export var points: int = 50
## Indestructible bricks bounce the ball but never break and are not
## required to clear the level.
@export var destructible: bool = true
