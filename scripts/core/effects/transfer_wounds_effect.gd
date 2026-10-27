class_name TransferWoundsEffect
extends EffectHandler

## "transfer_wounds": take up to `amount` Wounds from an ally's hand into yours (Lay on Hands).
## The ally draws replacements; the Wounds enter your hand as if from damage and can knock you Down (RULES §6).

func op_name() -> String:
    return "transfer_wounds"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var ally: HeroState = ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, candidates(ctx), ctx.card, {"purpose": "transfer", "amount": ctx.amount()})
    var moved: int = ctx.battle.heal_wounds(ally, ctx.amount(1), ctx.actor)
    ctx.battle.emit("transfer_wounds", "%s takes %d Wounds from %s." % [ctx.actor.name, moved, ally.name],
        {"hero": ctx.actor.id, "from": ally.id, "count": moved})
    for i in range(moved):
        ctx.battle.add_wound(ctx.hero, "transfer")
    ctx.set_targets([ally])
    ctx.earned_provoke = true

func candidates(ctx: EffectContext) -> Array:
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if h != ctx.actor and h.wound_count() > 0:
            result.append(h)
    return result
