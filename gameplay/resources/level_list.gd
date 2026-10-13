class_name LevelList
extends Resource
## An ordered list of levels. Order is the play order; nothing else about
## progression lives here.

@export var levels: Array[LevelData]


func size() -> int:
	return levels.size()


## Returns null when [param index] is out of range.
func get_level(index: int) -> LevelData:
	return levels[index] if index >= 0 and index < levels.size() else null
