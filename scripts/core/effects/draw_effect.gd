class_name DrawEffect
extends EffectHandler

## "draw": draw cards, even above hand size (RULES §5). `target`: self, or same (Greater Heal's healed hero).

func op_name() -> String:
    return "draw"

func is_follow_up(ctx: EffectContext) -> bool:
    return String(ctx.effect.get("target", "self")) == "same"

func is_legal(ctx: EffectContext) -> bool:
    for h in targets(ctx):
        if not h.deck.is_empty():
            return true
    return false

func resolve(ctx: EffectContext) -> void:
    for h in targets(ctx):
        ctx.battle.draw_cards(h, ctx.amount(1), ctx.card_name)

func targets(ctx: EffectContext) -> Array[HeroState]:
    var result: Array[HeroState] = []
    if String(ctx.effect.get("target", "self")) == "same":
        for t in ctx.standing_last_targets():
            if t is HeroState:
                result.append(t)
    elif ctx.actor is HeroState:
        result.append(ctx.hero)
    return result
