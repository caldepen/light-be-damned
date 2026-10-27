class_name AttackAreaEffect
extends EffectHandler

## "attack_area": `amount` to every hero in `area`: heroes_within_1 (Stomp) or
## area2x2_most_heroes (Fire Flask: the 2x2 block holding the most heroes; the first such block on ties).

func op_name() -> String:
    return "attack_area"

func is_legal(ctx: EffectContext) -> bool:
    return not targets(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var hit: Array[HeroState] = targets(ctx)
    var amount: int = maxi(0, ctx.amount() + ctx.damage_bonus)
    ctx.battle.emit("enemy_attack", "%s hits %d heroes for %d each." % [ctx.actor.name, hit.size(), amount],
        {"enemy": ctx.actor.id, "how": ctx.area(), "amount": amount})
    for h in hit:
        ctx.battle.damage(h, amount, ctx.actor, true)
    ctx.set_targets(hit)

func targets(ctx: EffectContext) -> Array[HeroState]:
    var battle: Battle = ctx.battle
    match ctx.area():
        "heroes_within_1":
            return battle.heroes_within_1_of(ctx.actor.cells)
        "area2x2_most_heroes":
            var best: Array[HeroState] = []
            for corner in Field.block_corners():
                var inside: Array[HeroState] = battle.heroes_in_cells(Field.block_cells(corner))
                if inside.size() > best.size():
                    best = inside
            return best
    push_error("attack_area: unsupported area '%s'." % ctx.area())
    return []
