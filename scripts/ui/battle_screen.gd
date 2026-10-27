class_name BattleScreen
extends Control

## The playtest battle scene (Milestone 2). Presentation only: it owns a BattleSession, redraws
## every view whenever the session's worker thread pauses, and sends the person's choices back as
## option indexes. It never changes game state itself.

var _data: Dictionary = {}
var _session: BattleSession = null
var _shown_serial: int = -1
var _needs_redraw: bool = false
var _last_hand_hero: HeroState = null

var _controls := ControlsBar.new()
var _provoke := ProvokeView.new()
var _board := BoardView.new()
var _turn_label := Label.new()
var _choice := ChoicePanel.new()
var _status := StatusView.new()
var _log := LogView.new()
var _hand := HandView.new()

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.1, 0.1, 0.12)
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
    root.add_child(_controls)
    var track_row := HBoxContainer.new()
    var track_label := Label.new()
    track_label.text = "Provoke"
    track_row.add_child(track_label)
    track_row.add_child(_provoke)
    root.add_child(track_row)
    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation", 14)
    root.add_child(main)
    main.add_child(_board)
    var middle := VBoxContainer.new()
    middle.custom_minimum_size = Vector2(430, 0)
    _turn_label.add_theme_font_size_override("font_size", 18)
    middle.add_child(_turn_label)
    middle.add_child(_choice)
    middle.add_child(HSeparator.new())
    middle.add_child(_status)
    main.add_child(middle)
    _log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _log.custom_minimum_size = Vector2(360, 0)
    main.add_child(_log)
    root.add_child(_hand)

    _controls.restart_requested.connect(_restart)
    _controls.ai_heroes_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_ai_heroes(on))
    _controls.auto_continue_toggled.connect(func(on: bool) -> void:
        if _session != null:
            _session.set_auto_continue(on))
    _board.option_chosen.connect(_answer)
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
    _log.reset()
    _hand.selected_uid = -1
    _last_hand_hero = null
    _shown_serial = -1
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
    _board.refresh(battle, request)
    _provoke.refresh(battle)
    _status.refresh(battle)
    _log.refresh(battle)
    var hand_hero: HeroState = _last_hand_hero
    if request != null and request.hero != null:
        hand_hero = request.hero
    elif battle != null and battle.active_figure is HeroState:
        hand_hero = battle.active_figure
    _last_hand_hero = hand_hero
    _hand.refresh(hand_hero, request)
    if request != null and request.kind == DecisionRequest.NEXT_HERO:
        _turn_label.text = "Round %d: choose the next hero" % battle.round_number
    elif battle != null and battle.active_figure != null:
        _turn_label.text = "Round %d: %s's turn" % [battle.round_number, battle.active_figure.name]
    elif battle != null:
        _turn_label.text = "Round %d" % battle.round_number
    if request != null:
        _choice.show_decision(request, _selected_card(request))
    elif kind == BattleSession.PAUSE_CONTINUE and battle != null:
        _choice.show_continue(UiText.turn_summary(battle, _session.pause_entry()))
    elif _session.is_finished() and battle != null:
        _choice.show_message("Battle over: %s after %d rounds. Press Restart for another." % [
            StatusView._result_text(battle.result), battle.round_number])
        _turn_label.text = "Battle over"

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
    _board.clear_options()
    _hand.set_interactive(false)
    _choice.set_busy()
