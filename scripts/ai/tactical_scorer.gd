class_name TacticalScorer
extends CardScorer

## CardScorer plus a look at who the enemies will hit (ThreatModel). It predicts where a play
## leaves the hero's Provoke token (points landed or healed, then the card's own Provoke, RULES §6)
## and values the change in the party's danger: putting a fragile hero in the line of fire costs,
## handing it to a sturdier hero pays. Guard is valued by the danger it takes off, and healing goes
## to whoever is closest to Down. Call prepare() before scoring in a new battle state.

## Score per point of drop in ThreatModel.party_danger. Tuned by batch: 1, 2 and 4 all beat
## SimpleAiProvider, 4 by the most; a bonus for the tank's lead over the next hero did not help.
const DANGER_WEIGHT := 4.0

var threat: ThreatModel
## Provoke moves to take as already made (HeroState -> value), for looking one hero turn ahead.
var assumed_moves: Dictionary = {}:
    set(value):
        assumed_moves = value
        _base_danger = -1.0

var _base_danger: float = -1.0  # party_danger(assumed_moves), worked out when first needed
var _card_cache: Dictionary = {}  # card uid -> [effects score, projected Provoke]

## Start scoring a new battle state: what `threat` expects, nothing cached, no moves assumed.
func prepare(threat_in: ThreatModel) -> void:
    threat = threat_in
    _card_cache.clear()
    assumed_moves = {}

func score(battle: Battle, hero: HeroState, card: Card) -> float:
    var parts: Dictionary = evaluate(battle, hero, card)
    return float(parts["effects"]) + float(parts["track"])

## A play in parts: "effects" (what the card does), "track" (what its Provoke change is worth)
## and "provoke" (where it leaves the hero's token). Only "track" depends on assumed_moves, so the
## rest is cached until the next prepare() (Guard cards keep the value worked out under the moves
## assumed when first scored, a small approximation).
func evaluate(battle: Battle, hero: HeroState, card: Card) -> Dictionary:
    if not _card_cache.has(card.uid):
        _card_cache[card.uid] = [super.score(battle, hero, card), projected_provoke(battle, hero, card)]
    var cached: Array = _card_cache[card.uid]
    var provoke: int = cached[1]
    return {"effects": cached[0], "track": track_value(battle, hero, provoke), "provoke": provoke}

## Provoke is valued as a whole in track_value, not effect by effect.
func _provoke_score(_e: Dictionary, _is_top: bool, _is_tank: bool) -> float:
    return 0.0

## Each Wound removed is worth more the fuller of Wounds the hero's hand is, and more on the top hero.
func _heal_score(battle: Battle, ctx: EffectContext, e: Dictionary, handler: HealWoundEffect) -> float:
    var amount: int = int(e.get("amount", 1))
    var target_kind: String = String(e.get("target", "hero_any"))
    var best: float = 0.0
    var total: float = 0.0
    for h in handler.candidates(ctx):
        var value: float = heal_value(battle, h, mini(amount, h.wound_count()))
        best = maxf(best, value)
        total += value
    if target_kind == "all_heroes" or target_kind == "heroes_within_1":
        return total
    return best

static func heal_value(battle: Battle, hero: HeroState, wounds_removed: int) -> float:
    if wounds_removed <= 0:
        return 0.0
    var urgency: float = 2.0 * float(hero.wound_count()) / maxf(float(hero.hand_size), 1.0)
    var on_top: float = 2.0 if battle.top_hero() == hero else 0.0
    return PER_WOUND_HEALED * float(wounds_removed) * (1.0 + urgency) + on_top

## Guard tokens are worth the danger they take off: on yourself, on everyone, or on the ally
## who gains most (how TacticalAiProvider picks the ally).
func _guard_score(battle: Battle, hero: HeroState, e: Dictionary, _is_top: bool) -> float:
    var amount: int = int(e.get("amount", 1))
    match String(e.get("target", "self")):
        "self":
            return guard_value({hero: amount})
        "all_heroes":
            var all: Dictionary = {}
            for h in battle.standing_heroes():
                all[h] = amount
            return guard_value(all)
    var best: float = 0.0
    for h in battle.standing_heroes():
        if h != hero or String(e.get("target", "")) == "hero_any":
            best = maxf(best, guard_value({h: amount}))
    return best

func guard_value(tokens: Dictionary) -> float:
    return DANGER_WEIGHT * (_danger_now() - threat.party_danger(assumed_moves, tokens))

## Value of moving `hero`'s token to `new_value`: the drop in the party's danger.
func track_value(battle: Battle, hero: HeroState, new_value: int) -> float:
    if new_value == battle.provoke.value_of(hero):
        return 0.0
    var moves: Dictionary = assumed_moves.duplicate()
    moves.erase(hero)
    moves[hero] = new_value
    return DANGER_WEIGHT * (_danger_now() - threat.party_danger(moves))

func _danger_now() -> float:
    if _base_danger < 0.0:
        _base_danger = threat.party_danger(assumed_moves)
    return _base_danger

## Where the hero's token would be after playing `card`: points it should land or heal (at least
## 1 if it damages or heals anything), then its own Provoke effects in order.
func projected_provoke(battle: Battle, hero: HeroState, card: Card) -> int:
    var effects: Array = CardRunner.effects_of(hero, card)
    var ctx := EffectContext.new(battle, hero, card.def, effects, card)
    ctx.dry_run = true
    ctx.damage_bonus = CardScorer._expected_bonus(hero, effects)
    var points: int = 0
    var earns: bool = false
    var own: Array = []
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        var e: Dictionary = effects[i]
        var op: String = String(e.get("op", ""))
        if CardRunner.PROVOKE_OPS.has(op):
            own.append(e)
            continue
        var handler: EffectHandler = battle.effects.handler(op)
        if not handler.is_follow_up(ctx) and not handler.is_legal(ctx):
            continue
        var p: int = _points(battle, ctx, handler)
        if p >= 0:
            earns = true
            points += p
    var track_max: int = battle.provoke.track_max
    var value: int = battle.provoke.value_of(hero)
    if earns:
        value = mini(value + maxi(points, 1), track_max)
    for e in own:
        if String(e.get("op", "")) == "provoke_halve":
            value = ceili(value / 2.0) if String(e.get("rounding", "up")) == "up" else floori(value / 2.0)
        else:
            value = clampi(value + int(e.get("amount", 0)), 0, track_max)
    return value

## Points an effect should land or heal; -1 for effects that never earn Provoke.
func _points(battle: Battle, ctx: EffectContext, handler: EffectHandler) -> int:
    var e: Dictionary = ctx.effect
    match String(e.get("op", "")):
        "damage":
            if ctx.area() == "single":
                var best: int = 0
                for t in (handler as DamageEffect).single_targets(ctx):
                    var enemy: EnemyState = t
                    best = maxi(best, mini(DamageEffect.hit_amount(ctx, enemy), enemy.unmarked_armor() + enemy.unmarked_hd()))
                return best
            return maxi(int(CardScorer._damage_score(battle, ctx, handler as DamageEffect)), 0)
        "damage_choice":
            return 2 + ctx.damage_bonus
        "consecrate":
            return int(e.get("enemy_damage", 2))
        "heal_wound":
            var amount: int = int(e.get("amount", 1))
            var healed: int = 0
            for h in (handler as HealWoundEffect).candidates(ctx):
                healed = maxi(healed, mini(amount, h.wound_count()))
            return healed
        "cleanse", "transfer_wounds":
            return int(e.get("amount", 1))
        "repair_armor":
            return 1
    return -1
