class_name EffectHandler
extends RefCounted

## Base for one effect `op` from the data. One subclass per op, registered in EffectRegistry.

func op_name() -> String:
    return ""

## Whether the effect has a legal target or use right now. Must not change state
## (ctx.dry_run is true when the engine is only checking whether a card can be played).
func is_legal(_ctx: EffectContext) -> bool:
    return true

## Whether a card with this effect can be played if only this effect is unusable.
## Follow-up effects (`"area": "same"`, splash) don't decide whether an enemy card is playable.
func is_follow_up(ctx: EffectContext) -> bool:
    return ctx.area() == "same"

func resolve(_ctx: EffectContext) -> void:
    pass
