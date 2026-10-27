class_name WeakenNextAttackEffect
extends EffectHandler

## "weaken_next_attack": the previous effect's targets deal `amount` less with their next attack card.

func op_name() -> String:
    return "weaken_next_attack"

func is_follow_up(_ctx: EffectContext) -> bool:
    return true

func is_legal(ctx: EffectContext) -> bool:
    return not ctx.standing_last_targets().is_empty()

func resolve(ctx: EffectContext) -> void:
    for t in ctx.standing_last_targets():
        if t is EnemyState:
            (t as EnemyState).weaken_next += ctx.amount(1)
            ctx.battle.emit("weaken", "%s's next attack deals %d less." % [t.name, ctx.amount(1)], {"target": t.id})
