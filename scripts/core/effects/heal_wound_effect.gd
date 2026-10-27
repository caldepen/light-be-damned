class_name HealWoundEffect
extends EffectHandler

## "heal_wound": remove Wounds; each is replaced by a draw (RULES §5). `target`:
## hero_adjacent (within 1 square, yourself included), hero_any, all_heroes, heroes_within_1.

func op_name() -> String:
    return "heal_wound"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var target_kind: String = String(ctx.effect.get("target", "hero_any"))
    var targets: Array = candidates(ctx)
    if target_kind == "hero_adjacent" or target_kind == "hero_any":
        targets = [ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, targets, ctx.card, {"purpose": "heal", "amount": ctx.amount()})]
    for t in targets:
        ctx.battle.heal_wounds(t, ctx.amount(1), ctx.actor)
    ctx.set_targets(targets)
    ctx.earned_provoke = true

func candidates(ctx: EffectContext) -> Array:
    var target_kind: String = String(ctx.effect.get("target", "hero_any"))
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if h.wound_count() == 0:
            continue
        var near: bool = Field.cells_distance(h.cells, ctx.actor.cells) <= 1
        if (target_kind == "hero_adjacent" or target_kind == "heroes_within_1") and not near:
            continue
        result.append(h)
    return result
