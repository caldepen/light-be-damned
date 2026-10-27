class_name HandView
extends VBoxContainer

## One hero's hand as cards showing name, skill and effect text. On that hero's turn the legal
## cards can be selected (then Play); for a discard request the offered cards are chosen directly.
## Wounds are shown but never clickable.

signal card_selected(card_uid: int)
signal option_chosen(index: int)

const CARD_SIZE := Vector2(180, 150)

var _title := Label.new()
var _row := HBoxContainer.new()
var selected_uid: int = -1

func _init() -> void:
    add_child(_title)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, CARD_SIZE.y + 14)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.add_child(_row)
    add_child(scroll)

## `hero`: whose hand to show. With a TURN request the PLAY options are selectable; with a request
## whose options are cards in this hand, those cards answer it.
func refresh(hero: HeroState, request: DecisionRequest) -> void:
    for child in _row.get_children():
        child.queue_free()
    if hero == null:
        _title.text = "Hand"
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
    for card in hero.hand:
        var button := Button.new()
        button.custom_minimum_size = CARD_SIZE
        button.clip_contents = true
        var face := Label.new()
        face.text = UiText.card_face(card)
        face.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        face.vertical_alignment = VERTICAL_ALIGNMENT_TOP
        face.mouse_filter = Control.MOUSE_FILTER_IGNORE
        face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
        face.add_theme_font_size_override("font_size", 13)
        button.add_child(face)
        var clickable: bool = playable.has(card.uid) and not card.is_wound
        button.disabled = not clickable
        if card.is_wound:
            button.modulate = Color(0.9, 0.5, 0.5)
        elif card.uid == selected_uid:
            button.modulate = Color(1.4, 1.3, 0.5)
        elif not clickable:
            face.modulate = Color(0.6, 0.6, 0.6)
        if clickable:
            var uid: int = card.uid
            var index: int = playable[card.uid]
            if direct:
                button.pressed.connect(func() -> void: option_chosen.emit(index))
            else:
                button.pressed.connect(func() -> void: card_selected.emit(uid))
        _row.add_child(button)

func set_interactive(on: bool) -> void:
    if on:
        return
    for child in _row.get_children():
        (child as Button).disabled = true
