class_name GameLayout
extends RefCounted
## Presentation layout maths, independent of any node.
##
## The design canvas is the project's base viewport size
## (display/window/size/viewport_width and viewport_height in project.godot).
## With canvas_items stretch and expand aspect the visible logical area is at
## least the design canvas and grows along one axis to match the window's
## shape. The design canvas is centered in it; the extra space shows the garden
## backdrop. Gameplay never moves: only the canvas transforms are offset.

const MIN_WINDOW_SIZE: Vector2i = Vector2i(960, 540)
## Width of the information sidebar on the right of the design canvas; the
## gameplay arena (Playfield) takes the rest.
const SIDEBAR_WIDTH: float = 320.0


static func get_design_size() -> Vector2:
	return Vector2(
			ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))


## Visible logical size for a window of [param window_size] pixels, as computed
## by the engine for canvas_items stretch with expand aspect (whole units).
static func get_visible_size(window_size: Vector2, design_size: Vector2 = get_design_size()) -> Vector2:
	var scale := minf(window_size.x / design_size.x, window_size.y / design_size.y)
	return (window_size / scale).floor()


## Offset that centers the design canvas in [param visible_size]. Whole logical
## units keep the canvas edges on the same pixel grid as the HUD.
static func get_offset(visible_size: Vector2, design_size: Vector2 = get_design_size()) -> Vector2:
	return ((visible_size - design_size) * 0.5).floor().max(Vector2.ZERO)
