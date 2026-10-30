class_name RoomDecks
extends RefCounted

## The room decks for one run (RULES §10): Lair, Dark, Vault, Library. Each is shuffled at the
## start of the run and reshuffles its discards when empty. draw() takes the last card.

var _defs: Dictionary = {}     # deck name -> card list from the module
var _draw: Dictionary = {}     # deck name -> Array[Dictionary]
var _discard: Dictionary = {}  # deck name -> Array[Dictionary]

func _init(decks: Dictionary, rng: SeededRng) -> void:
    for deck_name in decks:
        _defs[deck_name] = decks[deck_name]
        var cards: Array[Dictionary] = []
        for card in decks[deck_name]:
            for i in range(int(card.get("qty", 1))):
                cards.append(card)
        rng.shuffle(cards)
        _draw[deck_name] = cards
        var empty: Array[Dictionary] = []
        _discard[deck_name] = empty

func draw(deck_name: String, rng: SeededRng) -> Dictionary:
    var pile: Array[Dictionary] = _draw[deck_name]
    if pile.is_empty():
        pile.append_array(_discard[deck_name])
        (_discard[deck_name] as Array[Dictionary]).clear()
        rng.shuffle(pile)
    return {} if pile.is_empty() else pile.pop_back()

func discard(deck_name: String, card: Dictionary) -> void:
    (_discard[deck_name] as Array[Dictionary]).append(card)

func size(deck_name: String) -> int:
    return (_draw[deck_name] as Array).size()

## The card definition with this id (a card held for a room the party will come back to).
func card(deck_name: String, card_id: String) -> Dictionary:
    for c in _defs.get(deck_name, []):
        if String(c.get("id", "")) == card_id:
            return c
    return {}

## Put a card on top of its deck (tests and scripted runs).
func stack(deck_name: String, card_id: String) -> void:
    (_draw[deck_name] as Array[Dictionary]).append(card(deck_name, card_id))
