class_name TableScreen
extends Control

## The playtest table (Milestone 4 layout, placeholder visuals). Presentation only: it owns a
## BattleSession, redraws every view whenever the session's worker thread pauses, and sends the
## person's choices back as option indexes. It never changes game state itself.
##
##   top bar:  seed, encounter, DM, restart, AI toggles, the Layout menu and Reset layout
##   map:      Hut track / rations / party armor, then the map (dimmed during a battle)
##   battle:   DM board, player board (front rows facing), Provoke strip (BattlefieldView, tall or wide)
##   side:     decks, discards and Exhausted cards; enemy decks; the event log (collapsible)
##   dock:     the prompt and buttons, and the active hero's hand
##
## Flexible layout (4.1b): draggable dividers (TableSplit) between the areas; the map, battle,
## side column, log and hand collapse to thin strips (CollapsiblePanel); the hand docks at the
## bottom (full width or under the boards) or at either side; the battlefield is tall or wide.
## Exploring and battle each have their own layout state (LayoutSettings), switched with an
## animation; everything is saved to user://layout.cfg. No area floats free.
##
## Every piece is a small reusable scene (scenes/components/) styled by one Theme (ui/theme.tres),
## so the art pass swaps those pieces rather than this layout.

## Where the layout is saved; set before the scene enters the tree to use another file.
var layout_path: String = LayoutSettings.PATH

var _data: Dictionary = {}
var _session: BattleSession = null
var _shown_serial: int = -1
var _needs_redraw: bool = false
var _last_hand_hero: HeroState = null

var _layout: LayoutSettings = null
var _phase: String = LayoutSettings.PHASE_BATTLE
var _previewing_exploring: bool = false
var _applying: bool = false

var _controls := ControlsBar.new()
var _layout_menu := LayoutMenu.new()
var _map_status := MapStatusBar.new()
var _map := MapView.new()
var _battlefield := BattlefieldView.new()
var _party_summary := PartySummary.new()
var _piles := PilesView.new()
var _log := LogPanel.new()
var _choice := ChoicePanel.new()
var _hand := HandView.new()

var _root := VBoxContainer.new()
var _map_area: CollapsiblePanel = UiScenes.collapsible_panel("map", "Map", CollapsiblePanel.STRIP_COLUMN)
var _battle_area: CollapsiblePanel = UiScenes.collapsible_panel("battle", "Battle", CollapsiblePanel.STRIP_COLUMN)
var _side_area: CollapsiblePanel = UiScenes.collapsible_panel("side", "Decks and discards", CollapsiblePanel.STRIP_COLUMN)
var _hand_area: CollapsiblePanel = UiScenes.collapsible_panel("hand", "Hand", CollapsiblePanel.STRIP_ROW)
var _dock := PanelContainer.new()
var _dock_box := BoxContainer.new()
var _top_split: TableSplit = null
var _splits: Dictionary = {}  # split key -> TableSplit

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg := Panel.new()
    bg.theme_type_variation = &"TableBackground"
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var margin := MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 10)
    add_child(margin)
    _root.add_theme_constant_override("separation", 8)
    margin.add_child(_root)

    var top := PanelContainer.new()
    top.theme_type_variation = &"TableBar"
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    _controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(_controls)
    top_row.add_child(_layout_menu)
    var reset := Button.new()
    reset.text = "Reset layout"
    reset.pressed.connect(_reset_layout)
    top_row.add_child(reset)
    top.add_child(top_row)
    _root.add_child(top)

    _map_area.add_content(_map_status)
    _map_area.add_content(_map, true)
    _battle_area.add_content(_battlefield, true)
    _party_summary.vertical = true
    _battle_area.set_strip_extra(_party_summary)
    _side_area.add_content(_piles, true)
    _piles.size_flags_stretch_ratio = 1.3
    _side_area.add_content(_log)
    _hand.show_title(false)
    _hand_area.add_content(_hand, true)
    _hand_area.set_frameless()
    _hand_area.hover_peek = true
    _dock.theme_type_variation = &"TableBar"
    _dock_box.add_theme_constant_override("separation", 10)
    _dock.add_child(_dock_box)
    _choice.custom_minimum_size = Vector2(260, 0)
    _dock_box.add_child(_choice)
    _dock_box.add_child(_hand_area)
    for area in [_map_area, _battle_area, _side_area, _hand_area]:
        var panel: CollapsiblePanel = area
        panel.collapse_toggled.connect(func(collapsed: bool) -> void: _on_collapse_toggled(panel.key, collapsed))
        panel.open_changed.connect(func(_open: bool) -> void:
            if not _applying:
                _update_splits(true))
    _log.toggled.connect(func(open: bool) -> void: _on_collapse_toggled("log", not open))

    _controls.restart_requested.connect(_restart)
    _controls.ai_heroes_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_ai_heroes(on))
    _controls.auto_continue_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_auto_continue(on))
    _layout_menu.chosen.connect(_on_layout_chosen)
    _battlefield.dm_board.option_chosen.connect(_answer)
    _battlefield.hero_board.option_chosen.connect(_answer)
    _hand.option_chosen.connect(_answer)
    _hand.card_selected.connect(_select_card)
    _choice.option_chosen.connect(_answer)
    _choice.play_pressed.connect(_play_selected)
    _choice.continue_pressed.connect(func() -> void: _answer(0))

    _layout = LayoutSettings.load_from(layout_path)
    _build_layout()

    var loader := DataLoader.new()
    _data = loader.load_all()
    if _data.is_empty():
        _choice.show_message("Data did not load:\n" + "\n".join(loader.errors))
        return
    _restart()

