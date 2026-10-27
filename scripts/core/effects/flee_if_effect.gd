class_name FleeIfEffect
extends EffectHandler

## "flee_if": leave the battle (no loot) if `condition` holds; otherwise run `otherwise` (Flee).

func op_name() -> String:
    return "flee_if"

func resolve(ctx: EffectContext) -> void:
    if CardRunner.condition_holds(ctx.enemy, String(ctx.effect.get("condition", ""))):
        ctx.enemy.fled = true
        ctx.battle.knock_down(ctx.enemy)
    else:
        CardRunner.run_effects(ctx, ctx.effect.get("otherwise", []))
