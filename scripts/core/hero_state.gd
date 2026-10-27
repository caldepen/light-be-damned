class_name HeroState
extends FigureState

## A hero: their deck, hand and piles. Index 0 of `deck` is the bottom; the top card is at the back.

var hero_id: String = ""
var hero_type: String = ""
var hand_size: int = 0

var deck: Array[Card] = []
var hand: Array[Card] = []
var discard: Array[Card] = []
var exhausted: Array[Card] = []

## Cards owed from Disarm and similar, drawn at the start of the hero's next turn.
var owed_draws: int = 0
## Pending "next card gets +X" bonuses: {"amount": int, "applies_to": "attack"|"damage_or_guard", "source": String}.
var buffs: Array[Dictionary] = []
## Turns left as a toad (Polymorph).
var toad_turns: int = 0
## The wizard's chosen signature option, as a card-like object; empty if none.
var signature_option: Dictionary = {}

func _init() -> void:
    side = FigureState.SIDE_HEROES

func wound_count() -> int:
    var n: int = 0
    for c in hand:
        if c.is_wound:
            n += 1
    return n

func non_wound_cards() -> Array[Card]:
    var result: Array[Card] = []
    for c in hand:
        if not c.is_wound:
            result.append(c)
    return result

func hand_is_all_wounds() -> bool:
    return not hand.is_empty() and wound_count() == hand.size()

## Down when the hand holds nothing but Wounds, or hand and deck are both empty (RULES §6).
func is_spent() -> bool:
    return hand_is_all_wounds() or (hand.is_empty() and deck.is_empty())

## Whether discarding `card` from the hand would leave the hero spent (enemy discards never do, RULES §7).
func spent_without(card: Card) -> bool:
    var rest: int = hand.size() - 1
    if rest == 0:
        return deck.is_empty()
    return not card.is_wound and wound_count() == rest

func power() -> int:
    return unmarked_armor() + non_wound_cards().size()
