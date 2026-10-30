class_name CardRunner
extends RefCounted

## Runs a card's `effects` list through the effect handlers, and answers "can this card be played?".

const ATTACK_OPS: Array[String] = ["damage", "damage_choice", "consecrate"]
## A card's own Provoke resolves last, after the automatic +1 (RULES §6 Provoke, Order).
const PROVOKE_OPS: Array[String] = ["provoke", "provoke_halve"]
const ENEMY_ATTACK_OPS: Array[String] = ["attack", "attack_area", "splash", "throw_ally"]
## How an enemy plays a card with a melee attack (RULES §7 Targeting priority).
const PLAN_MELEE := "melee"      # step if needed, then hit the top hero (or, melee only, the best in reach)
const PLAN_THROW := "throw"      # the top hero is out of reach after the step: throw at them from here
const PLAN_ADVANCE := "advance"  # melee only, nobody in reach after the step: step, the turn ends

## The effects a hero card actually has: the wizard's signature uses the option chosen at camp.
static func effects_of(hero: HeroState, card: Card) -> Array:
    for e in card.effects:
        if String(e.get("op", "")) == "signature_choice":
            return hero.signature_option.get("effects", [])
    return card.effects

static func has_op(effects: Array, ops: Array[String]) -> bool:
    for e in effects:
        if ops.has(String(e.get("op", ""))):
            return true
    return false

## A hero may play a card from hand only if at least one of its effects has a legal use (RULES §5).
static func is_card_legal(battle: Battle, hero: HeroState, card: Card) -> bool:
    if card.is_wound:
        return false
    var effects: Array = effects_of(hero, card)
    var ctx := EffectContext.new(battle, hero, card.def, effects, card)
    ctx.dry_run = true
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        if battle.effects.handler(String(ctx.effect.get("op", ""))).is_legal(ctx):
            return true
    return false

static func legal_hand_cards(battle: Battle, hero: HeroState) -> Array[Card]:
    var result: Array[Card] = []
    for c in hero.hand:
        if is_card_legal(battle, hero, c):
            result.append(c)
    return result

## Resolve a hero card (already out of the hand): bonuses, the effects, the Provoke for points
## landed and healed (RULES §6), and finally the card's own Provoke effects.
static func resolve_hero_card(battle: Battle, hero: HeroState, card: Card) -> void:
    var effects: Array = effects_of(hero, card)
    var ctx := EffectContext.new(battle, hero, card.def, effects, card)
    var is_attack: bool = has_op(effects, ATTACK_OPS)
    var is_guard: bool = has_op(effects, ["guard"])
    if is_attack:
        ctx.damage_bonus += hero.status_damage_bonus()
    for buff in hero.buffs.duplicate():
        var applies_to: String = String(buff.get("applies_to", "attack"))
        var used: bool = false
        if is_attack and (applies_to == "attack" or applies_to == "damage_or_guard"):
            ctx.damage_bonus += int(buff["amount"])
            used = true
        elif is_guard and applies_to == "damage_or_guard":
            ctx.guard_bonus += int(buff["amount"])
            used = true
        if used:
            hero.buffs.erase(buff)
            battle.emit("buff_used", "%s's %s adds +%d to %s." % [hero.name, buff.get("source", "bonus"), int(buff["amount"]), card.name],
                {"hero": hero.id, "amount": int(buff["amount"]), "card": card.id})
    var main: Array = []
    var own_provoke: Array = []
    for e in effects:
        if PROVOKE_OPS.has(String(e.get("op", ""))):
            own_provoke.append(e)
        else:
            main.append(e)
    var outer_counter: HeroState = battle.point_counter
    var outer_points: int = battle.points_landed
    battle.point_counter = hero
    battle.points_landed = 0
    run_effects(ctx, main)
    var points: int = battle.points_landed
    battle.point_counter = outer_counter
    battle.points_landed = outer_points
    if ctx.earned_provoke:
        var rules: Dictionary = battle.rules.get("provoke", {})
        var gain: int = maxi(points * int(rules.get("per_point_landed_or_healed", 1)),
            int(rules.get("minimum_per_card_that_damages_or_heals", 1)))
        battle.move_provoke(hero, gain, "%s: %d point%s landed or healed" % [card.name, points, "" if points == 1 else "s"])
    run_effects(ctx, own_provoke)

