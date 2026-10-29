class_name TableScreen
extends Control

## The playtest table (Milestone 4 layout, placeholder visuals). Presentation only: it owns a
## BattleSession, redraws every view whenever the session's worker thread pauses, and sends the
## person's choices back as option indexes. It never changes game state itself.
##
##   top bar:  seed, encounter, DM, restart, AI toggles
##   left:     Hut track / rations / party armor, then the map (dimmed during a battle)
##   centre:   DM board, Provoke strip, player board (the two front rows face each other)
##   right:    decks, discards and Exhausted cards; enemy decks; the event log (collapsible)
##   bottom:   the prompt and buttons, and the active hero's hand (under centre and right)
##
## Every piece is a small reusable scene (scenes/components/) styled by one Theme (ui/theme.tres),
## so the art pass swaps those pieces rather than this layout.

var _data: Dictionary = {}
var _session: BattleSession = null
var _shown_serial: int = -1
var _needs_redraw: bool = false
var _last_hand_hero: HeroState = null

var _controls := ControlsBar.new()
var _map_status := MapStatusBar.new()
var _map := MapView.new()
var _turn_label := Label.new()
var _dm_board := BoardView.new(FigureState.SIDE_ENEMIES)
var _provoke := ProvokeView.new()
var _hero_board := BoardView.new(FigureState.SIDE_HEROES)
var _piles := PilesView.new()
var _log := LogPanel.new()
var _choice := ChoicePanel.new()
var _hand := HandView.new()

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
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 8)
    margin.add_child(root)

    var top := PanelContainer.new()
    top.theme_type_variation = &"TableBar"
    top.add_child(_controls)
    root.add_child(top)

    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 10)
    root.add_child(main)

    # Left column: map status strip and the map.
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.size_flags_stretch_ratio = 1.0
    left.add_child(_map_status)
    var map_panel: PanelFrame = UiScenes.panel("Map area")
    map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_panel.add_content(_map, true)
    left.add_child(map_panel)
    main.add_child(left)

    # Centre and right columns, with the hand bar under both.
    var centre_right := VBoxContainer.new()
    centre_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    centre_right.size_flags_stretch_ratio = 1.9
    centre_right.add_theme_constant_override("separation", 8)
    main.add_child(centre_right)
    var columns := HBoxContainer.new()
    columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
    columns.add_theme_constant_override("separation", 10)
    centre_right.add_child(columns)

    var centre := VBoxContainer.new()
    centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    centre.size_flags_stretch_ratio = 1.15
    centre.add_theme_constant_override("separation", 6)
    _turn_label.theme_type_variation = &"PanelTitle"
    _turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    centre.add_child(_turn_label)
    var dm_panel: PanelFrame = UiScenes.panel("DM board")
    dm_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    dm_panel.add_content(_dm_board, true)
    centre.add_child(dm_panel)
    var track := PanelContainer.new()
    track.theme_type_variation = &"TableBar"
    track.add_child(_provoke)
    centre.add_child(track)
    var hero_panel: PanelFrame = UiScenes.panel("Player board")
    hero_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hero_panel.add_content(_hero_board, true)
    centre.add_child(hero_panel)
    columns.add_child(centre)

    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.size_flags_stretch_ratio = 0.85
    right.add_theme_constant_override("separation", 6)
    var piles_panel: PanelFrame = UiScenes.panel("Decks and discards")
    piles_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    piles_panel.size_flags_stretch_ratio = 1.3
    piles_panel.add_content(_piles, true)
    right.add_child(piles_panel)
    _log.size_flags_stretch_ratio = 1.0
    right.add_child(_log)
    columns.add_child(right)

    var bottom := PanelContainer.new()
    bottom.theme_type_variation = &"TableBar"
    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 10)
    _choice.custom_minimum_size = Vector2(300, 0)
    bottom_row.add_child(_choice)
    _hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_row.add_child(_hand)
    bottom.add_child(bottom_row)
    centre_right.add_child(bottom)

    _controls.restart_requested.connect(_restart)
    _controls.ai_heroes_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_ai_heroes(on))
    _controls.auto_continue_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_auto_continue(on))
    _dm_board.option_chosen.connect(_answer)
    _hero_board.option_chosen.connect(_answer)
    _hand.option_chosen.connect(_answer)
    _hand.card_selected.connect(_select_card)
    _choice.option_chosen.connect(_answer)
    _choice.play_pressed.connect(_play_selected)
    _choice.continue_pressed.connect(func() -> void: _answer(0))

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
    _map.set_dimmed(true)
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
    _dm_board.refresh(battle, request)
    _hero_board.refresh(battle, request)
    _provoke.refresh(battle)
    _piles.refresh(battle)
    _log.log_view.refresh(battle)
    var heroes: Array[HeroState] = battle.heroes if battle != null else ([] as Array[HeroState])
    _map_status.refresh(-1, 10, {}, -1, heroes)
    var hand_hero: HeroState = _last_hand_hero
    if request != null and request.hero != null:
        hand_hero = request.hero
    elif battle != null and battle.active_figure is HeroState:
        hand_hero = battle.active_figure
    _last_hand_hero = hand_hero
    _hand.refresh(hand_hero, request)
    _turn_label.text = _turn_text(battle, request)
    if request != null:
        _choice.show_decision(request, _selected_card(request))
    elif kind == BattleSession.PAUSE_CONTINUE and battle != null:
        _choice.show_continue(UiText.turn_summary(battle, _session.pause_entry()))
    elif _session.is_finished() and battle != null:
        _choice.show_message("Battle over: %s after %d rounds. Press Restart for another." % [
            UiText.result_text(battle.result), battle.round_number])

func _turn_text(battle: Battle, request: DecisionRequest) -> String:
    if battle == null:
        return ""
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
    _dm_board.clear_options()
    _hero_board.clear_options()
    _hand.set_interactive(false)
    _choice.set_busy()
