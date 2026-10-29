class_name CollapsiblePanel
extends PanelContainer

## A table area (map, battle boards, decks column, hand) that collapses to a thin strip and expands
## again. Open: a header (title and a collapse button) over the content. Collapsed: only the strip,
## a column strip (title reading upwards) or a row strip, with optional extra content such as the
## party summary. A collapsed panel can "peek": open for a while without changing its saved state,
## on hover (`hover_peek`) or when the table asks (a hero must choose a card). The table moves the
## split containers around it when `open_changed` fires. Reusable scene:
## scenes/components/collapsible_panel.tscn.

signal open_changed(open: bool)
signal collapse_toggled(collapsed: bool)

const STRIP_COLUMN := "column"
const STRIP_ROW := "row"
## A hover peek closes this long after the mouse leaves the panel.
const PEEK_GRACE_SECONDS := 0.4

var key: String = ""
var strip_kind: String = STRIP_ROW
var collapsed: bool = false
var peeking: bool = false
var hover_peek: bool = false
var content := VBoxContainer.new()

var _body := VBoxContainer.new()
var _header := HBoxContainer.new()
var _title := Label.new()
var _toggle := Button.new()
var _strip := BoxContainer.new()
var _strip_button := StripButton.new()
var _strip_extra: Control = null
var _hover_peeking: bool = false
var _outside_seconds: float = 0.0

func _init() -> void:
    _body.add_theme_constant_override("separation", 4)
    _title.theme_type_variation = &"PanelTitle"
    _title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title.clip_text = true
    _header.add_child(_title)
    _toggle.focus_mode = Control.FOCUS_NONE
    _toggle.custom_minimum_size = Vector2(28, 24)
    _toggle.tooltip_text = "Collapse"
    _toggle.pressed.connect(_on_toggle_pressed)
    _header.add_child(_toggle)
    _body.add_child(_header)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _body.add_child(content)
    add_child(_body)
    _strip.add_theme_constant_override("separation", 6)
    _strip_button.pressed.connect(func() -> void: set_collapsed(false))
    _strip_button.mouse_entered.connect(_on_strip_hovered)
    _strip.add_child(_strip_button)
    add_child(_strip)
    set_process(false)
    _update()

## `kind` is STRIP_COLUMN (collapses sideways to a thin column) or STRIP_ROW (to a thin row).
func setup(panel_key: String, title: String, kind: String) -> void:
    key = panel_key
    strip_kind = kind
    _strip.vertical = kind == STRIP_COLUMN
    set_title(title)

func set_title(title: String) -> void:
    _title.text = title
    _strip_button.setup(title, strip_kind == STRIP_COLUMN)

## Extra content shown in the strip next to (row) or above (column) the strip button.
func set_strip_extra(node: Control) -> void:
    _strip_extra = node
    _strip.add_child(node)
    _strip.move_child(node, 0)

## Draw without the panel box (for a panel inside another bar).
func set_frameless() -> void:
    add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func add_content(node: Control, expand: bool = false) -> void:
    if expand:
        node.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(node)

func is_open() -> bool:
    return not collapsed or peeking

func set_collapsed(value: bool) -> void:
    var was_open: bool = is_open()
    var changed: bool = value != collapsed
    collapsed = value
    if not collapsed:
        peeking = false
        _hover_peeking = false
    _update()
    if changed:
        collapse_toggled.emit(collapsed)
    if is_open() != was_open:
        open_changed.emit(is_open())

## Open a collapsed panel for now (or close the peek). The saved collapsed state stays.
func set_peek(value: bool) -> void:
    if not collapsed or value == peeking:
        return
    peeking = value
    if not value:
        _hover_peeking = false
    _update()
    open_changed.emit(is_open())

func _on_toggle_pressed() -> void:
    # While peeking the button pins the panel open; otherwise it collapses it.
    set_collapsed(not peeking)

func _on_strip_hovered() -> void:
    if hover_peek and collapsed and not peeking:
        _hover_peeking = true
        _outside_seconds = 0.0
        set_peek(true)

func _process(delta: float) -> void:
    if not _hover_peeking:
        set_process(false)
        return
    if get_global_rect().has_point(get_global_mouse_position()):
        _outside_seconds = 0.0
        return
    _outside_seconds += delta
    if _outside_seconds >= PEEK_GRACE_SECONDS:
        set_peek(false)

## A peek the table opened (not the mouse) is closed by the table; true while that is the case.
func is_auto_peek() -> bool:
    return peeking and not _hover_peeking

func _update() -> void:
    var open: bool = is_open()
    _body.visible = open
    _strip.visible = not open
    _toggle.text = "+" if peeking else "–"
    _toggle.tooltip_text = "Keep open" if peeking else "Collapse"
    set_process(_hover_peeking)
