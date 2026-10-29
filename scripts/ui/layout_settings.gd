class_name LayoutSettings
extends RefCounted

## The player's table layout, saved to a user settings file (user://layout.cfg) and restored on
## launch: preset, battlefield orientation, Provoke strip edge, hand dock, phase-layout mode, hand
## auto-open, and per phase the divider sizes and collapsed panels. Presentation only.
##
## Divider sizes are fractions: "map" is the map's share of the table width, "side" the battle
## area's share of what is left beside the decks column, "dock" the hand dock's share (of the height
## when docked at the bottom, of the width when docked at a side).
##
## Phase layouts: "automatic" keeps one state per phase (exploring, battle) and switches with the
## phase; "both" also keeps a state per phase but always reopens the map and the boards on a phase
## change; "manual" keeps a single state and never changes it by itself. Presets ("tall", "wide",
## and "custom", the player's own saved layout) set every phase's state at once.

const PATH := "user://layout.cfg"
const VERSION := 1

const PHASE_EXPLORING := "exploring"
const PHASE_BATTLE := "battle"
const PHASES: Array[String] = [PHASE_EXPLORING, PHASE_BATTLE]
const STATE_MANUAL := "manual"

const PRESET_TALL := "tall"
const PRESET_WIDE := "wide"
const PRESET_CUSTOM := "custom"
const PRESETS: Array[String] = [PRESET_TALL, PRESET_WIDE, PRESET_CUSTOM]

const DOCK_BOTTOM_FULL := "bottom_full"
const DOCK_BOTTOM_BOARDS := "bottom_boards"
const DOCK_LEFT := "left"
const DOCK_RIGHT := "right"
const DOCKS: Array[String] = [DOCK_BOTTOM_FULL, DOCK_BOTTOM_BOARDS, DOCK_LEFT, DOCK_RIGHT]

const MODE_AUTOMATIC := "automatic"
const MODE_BOTH := "both"
const MODE_MANUAL := "manual"
const PHASE_MODES: Array[String] = [MODE_AUTOMATIC, MODE_BOTH, MODE_MANUAL]

const EDGES: Array[String] = [BattlefieldView.EDGE_TOP, BattlefieldView.EDGE_BOTTOM]
const PANELS: Array[String] = ["map", "battle", "side", "log", "hand"]
const SPLITS: Array[String] = ["map", "side", "dock"]
const MIN_FRACTION := 0.05
const MAX_FRACTION := 0.95

var preset: String = PRESET_TALL
var orientation: String = BoardOrientation.TALL
var provoke_edge: String = BattlefieldView.EDGE_BOTTOM
var hand_dock: String = DOCK_BOTTOM_BOARDS
var phase_mode: String = MODE_AUTOMATIC
var hand_auto_open: bool = true
## State key (a phase or STATE_MANUAL) -> {"splits": {split: fraction}, "collapsed": {panel: bool}}.
var states: Dictionary = {}
## The player's saved layout ("custom" preset): the preset-controlled fields; empty until saved.
var custom: Dictionary = {}

static func defaults() -> LayoutSettings:
    var s := LayoutSettings.new()
    s.apply_preset(PRESET_TALL)
    return s

## What a built-in preset sets: orientation, Provoke edge, hand dock and each phase's state.
static func preset_layout(name: String) -> Dictionary:
    var wide: bool = name == PRESET_WIDE
    var battle_map: float = 0.24 if wide else 0.3
    var side: float = 0.72 if wide else 0.62
    # Wide boards are limited by their width, so the hand dock can have more of the height.
    var dock: float = 0.3 if wide else 0.22
    var states_out: Dictionary = {
        PHASE_BATTLE: _state(battle_map, side, dock, {}),
        PHASE_EXPLORING: _state(0.68, side, dock, {"battle": true, "hand": true}),
        STATE_MANUAL: _state(battle_map, side, dock, {}),
    }
    return {
        "orientation": BoardOrientation.WIDE if wide else BoardOrientation.TALL,
        "provoke_edge": BattlefieldView.EDGE_BOTTOM,
        "hand_dock": DOCK_BOTTOM_FULL if wide else DOCK_BOTTOM_BOARDS,
        "states": states_out,
    }

static func _state(map_fraction: float, side: float, dock: float, collapsed_panels: Dictionary) -> Dictionary:
    var collapsed: Dictionary = {}
    for panel in PANELS:
        collapsed[panel] = bool(collapsed_panels.get(panel, false))
    return {"splits": {"map": map_fraction, "side": side, "dock": dock}, "collapsed": collapsed}

## Switch to a preset. "custom" restores the saved layout (nothing happens if none is saved).
func apply_preset(name: String) -> void:
    var layout: Dictionary = custom if name == PRESET_CUSTOM else preset_layout(name)
    if layout.is_empty():
        return
    preset = name
    _set_layout(layout)

