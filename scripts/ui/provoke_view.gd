class_name ProvokeView
extends Control

## The 0-20 Provoke track as a horizontal strip between the two boards. It stretches to the width
## it is given. Tied tokens stack on their space with the top token drawn highest (the one enemies
## treat as highest). Down heroes are drawn faded. Colours: Theme type ProvokeTrack.

const LABEL_HEIGHT := 14.0
const TOKEN_HEIGHT := 15.0

var _track_max: int = 20
var _stacks: Dictionary = {}  # value -> Array of {"label", "color", "down"}, top first

func _init() -> void:
    custom_minimum_size = Vector2(420, TOKEN_HEIGHT * 4 + LABEL_HEIGHT + 8)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func refresh(battle: Battle) -> void:
    _stacks.clear()
    if battle != null:
        _track_max = battle.provoke.track_max
        for hero in battle.provoke.ordered(battle.heroes):
            var value: int = battle.provoke.value_of(hero)
            if not _stacks.has(value):
                _stacks[value] = []
            _stacks[value].append({"label": UiText.short_name(hero), "color": UiText.figure_color(hero), "down": hero.down})
    queue_redraw()

func _draw() -> void:
    var font: Font = get_theme_default_font()
    var slot_w: float = size.x / float(_track_max + 1)
    var bottom: float = size.y - LABEL_HEIGHT - 2
    var token_h: float = minf(TOKEN_HEIGHT, (bottom - 2) / 4.0)
    for v in range(_track_max + 1):
        var x: float = v * slot_w
        draw_rect(Rect2(Vector2(x + 1, 0), Vector2(slot_w - 2, bottom)), get_theme_color("space", "ProvokeTrack"))
        draw_string(font, Vector2(x, size.y - 3), str(v), HORIZONTAL_ALIGNMENT_CENTER, slot_w, 11, get_theme_color("number", "ProvokeTrack"))
        if not _stacks.has(v):
            continue
        var stack: Array = _stacks[v]
        # Bottom of the stack sits at the bottom of the space; the top token is drawn highest.
        for i in range(stack.size()):
            var token: Dictionary = stack[stack.size() - 1 - i]
            var r := Rect2(Vector2(x + 2, bottom - (i + 1) * token_h), Vector2(slot_w - 4, token_h - 1))
            var color: Color = token["color"]
            draw_rect(r, color.darkened(0.6) if token["down"] else color)
            draw_string(font, r.position + Vector2(0, token_h - 3), String(token["label"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color.WHITE)
