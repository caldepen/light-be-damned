class_name SplashEffect
extends EffectHandler

## "splash": extra `amount` to one hero next to the previous target (Rampage): the highest-Provoke one.

func op_name() -> String:
    return "splash"

func is_follow_up(_ctx: EffectContext) -> bool:
    return true

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var target: HeroState = ctx.battle.provoke.top(candidates(ctx))
    var amount: int = maxi(0, ctx.amount() + ctx.damage_bonus)
    ctx.battle.emit("enemy_attack", "%s splashes %s for %d." % [ctx.actor.name, target.name, amount],
        {"enemy": ctx.actor.id, "target": target.id, "how": "splash", "amount": amount})
    ctx.battle.damage(target, amount, ctx.actor, true)

func candidates(ctx: EffectContext) -> Array[HeroState]:
    var result: Array[HeroState] = []
    if ctx.last_targets.is_empty():
        return result
    var first: FigureState = ctx.last_targets[0]
    if not first.standing:
        return result
    for h in ctx.battle.heroes_within_1_of(first.cells):
        if h != first:
            result.append(h)
    return result
