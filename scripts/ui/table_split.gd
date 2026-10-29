class_name TableSplit
extends SplitContainer

## A draggable divider between two table areas. Both children expand, so with offset 0 the divider
## sits in the middle and the first child's length is (length - separation) / 2 + offset, clamped
## by the children's minimum sizes. The split keeps `fraction` (the first child's share of the
## length) so sizes survive window resizes and can be saved. `squeeze` pushes one child down to its
## minimum (a collapsed panel's strip) and locks the divider; changes can animate.

signal fraction_changed(key: String, fraction: float)

const ANIMATE_SECONDS := 0.25
const SQUEEZE_NONE := 0
const SQUEEZE_FIRST := -1
const SQUEEZE_SECOND := 1

var key: String = ""
var fraction: float = 0.5
var squeeze: int = SQUEEZE_NONE
var _tween: Tween = null

func _init(split_key: String = "", is_vertical: bool = false) -> void:
    key = split_key
    vertical = is_vertical
    drag_ended.connect(_on_drag_ended)

## Put `first` and `second` in the split, both expanding along it.
func set_children(first: Control, second: Control) -> void:
    for child in [first, second]:
        var c := child as Control
        if c.get_parent() != null:
            c.get_parent().remove_child(c)
        if vertical:
            c.size_flags_vertical = Control.SIZE_EXPAND_FILL
        else:
            c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        add_child(c)

func length() -> float:
    return size.y if vertical else size.x

## The split_offset that gives the first child `first_length` (before clamping).
func offset_for(first_length: float) -> int:
    return roundi(first_length - (length() - float(get_theme_constant("separation"))) * 0.5)

## The first child's length the current fraction and squeeze ask for.
func target_length() -> float:
    match squeeze:
        SQUEEZE_FIRST:
            return 0.0
        SQUEEZE_SECOND:
            return length()
    return fraction * length()

func apply(animated: bool = false) -> void:
    dragging_enabled = squeeze == SQUEEZE_NONE
    if _tween != null and _tween.is_valid():
        _tween.kill()
    var target: int = offset_for(target_length())
    if not animated or not is_inside_tree() or get_child_count() < 2 or length() <= 0.0:
        split_offset = target
        return
    var first := get_child(0) as Control
    var from: int = offset_for(first.size.y if vertical else first.size.x)
    _tween = create_tween()
    _tween.tween_method(func(v: float) -> void: split_offset = roundi(v), float(from), float(target), ANIMATE_SECONDS) \
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_animating() -> bool:
    return _tween != null and _tween.is_valid() and _tween.is_running()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and not is_animating():
        apply(false)

func _on_drag_ended() -> void:
    if length() <= 0.0 or get_child_count() < 2:
        return
    var first := get_child(0) as Control
    fraction = clampf((first.size.y if vertical else first.size.x) / length(), 0.0, 1.0)
    fraction_changed.emit(key, fraction)