## Run an effect list in order, skipping effects with no legal use.
static func run_effects(ctx: EffectContext, effects: Array) -> void:
    var saved_effects: Array = ctx.effects
    var saved_index: int = ctx.index
    ctx.effects = effects
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        var handler: EffectHandler = ctx.battle.effects.handler(String(ctx.effect.get("op", "")))
        if handler.is_legal(ctx):
            handler.resolve(ctx)
    ctx.effects = saved_effects
    ctx.index = saved_index

# ------------------------------------------------------------------ enemy cards

## Whether an enemy can play a flipped card (RULES §7, Playable enemy cards): ▲ cards once per
## battle per enemy; a melee attack always (at worst it steps and ends the turn); otherwise every
## effect that isn't a follow-up must have a legal use.
static func enemy_card_playable(battle: Battle, enemy: EnemyState, card_def: Dictionary) -> bool:
    if String(card_def.get("tag", "")) == "top" and enemy.used_top.has(String(card_def.get("id", ""))):
        return false
    if melee_plan(battle, enemy, card_def) == PLAN_ADVANCE:
        return true
    var effects: Array = card_def.get("effects", [])
    var ctx := EffectContext.new(battle, enemy, card_def, effects)
    ctx.dry_run = true
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        var handler: EffectHandler = battle.effects.handler(String(ctx.effect.get("op", "")))
        if handler.is_follow_up(ctx):
            continue
        if not handler.is_legal(ctx):
            return false
    return true

## Play an enemy card: a melee card first takes its free step (or, with nobody to reach and no
## throw, takes the step and ends the turn); then the effects run.
static func play_enemy_card(battle: Battle, enemy: EnemyState, card_def: Dictionary) -> void:
    match melee_plan(battle, enemy, card_def):
        PLAN_MELEE:
            var cells: Array[Vector2i] = EnemyMoves.melee_cells(battle, enemy)
            if cells != enemy.cells:
                battle.move_figure(enemy, cells, "free step")
        PLAN_ADVANCE:
            _mark_top_used(enemy, card_def)
            var step: Array[Vector2i] = EnemyMoves.free_step(battle, enemy)
            if not step.is_empty():
                battle.move_figure(enemy, step, "free step")
            battle.emit("advance", "%s can't reach anyone; its turn ends." % enemy.name, {"enemy": enemy.id, "card": card_def.get("id", "")})
            return
    resolve_enemy_card(battle, enemy, card_def)

static func resolve_enemy_card(battle: Battle, enemy: EnemyState, card_def: Dictionary) -> void:
    var effects: Array = card_def.get("effects", [])
    var ctx := EffectContext.new(battle, enemy, card_def, effects)
    if has_op(effects, ENEMY_ATTACK_OPS):
        ctx.damage_bonus = enemy.status_damage_bonus() - enemy.weaken_next
        if enemy.weaken_next > 0:
            battle.emit("weakened", "%s's attack is weakened by %d." % [enemy.name, enemy.weaken_next], {"enemy": enemy.id})
        enemy.weaken_next = 0
    _mark_top_used(enemy, card_def)
    run_effects(ctx, effects)

static func _mark_top_used(enemy: EnemyState, card_def: Dictionary) -> void:
    if String(card_def.get("tag", "")) == "top":
        enemy.used_top[String(card_def.get("id", ""))] = true

## PLAN_MELEE / PLAN_THROW / PLAN_ADVANCE for a card whose effects (with Flee's and Shriek's branch
## picked) hold a melee attack; "" for other cards and for cards with their own movement, which
## replaces the free step (RULES §5 Card movement).
static func melee_plan(battle: Battle, enemy: EnemyState, card_def: Dictionary) -> String:
    var effects: Array = card_def.get("effects", [])
    if has_op(effects, ["move"]):
        return ""
    var melee: bool = false
    var can_throw: bool = false
    for e in branch_effects(battle, enemy, effects):
        if is_melee_attack(e):
            melee = true
            can_throw = can_throw or e.has("throw")
    if not melee:
        return ""
    var cells: Array[Vector2i] = EnemyMoves.melee_cells(battle, enemy)
    if top_in_reach_from(battle, cells):
        return PLAN_MELEE
    if can_throw:
        return PLAN_THROW
    return PLAN_ADVANCE if battle.heroes_within_1_of(cells).is_empty() else PLAN_MELEE

