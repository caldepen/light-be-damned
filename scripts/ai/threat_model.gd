class_name ThreatModel
extends RefCounted

## What the hero AI expects the enemies to do this round: each enemy's expected damage on its next
## card, who it will aim at (RULES §6 Who enemies attack), and how close that puts each hero to
## Down. Built fresh for each decision; reads the battle, changes nothing.
##
## "What if" questions move Provoke tokens or add Guard without touching the battle:
## party_danger(moves, extra_buffer).

## A hero's danger is (damage aimed at them / buffer)^2, capped so one hero can't swamp every other
## term. (Adding a cost per point expected past Guard and armor made the AI too timid in batches.)
const MAX_DANGER := 9.0

var battle: Battle
var _threat: Dictionary = {}  # EnemyState -> float
var _moves: Dictionary = {}   # HeroState -> Provoke value, in the order the tokens move

func _init(battle_in: Battle) -> void:
    battle = battle_in
    for e in battle.standing_enemies():
        _threat[e] = expected_hit(battle, e)

func threat_of(enemy: FigureState) -> float:
    return float(_threat.get(enemy, 0.0))

## Damage a hero can take before going Down: Guard, open armor slots and non-Wound cards in hand.
func buffer(hero: HeroState) -> float:
    var total: float = float(hero.guard_tokens + hero.unmarked_armor() + hero.non_wound_cards().size())
    if hero.statuses.has("ignore_next_attack"):
        total += _biggest_threat()
    return total

## Sum of every standing hero's danger, with the tokens in `moves` (HeroState -> Provoke value,
## moved in that order) and the Guard tokens in `extra_buffer` (HeroState -> int). Lower is safer.
func party_danger(moves: Dictionary = {}, extra_buffer: Dictionary = {}) -> float:
    _moves = moves
    var aimed: Dictionary = {}  # HeroState -> expected damage
    for e in _threat:
        var target: HeroState = _target_of(e)
        if target != null:
            aimed[target] = float(aimed.get(target, 0.0)) + float(_threat[e])
    _moves = {}
    var total: float = 0.0
    for h in aimed:
        var ratio: float = float(aimed[h]) / maxf(buffer(h) + float(extra_buffer.get(h, 0)), 1.0)
        total += minf(ratio * ratio, MAX_DANGER)
    return total

## Who an enemy goes after: ranged enemies the top hero; melee enemies the highest hero in reach,
## else the highest one free step away, else the top hero (it walks toward them or throws).
func _target_of(enemy: EnemyState) -> HeroState:
    var heroes: Array[HeroState] = battle.standing_heroes()
    if enemy.is_melee():
        for reach in [1, 2]:
            var near: Array[HeroState] = []
            for h in heroes:
                if Field.cells_distance(enemy.cells, h.cells) <= reach:
                    near.append(h)
            if not near.is_empty():
                return _highest(near)
    return _highest(heroes)

func _highest(heroes: Array[HeroState]) -> HeroState:
    var best: HeroState = null
    for h in heroes:
        if best == null or _is_above(h, best):
            best = h
    return best

## ProvokeTrack.is_above, with moved tokens where the question puts them: a token that moves lands
## on top of its new space, so of two that moved to the same space the later one is above.
func _is_above(a: HeroState, b: HeroState) -> bool:
    var va: int = _value(a)
    var vb: int = _value(b)
    if va != vb:
        return va > vb
    var ma: int = _move_order(a)
    var mb: int = _move_order(b)
    if ma != mb:
        return ma > mb
    return battle.provoke.is_above(a, b)

func _value(hero: HeroState) -> int:
    return int(_moves[hero]) if _moves.has(hero) else battle.provoke.value_of(hero)

## -1 for a token that stays put, else its place in the order of moves.
func _move_order(hero: HeroState) -> int:
    if not _moves.has(hero) or int(_moves[hero]) == battle.provoke.value_of(hero):
        return -1
    return _moves.keys().find(hero)

## Expected damage of the card this enemy plays next. It flips Draw (plus any DM extra) cards and
## plays the highest-valued one (DM, Bold, Desperate) or the lowest (Timid), valuing them as the
## enemy itself does (CardRunner.enemy_card_value). Flips are treated as draws with replacement
## from the full deck list; playability is ignored.
static func expected_hit(battle: Battle, enemy: EnemyState) -> float:
    var values: Array[float] = []
    var weights: Array[float] = []
    var total_weight: float = 0.0
    for card_def in enemy.def.get("deck", []):
        var qty: float = float(card_def.get("qty", 1))
        values.append(maxf(CardRunner.enemy_card_value(battle, enemy, card_def), 0.0))
        weights.append(qty)
        total_weight += qty
    if values.is_empty():
        return 0.0
    var order: Array = range(values.size())
    order.sort_custom(func(a: int, b: int) -> bool: return values[a] < values[b])
    var flips: int = enemy.draw_count + battle.dm_extra_flips()
    var lowest: bool = not battle.has_dm() and enemy.morale() == EnemyState.MORALE_TIMID
    var expected: float = 0.0
    var below: float = 0.0  # chance a single flip is below the current value
    for i in order:
        var at_or_below: float = below + weights[i] / total_weight
        if lowest:
            expected += values[i] * (pow(1.0 - below, flips) - pow(1.0 - at_or_below, flips))
        else:
            expected += values[i] * (pow(at_or_below, flips) - pow(below, flips))
        below = at_or_below
    return expected

func _biggest_threat() -> float:
    var best: float = 0.0
    for e in _threat:
        best = maxf(best, float(_threat[e]))
    return best
