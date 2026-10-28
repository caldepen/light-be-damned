class_name CardScorer
extends RefCounted

## Heuristic value of playing a card now, read from its effects (ported loosely from
## reference/sim.py `choose`). Higher is better; below FLIP_THRESHOLD the AI would rather flip.
## An instance so that TacticalScorer can override the Provoke and healing parts.

const KILL_BONUS := 3.0
const PER_WOUND_HEALED := 3.0

## The party's tank: the hero with the most armor slots (the fighter, with Chainmail and Shield).
static func tank(battle: Battle) -> HeroState:
    var best: HeroState = null
    for h in battle.standing_heroes():
        if best == null or h.armor_slots > best.armor_slots:
            best = h
    return best

func score(battle: Battle, hero: HeroState, card: Card) -> float:
    var effects: Array = CardRunner.effects_of(hero, card)
    var bonus: int = _expected_bonus(hero, effects)
    var is_top: bool = battle.top_hero() == hero
    var is_tank: bool = tank(battle) == hero
    var total: float = 0.0
    var ctx := EffectContext.new(battle, hero, card.def, effects, card)
    ctx.dry_run = true
    ctx.damage_bonus = bonus
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        var e: Dictionary = effects[i]
        var op: String = String(e.get("op", ""))
        var handler: EffectHandler = battle.effects.handler(op)
        if not handler.is_follow_up(ctx) and not handler.is_legal(ctx):
            continue
        match op:
            "damage":
                total += _damage_score(battle, ctx, handler as DamageEffect)
            "damage_choice":
                total += float(2 + bonus) + 0.5
            "bleed":
                total += 1.5
            "stun":
                total += 1.5 * maxf(1.0, float((handler as StunEffect).targets(ctx).size()))
            "guard":
                total += _guard_score(battle, hero, e, is_top)
            "provoke", "provoke_halve":
                total += _provoke_score(e, is_top, is_tank)
            "heal_wound":
                total += _heal_score(battle, ctx, e, handler as HealWoundEffect)
            "cleanse":
                var most: int = _most_wounds(battle)
                total += PER_WOUND_HEALED * mini(int(e.get("amount", 1)), most) if most > 0 else 1.0
            "repair_armor":
                total += 0.7
            "transfer_wounds":
                total += PER_WOUND_HEALED * 1.5 if hero.non_wound_cards().size() > int(e.get("amount", 2)) + 2 else -10.0
            "consecrate":
                total += 4.0
            "draw":
                total += 1.2 * float(e.get("amount", 1))
            "status":
                total += _status_score(battle, hero, String(e.get("name", "")), is_top)
            "buff_next":
                total += 1.5
            "weaken_next_attack":
                total += 0.5
            "peek":
                total += 0.1
            "recover":
                total += 0.8 if hero.deck.size() < 8 else 0.1
            "move":
                var mode: String = String(e.get("mode", ""))
                if mode == "teleport_own_board":
                    total += 2.0 if (is_top and not is_tank) else 0.2
    return total

## The card's own Provoke effects: the tank wants to climb, everyone else to drop.
func _provoke_score(e: Dictionary, is_top: bool, is_tank: bool) -> float:
    if String(e.get("op", "")) == "provoke_halve":
        return 0.5 if not is_tank else -1.0
    if int(e.get("amount", 0)) > 0:
        return (0.8 if is_top else 4.0) if is_tank else -1.0
    return 2.5 if (is_top and not is_tank) else -0.5

## A rough worth of holding a card, used to pick what to discard (low = discard first).
static func keep_value(card: Card) -> float:
    var value: float = 0.0
    for e in card.effects:
        match String(e.get("op", "")):
            "damage", "damage_choice", "consecrate":
                value += 2.0 + float(e.get("amount", 2))
            "heal_wound", "cleanse", "transfer_wounds":
                value += 3.0
            "guard":
                value += float(e.get("amount", 1))
            "signature_choice":
                value += 5.0
    if card.tier == "top" or card.tier == "signature":
        value += 2.0
    return value

static func _expected_bonus(hero: HeroState, effects: Array) -> int:
    if not CardRunner.has_op(effects, CardRunner.ATTACK_OPS):
        return 0
    var bonus: int = hero.status_damage_bonus()
    for buff in hero.buffs:
        bonus += int(buff.get("amount", 0))
    return bonus

static func _damage_score(battle: Battle, ctx: EffectContext, handler: DamageEffect) -> float:
    var per_hit: int = ctx.amount() + ctx.damage_bonus
    match ctx.area():
        "single":
            var best: float = 0.0
            for e in handler.single_targets(ctx):
                var dmg: int = DamageEffect.hit_amount(ctx, e)
                best = maxf(best, float(dmg) + (KILL_BONUS if dmg >= battle.toughness(e) else 0.0))
            return best
        "adjacent":
            var most: int = 0
            for pos in handler.adjacent_positions(ctx):
                most = maxi(most, battle.enemies_within_1_of([pos]).size())
            return float(most * per_hit)
        "row":
            if String(ctx.effect.get("row", "")) == "enemy_front":
                return float(battle.enemies_in_cells(Battle.row_cells(battle.enemy_front_row_y())).size() * per_hit)
            var most_row: int = 0
            for y in handler.row_options(ctx):
                most_row = maxi(most_row, battle.enemies_in_cells(Battle.row_cells(y)).size())
            return float(most_row * per_hit)
        "area2x2":
            var most_block: int = 0
            for corner in handler.area_options(ctx):
                most_block = maxi(most_block, battle.enemies_in_cells(Field.block_cells(corner)).size())
            return float(most_block * per_hit) - (2.0 if most_block < 2 else 0.0)
        "chain", "split":
            var hits: int = int(ctx.effect.get("bolts", 0))
            if hits == 0:
                hits = mini(int(ctx.effect.get("targets", 1)), battle.standing_enemies().size())
            return float(hits * per_hit)
    return float(per_hit)

func _guard_score(battle: Battle, hero: HeroState, e: Dictionary, is_top: bool) -> float:
    var amount: float = float(e.get("amount", 1))
    match String(e.get("target", "self")):
        "self":
            return (amount * 0.9 if is_top else 0.4) - (1.0 if hero.guard_tokens > 0 else 0.0)
        "all_heroes":
            return 0.5 * amount * float(battle.standing_heroes().size())
    return amount * 0.9

func _heal_score(_battle: Battle, ctx: EffectContext, e: Dictionary, handler: HealWoundEffect) -> float:
    var amount: int = int(e.get("amount", 1))
    var target_kind: String = String(e.get("target", "hero_any"))
    var best: int = 0
    var total: int = 0
    for h in handler.candidates(ctx):
        var healed: int = mini(amount, h.wound_count())
        best = maxi(best, healed)
        total += healed
    if target_kind == "all_heroes" or target_kind == "heroes_within_1":
        return PER_WOUND_HEALED * float(total)
    return PER_WOUND_HEALED * float(best)

static func _status_score(battle: Battle, hero: HeroState, status_name: String, is_top: bool) -> float:
    match status_name:
        "berserk":
            return 3.5
        "thorns":
            return 3.0 if is_top else 1.0
        "ignore_next_attack":
            return 2.5 if is_top else 0.8
        "lightning_orb":
            return 1.0 + float(battle.enemies_within_1_of(hero.cells).size())
    return 0.0

static func _most_wounds(battle: Battle) -> int:
    var most: int = 0
    for h in battle.standing_heroes():
        most = maxi(most, h.wound_count())
    return most
