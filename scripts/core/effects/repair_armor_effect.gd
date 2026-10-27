class_name RepairArmorEffect
extends EffectHandler

## "repair_armor": remove armor and shield damage. `amount` is a number or "all"; `target` self or hero_any.
## (`between_battles_amount` applies outside battle, a later milestone.)

func op_name() -> String:
    return "repair_armor"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var targets: Array = candidates(ctx)
    var target: HeroState = targets[0]
    if String(ctx.effect.get("target", "self")) != "self":
        target = ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, targets, ctx.card, {"purpose": "repair"})
    var raw: Variant = ctx.effect.get("amount", 1)
    var amount: int = target.armor_damage if typeof(raw) == TYPE_STRING and raw == "all" else int(raw)
    ctx.battle.repair_armor(target, amount, ctx.actor)
    ctx.set_targets([target])
    ctx.earned_provoke = true

func candidates(ctx: EffectContext) -> Array:
    var result: Array = []
    if String(ctx.effect.get("target", "self")) == "self":
        if ctx.actor.armor_damage > 0:
            result.append(ctx.actor)
        return result
    for h in ctx.battle.standing_heroes():
        if h.armor_damage > 0:
            result.append(h)
    return result
