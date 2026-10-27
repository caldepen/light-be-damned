class_name BoardView
extends Control

## Both 3x3 boards as one 6x3 grid (enemy board on top). refresh() copies what to draw from the
## battle while the engine is paused; _draw only uses that copy. Legal targets and squares of the
## pending request are outlined and clickable.

signal option_chosen(index: int)

const CELL := Vector2(132, 84)
const GAP := 16.0
const FONT_SIZE := 13

var _figures: Array[Dictionary] = []       # what to draw for each standing figure
var _figure_at: Dictionary = {}            # Vector2i -> index into _figures
var _cell_options: Dictionary = {}         # Vector2i -> option index
var _row_options: Dictionary = {}          # grid y -> option index

func _init() -> void:
    custom_minimum_size = Vector2(CELL.x * Field.LANES, CELL.y * Field.HEIGHT + GAP)
    mouse_filter = Control.MOUSE_FILTER_STOP

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
    if battle == null:
        queue_redraw()
        return
    var all: Array[FigureState] = []
    for h in battle.heroes:
        all.append(h)
    for e in battle.enemies:
        all.append(e)
    for f in all:
        if f.down or f.cells.is_empty():
            continue
        var item: Dictionary = {
            "rect": _cells_rect(f.cells), "name": f.name, "color": UiText.figure_color(f),
            "active": f == battle.active_figure, "option": figure_options.get(f, -1),
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
            item["deciding"] = false
        for c in f.cells:
            _figure_at[c] = _figures.size()
        _figures.append(item)
    queue_redraw()

## Drop the clickable options (after answering, until the next pause redraws).
func clear_options() -> void:
    _cell_options.clear()
    _row_options.clear()
    for item in _figures:
        item["option"] = -1
    queue_redraw()

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

func _cell_rect(cell: Vector2i) -> Rect2:
    var y: float = cell.y * CELL.y + (GAP if cell.y >= Field.HERO_FRONT_Y else 0.0)
    return Rect2(Vector2(cell.x * CELL.x, y), CELL)

func _cells_rect(cells: Array[Vector2i]) -> Rect2:
    var r: Rect2 = _cell_rect(cells[0])
    for c in cells:
        r = r.merge(_cell_rect(c))
    return r

func _cell_at(pos: Vector2) -> Vector2i:
    for cell in Field.all_cells():
        if _cell_rect(cell).has_point(pos):
            return cell
    return Vector2i(-1, -1)

func _gui_input(event: InputEvent) -> void:
    var mb := event as InputEventMouseButton
    if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    var cell: Vector2i = _cell_at(mb.position)
    if cell.x < 0:
        return
    if _cell_options.has(cell):
        option_chosen.emit(_cell_options[cell])
    elif _row_options.has(cell.y):
        option_chosen.emit(_row_options[cell.y])
    elif _figure_at.has(cell) and int(_figures[_figure_at[cell]]["option"]) >= 0:
        option_chosen.emit(int(_figures[_figure_at[cell]]["option"]))

func _draw() -> void:
    var font: Font = ThemeDB.fallback_font
    for cell in Field.all_cells():
        var r: Rect2 = _cell_rect(cell)
        var base: Color = Color(0.2, 0.17, 0.17) if cell.y < Field.HERO_FRONT_Y else Color(0.15, 0.18, 0.22)
        draw_rect(r.grow(-1), base)
        if _row_options.has(cell.y):
            draw_rect(r.grow(-3), Color(1, 0.85, 0.2, 0.25))
    draw_string(font, Vector2(4, Field.HERO_FRONT_Y * CELL.y + GAP - 3), "enemy front  ^   |   v  hero front",
        HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.7, 0.7, 0.7))
    for item in _figures:
        _draw_figure(font, item)
    for cell in _cell_options:
        var r: Rect2 = _cell_rect(cell).grow(-4)
        draw_rect(r, Color(1, 0.85, 0.2, 0.18))
        draw_rect(r, Color(1, 0.85, 0.2), false, 3.0)

func _draw_figure(font: Font, item: Dictionary) -> void:
    var r: Rect2 = (item["rect"] as Rect2).grow(-6)
    var acted: bool = item.get("acted", false)
    draw_rect(r, (item["color"] as Color).darkened(0.55) if acted else item["color"])
    if acted:
        draw_string(font, r.position + Vector2(r.size.x - 42, 15), "acted", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, Color(0.8, 0.8, 0.8))
    if item["active"]:
        draw_rect(r.grow(3), Color.WHITE, false, 3.0)
    if int(item["option"]) >= 0:
        draw_rect(r.grow(1), Color(1, 0.85, 0.2), false, 4.0)
    var x: float = r.position.x + 5
    var y: float = r.position.y + 15
    var text_color := Color.WHITE
    draw_string(font, Vector2(x, y), String(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, FONT_SIZE + 1, text_color)
    y += 6
    if item["hero"]:
        y = _draw_boxes(Vector2(x, y), "Armor", int(item["armor_slots"]), int(item["armor_damage"]), Color(0.75, 0.75, 0.8), font)
        draw_string(font, Vector2(x, y + 12), "Guard %d" % int(item["guard"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, FONT_SIZE, text_color)
        var wounds: int = int(item["wounds"])
        draw_string(font, Vector2(x + 56, y + 12), "Wounds %d" % wounds, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
            Color(1, 0.6, 0.6) if wounds > 0 else text_color)
        y += 16
    else:
        y = _draw_boxes(Vector2(x, y), "Hd", int(item["hd"]), int(item["marked_hd"]), Color(0.9, 0.85, 0.7), font)
        y = _draw_boxes(Vector2(x, y), "Armor", int(item["armor_slots"]), int(item["armor_damage"]), Color(0.75, 0.75, 0.8), font)
        var guard: String = "   Guard %d" % int(item["guard"]) if int(item["guard"]) > 0 else ""
        draw_string(font, Vector2(x, y + 12), String(item["morale"]) + guard, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, FONT_SIZE, text_color)
        y += 16
    if not String(item["extra"]).is_empty():
        draw_string(font, Vector2(x, y + 12), String(item["extra"]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, FONT_SIZE - 2, Color(1, 0.9, 0.6))

## A row of boxes, the first `marked` of them crossed out (damage). Returns the next y.
func _draw_boxes(pos: Vector2, label: String, count: int, marked: int, color: Color, font: Font) -> float:
    draw_string(font, pos + Vector2(0, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE - 2, Color.WHITE)
    var bx: float = pos.x + 40
    for i in range(count):
        var box := Rect2(Vector2(bx + i * 11, pos.y + 2), Vector2(9, 9))
        if i < marked:
            draw_rect(box, Color(0.8, 0.15, 0.15))
        else:
            draw_rect(box, color)
    return pos.y + 15
