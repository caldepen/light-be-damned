class_name BleedEffect
extends EffectHandler

## "bleed": the target takes 1 damage at the end of each round for `rounds` rounds.
## `"area": "same"` bleeds the previous effect's targets; otherwise a hero picks any enemy (Burn).
## Bleed is not damage for Provoke, so it never earns the +1.

func op_name() -> String:
    return "bleed"

func is_legal(ctx: EffectContext) -> bool:
    if ctx.area() == "same":
        return not ctx.standing_last_targets().is_empty()
    return not ctx.battle.standing_opponents(ctx.actor).is_empty()

func resolve(ctx: EffectContext) -> void:
    var targets: Array = []
    if ctx.area() == "same":
        targets = ctx.standing_last_targets()
    else:
        var target: FigureState = ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, ctx.battle.standing_opponents(ctx.actor), ctx.card, {"purpose": "bleed"})
        targets = [target]
        ctx.set_targets(targets)
    for t in targets:
        ctx.battle.apply_bleed(t, int(ctx.effect.get("rounds", 1)), ctx.actor)
