class_name DecisionRequest
extends RefCounted

## A choice the engine needs from a hero's player (or the party, for NEXT_HERO). The engine always lists the legal
## `options`; the provider returns the index of one. See DecisionProvider for the kinds.

const NEXT_HERO := "next_hero"             # options: HeroState (who acts next; asked of the party, hero is null)
const TURN := "turn"                       # options: TurnOption
const TARGET := "target"                   # options: FigureState (who an effect hits)
const FREE_STEP := "free_step"             # options: Vector2i (where to step before a melee attack)
const MELEE_POSITION := "melee_position"   # options: Vector2i (stay or step, for Adjacent attacks)
const MOVE_SQUARE := "move_square"         # options: Vector2i
const MOVE_TARGET := "move_target"         # options: EnemyState (who to move into reach of)
const OPTIONAL_MOVE := "optional_move"     # options: [false, true]
const ROW := "row"                         # options: int (grid y of the row)
const AREA := "area"                       # options: Vector2i (top-left of a 2x2 block)
const DAMAGE_OPTION := "damage_option"     # options: Dictionary {"amount": int, "targets": Array[FigureState]}
const WOUND_DISCARD := "wound_discard"     # options: Card (discarded to make room for a Wound)
const FORCED_DISCARD := "forced_discard"   # options: Card (Roar)
const CLEANSE_SPLIT := "cleanse_split"     # options: int (how many of the points remove Wounds; the rest repair armor)
const RECOVER_CARD := "recover_card"       # options: Card, or null to stop
const PEEK_TYPE := "peek_type"             # options: String (enemy type)
const PEEK_ORDER := "peek_order"           # options: Array[Dictionary] (the peeked cards in a new order, top first)
const SIGNATURE_OPTION := "signature_option"  # options: Dictionary (card-like option)

var kind: String = ""
var hero: HeroState = null
var card: Card = null
var options: Array = []
var details: Dictionary = {}

func _init(request_kind: String, deciding_hero: HeroState, choices: Array, for_card: Card = null, extra: Dictionary = {}) -> void:
    kind = request_kind
    hero = deciding_hero
    options = choices
    card = for_card
    details = extra
