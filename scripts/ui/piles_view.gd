class_name PilesView
extends ScrollContainer

## The right column's deck and muck area: each hero's deck, discard and Exhausted piles, then each
## enemy type's action deck and discards. Hovering a pile lists its cards where that is public
## (discards and Exhausted cards are face up at the table; decks are not).

var _box := VBoxContainer.new()
var _rows: Dictionary = {}  # row key -> Array[DeckPile]
var _names: Dictionary = {} # row key -> Label

func _init() -> void:
    horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    _box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _box.add_theme_constant_override("separation", 4)
    add_child(_box)

func refresh(battle: Battle) -> void:
    if battle == null:
        return
    var keys: Dictionary = {}
    for h in battle.heroes:
        var key: String = "hero:" + h.id
        keys[key] = true
        var piles: Array = _row(key, 3)
        var name: String = h.name + ("  (Down)" if h.down else "")
        _set_name(key, name, UiText.figure_color(h).lightened(0.35))
        (piles[0] as DeckPile).show_pile("Deck", h.deck.size())
        (piles[1] as DeckPile).show_pile("Discard", h.discard.size(), _card_names(h.discard))
        (piles[2] as DeckPile).show_pile("Exhausted", h.exhausted.size(), _card_names(h.exhausted))
    for enemy_type in battle.enemy_decks:
        var key: String = "enemy:" + String(enemy_type)
        keys[key] = true
        var deck: EnemyDeck = battle.enemy_decks[enemy_type]
        var piles: Array = _row(key, 2)
        _set_name(key, "%s deck" % String(enemy_type).capitalize(), Color(0.95, 0.85, 0.75))
        (piles[0] as DeckPile).show_pile("Deck", deck.draw_pile.size())
        (piles[1] as DeckPile).show_pile("Discard", deck.discard_pile.size())
    for key in _rows.keys():
        if not keys.has(key):
            (_names[key] as Label).get_parent().queue_free()
            _rows.erase(key)
            _names.erase(key)

## Start over (a new battle may have different enemy types).
func reset() -> void:
    for child in _box.get_children():
        child.queue_free()
    _rows.clear()
    _names.clear()

func _row(key: String, count: int) -> Array:
    if _rows.has(key):
        return _rows[key]
    var line := HBoxContainer.new()
    var name := Label.new()
    name.custom_minimum_size = Vector2(110, 0)
    name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    line.add_child(name)
    var piles: Array = []
    for i in range(count):
        var pile: DeckPile = UiScenes.deck_pile()
        line.add_child(pile)
        piles.append(pile)
    _box.add_child(line)
    _rows[key] = piles
    _names[key] = name
    return piles

func _set_name(key: String, text: String, color: Color) -> void:
    var label: Label = _names[key]
    label.text = text
    label.add_theme_color_override("font_color", color)

func _card_names(cards: Array[Card]) -> String:
    var names: PackedStringArray = []
    for c in cards:
        names.append(c.name)
    return ", ".join(names)
