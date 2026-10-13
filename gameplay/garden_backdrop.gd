extends Control
## Hedge pattern behind everything, filling whatever part of the window lies
## outside the design canvas when the window's shape differs from it.

const LEAF_SPACING: float = 48.0

@export var base_color: Color = Color(0.09, 0.22, 0.1)
@export var leaf_color: Color = Color(0.13, 0.3, 0.13)
@export var flower_color: Color = Color(0.98, 0.93, 0.75)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), base_color)
	var row := 0
	var y := 0.0
	while y < size.y + LEAF_SPACING:
		var column := 0
		var x := LEAF_SPACING * 0.5 if row % 2 == 1 else 0.0
		while x < size.x + LEAF_SPACING:
			draw_circle(Vector2(x, y), LEAF_SPACING * 0.42, leaf_color, true, -1.0, true)
			if (row * 7 + column * 3) % 5 == 0:
				draw_circle(Vector2(x, y), 3.0, flower_color, true, -1.0, true)
			x += LEAF_SPACING
			column += 1
		y += LEAF_SPACING * 0.75
		row += 1
