class_name EffectContext
extends RefCounted

## Everything an effect handler needs while one card resolves. Effects run in list order and
## share this context, so `"area": "same"` effects can reuse `last_targets`.

var battle: Battle
var actor: FigureState
var card: Card = null          # hero card being played; null for enemy cards
var card_def: Dictionary = {}  # the card object from the data (hero or enemy)
var effects: Array = []        # the effect list being run
var effect: Dictionary = {}    # the effect being checked or resolved
var index: int = 0             # position of `effect` in `effects`

## True while checking whether a card has a legal effect: handlers must not change anything.
var dry_run: bool = false

var last_targets: Array[FigureState] = []
## Set by "move to melee reach of X" so the following damage hits X.
var planned_target: FigureState = null
## A card's own movement replaces the free step (RULES §5), so once set, melee needs reach as is.
var moved_by_card: bool = false
## Set when a damage, heal or repair effect lands on a legal target (RULES §6 Provoke).
var earned_provoke: bool = false
## Added to every damage instance this card deals (Berserk, Bless, Feint, Arcane Surge, Rage, Frost Ray).
var damage_bonus: int = 0
## Added to every Guard grant on this card (Bless).
var guard_bonus: int = 0

var hero: HeroState:
    get:
        return actor as HeroState

var enemy: EnemyState:
    get:
        return actor as EnemyState

var card_name: String:
    get:
        return String(card_def.get("name", "?"))

func _init(battle_in: Battle, actor_in: FigureState, def_in: Dictionary, effect_list: Array, card_in: Card = null) -> void:
    battle = battle_in
    actor = actor_in
    card_def = def_in
    effects = effect_list
    card = card_in

func amount(default_value: int = 0) -> int:
    return int(effect.get("amount", default_value))

func area() -> String:
    return String(effect.get("area", "single"))

## Only effects marked "range": "melee" need reach; enemy-front-row cards carry no range (RULES §6).
func is_melee() -> bool:
    return String(effect.get("range", "")) == "melee"

## The first movement effect on this card before the current one, or {}.
func earlier_move() -> Dictionary:
    for i in range(index):
        var e: Dictionary = effects[i]
        if String(e.get("op", "")) == "move":
            return e
    return {}

func set_targets(targets: Array) -> void:
    last_targets.clear()
    for t in targets:
        last_targets.append(t)

func standing_last_targets() -> Array[FigureState]:
    var result: Array[FigureState] = []
    for t in last_targets:
        if t.standing:
            result.append(t)
    return result