func _process(_delta: float) -> void:
    if _session == null:
        return
    var serial: int = _session.serial()
    if serial != _shown_serial or _needs_redraw:
        if _session.begin_view():
            _shown_serial = serial
            _needs_redraw = false
            _refresh()
            _session.end_view()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
        if _session != null:
            _session.abort()

# ------------------------------------------------------------------ layout

## The current layout settings (read-only use; change them through the Layout menu).
func layout_settings() -> LayoutSettings:
    return _layout

## Switch between the exploring and battle layouts (LayoutSettings.PHASE_*). Exploration (4.4/4.6)
## calls this when a battle starts and ends; until then only the preview item uses it.
func set_phase(phase: String) -> void:
    if phase == _phase:
        return
    _phase = phase
    if _layout.phase_mode == LayoutSettings.MODE_BOTH:
        _layout.set_collapsed(phase, "map", false)
        _layout.set_collapsed(phase, "battle", false)
    _apply_state(true)

func phase() -> String:
    return _phase

## Apply a preset by name (also used by tools/screenshot_table.gd).
func apply_preset(preset: String) -> void:
    _layout.apply_preset(preset)
    _build_layout()
    _save_layout()

## Rebuild the split tree for the hand dock, arrange the battlefield and apply the phase's state.
func _build_layout() -> void:
    for node in [_map_area, _battle_area, _side_area, _dock]:
        var c := node as Control
        if c.get_parent() != null:
            c.get_parent().remove_child(c)
    if _top_split != null:
        _top_split.queue_free()
    _splits.clear()
    var map_split := TableSplit.new("map", false)
    var side_split := TableSplit.new("side", false)
    side_split.set_children(_battle_area, _side_area)
    var dock_split: TableSplit
    match _layout.hand_dock:
        LayoutSettings.DOCK_BOTTOM_BOARDS:
            dock_split = TableSplit.new("dock", true)
            dock_split.set_children(side_split, _dock)
            map_split.set_children(_map_area, dock_split)
            _top_split = map_split
        LayoutSettings.DOCK_BOTTOM_FULL:
            map_split.set_children(_map_area, side_split)
            dock_split = TableSplit.new("dock", true)
            dock_split.set_children(map_split, _dock)
            _top_split = dock_split
        LayoutSettings.DOCK_LEFT:
            map_split.set_children(_map_area, side_split)
            dock_split = TableSplit.new("dock", false)
            dock_split.set_children(_dock, map_split)
            _top_split = dock_split
        _:
            map_split.set_children(_map_area, side_split)
            dock_split = TableSplit.new("dock", false)
            dock_split.set_children(map_split, _dock)
            _top_split = dock_split
    for split in [map_split, side_split, dock_split]:
        var s: TableSplit = split
        _splits[s.key] = s
        s.fraction_changed.connect(_on_split_dragged)
    _top_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _root.add_child(_top_split)

    var side_dock: bool = _is_side_dock()
    _dock_box.vertical = side_dock
    _hand.set_stacked(side_dock)
    _hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _hand_area.size_flags_vertical = Control.SIZE_EXPAND_FILL if side_dock else Control.SIZE_FILL
    _battlefield.arrange(_layout.orientation, _layout.provoke_edge)
    _apply_state(false)

