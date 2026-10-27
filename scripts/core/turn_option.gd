class_name TurnOption
extends RefCounted

## One legal way to spend a hero's turn: play a card from hand, flip the top of the deck, or pass.

const PLAY := "play"
const FLIP := "flip"
const PASS := "pass"

var kind: String = PASS
var card: Card = null

func _init(option_kind: String, option_card: Card = null) -> void:
    kind = option_kind
    card = option_card

func _to_string() -> String:
    if kind == PLAY:
        return "play %s" % card.name
    return kind
