class_name HealHdEffect
extends EffectHandler

## "heal_hd": clear `amount` marked Hit Dice from `target`: self, or most_damaged_ally (any enemy, itself
## included). Needs something damaged (RULES §7).

func op_name() -> String:
    return "heal_hd"

func is_legal(ctx: EffectContext) -> bool:
    return target(ctx) != null

func resolve(ctx: EffectContext) -> void:
    var t: EnemyState = target(ctx)
    var cleared: int = mini(ctx.amount(1), t.marked_hd)
    t.marked_hd -= cleared
    ctx.battle.emit("heal_hd", "%s clears %d Hd on %s." % [ctx.actor.name, cleared, t.name], {"enemy": ctx.actor.id, "target": t.id, "amount": cleared})

func target(ctx: EffectContext) -> EnemyState:
    if String(ctx.effect.get("target", "self")) == "self":
        return ctx.enemy if ctx.enemy.marked_hd > 0 else null
    var best: EnemyState = null
    for e in ctx.battle.standing_enemies():
        if e.marked_hd > 0 and (best == null or e.marked_hd > best.marked_hd):
            best = e
    return best
