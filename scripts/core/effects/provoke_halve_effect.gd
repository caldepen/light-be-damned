class_name ProvokeHalveEffect
extends EffectHandler

## "provoke_halve": halve the hero's Provoke, rounding as `rounding` says (Backstab: up).

func op_name() -> String:
    return "provoke_halve"

func is_legal(ctx: EffectContext) -> bool:
    if not ctx.actor.is_hero():
        return false
    var value: int = ctx.battle.provoke.value_of(ctx.hero)
    return halved(ctx, value) != value

func resolve(ctx: EffectContext) -> void:
    var value: int = ctx.battle.provoke.value_of(ctx.hero)
    ctx.battle.move_provoke(ctx.hero, halved(ctx, value) - value, ctx.card_name)

func halved(ctx: EffectContext, value: int) -> int:
    if String(ctx.effect.get("rounding", "up")) == "up":
        return ceili(value / 2.0)
    return floori(value / 2.0)
