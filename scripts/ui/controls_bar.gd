class_name ControlsBar
extends HFlowContainer

## Seed, encounter, DM mode, Restart, and the "AI plays heroes" and auto-continue toggles.

signal restart_requested
signal ai_heroes_toggled(on: bool)
signal auto_continue_toggled(on: bool)

var _seed := SpinBox.new()
var _encounter := OptionButton.new()
var _dm := OptionButton.new()
var _ai := CheckBox.new()
var _auto := CheckBox.new()

func _init() -> void:
    add_theme_constant_override("h_separation", 12)
    _add_label("Seed")
    _seed.min_value = 1
    _seed.max_value = 999999
    _seed.value = 1
    _seed.rounded = true
    add_child(_seed)
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
