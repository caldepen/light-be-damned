class_name SummonIfLastEffect
extends EffectHandler

## "summon_if_last": if this is the last enemy of `type` and a square is free, `count` more join (Shriek);
## otherwise run `otherwise`.

func op_name() -> String:
    return "summon_if_last"

func resolve(ctx: EffectContext) -> void:
    var enemy_type: String = String(ctx.effect.get("type", ""))
    var size: Vector2i = BattleSetup.size_of(ctx.battle.enemy_defs[enemy_type])
    if CardRunner.is_last_of_type(ctx.battle, ctx.enemy, enemy_type) and not BattleSetup.first_free_cells(ctx.battle, size).is_empty():
        ctx.battle.emit("shriek", "%s shrieks for help." % ctx.actor.name, {"enemy": ctx.actor.id})
        ctx.battle.summon(enemy_type, int(ctx.effect.get("count", 1)), ctx.actor)
    else:
        CardRunner.run_effects(ctx, ctx.effect.get("otherwise", []))
