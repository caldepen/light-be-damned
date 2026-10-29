class_name HutTrackView
extends Control

## The Hut track: one box per value, filled up to the current value. `marks` maps a value to a
## short tag drawn under it (W for a Whim, the special tiles, "wake" at 10).

var value: int = -1
var track_max: int = 10
var marks: Dictionary = {}

func _init() -> void:
    custom_minimum_size = Vector2(180, 30)

func show_track(v: int, m: int, track_marks: Dictionary) -> void:
    value = v
    track_max = m
    marks = track_marks
    queue_redraw()

func _draw() -> void:
    var font: Font = get_theme_default_font()
    var w: float = size.x / float(track_max + 1)
    for i in range(track_max + 1):
        var r := Rect2(Vector2(i * w + 1, 0), Vector2(w - 2, size.y - 12))
        var filled: bool = value >= 0 and i <= value and i > 0
        draw_rect(r, get_theme_color("filled", "HutTrack") if filled else get_theme_color("space", "HutTrack"))
        if i == value:
            draw_rect(r, get_theme_color("marker", "HutTrack"), false, 2.0)
        draw_string(font, r.position + Vector2(0, r.size.y - 3), str(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color.WHITE)
        if marks.has(i):
            draw_string(font, Vector2(i * w, size.y - 1), String(marks[i]), HORIZONTAL_ALIGNMENT_CENTER, w, 9, Color(0.85, 0.85, 0.9))
