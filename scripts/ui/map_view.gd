class_name MapView
extends Control

## The map area: a SubViewport with its own Camera2D, so the open, unbounded map can be zoomed and
## panned inside the panel. It draws in separate layers, bottom to top (EXPLORATION_SPEC §9a):
##   paper   - paper and graph-paper grid (MapPaperLayer)
##   tiles   - placed room tiles (TileView scenes)
##   features - hand-drawn decorations on the tiles (MapFeatureLayer)
##   annotations - player notes; presentation only, never in scripts/core (reserved, empty)
##   overlay - wall tokens, the party marker, the pending choice's doorways and previews (MapOverlayLayer)
## Placed tiles go through ink_in(), the hook Milestone 7 turns into a draw-on animation.
##
## show_run() redraws from a paused run (4.6). The camera follows on its own: it zooms to fit the
## whole map while keeping the party's room in view, and toward the options while the party places
## a tile. Dragging pans and the wheel zooms, which stops the following until "Centre on party".
## Clicking a highlighted doorway, preview or campsite emits option_chosen. During a battle the map
## is dimmed.

signal option_chosen(index: int)

## World units per map square. Map y is north-up; world y = -map y (see TileView.square_rect).
const SQUARE := 64.0
const INK_IN_SECONDS := 0.35
const DIMMED := Color(0.68, 0.7, 0.74)
const ZOOM_MIN := 0.15
const ZOOM_MAX := 2.5
const WHEEL_STEP := 1.15
const DRAG_START := 4.0

var paper := MapPaperLayer.new()
var tiles := Node2D.new()
var features := Node2D.new()
var annotations := Node2D.new()
var overlay := Node2D.new()
var camera := Camera2D.new()
var feature_marks := MapFeatureLayer.new()
var marks := MapOverlayLayer.new()
## True while the camera frames the map by itself; a drag or the wheel turns it off.
var follow: bool = true

var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _hint := Label.new()
var _centre := Button.new()
var _tile_views: Dictionary = {}   # placed tile uid -> TileView
var _tile_keys: Dictionary = {}    # placed tile uid -> what it was drawn from
var _map_rect := Rect2()
var _party_rect := Rect2()
var _focus_rect := Rect2()
var _press_at := Vector2.ZERO
var _pressed: bool = false
var _dragging: bool = false

func _init() -> void:
    clip_contents = true
    custom_minimum_size = Vector2(240, 240)
    _container.stretch = true
    _container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_container)
    _viewport.handle_input_locally = true
    _viewport.msaa_2d = Viewport.MSAA_4X
    _container.add_child(_viewport)
    var world := Node2D.new()
    world.name = "MapWorld"
    for pair in [[paper, "Paper"], [tiles, "Tiles"], [features, "Features"], [annotations, "Annotations"], [overlay, "Overlay"]]:
        (pair[0] as Node2D).name = String(pair[1])
        world.add_child(pair[0])
    features.add_child(feature_marks)
    overlay.add_child(marks)
    world.add_child(camera)
    _viewport.add_child(world)
    _hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
    _hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
    _hint.add_theme_color_override("font_color", Color(0.25, 0.25, 0.3))
    _hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_hint)
    _centre.text = "Centre on party"
    _centre.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _centre.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _centre.position -= Vector2(6, -6)
    _centre.visible = false
    _centre.pressed.connect(centre_on_party)
    add_child(_centre)
    mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
    camera.enabled = true
    camera.make_current()
    _apply_palette()
    fit_to(Rect2(Vector2(-2, -3) * SQUARE, Vector2(5, 5) * SQUARE))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        if follow and _map_rect.size != Vector2.ZERO:
            _frame()
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
    for child in tiles.get_children():
        child.queue_free()
    for child in annotations.get_children():
        child.queue_free()
    _tile_views.clear()
    _tile_keys.clear()
    feature_marks.show_features([] as Array[Dictionary], palette())
    marks.show_overlay([] as Array[Dictionary], [] as Array[Dictionary], Rect2(), palette())
    _map_rect = Rect2()
    _party_rect = Rect2()
    _focus_rect = Rect2()
    follow = true
    _centre.visible = false

# ------------------------------------------------------------------ the run's map

## Redraw from the run's map (read while the run is paused): new tiles ink in, moved or turned
## tiles redraw, removed ones go; features, wall tokens and the party marker; and `request`'s
## options when it is a doorway, placement or campsite choice. Then the camera frames it all.
func show_run(map: HutMap, party_tile: PlacedTile, request: RunRequest) -> void:
    var colors: Dictionary = palette()
    var seen: Dictionary = {}
    var all_features: Array[Dictionary] = []
    _map_rect = Rect2()
    for t in map.tiles:
        seen[t.uid] = true
        var key: String = "%s|%s|%s|%s" % [str(t.cells), str(t.all_doors()), t.explored, t.moon]
        if not _tile_views.has(t.uid):
            var view: TileView = UiScenes.tile_view()
            view.setup(t.cells.duplicate(), t.all_doors(), String(t.def.get("name", t.tile_id)), t.moon, colors, not t.explored)
            _tile_views[t.uid] = view
            add_tile(view)
        elif _tile_keys.get(t.uid, "") != key:
            (_tile_views[t.uid] as TileView).setup(t.cells.duplicate(), t.all_doors(), String(t.def.get("name", t.tile_id)), t.moon, colors, not t.explored)
        _tile_keys[t.uid] = key
        all_features.append_array(t.features)
        _map_rect = _cells_rect(t.cells) if _map_rect.size == Vector2.ZERO else _map_rect.merge(_cells_rect(t.cells))
    for uid in _tile_views.keys():
        if not seen.has(uid):
            (_tile_views[uid] as TileView).queue_free()
            _tile_views.erase(uid)
            _tile_keys.erase(uid)
    feature_marks.show_features(all_features, colors)
    _party_rect = _cells_rect(party_tile.cells) if party_tile != null else Rect2()
    var option_shapes: Array[Dictionary] = options_for(request)
    _focus_rect = Rect2()
    if request != null and request.kind == RunRequest.PLACEMENT:
        for o in option_shapes:
            var r: Rect2 = _cells_rect(o["cells"])
            _focus_rect = r if _focus_rect.size == Vector2.ZERO else _focus_rect.merge(r)
        _focus_rect = _focus_rect.merge(_party_rect)
    marks.show_overlay(option_shapes, map.wall_tokens(), _party_rect, colors)
    if follow:
        _frame()

