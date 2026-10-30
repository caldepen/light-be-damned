class_name AttackEffect
extends EffectHandler

## "attack": an enemy attack (RULES §6 Who enemies attack, §12 goblins).
## `melee` X hits the highest-Provoke hero in reach; with `throw` Y it throws at the top-Provoke hero
## when nobody is in reach. `ranged` X targets `target` (top_provoke or lowest_provoke).
## `melee_bonus_per_ally`: +1 per other standing enemy of that type (Gang Up).

func op_name() -> String:
    return "attack"

func is_legal(ctx: EffectContext) -> bool:
    if ctx.effect.has("ranged") or ctx.effect.has("throw"):
        return not ctx.battle.standing_heroes().is_empty()
    return not ctx.battle.heroes_within_1_of(AttackEffect.reach_cells(ctx)).is_empty()

## Where a melee attack reaches from. While checking playability: after the card's own move, or
## else after the free step (RULES §5); once playing, the enemy has already moved.
static func reach_cells(ctx: EffectContext) -> Array[Vector2i]:
    if not ctx.dry_run:
        return ctx.actor.cells
    var move: Dictionary = ctx.earlier_move()
    if not move.is_empty():
        return EnemyMoves.preview(ctx.battle, ctx.enemy, move)
    return EnemyMoves.melee_cells(ctx.battle, ctx.enemy)

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var target: HeroState = null
    var amount: int = 0
    var how: String = ""
    if ctx.effect.has("ranged"):
        how = "ranged"
        amount = int(ctx.effect["ranged"])
        if String(ctx.effect.get("target", "top_provoke")) == "lowest_provoke":
            target = battle.provoke.bottom(battle.standing_heroes())
        else:
            target = battle.top_hero()
    else:
        # RULES §7 Targeting priority: a Melee · Throw card hits the top hero in melee or throws at them.
        var in_reach: Array[HeroState] = battle.heroes_within_1_of(ctx.actor.cells)
        var melee_ok: bool = not in_reach.is_empty()
        if ctx.effect.has("throw"):
            melee_ok = in_reach.has(battle.top_hero())
        if ctx.effect.has("melee") and melee_ok:
            how = "melee"
            target = battle.provoke.top(in_reach)
            amount = int(ctx.effect["melee"]) + CardRunner.allies_of_type(battle, ctx.enemy, String(ctx.effect.get("melee_bonus_per_ally", "")))
        elif ctx.effect.has("throw"):
            how = "throw"
            target = battle.top_hero()
            amount = int(ctx.effect["throw"])
    if target == null:
        return
    amount = maxi(0, amount + ctx.damage_bonus)
    battle.emit("enemy_attack", "%s %s attack on %s for %d." % [ctx.actor.name, how, target.name, amount],
        {"enemy": ctx.actor.id, "target": target.id, "how": how, "amount": amount})
    battle.damage(target, amount, ctx.actor, true)
    ctx.set_targets([target])
