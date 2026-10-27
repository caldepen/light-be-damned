class_name ProvokeView
extends Control

## The 0-20 Provoke track. Tied tokens stack on their space with the top token drawn highest
## (the one enemies treat as highest). Down heroes are drawn faded.

const SLOT := Vector2(34, 18)
const LABEL_HEIGHT := 16.0

var _track_max: int = 20
var _stacks: Dictionary = {}  # value -> Array of {"label", "color", "down"}, top first

func _init() -> void:
    custom_minimum_size = Vector2(SLOT.x * 21, SLOT.y * 4 + LABEL_HEIGHT + 6)

func refresh(battle: Battle) -> void:
    _stacks.clear()
    if battle == null:
        queue_redraw()
        return
    _track_max = battle.provoke.track_max
    custom_minimum_size = Vector2(SLOT.x * (_track_max + 1), SLOT.y * 4 + LABEL_HEIGHT + 6)
    for hero in battle.provoke.ordered(battle.heroes):
        var value: int = battle.provoke.value_of(hero)
        if not _stacks.has(value):
            _stacks[value] = []
        _stacks[value].append({"label": UiText.short_name(hero), "color": UiText.figure_color(hero), "down": hero.down})
    queue_redraw()

func _draw() -> void:
    var font: Font = ThemeDB.fallback_font
    var bottom: float = SLOT.y * 4 + 4
    for v in range(_track_max + 1):
        var x: float = v * SLOT.x
        draw_rect(Rect2(Vector2(x + 1, 0), Vector2(SLOT.x - 2, bottom)), Color(0.16, 0.16, 0.18))
        draw_string(font, Vector2(x + 2, bottom + LABEL_HEIGHT - 2), str(v), HORIZONTAL_ALIGNMENT_CENTER, SLOT.x - 4, 12, Color(0.75, 0.75, 0.75))
        if not _stacks.has(v):
            continue
        var stack: Array = _stacks[v]
        # Bottom of the stack sits at the bottom of the space; the top token is drawn highest.
        for i in range(stack.size()):
            var token: Dictionary = stack[stack.size() - 1 - i]
            var r := Rect2(Vector2(x + 3, bottom - (i + 1) * SLOT.y), Vector2(SLOT.x - 6, SLOT.y - 2))
            var color: Color = token["color"]
            if token["down"]:
                color = color.darkened(0.6)
            draw_rect(r, color)
            draw_string(font, r.position + Vector2(0, 13), String(token["label"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color.WHITE)
