class_name StunEffect
extends EffectHandler

## "stun": the target skips its next turn. Areas: same (previous targets), row (with `row`
## enemy_front and optional `only`: undead), adjacent_to_self (enemies next to the actor).

func op_name() -> String:
    return "stun"

func is_legal(ctx: EffectContext) -> bool:
    return not targets(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var hit: Array = targets(ctx)
    for t in hit:
        ctx.battle.apply_stun(t, ctx.actor)
    if ctx.area() != "same":
        ctx.set_targets(hit)

func targets(ctx: EffectContext) -> Array:
    var battle: Battle = ctx.battle
    var result: Array = []
    match ctx.area():
        "same":
            result = ctx.standing_last_targets()
        "row":
            var y: int = battle.enemy_front_row_y()
            if y >= 0:
                result = battle.enemies_in_cells(Battle.row_cells(y))
        "adjacent_to_self":
            result = battle.enemies_within_1_of(ctx.actor.cells)
        _:
            push_error("stun: unsupported area '%s'." % ctx.area())
    if String(ctx.effect.get("only", "")) == "undead":
        result = result.filter(func(f: FigureState) -> bool: return f is EnemyState and (f as EnemyState).undead)
    return result