## The clickable shapes for a run request's options (doorways, placements, campsites); empty for
## any other request, which the prompt's buttons answer.
static func options_for(request: RunRequest) -> Array[Dictionary]:
    var shapes: Array[Dictionary] = []
    if request == null:
        return shapes
    var walks: Array = request.details.get("walk", [])
    for i in range(request.options.size()):
        var option: Variant = request.options[i]
        var walk: int = int(walks[i]) if i < walks.size() else 0
        var label: String = "" if walk == 0 else str(walk)
        if option is MapDoorway:
            var d: MapDoorway = option
            shapes.append({"index": i, "kind": "point", "point": MapOverlayLayer.doorway_point(d.cell, d.side), "cells": [] as Array[Vector2i], "label": label})
        elif option is TilePlacement:
            var p: TilePlacement = option
            var doors: Array[Dictionary] = p.doors.duplicate()
            if not p.hut_door.is_empty():
                doors.append({"cell": TileGeometry.facing_cell(p.hut_door["cell"], p.hut_door["side"]), "side": TileGeometry.opposite(p.hut_door["side"])})
            shapes.append({"index": i, "kind": "cells", "cells": p.cells, "doors": doors, "label": str(i + 1)})
        elif option is PlacedTile:
            shapes.append({"index": i, "kind": "cells", "cells": (option as PlacedTile).cells, "label": label})
    return shapes

## The option index under a point in this control's own coordinates, or -1.
func option_at_screen(local: Vector2) -> int:
    return marks.option_at(screen_to_world(local))

# ------------------------------------------------------------------ camera

## Centre the camera on a world rect and zoom so all of it shows.
func fit_to(world_rect: Rect2) -> void:
    var view_size: Vector2 = _viewport_size()
    var zoom: float = minf(view_size.x / maxf(world_rect.size.x, 1.0), view_size.y / maxf(world_rect.size.y, 1.0))
    camera.position = world_rect.get_center()
    camera.zoom = Vector2.ONE * clampf(zoom, ZOOM_MIN, ZOOM_MAX)
    _update_paper()

## Back to following: frame the whole map with the party in view.
func centre_on_party() -> void:
    follow = true
    _centre.visible = false
    _frame()

## Zoom by `factor` keeping the world point under `local` (control coordinates) where it is.
func zoom_at(local: Vector2, factor: float) -> void:
    var before: Vector2 = screen_to_world(local)
    camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
    camera.position += before - screen_to_world(local)
    _stop_following()
    _update_paper()

func pan_by(screen_delta: Vector2) -> void:
    camera.position -= screen_delta / camera.zoom
    _stop_following()
    _update_paper()

func screen_to_world(local: Vector2) -> Vector2:
    return camera.position + (local - _viewport_size() * 0.5) / camera.zoom

## The part of the world the camera shows.
func visible_world_rect() -> Rect2:
    var view_size: Vector2 = _viewport_size() / camera.zoom
    return Rect2(camera.position - view_size * 0.5, view_size)

func _frame() -> void:
    if _focus_rect.size != Vector2.ZERO:
        fit_to(_focus_rect.grow(SQUARE))
    elif _map_rect.size != Vector2.ZERO:
        fit_to(_map_rect.grow(SQUARE * 0.5))
    if _party_rect.size != Vector2.ZERO and not visible_world_rect().encloses(_party_rect):
        camera.position = _party_rect.get_center()
        _update_paper()

func _stop_following() -> void:
    follow = false
    _centre.visible = true

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom_at(mb.position, WHEEL_STEP)
        elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom_at(mb.position, 1.0 / WHEEL_STEP)
        elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
            if mb.pressed:
                _pressed = true
                _dragging = false
                _press_at = mb.position
            else:
                if _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT:
                    var index: int = option_at_screen(mb.position)
                    if index >= 0:
                        option_chosen.emit(index)
                _pressed = false
                _dragging = false
        accept_event()
    elif event is InputEventMouseMotion:
        var mm: InputEventMouseMotion = event
        if _pressed:
            if not _dragging and mm.position.distance_to(_press_at) >= DRAG_START:
                _dragging = true
            if _dragging:
                pan_by(mm.relative)
        else:
            var hot: int = option_at_screen(mm.position)
            if hot != marks.hovered:
                marks.hovered = hot
                marks.queue_redraw()
            mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hot >= 0 else Control.CURSOR_ARROW

static func _cells_rect(cells: Array) -> Rect2:
    var r := Rect2()
    for i in range(cells.size()):
        var sq: Rect2 = TileView.square_rect(cells[i])
        r = sq if i == 0 else r.merge(sq)
    return r

func _viewport_size() -> Vector2:
    return Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))

func _update_paper() -> void:
    paper.visible_rect = visible_world_rect()
    paper.queue_redraw()

func _apply_palette() -> void:
    paper.palette = palette()
    _update_paper()