static func top_in_reach_from(battle: Battle, cells: Array[Vector2i]) -> bool:
    var top: HeroState = battle.top_hero()
    return top != null and Field.cells_distance(cells, top.cells) <= 1

## Enemy attacks are melee unless marked Ranged (RULES §7): Melee X, and Stomp's every hero within 1.
static func is_melee_attack(e: Dictionary) -> bool:
    match String(e.get("op", "")):
        "attack":
            return e.has("melee")
        "attack_area":
            return String(e.get("area", "")) == "heroes_within_1" and String(e.get("range", "")) != "ranged"
    return false

## The effects a card will run now, with the branch of each Flee and Shriek picked.
static func branch_effects(battle: Battle, enemy: EnemyState, effects: Array) -> Array:
    var result: Array = []
    for e in effects:
        var taken: bool = true
        match String(e.get("op", "")):
            "flee_if":
                taken = condition_holds(enemy, String(e.get("condition", "")))
            "summon_if_last":
                taken = SummonIfLastEffect.will_summon(battle, enemy, e)
        if taken:
            result.append(e)
        else:
            result.append_array(branch_effects(battle, enemy, e.get("otherwise", [])))
    return result

## Damage value used for morale (RULES §7): a number from the data, or computed at play time
## when the data gives a formula (a String) or when a Melee · Throw card would have to throw.
## A melee card with nobody to reach deals nothing (it only steps).
static func enemy_card_value(battle: Battle, enemy: EnemyState, card_def: Dictionary) -> float:
    var value: Variant = card_def.get("ai_value", 0)
    var effects: Array = card_def.get("effects", [])
    var plan: String = melee_plan(battle, enemy, card_def)
    if plan == PLAN_ADVANCE:
        return 0.0
    if typeof(value) == TYPE_STRING or plan == PLAN_THROW:
        return estimate_enemy_damage(battle, enemy, effects)
    return float(value)

## Expected damage of an enemy effect list, for morale.
static func estimate_enemy_damage(battle: Battle, enemy: EnemyState, effects: Array) -> float:
    var total: float = 0.0
    var cells: Array[Vector2i] = EnemyMoves.melee_cells(battle, enemy)
    var in_reach: Array[HeroState] = battle.heroes_within_1_of(cells)
    var top_in_reach: bool = top_in_reach_from(battle, cells)
    for e in effects:
        match String(e.get("op", "")):
            "attack":
                if e.has("ranged"):
                    total += float(e["ranged"])
                elif e.has("melee") and (top_in_reach or (not e.has("throw") and not in_reach.is_empty())):
                    total += float(e["melee"]) + float(allies_of_type(battle, enemy, String(e.get("melee_bonus_per_ally", ""))))
                elif e.has("throw"):
                    total += float(e["throw"])
            "attack_area":
                total += float(e.get("amount", 0)) * float(in_reach.size())
            "splash":
                total += float(e.get("amount", 0))
            "flee_if":
                if condition_holds(enemy, String(e.get("condition", ""))):
                    total -= 1.0
                else:
                    total += estimate_enemy_damage(battle, enemy, e.get("otherwise", []))
            "summon_if_last":
                if not is_last_of_type(battle, enemy, String(e.get("type", ""))):
                    total += estimate_enemy_damage(battle, enemy, e.get("otherwise", []))
    return total

## Other standing enemies of `enemy_type` (Gang Up's bonus); 0 if no type is given.
static func allies_of_type(battle: Battle, enemy: EnemyState, enemy_type: String) -> int:
    if enemy_type.is_empty():
        return 0
    var n: int = 0
    for e in battle.standing_enemies():
        if e != enemy and e.enemy_type == enemy_type:
            n += 1
    return n

static func is_last_of_type(battle: Battle, enemy: EnemyState, enemy_type: String) -> bool:
    return allies_of_type(battle, enemy, enemy_type) == 0 and enemy.enemy_type == enemy_type

static func condition_holds(enemy: EnemyState, condition: String) -> bool:
    match condition:
        "hd_marked_at_least_half":
            return enemy.marked_hd * 2 >= enemy.hit_dice
    push_error("Unknown condition '%s'." % condition)
    return false
