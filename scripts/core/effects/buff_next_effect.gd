class_name BuffNextEffect
extends EffectHandler

## "buff_next": the target's next qualifying card gets +amount, to every target of that card (RULES §6 Bonuses).
## `target`: self, or ally (another hero: Bless never targets the Cleric herself).
## `applies_to`: attack (next damage card) or damage_or_guard (Bless: next damage or Guard card).

func op_name() -> String:
    return "buff_next"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var target: HeroState = ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, candidates(ctx), ctx.card, {"purpose": "buff"})
    target.buffs.append({"amount": ctx.amount(), "applies_to": String(ctx.effect.get("applies_to", "attack")), "source": ctx.card_name})
    ctx.battle.emit("buff", "%s's next card gets +%d (%s)." % [target.name, ctx.amount(), ctx.card_name],
        {"hero": target.id, "amount": ctx.amount(), "source": ctx.card_name})

func candidates(ctx: EffectContext) -> Array:
    if String(ctx.effect.get("target", "self")) != "ally":
        return [ctx.hero]
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if h != ctx.actor:
            result.append(h)
    return result