## Save the current layout as the player's own ("custom") preset.
func save_custom() -> void:
    custom = _layout_part()
    preset = PRESET_CUSTOM

## The state a phase uses under the current phase mode.
func state_key(phase: String) -> String:
    return STATE_MANUAL if phase_mode == MODE_MANUAL else phase

func state(phase: String) -> Dictionary:
    var key: String = state_key(phase)
    if not states.has(key):
        states[key] = (preset_layout(PRESET_TALL)["states"] as Dictionary)[key].duplicate(true)
    return states[key]

func split_fraction(phase: String, split: String) -> float:
    return float((state(phase)["splits"] as Dictionary).get(split, 0.5))

func set_split_fraction(phase: String, split: String, fraction: float) -> void:
    (state(phase)["splits"] as Dictionary)[split] = clampf(fraction, MIN_FRACTION, MAX_FRACTION)

func is_collapsed(phase: String, panel: String) -> bool:
    return bool((state(phase)["collapsed"] as Dictionary).get(panel, false))

func set_collapsed(phase: String, panel: String, collapsed: bool) -> void:
    (state(phase)["collapsed"] as Dictionary)[panel] = collapsed

func to_dict() -> Dictionary:
    var d: Dictionary = _layout_part()
    d["version"] = VERSION
    d["preset"] = preset
    d["phase_mode"] = phase_mode
    d["hand_auto_open"] = hand_auto_open
    d["custom"] = custom.duplicate(true)
    return d

## Settings from a saved dictionary. Unknown or missing values fall back to the defaults, so an old
## or hand-edited file never breaks the table.
static func from_dict(d: Dictionary) -> LayoutSettings:
    var s: LayoutSettings = defaults()
    s._set_layout(d)
    s.preset = _pick(d.get("preset"), PRESETS, PRESET_TALL)
    s.phase_mode = _pick(d.get("phase_mode"), PHASE_MODES, MODE_AUTOMATIC)
    var auto_open: Variant = d.get("hand_auto_open", true)
    s.hand_auto_open = auto_open if auto_open is bool else true
    var saved_custom: Variant = d.get("custom", {})
    if saved_custom is Dictionary and not (saved_custom as Dictionary).is_empty():
        var check: LayoutSettings = defaults()
        check._set_layout(saved_custom)
        s.custom = check._layout_part()
    if s.preset == PRESET_CUSTOM and s.custom.is_empty():
        s.preset = PRESET_TALL
    return s

func save(path: String = PATH) -> Error:
    var config := ConfigFile.new()
    var d: Dictionary = to_dict()
    for field in d:
        config.set_value("layout", String(field), d[field])
    return config.save(path)

## The saved settings, or the defaults when there is no file (first launch) or it cannot be read.
static func load_from(path: String = PATH) -> LayoutSettings:
    var config := ConfigFile.new()
    if not FileAccess.file_exists(path) or config.load(path) != OK or not config.has_section("layout"):
        return defaults()
    var d: Dictionary = {}
    for field in config.get_section_keys("layout"):
        d[field] = config.get_value("layout", field)
    return from_dict(d)

# ------------------------------------------------------------------ helpers

func _layout_part() -> Dictionary:
    return {"orientation": orientation, "provoke_edge": provoke_edge, "hand_dock": hand_dock, "states": states.duplicate(true)}

func _set_layout(layout: Dictionary) -> void:
    orientation = _pick(layout.get("orientation"), BoardOrientation.ALL, orientation)
    provoke_edge = _pick(layout.get("provoke_edge"), EDGES, provoke_edge)
    hand_dock = _pick(layout.get("hand_dock"), DOCKS, hand_dock)
    var fallback: Dictionary = preset_layout(PRESET_WIDE if orientation == BoardOrientation.WIDE else PRESET_TALL)["states"]
    var saved: Variant = layout.get("states", {})
    var saved_states: Dictionary = saved if saved is Dictionary else {}
    states = {}
    for key in fallback:
        var base: Dictionary = (fallback[key] as Dictionary).duplicate(true)
        var from: Variant = saved_states.get(key, {})
        if from is Dictionary:
            var splits: Variant = (from as Dictionary).get("splits", {})
            if splits is Dictionary:
                for split in SPLITS:
                    var v: Variant = (splits as Dictionary).get(split)
                    if v is float or v is int:
                        base["splits"][split] = clampf(float(v), MIN_FRACTION, MAX_FRACTION)
            var collapsed: Variant = (from as Dictionary).get("collapsed", {})
            if collapsed is Dictionary:
                for panel in PANELS:
                    var c: Variant = (collapsed as Dictionary).get(panel)
                    if c is bool:
                        base["collapsed"][panel] = c
        states[key] = base

static func _pick(value: Variant, allowed: Array[String], fallback: String) -> String:
    if (value is String or value is StringName) and allowed.has(String(value)):
        return String(value)
    return fallback
