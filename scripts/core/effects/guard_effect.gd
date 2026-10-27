class_name GuardEffect
extends EffectHandler

## "guard": add Guard tokens (RULES §6 Guard). `target`: self, ally (another hero), hero_any, all_heroes.
## Bless adds its bonus to each hero that gains Guard from the card.

func op_name() -> String:
    return "guard"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var amount: int = ctx.amount() + ctx.guard_bonus
    var target_kind: String = String(ctx.effect.get("target", "self"))
    var recipients: Array = candidates(ctx)
    if target_kind == "ally" or target_kind == "hero_any":
        recipients = [ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, recipients, ctx.card, {"purpose": "guard", "amount": amount})]
    for f in recipients:
        ctx.battle.add_guard(f, amount, ctx.actor)
    ctx.set_targets(recipients)

func candidates(ctx: EffectContext) -> Array:
    var target_kind: String = String(ctx.effect.get("target", "self"))
    if target_kind == "self" or not ctx.actor.is_hero():
        return [ctx.actor]
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if target_kind == "ally" and h == ctx.actor:
            continue
        result.append(h)
    return result
