class_name ProvokeEffect
extends EffectHandler

## "provoke": move the hero's token by `amount` (may be negative). A loss at 0 has no use.

func op_name() -> String:
    return "provoke"

func is_legal(ctx: EffectContext) -> bool:
    if not ctx.actor.is_hero():
        return false
    return ctx.amount() > 0 or ctx.battle.provoke.value_of(ctx.hero) > 0

func resolve(ctx: EffectContext) -> void:
    ctx.battle.move_provoke(ctx.hero, ctx.amount(), ctx.card_name)
