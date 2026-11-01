class_name MapFeatureLayer
extends Node2D

## The features layer's drawing: every placed tile's cosmetic decorations (bones, cobwebs, a well)
## as placeholder dots with a short name until the art pass. MapView fills `items` from the placed
## tiles: [{"cell": Vector2i, "id": String}] in map squares.

var items: Array[Dictionary] = []
var palette: Dictionary = {}

func show_features(list: Array[Dictionary], colors: Dictionary) -> void:
    items = list
    palette = colors
    queue_redraw()

func _draw() -> void:
    var ink: Color = palette.get("ink", Color.BLACK)
    var font: Font = ThemeDB.fallback_font
    var per_cell: Dictionary = {}
    for item in items:
        var cell: Vector2i = item["cell"]
        var n: int = int(per_cell.get(cell, 0))
        per_cell[cell] = n + 1
        var r: Rect2 = TileView.square_rect(cell)
        var at: Vector2 = r.position + Vector2(8 + 18 * (n % 3), r.size.y - 10 - 12 * int(n / 3))
        draw_circle(at, 2.5, ink.lerp(Color.TRANSPARENT, 0.4))
        draw_string(font, at + Vector2(4, 3), String(item["id"]).replace("_", " ").substr(0, 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink.lerp(Color.TRANSPARENT, 0.45))
