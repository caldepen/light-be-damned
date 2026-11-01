class_name ControlsBar
extends HFlowContainer

## Mode (a whole run or a single battle), seed, components held at the start (runs), encounter
## (single battles), DM mode, Restart, and the "AI plays heroes" and auto-continue toggles.

const MODE_RUN := "run"
const MODE_BATTLE := "battle"

signal restart_requested
signal ai_heroes_toggled(on: bool)
signal auto_continue_toggled(on: bool)

var _mode := OptionButton.new()
var _components := SpinBox.new()
var _seed := SpinBox.new()
var _encounter := OptionButton.new()
var _dm := OptionButton.new()
var _ai := CheckBox.new()
var _auto := CheckBox.new()

func _init() -> void:
    add_theme_constant_override("h_separation", 12)
    _mode.add_item("Run")
    _mode.add_item("Single battle")
    add_child(_mode)
    _add_label("Seed")
    _seed.min_value = 1
    _seed.max_value = 999999
    _seed.value = 1
    _seed.rounded = true
    add_child(_seed)
    _add_label("Components")
    _components.min_value = 0
    _components.max_value = 4
    _components.rounded = true
    _components.tooltip_text = "Components the party holds at the start of a run (all four put the Inner Study in the bag)"
    add_child(_components)
    _add_label("Encounter")
    for pair in UiText.ENCOUNTERS:
        _encounter.add_item(String(pair[1]))
    add_child(_encounter)
    _add_label("DM")
    for mode in Battle.DM_MODES:
        _dm.add_item(mode)
    add_child(_dm)
    var restart := Button.new()
    restart.text = "Restart"
    restart.pressed.connect(func() -> void: restart_requested.emit())
    add_child(restart)
    _ai.text = "AI plays heroes"
    _ai.toggled.connect(func(on: bool) -> void: ai_heroes_toggled.emit(on))
    add_child(_ai)
    _auto.text = "Auto-continue"
    _auto.toggled.connect(func(on: bool) -> void: auto_continue_toggled.emit(on))
    add_child(_auto)

func mode() -> String:
    return MODE_RUN if _mode.selected == 0 else MODE_BATTLE

## Select the mode (tools and tests).
func set_mode(value: String) -> void:
    _mode.selected = 0 if value == MODE_RUN else 1

func components() -> int:
    return int(_components.value)

func seed_value() -> int:
    return int(_seed.value)

func encounter_name() -> String:
    return String(UiText.ENCOUNTERS[_encounter.selected][0])

func dm_mode() -> String:
    return Battle.DM_MODES[_dm.selected]

func ai_heroes() -> bool:
    return _ai.button_pressed

func auto_continue() -> bool:
    return _auto.button_pressed

func _add_label(text: String) -> void:
    var l := Label.new()
    l.text = text
    add_child(l)
