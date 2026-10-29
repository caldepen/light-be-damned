class_name ArmorMeter
extends Control

## The party's armor slots in one row: damaged slots in the damage colour.

var slots: int = 0
var damaged: int = 0
var warning: bool = false:
    set(v):
        warning = v
        queue_redraw()

func _init() -> void:
    custom_minimum_size = Vector2(120, 22)

func show_armor(total: int, hurt: int) -> void:
    slots = total
    damaged = hurt
    queue_redraw()

func _draw() -> void:
    if slots <= 0:
        return
    var w: float = minf(size.x / float(slots), 16.0)
    for i in range(slots):
        var r := Rect2(Vector2(i * w + 1, 3), Vector2(w - 2, size.y - 6))
        draw_rect(r, get_theme_color("damaged", "ArmorMeter") if i < damaged else get_theme_color("ok", "ArmorMeter"))
    if warning:
        draw_rect(Rect2(Vector2.ZERO, Vector2(w * slots, size.y)), get_theme_color("warning", "ArmorMeter"), false, 2.0)
