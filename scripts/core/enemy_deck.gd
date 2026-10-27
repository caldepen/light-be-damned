class_name EnemyDeck
extends RefCounted

## The shared action deck for one enemy type (RULES §7). The top card is at the back of `draw_pile`.
## When it runs out, the discards are shuffled into a new deck.

var enemy_type: String = ""
var draw_pile: Array[Dictionary] = []
var discard_pile: Array[Dictionary] = []
## Set by flip() when it had to reshuffle, so the battle can log it.
var reshuffled_on_last_flip: bool = false

func _init(type_id: String, card_defs: Array, rng: SeededRng) -> void:
    enemy_type = type_id
    for card_def in card_defs:
        for i in range(int(card_def.get("qty", 1))):
            draw_pile.append(card_def)
    rng.shuffle(draw_pile)

## Flip the top card. Returns {} only if the deck and discards are both empty.
func flip(rng: SeededRng) -> Dictionary:
    reshuffled_on_last_flip = false
    if draw_pile.is_empty():
        if discard_pile.is_empty():
            return {}
        draw_pile = discard_pile.duplicate()
        discard_pile.clear()
        rng.shuffle(draw_pile)
        reshuffled_on_last_flip = true
    return draw_pile.pop_back()

func discard(card_def: Dictionary) -> void:
    discard_pile.append(card_def)

## The top `count` cards, top first, without removing them.
func peek(count: int) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(mini(count, draw_pile.size())):
        result.append(draw_pile[draw_pile.size() - 1 - i])
    return result

## Replace the top cards with `top_first` (same cards, new order).
func reorder_top(top_first: Array[Dictionary]) -> void:
    for i in range(top_first.size()):
        draw_pile.pop_back()
    for i in range(top_first.size() - 1, -1, -1):
        draw_pile.append(top_first[i])
