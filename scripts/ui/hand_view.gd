class_name HandView
extends VBoxContainer

## The active hero's hand, as CardView scenes. On that hero's turn the legal cards can be selected
## (then Play); for a discard request the offered cards are chosen directly. Wounds are shown but
## never clickable. Docked at the bottom the cards sit in a row, share its width and grow with the
## dock's height; docked at a side (`set_stacked`) they stack and share the height. Cards that do
## not fit scroll. The title can move to the panel header (`show_title`).

signal card_selected(card_uid: int)
signal option_chosen(index: int)

const CARD_SIZE := Vector2(150, 132)
const MIN_CARD_WIDTH := 96.0
const MAX_CARD_HEIGHT := 210.0
const MIN_STACKED_HEIGHT := 84.0
const MAX_STACKED_HEIGHT := 150.0

var selected_uid: int = -1
var vertical_cards: bool = false
var _title := Label.new()
var _scroll := ScrollContainer.new()
var _row := BoxContainer.new()
var _cards: Array[CardView] = []

func _init() -> void:
    add_child(_title)
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _scroll.resized.connect(_fit_cards)
    add_child(_scroll)
    _row.add_theme_constant_override("separation", 6)
    _scroll.add_child(_row)
    set_stacked(false)

func show_title(on: bool) -> void:
    _title.visible = on

func title_text() -> String:
    return _title.text

## Stack the cards (side dock) or line them up (bottom dock).
func set_stacked(on: bool) -> void:
    vertical_cards = on
    _row.vertical = on
    custom_minimum_size = Vector2(CARD_SIZE.x + 16, 0) if on else Vector2(0, CARD_SIZE.y + 24)
    _fit_cards()

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

## True when `request` asks this hero to choose a card from the hand (a turn with cards to play, or
## a choice among hand cards such as a discard).
static func wants_card(request: DecisionRequest) -> bool:
    if request == null or request.hero == null:
        return false
    for option in request.options:
        if option is TurnOption and (option as TurnOption).kind == TurnOption.PLAY:
            return true
        if option is Card and request.hero.hand.has(option):
            return true
    return false

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

## In a row: full-width cards when they fit, narrower (down to MIN_CARD_WIDTH) when the hand is
## large, as tall as the dock allows. In a stack: full width, sharing the height.
func _fit_cards() -> void:
    var shown: int = 0
    for view in _cards:
        if view.visible:
            shown += 1
    if shown == 0:
        return
    var gap: float = float(_row.get_theme_constant("separation"))
    var avail: Vector2 = _scroll.size - Vector2(4, 4)
    var card_size: Vector2
    if vertical_cards:
        var height: float = clampf((avail.y - gap * (shown - 1)) / shown, MIN_STACKED_HEIGHT, MAX_STACKED_HEIGHT)
        card_size = Vector2(maxf(avail.x - 12, MIN_CARD_WIDTH), height)
    else:
        var width: float = clampf((avail.x - gap * (shown - 1)) / shown, MIN_CARD_WIDTH, CARD_SIZE.x)
        card_size = Vector2(width, clampf(avail.y, CARD_SIZE.y - 20, MAX_CARD_HEIGHT))
    for view in _cards:
        view.custom_minimum_size = card_size
