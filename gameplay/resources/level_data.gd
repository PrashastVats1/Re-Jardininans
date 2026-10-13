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


## Returns null for empty cells, unknown symbols and entries that are not a BrickType.
func get_brick_type(symbol: String) -> BrickType:
	if is_empty_cell(symbol):
		return null
	var brick_type: Variant = legend.get(symbol)
	return brick_type if brick_type is BrickType else null


func count_destructible() -> int:
	var count := 0
	for row: String in rows:
		for column: int in row.length():
			var brick_type := get_brick_type(row[column])
			if brick_type != null and brick_type.destructible:
				count += 1
	return count


## Returns human-readable problems with the level's data; an empty array means
## it is well formed. Whether it fits the arena is LevelValidator's job.
func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if rows.is_empty():
		problems.append("level has no rows")
	elif get_column_count() == 0:
		problems.append("rows have no cells")
	for row_index: int in range(1, rows.size()):
		if rows[row_index].length() != rows[0].length():
			problems.append("row %d is %d cells wide but row 0 is %d; every row must be the same width (pad with '.')"
					% [row_index, rows[row_index].length(), rows[0].length()])

	var used: Dictionary = {}
	for row_index: int in rows.size():
		var row := rows[row_index]
		for column: int in row.length():
			var symbol := row[column]
			if is_empty_cell(symbol):
				continue
			used[symbol] = true
			if not legend.has(symbol):
				problems.append("row %d, column %d: brick symbol '%s' is not in the legend (add it, or use '.' for an empty cell)"
						% [row_index, column, symbol])

	for key: Variant in legend:
		if not (key is String and (key as String).length() == 1):
			problems.append("legend key %s must be a single character" % [var_to_str(key)])
		elif is_empty_cell(key):
			problems.append("legend key '%s' is reserved for empty cells" % [key])
		elif not (legend[key] is BrickType):
			problems.append("legend entry '%s' is not a BrickType" % [key])
		else:
			var brick_type := legend[key] as BrickType
			for problem: String in brick_type.validate():
				problems.append("legend entry '%s' (%s): %s" % [key, brick_type.display_name, problem])
			if not used.has(key):
				problems.append("legend entry '%s' (%s) is not used in any row" % [key, brick_type.display_name])

	if count_destructible() == 0:
		problems.append("level has no destructible bricks")
	return problems
