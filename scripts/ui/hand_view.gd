class_name HandView
extends VBoxContainer

## The active hero's hand along the bottom of the table, as CardView scenes. On that hero's turn
## the legal cards can be selected (then Play); for a discard request the offered cards are chosen
## directly. Wounds are shown but never clickable. Cards shrink to share the bar's width.

signal card_selected(card_uid: int)
signal option_chosen(index: int)

const CARD_SIZE := Vector2(150, 132)
const MIN_CARD_WIDTH := 96.0

var _title := Label.new()
var _row := HBoxContainer.new()
var _cards: Array[CardView] = []
var selected_uid: int = -1

func _init() -> void:
    add_child(_title)
    _row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _row.add_theme_constant_override("separation", 6)
    add_child(_row)
    custom_minimum_size = Vector2(0, CARD_SIZE.y + 24)

## `hero`: whose hand to show. With a TURN request the PLAY options are selectable; with a request
## whose options are cards in this hand, those cards answer it.
func refresh(hero: HeroState, request: DecisionRequest) -> void:
    if hero == null:
        _title.text = "Hand"
        _show_cards(0)
        return
    _title.text = "%s's hand (%d / %d)" % [hero.name, hero.hand.size(), hero.hand_size]
    var playable: Dictionary = {}  # card uid -> option index
    var direct: bool = false
    if request != null and request.hero == hero:
        for i in range(request.options.size()):
            var option: Variant = request.options[i]
            if option is TurnOption and (option as TurnOption).kind == TurnOption.PLAY:
                playable[(option as TurnOption).card.uid] = i
            elif option is Card and hero.hand.has(option):
                playable[(option as Card).uid] = i
                direct = true
    if not playable.has(selected_uid):
        selected_uid = -1
    _show_cards(hero.hand.size())
    for i in range(hero.hand.size()):
        var card: Card = hero.hand[i]
        var view: CardView = _cards[i]
        var clickable: bool = playable.has(card.uid) and not card.is_wound
        var state: String = CardView.STATE_NORMAL
        if card.is_wound:
            state = CardView.STATE_WOUND
        elif card.uid == selected_uid:
            state = CardView.STATE_SELECTED
        elif not clickable:
            state = CardView.STATE_DIMMED
        view.show_card(card, state)
        view.disabled = not clickable
        for connection in view.pressed.get_connections():
            view.pressed.disconnect(connection["callable"])
        if clickable:
            var uid: int = card.uid
            var index: int = playable[card.uid]
            if direct:
                view.pressed.connect(func() -> void: option_chosen.emit(index))
            else:
                view.pressed.connect(func() -> void: card_selected.emit(uid))

func set_interactive(on: bool) -> void:
    if on:
        return
    for view in _cards:
        view.disabled = true

## Keep exactly `count` card views visible, reusing them between refreshes.
func _show_cards(count: int) -> void:
    while _cards.size() < count:
        var view: CardView = UiScenes.card_view()
        _cards.append(view)
        _row.add_child(view)
    for i in range(_cards.size()):
        _cards[i].visible = i < count
    _fit_cards()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        _fit_cards()

## Full-size cards when they fit; narrower (down to MIN_CARD_WIDTH) when the hand is large.
func _fit_cards() -> void:
    var shown: int = 0
    for view in _cards:
        if view.visible:
            shown += 1
    if shown == 0:
        return
    var gap: float = float(_row.get_theme_constant("separation"))
    var width: float = clampf((size.x - gap * (shown - 1)) / shown, MIN_CARD_WIDTH, CARD_SIZE.x)
    for view in _cards:
        view.custom_minimum_size = Vector2(width, CARD_SIZE.y)
