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


## Returns human-readable problems; an empty array means the type is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if hit_points < 1:
		problems.append("hit points must be at least 1 (got %d)" % hit_points)
	if points < 0:
		problems.append("points must not be negative (got %d)" % points)
	return problems
