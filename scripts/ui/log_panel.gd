class_name LogPanel
extends VBoxContainer

## The event log as a collapsible panel at the bottom of the right column. Collapsed, only the
## header button shows and the deck area above gets the room.

signal toggled(open: bool)

var log_view := LogView.new()
var _header := Button.new()

func _init() -> void:
    _header.alignment = HORIZONTAL_ALIGNMENT_LEFT
    _header.pressed.connect(func() -> void: set_open(not log_view.visible))
    add_child(_header)
    log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    log_view.custom_minimum_size = Vector2(0, 120)
    add_child(log_view)
    set_open(true)

func is_open() -> bool:
    return log_view.visible

func set_open(open: bool) -> void:
    log_view.visible = open
    _header.text = ("v  " if open else ">  ") + "Event log"
    size_flags_vertical = Control.SIZE_EXPAND_FILL if open else Control.SIZE_SHRINK_END
    toggled.emit(open)
