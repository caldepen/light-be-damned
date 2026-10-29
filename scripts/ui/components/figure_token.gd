class_name FigureToken
extends Control

## A hero or enemy standing on a board: name, armor boxes, Hit Dice or Wounds, Guard and statuses.
## It ignores the mouse, so clicks reach the BoardSquare underneath. `show_figure` takes the copy
## the BoardView made while the engine was paused. Reusable scene: scenes/components/figure_token.tscn.

const FONT_SIZE := 13

var _item: Dictionary = {}

func _init() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    clip_contents = true

func show_figure(item: Dictionary) -> void:
    _item = item
    queue_redraw()

func _draw() -> void:
    if _item.is_empty():
        return
    var font: Font = get_theme_default_font()
    var text_color: Color = get_theme_color("text", "FigureToken")
    var r := Rect2(Vector2.ZERO, size).grow(-5)
    var acted: bool = _item.get("acted", false)
    var color: Color = _item["color"]
    draw_rect(r, color.darkened(0.55) if acted else color)
    if acted:
        draw_string(font, r.position + Vector2(r.size.x - 40, 14), "acted", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, text_color.darkened(0.2))
    if _item.get("active", false):
        draw_rect(r.grow(3), get_theme_color("active", "FigureToken"), false, 3.0)
    if int(_item.get("option", -1)) >= 0:
        draw_rect(r.grow(1), get_theme_color("option", "FigureToken"), false, 4.0)
    var x: float = r.position.x + 5
    var y: float = r.position.y + 15
    var width: float = r.size.x - 8
    draw_string(font, Vector2(x, y), String(_item["name"]), HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE + 1, text_color)
    y += 6
    var armor: Color = get_theme_color("armor", "FigureToken")
    if _item["hero"]:
        y = _boxes(font, Vector2(x, y), "Armor", int(_item["armor_slots"]), int(_item["armor_damage"]), armor)
        var wounds: int = int(_item["wounds"])
        draw_string(font, Vector2(x, y + 12), "Wounds %d" % wounds, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE,
            get_theme_color("wound_text", "FigureToken") if wounds > 0 else text_color)
        if int(_item["guard"]) > 0:
            y += 15
            draw_string(font, Vector2(x, y + 12), "Guard %d" % int(_item["guard"]), HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, text_color)
    else:
        y = _boxes(font, Vector2(x, y), "Hd", int(_item["hd"]), int(_item["marked_hd"]), get_theme_color("hit_die", "FigureToken"))
        y = _boxes(font, Vector2(x, y), "Armor", int(_item["armor_slots"]), int(_item["armor_damage"]), armor)
        var guard: String = "   Guard %d" % int(_item["guard"]) if int(_item["guard"]) > 0 else ""
        draw_string(font, Vector2(x, y + 12), String(_item["morale"]) + guard, HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE, text_color)
    y += 16
    if not String(_item.get("extra", "")).is_empty():
        draw_string(font, Vector2(x, y + 12), String(_item["extra"]), HORIZONTAL_ALIGNMENT_LEFT, width, FONT_SIZE - 2,
            get_theme_color("status_text", "FigureToken"))

## A row of boxes, the first `marked` of them filled with the damage colour. Returns the next y.
func _boxes(font: Font, pos: Vector2, label: String, count: int, marked: int, color: Color) -> float:
    draw_string(font, pos + Vector2(0, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, get_theme_color("text", "FigureToken"))
    var damage: Color = get_theme_color("damage", "FigureToken")
    for i in range(count):
        var box := Rect2(Vector2(pos.x + 40 + i * 11, pos.y + 2), Vector2(9, 9))
        draw_rect(box, damage if i < marked else color)
    return pos.y + 15
