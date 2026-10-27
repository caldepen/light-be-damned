class_name RepairSelfArmorEffect
extends EffectHandler

## "repair_self_armor": clear `amount` marked armor slots (Thick Hide). Needs armor damage (RULES §7).

func op_name() -> String:
    return "repair_self_armor"

func is_legal(ctx: EffectContext) -> bool:
    return ctx.actor.armor_damage > 0

func resolve(ctx: EffectContext) -> void:
    ctx.battle.repair_armor(ctx.actor, ctx.amount(1), ctx.actor)
