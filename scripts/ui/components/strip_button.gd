class_name StripButton
extends Button

## The thin strip a collapsed panel leaves behind; clicking it expands the panel again. In a column
## strip the title reads bottom to top so the strip can stay narrow.

const THICKNESS := 30.0

var title: String = ""
var column: bool = false

func _init() -> void:
    focus_mode = Control.FOCUS_NONE
    clip_contents = true

func setup(strip_title: String, as_column: bool) -> void:
    title = strip_title
    column = as_column
    text = "" if column else "+  " + title
    alignment = HORIZONTAL_ALIGNMENT_LEFT
    custom_minimum_size = Vector2(THICKNESS, 0) if column else Vector2(0, THICKNESS)
    size_flags_vertical = Control.SIZE_EXPAND_FILL if column else Control.SIZE_FILL
    size_flags_horizontal = Control.SIZE_FILL if column else Control.SIZE_EXPAND_FILL
    queue_redraw()

func _draw() -> void:
    if not column:
        return
    var font: Font = get_theme_font("font")
    var font_size: int = get_theme_font_size("font_size")
    var color: Color = get_theme_color("font_color")
    draw_set_transform(Vector2(size.x * 0.5 + font_size * 0.35, size.y - 10), -PI / 2.0)
    draw_string(font, Vector2.ZERO, "+  " + title, HORIZONTAL_ALIGNMENT_LEFT, size.y - 20, font_size, color)
    draw_set_transform(Vector2.ZERO)
