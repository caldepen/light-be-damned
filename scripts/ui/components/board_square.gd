class_name BoardSquare
extends Control

## One square of a 3x3 battle board. Highlighted when it (or its row) answers the pending
## request; clicking emits `pressed` with the square's grid cell. Colours come from the Theme
## (type BoardSquare). Reusable scene: scenes/components/board_square.tscn.

signal pressed(cell: Vector2i)

var cell: Vector2i = Vector2i.ZERO
var highlighted: bool = false
var row_highlighted: bool = false

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP

func set_highlight(square: bool, row: bool) -> void:
    if square != highlighted or row != row_highlighted:
        highlighted = square
        row_highlighted = row
        queue_redraw()

func _gui_input(event: InputEvent) -> void:
    var mb := event as InputEventMouseButton
    if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
        pressed.emit(cell)
        accept_event()

func _draw() -> void:
    var r := Rect2(Vector2.ZERO, size).grow(-2)
    var option: Color = get_theme_color("option", "BoardSquare")
    draw_style_box(_box(get_theme_color("empty", "BoardSquare"), get_theme_color("border", "BoardSquare")), r)
    if row_highlighted:
        draw_rect(r.grow(-2), Color(option, 0.25))
    if highlighted:
        draw_rect(r.grow(-3), Color(option, 0.2))
        draw_rect(r.grow(-3), option, false, 3.0)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = fill
    box.border_color = border
    box.set_border_width_all(1)
    box.set_corner_radius_all(int(minf(size.x, size.y) * 0.12))
    return box
