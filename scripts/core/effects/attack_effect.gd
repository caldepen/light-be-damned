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
    var cells: Array[Vector2i] = ctx.actor.cells
    var move: Dictionary = ctx.earlier_move()
    if ctx.dry_run and not move.is_empty():
        cells = EnemyMoves.preview(ctx.battle, ctx.enemy, move)
    return not ctx.battle.heroes_within_1_of(cells).is_empty()

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
        var in_reach: Array[HeroState] = battle.heroes_within_1_of(ctx.actor.cells)
        if ctx.effect.has("melee") and not in_reach.is_empty():
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