func _is_side_dock() -> bool:
    return _layout.hand_dock == LayoutSettings.DOCK_LEFT or _layout.hand_dock == LayoutSettings.DOCK_RIGHT

## Open or collapse every area as the phase's state says, then move the dividers.
func _apply_state(animated: bool) -> void:
    _applying = true
    _map_area.set_collapsed(_layout.is_collapsed(_phase, "map"))
    _battle_area.set_collapsed(_layout.is_collapsed(_phase, "battle"))
    _side_area.set_collapsed(_layout.is_collapsed(_phase, "side"))
    _hand_area.set_collapsed(_layout.is_collapsed(_phase, "hand"))
    _log.set_open(not _layout.is_collapsed(_phase, "log"))
    _applying = false
    _map.set_dimmed(_phase == LayoutSettings.PHASE_BATTLE)
    _update_splits(animated)
    _layout_menu.refresh(_layout, _previewing_exploring)

## Divider positions from the saved fractions; a collapsed area squeezes its side to the strip.
func _update_splits(animated: bool) -> void:
    if _splits.is_empty():
        return
    var map_split: TableSplit = _splits["map"]
    var side_split: TableSplit = _splits["side"]
    var dock_split: TableSplit = _splits["dock"]
    map_split.fraction = _layout.split_fraction(_phase, "map")
    side_split.fraction = _layout.split_fraction(_phase, "side")
    var battle_open: bool = _battle_area.is_open()
    var side_open: bool = _side_area.is_open()
    side_split.squeeze = TableSplit.SQUEEZE_NONE
    if not battle_open:
        side_split.squeeze = TableSplit.SQUEEZE_FIRST
    elif not side_open:
        side_split.squeeze = TableSplit.SQUEEZE_SECOND
    map_split.squeeze = TableSplit.SQUEEZE_NONE
    if not _map_area.is_open():
        map_split.squeeze = TableSplit.SQUEEZE_FIRST
    elif not battle_open and not side_open:
        map_split.squeeze = TableSplit.SQUEEZE_SECOND
    var dock_share: float = _layout.split_fraction(_phase, "dock")
    var dock_first: bool = _layout.hand_dock == LayoutSettings.DOCK_LEFT
    dock_split.fraction = dock_share if dock_first else 1.0 - dock_share
    dock_split.squeeze = TableSplit.SQUEEZE_NONE
    if not _is_side_dock() and not _hand_area.is_open():
        dock_split.squeeze = TableSplit.SQUEEZE_SECOND
    for split in [map_split, side_split, dock_split]:
        (split as TableSplit).apply(animated)

func _on_split_dragged(key: String, fraction: float) -> void:
    if key == "dock" and _layout.hand_dock != LayoutSettings.DOCK_LEFT:
        fraction = 1.0 - fraction
    _layout.set_split_fraction(_phase, key, fraction)
    _save_layout()

func _on_collapse_toggled(key: String, collapsed: bool) -> void:
    if _applying:
        return
    _layout.set_collapsed(_phase, key, collapsed)
    _save_layout()

func _on_layout_chosen(action: String, value: String) -> void:
    match action:
        LayoutMenu.ACTION_PRESET:
            _layout.apply_preset(value)
        LayoutMenu.ACTION_SAVE_CUSTOM:
            _layout.save_custom()
        LayoutMenu.ACTION_ORIENTATION:
            _layout.orientation = value
        LayoutMenu.ACTION_EDGE:
            _layout.provoke_edge = value
        LayoutMenu.ACTION_DOCK:
            _layout.hand_dock = value
        LayoutMenu.ACTION_AUTO_OPEN:
            _layout.hand_auto_open = not _layout.hand_auto_open
        LayoutMenu.ACTION_PHASE_MODE:
            _layout.phase_mode = value
        LayoutMenu.ACTION_PREVIEW:
            _previewing_exploring = not _previewing_exploring
            set_phase(LayoutSettings.PHASE_EXPLORING if _previewing_exploring else LayoutSettings.PHASE_BATTLE)
    if action == LayoutMenu.ACTION_PHASE_MODE:
        _apply_state(true)
    elif not [LayoutMenu.ACTION_AUTO_OPEN, LayoutMenu.ACTION_SAVE_CUSTOM, LayoutMenu.ACTION_PREVIEW].has(action):
        _build_layout()
    _layout_menu.refresh(_layout, _previewing_exploring)
    _save_layout()

## Back to the default layout (the Tall preset, automatic phases). A saved "My layout" is kept.
func _reset_layout() -> void:
    var saved_custom: Dictionary = _layout.custom
    _layout = LayoutSettings.defaults()
    _layout.custom = saved_custom
    _build_layout()
    _save_layout()

