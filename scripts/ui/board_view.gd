class_name BoardView
extends Control

## One side's 3x3 battle board, built from BoardSquare and FigureToken scenes. The DM board shows
## grid rows 0-2 and the player board rows 3-5; BoardOrientation places them so the two front rows
## face each other (tall: across the Provoke strip; wide: side by side). refresh() copies what to
## draw while the engine is paused. Squares, rows and figures that answer the pending request are
## highlighted and clickable. The board scales to fit its rect, keeping the squares' shape.

signal option_chosen(index: int)

const ASPECT := 1.6  # square width / height

var side: String = FigureState.SIDE_ENEMIES
var orientation: String = BoardOrientation.TALL
var _squares: Dictionary = {}      # Vector2i -> BoardSquare
var _tokens: Array[FigureToken] = []
var _figures: Array[Dictionary] = []
var _figure_at: Dictionary = {}    # Vector2i -> index into _figures
var _cell_options: Dictionary = {} # Vector2i -> option index
var _row_options: Dictionary = {}  # grid y -> option index

func _init(board_side: String = FigureState.SIDE_ENEMIES) -> void:
    side = board_side
    custom_minimum_size = Vector2(300, 190)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    for cell in Field.board_cells(side):
        var square: BoardSquare = UiScenes.board_square()
        square.cell = cell
        square.tooltip_text = BoardOrientation.square_label(cell)
        square.pressed.connect(_on_square_pressed)
        _squares[cell] = square
        add_child(square)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _layout()

func set_orientation(value: String) -> void:
    orientation = value
    _layout()

func refresh(battle: Battle, request: DecisionRequest) -> void:
    _figures.clear()
    _figure_at.clear()
    _cell_options.clear()
    _row_options.clear()
    var figure_options: Dictionary = {}
    if request != null:
        for i in range(request.options.size()):
            var option: Variant = request.options[i]
            if option is FigureState:
                figure_options[option] = i
            elif option is Vector2i:
                _cell_options[option] = i
            elif option is int and request.kind == DecisionRequest.ROW:
                _row_options[option] = i
    if battle != null:
        for f in _figures_on_board(battle):
            _figures.append(_figure_item(battle, request, f, figure_options.get(f, -1)))
            for c in f.cells:
                _figure_at[c] = _figures.size() - 1
    _sync_tokens()
    _update_squares()

## Drop the clickable options (after answering, until the next pause redraws).
func clear_options() -> void:
    _cell_options.clear()
    _row_options.clear()
    for item in _figures:
        item["option"] = -1
    _sync_tokens()
    _update_squares()

## Standing figures whose cells are on this board (a figure behind the lines shows where it stands).
func _figures_on_board(battle: Battle) -> Array[FigureState]:
    var result: Array[FigureState] = []
    var all: Array[FigureState] = []
    for h in battle.heroes:
        all.append(h)
    for e in battle.enemies:
        all.append(e)
    for f in all:
        if f.down or f.cells.is_empty():
            continue
        if Field.board_of(f.cells[0]) == side:
            result.append(f)
    return result

func _figure_item(battle: Battle, request: DecisionRequest, f: FigureState, option: int) -> Dictionary:
    var item: Dictionary = {
        "cells": f.cells.duplicate(), "name": f.name, "color": UiText.figure_color(f),
        "active": f == battle.active_figure, "option": option,
        "armor_slots": f.armor_slots, "armor_damage": f.armor_damage, "guard": f.guard_tokens,
        "extra": _status_text(f),
    }
    if f is HeroState:
        var h: HeroState = f
        item["hero"] = true
        item["acted"] = battle.heroes_acted.has(h) and h != battle.active_figure
        item["wounds"] = h.wound_count()
        item["deciding"] = request != null and request.hero == h
    else:
        var e: EnemyState = f
        item["hero"] = false
        item["hd"] = e.hit_dice
        item["marked_hd"] = e.marked_hd
        item["morale"] = e.morale().capitalize()
    return item

func _status_text(f: FigureState) -> String:
    var parts: PackedStringArray = []
    if f.stunned:
        parts.append("Stunned")
    if not f.bleeds.is_empty():
        parts.append("Bleed x%d" % f.bleeds.size())
    for status_name in f.statuses:
        parts.append(String(status_name).capitalize())
    if f is HeroState and (f as HeroState).toad_turns > 0:
        parts.append("Toad")
    return ", ".join(parts)

func _sync_tokens() -> void:
    while _tokens.size() < _figures.size():
        var token: FigureToken = UiScenes.figure_token()
        _tokens.append(token)
        add_child(token)
    for i in range(_tokens.size()):
        _tokens[i].visible = i < _figures.size()
        if i < _figures.size():
            _tokens[i].show_figure(_figures[i])
    _layout()

func _update_squares() -> void:
    for cell in _squares:
        (_squares[cell] as BoardSquare).set_highlight(_cell_options.has(cell), _row_options.has(cell.y))

func _on_square_pressed(cell: Vector2i) -> void:
    if _cell_options.has(cell):
        option_chosen.emit(_cell_options[cell])
    elif _row_options.has(cell.y):
        option_chosen.emit(_row_options[cell.y])
    elif _figure_at.has(cell) and int(_figures[_figure_at[cell]]["option"]) >= 0:
        option_chosen.emit(int(_figures[_figure_at[cell]]["option"]))

# ------------------------------------------------------------------ layout

func _cell_size() -> Vector2:
    var w: float = minf(size.x / Field.LANES, size.y / 3.0 * ASPECT)
    return Vector2(w, w / ASPECT)

func _cell_rect(cell: Vector2i) -> Rect2:
    var cs: Vector2 = _cell_size()
    var origin := (size - cs * Vector2(Field.LANES, 3)) * 0.5
    var screen: Vector2i = BoardOrientation.screen_cell_of(cell, orientation)
    return Rect2(origin + Vector2(screen) * cs, cs)

func _layout() -> void:
    for cell in _squares:
        var r: Rect2 = _cell_rect(cell)
        (_squares[cell] as BoardSquare).position = r.position
        (_squares[cell] as BoardSquare).size = r.size
    for i in range(mini(_tokens.size(), _figures.size())):
        var cells: Array = _figures[i]["cells"]
        var r: Rect2 = _cell_rect(cells[0])
        for c in cells:
            if Field.board_of(c) == side:
                r = r.merge(_cell_rect(c))
        _tokens[i].position = r.position
        _tokens[i].size = r.size
