class_name TileView
extends Node2D

## One room tile on the map's tiles layer: a placeholder labelled rectangle per square, an ink
## outline with gaps for doorways, and a moon mark. Map squares are MapView.SQUARE world units;
## map y is north-up, so world y = -map y. Milestone 7 swaps this scene for the inked art.
## Reusable scene: scenes/components/tile_view.tscn.

var cells: Array[Vector2i] = []
var doors: Array[Dictionary] = []   # {"cell": Vector2i, "side": String} in map coordinates
var label: String = ""
var moon: bool = false
var palette: Dictionary = {}        # MapPaper theme colours, passed in by MapView

func setup(tile_cells: Array[Vector2i], tile_doors: Array[Dictionary], tile_label: String, has_moon: bool, colors: Dictionary) -> void:
    cells = tile_cells
    doors = tile_doors
    label = tile_label
    moon = has_moon
    palette = colors
    queue_redraw()

static func square_rect(cell: Vector2i) -> Rect2:
    var s: float = MapView.SQUARE
    return Rect2(Vector2(cell.x * s, -(cell.y + 1) * s), Vector2(s, s))

func _draw() -> void:
    var ink: Color = palette.get("ink", Color.BLACK)
    var fill: Color = palette.get("room_fill", Color(1, 1, 1, 0.8))
    var bounds := Rect2()
    for i in range(cells.size()):
        var r: Rect2 = square_rect(cells[i])
        draw_rect(r, fill)
        bounds = r if i == 0 else bounds.merge(r)
    for c in cells:
        for side in TileGeometry.SIDES:
            if cells.has(TileGeometry.facing_cell(c, side)):
                continue
            _edge(c, side, ink, _has_door(c, side))
    var font: Font = ThemeDB.fallback_font
    draw_string(font, bounds.position + Vector2(4, bounds.size.y * 0.5 + 5), label, HORIZONTAL_ALIGNMENT_CENTER,
        bounds.size.x - 8, 12, ink)
    if moon:
        draw_circle(bounds.position + Vector2(bounds.size.x - 12, 12), 6.0, palette.get("moon", ink))

func _has_door(cell: Vector2i, side: String) -> bool:
    for d in doors:
        if d["cell"] == cell and d["side"] == side:
            return true
    return false

## An outer wall of `cell`; a doorway leaves a gap in the middle third.
func _edge(cell: Vector2i, side: String, ink: Color, door: bool) -> void:
    var r: Rect2 = square_rect(cell)
    var a: Vector2
    var b: Vector2
    match side:
        "N":
            a = r.position
            b = Vector2(r.end.x, r.position.y)
        "S":
            a = Vector2(r.position.x, r.end.y)
            b = r.end
        "E":
            a = Vector2(r.end.x, r.position.y)
            b = r.end
        _:
            a = r.position
            b = Vector2(r.position.x, r.end.y)
    if not door:
        draw_line(a, b, ink, 3.0)
        return
    draw_line(a, a.lerp(b, 1.0 / 3.0), ink, 3.0)
    draw_line(a.lerp(b, 2.0 / 3.0), b, ink, 3.0)
