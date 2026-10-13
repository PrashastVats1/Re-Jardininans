extends Node2D
## Plain black behind the play area, from the ceiling down, so the ball, paddle,
## bricks and everything else in the arena stand out however many there are.
## The strip above the ceiling is left to the backdrop, so the arena's top edge
## stays visible. Drawn only inside Playfield.get_size().

@export var playfield: Playfield
@export var color: Color = Color.BLACK


func get_top() -> float:
	return playfield.ceiling_y if playfield != null else 0.0


func _draw() -> void:
	var size := Playfield.get_size()
	var top := get_top()
	draw_rect(Rect2(0.0, top, size.x, size.y - top), color)
