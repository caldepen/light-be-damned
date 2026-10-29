class_name MapPaperLayer
extends Node2D

## The bottom map layer: paper and graph-paper grid, drawn over whatever part of the endless map the
## camera shows (the map has no fixed board). Minor lines every quarter square, major lines on the
## squares. MapView sets `visible_rect` and `palette` and redraws it when the camera moves.

const MINOR_PER_SQUARE := 4

var visible_rect := Rect2(-400, -400, 800, 800)
var palette: Dictionary = {}

func _draw() -> void:
    var r: Rect2 = visible_rect.grow(MapView.SQUARE)
    draw_rect(r, palette.get("paper", Color(0.95, 0.93, 0.86)))
    var step: float = MapView.SQUARE / MINOR_PER_SQUARE
    var minor: Color = palette.get("grid_minor", Color(0.6, 0.7, 0.8, 0.4))
    var major: Color = palette.get("grid_major", Color(0.45, 0.6, 0.75, 0.6))
    var x0: int = floori(r.position.x / step)
    var x1: int = ceili(r.end.x / step)
    for i in range(x0, x1 + 1):
        var is_major: bool = posmod(i, MINOR_PER_SQUARE) == 0
        draw_line(Vector2(i * step, r.position.y), Vector2(i * step, r.end.y), major if is_major else minor, 1.5 if is_major else 1.0)
    var y0: int = floori(r.position.y / step)
    var y1: int = ceili(r.end.y / step)
    for i in range(y0, y1 + 1):
        var is_major: bool = posmod(i, MINOR_PER_SQUARE) == 0
        draw_line(Vector2(r.position.x, i * step), Vector2(r.end.x, i * step), major if is_major else minor, 1.5 if is_major else 1.0)
