class_name MapView
extends Control

## The map area: a SubViewport with its own Camera2D, so the open, unbounded map can be zoomed and
## panned inside the panel. It draws in separate layers, bottom to top (EXPLORATION_SPEC §9a):
##   paper   - paper and graph-paper grid (MapPaperLayer)
##   tiles   - placed room tiles (TileView scenes)
##   features - hand-drawn decorations on the tiles
##   annotations - player notes; presentation only, never in scripts/core (reserved, empty)
##   overlay - doorway highlights, party marker, placement previews
## Placed tiles go through ink_in(), the hook Milestone 7 turns into a draw-on animation.
## Exploration (4.6) adds zoom to fit, drag pan, wheel zoom, centre on party and doorway zoom on top
## of fit_to() and the camera. During a battle the map is dimmed.

## World units per map square. Map y is north-up; world y = -map y (see TileView.square_rect).
const SQUARE := 64.0
const INK_IN_SECONDS := 0.35
const DIMMED := Color(0.68, 0.7, 0.74)
const ZOOM_MIN := 0.15
const ZOOM_MAX := 2.5

var paper := MapPaperLayer.new()
var tiles := Node2D.new()
var features := Node2D.new()
var annotations := Node2D.new()
var overlay := Node2D.new()
var camera := Camera2D.new()

var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _hint := Label.new()

func _init() -> void:
    clip_contents = true
    custom_minimum_size = Vector2(240, 240)
    _container.stretch = true
    _container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(_container)
    _viewport.handle_input_locally = true
    _viewport.msaa_2d = Viewport.MSAA_4X
    _container.add_child(_viewport)
    var world := Node2D.new()
    world.name = "MapWorld"
    for pair in [[paper, "Paper"], [tiles, "Tiles"], [features, "Features"], [annotations, "Annotations"], [overlay, "Overlay"]]:
        (pair[0] as Node2D).name = String(pair[1])
        world.add_child(pair[0])
    world.add_child(camera)
    _viewport.add_child(world)
    _hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hint.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
    add_child(_hint)

func _ready() -> void:
    camera.enabled = true
    camera.make_current()
    _apply_palette()
    fit_to(Rect2(Vector2(-2, -3) * SQUARE, Vector2(5, 5) * SQUARE))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _update_paper()
    elif what == NOTIFICATION_THEME_CHANGED and is_inside_tree():
        _apply_palette()

## The map's colours from the Theme (type MapPaper), for layers that are not Controls.
func palette() -> Dictionary:
    var p: Dictionary = {}
    for color_name in ["paper", "grid_minor", "grid_major", "ink", "room_fill", "doorway", "highlight", "moon"]:
        p[color_name] = get_theme_color(color_name, "MapPaper")
    return p

## Dim the map while the battle boards have the focus; full brightness while exploring.
func set_dimmed(dimmed: bool) -> void:
    _container.modulate = DIMMED if dimmed else Color.WHITE

func set_hint(text: String) -> void:
    _hint.text = text
    _hint.visible = not text.is_empty()

## The "ink in" hook: every placed tile (and its features) appears through here. A short fade for
## now; Milestone 7 replaces it with a draw-on animation.
func ink_in(item: CanvasItem) -> void:
    item.modulate.a = 0.0
    var tween: Tween = create_tween()
    tween.tween_property(item, "modulate:a", 1.0, INK_IN_SECONDS)

## Put a tile on the tiles layer and ink it in.
func add_tile(view: TileView) -> void:
    tiles.add_child(view)
    ink_in(view)

## Clear every map layer except the paper (a new run builds a new Hut).
func clear_map() -> void:
    for layer in [tiles, features, annotations, overlay]:
        for child in (layer as Node2D).get_children():
            child.queue_free()

## Centre the camera on a world rect and zoom so all of it shows.
func fit_to(world_rect: Rect2) -> void:
    var view_size: Vector2 = _viewport_size()
    var zoom: float = minf(view_size.x / maxf(world_rect.size.x, 1.0), view_size.y / maxf(world_rect.size.y, 1.0))
    camera.position = world_rect.get_center()
    camera.zoom = Vector2.ONE * clampf(zoom, ZOOM_MIN, ZOOM_MAX)
    _update_paper()

## The part of the world the camera shows.
func visible_world_rect() -> Rect2:
    var view_size: Vector2 = _viewport_size() / camera.zoom
    return Rect2(camera.position - view_size * 0.5, view_size)

func _viewport_size() -> Vector2:
    return Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))

func _update_paper() -> void:
    paper.visible_rect = visible_world_rect()
    paper.queue_redraw()

func _apply_palette() -> void:
    paper.palette = palette()
    _update_paper()
