class_name HutDeck
extends RefCounted

## The Hut deck for one run (RULES §10): drawn in every room. Shuffled at the start of the run; it
## reshuffles its discards when empty. draw() takes the last card.

var _defs: Array = []                 # the card list from the module
var _draw: Array[Dictionary] = []
var _discard: Array[Dictionary] = []

func _init(cards: Array, rng: SeededRng) -> void:
    _defs = cards
    for card in cards:
        for i in range(int(card.get("qty", 1))):
            _draw.append(card)
    rng.shuffle(_draw)

func draw(rng: SeededRng) -> Dictionary:
    if _draw.is_empty():
        _draw.append_array(_discard)
        _discard.clear()
        rng.shuffle(_draw)
    return {} if _draw.is_empty() else _draw.pop_back()

func discard(card: Dictionary) -> void:
    _discard.append(card)

func size() -> int:
    return _draw.size()

## The card definition with this id.
func card(card_id: String) -> Dictionary:
    for c in _defs:
        if String(c.get("id", "")) == card_id:
            return c
    return {}

## Put a card on top of the deck (tests and scripted runs).
func stack(card_id: String) -> void:
    _draw.append(card(card_id))
