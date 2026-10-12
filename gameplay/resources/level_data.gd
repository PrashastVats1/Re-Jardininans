class_name LevelData
extends Resource
## A brick layout. Each character in [member rows] is one grid cell, and
## [member legend] maps characters to [BrickType] resources.
## "." and " " are empty cells.

@export var display_name: String = ""
## Keep the PackedStringArray() initializer: a bare [] makes the editor treat the
## property as a generic Array and drop the rows when it re-saves the resource.
@export var rows: PackedStringArray = PackedStringArray()
## Single-character String keys mapped to BrickType resources.
@export var legend: Dictionary = {}


static func is_empty_cell(symbol: String) -> bool:
	return symbol == "." or symbol == " "


func get_column_count() -> int:
	var columns := 0
	for row: String in rows:
		columns = maxi(columns, row.length())
	return columns


## Returns null for empty cells and unknown symbols.
func get_brick_type(symbol: String) -> BrickType:
	return legend.get(symbol) as BrickType


func count_destructible() -> int:
	var count := 0
	for row: String in rows:
		for column: int in row.length():
			var brick_type := get_brick_type(row[column])
			if brick_type != null and brick_type.destructible:
				count += 1
	return count


## Returns human-readable problems; an empty array means the level is usable.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if rows.is_empty():
		problems.append("level has no rows")
	for key: Variant in legend:
		if not (key is String and (key as String).length() == 1):
			problems.append("legend key %s must be a single character" % [key])
		elif not (legend[key] is BrickType):
			problems.append("legend entry '%s' is not a BrickType" % [key])
	for row_index: int in rows.size():
		var row := rows[row_index]
		for column: int in row.length():
			var symbol := row[column]
			if not is_empty_cell(symbol) and get_brick_type(symbol) == null:
				problems.append("row %d, column %d: unknown brick symbol '%s'" % [row_index, column, symbol])
	if count_destructible() == 0:
		problems.append("level has no destructible bricks")
	return problems