func _save_layout() -> void:
    var err: Error = _layout.save(layout_path)
    if err != OK:
        push_warning("Could not save the layout to %s (error %d)" % [layout_path, err])

# ------------------------------------------------------------------ battle

func _restart() -> void:
    if _data.is_empty():
        return
    if _session != null:
        _session.abort()
    _log.log_view.reset()
    _piles.reset()
    _hand.selected_uid = -1
    _last_hand_hero = null
    _shown_serial = -1
    _map.clear_map()
    _map.set_hint("Single battle: the map comes with exploration.")
    _session = BattleSession.new()
    _session.set_ai_heroes(_controls.ai_heroes())
    _session.set_auto_continue(_controls.auto_continue())
    _choice.show_message("Starting...")
    _session.start(_data, _data["encounters"][_controls.encounter_name()], _controls.seed_value(), _controls.dm_mode())

## Redraw every view from the paused battle. Called with the session's state lock held.
func _refresh() -> void:
    var battle: Battle = _session.battle
    var kind: String = _session.pause_kind()
    var request: DecisionRequest = _session.pending_request() if kind == BattleSession.PAUSE_DECISION else null
    _battlefield.refresh(battle, request)
    _piles.refresh(battle)
    _log.log_view.refresh(battle)
    var heroes: Array[HeroState] = battle.heroes if battle != null else ([] as Array[HeroState])
    _map_status.refresh(-1, 10, {}, -1, heroes)
    _party_summary.refresh(heroes)
    var hand_hero: HeroState = _last_hand_hero
    if request != null and request.hero != null:
        hand_hero = request.hero
    elif battle != null and battle.active_figure is HeroState:
        hand_hero = battle.active_figure
    _last_hand_hero = hand_hero
    _hand.refresh(hand_hero, request)
    _hand_area.set_title(_hand.title_text())
    _update_hand_peek(request)
    _battle_area.set_title(_turn_text(battle, request))
    if request != null:
        _choice.show_decision(request, _selected_card(request))
    elif kind == BattleSession.PAUSE_CONTINUE and battle != null:
        _choice.show_continue(UiText.turn_summary(battle, _session.pause_entry()))
    elif _session.is_finished() and battle != null:
        _choice.show_message("Battle over: %s after %d rounds. Press Restart for another." % [
            UiText.result_text(battle.result), battle.round_number])

## A collapsed hand pops open while a hero must choose a card from it (unless that is turned off),
## and closes again once the choice is made.
func _update_hand_peek(request: DecisionRequest) -> void:
    var wants: bool = _layout.hand_auto_open and HandView.wants_card(request)
    if wants and _hand_area.collapsed and not _hand_area.peeking:
        _hand_area.set_peek(true)
    elif not wants and _hand_area.is_auto_peek():
        _hand_area.set_peek(false)

func _turn_text(battle: Battle, request: DecisionRequest) -> String:
    if battle == null:
        return "Battle"
    var head: String = "Round %d  ·  DM: %s" % [battle.round_number, battle.dm_mode]
    if _session.is_finished():
        return "Battle over: %s" % UiText.result_text(battle.result)
    if request != null and request.kind == DecisionRequest.NEXT_HERO:
        return head + "  ·  choose the next hero"
    if battle.active_figure != null:
        return head + "  ·  %s's turn" % battle.active_figure.name
    return head

func _selected_card(request: DecisionRequest) -> Card:
    if request.kind != DecisionRequest.TURN or _hand.selected_uid < 0:
        return null
    for option in request.options:
        var turn: TurnOption = option
        if turn.kind == TurnOption.PLAY and turn.card.uid == _hand.selected_uid:
            return turn.card
    return null

func _select_card(uid: int) -> void:
    _hand.selected_uid = uid
    _needs_redraw = true

func _play_selected() -> void:
    var request: DecisionRequest = _session.pending_request()
    if request == null or request.kind != DecisionRequest.TURN:
        return
    for i in range(request.options.size()):
        var turn: TurnOption = request.options[i]
        if turn.kind == TurnOption.PLAY and turn.card.uid == _hand.selected_uid:
            _answer(i)
            return

func _answer(index: int) -> void:
    if _session == null:
        return
    _session.answer(index)
    _hand.selected_uid = -1
    _battlefield.clear_options()
    _hand.set_interactive(false)
    _choice.set_busy()
