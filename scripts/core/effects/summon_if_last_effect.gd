class_name SummonIfLastEffect
extends EffectHandler

## "summon_if_last": if this is the last enemy of `type` and a square is free, `count` more join (Shriek);
## otherwise run `otherwise`.

func op_name() -> String:
    return "summon_if_last"

func resolve(ctx: EffectContext) -> void:
    if will_summon(ctx.battle, ctx.enemy, ctx.effect):
        var enemy_type: String = String(ctx.effect.get("type", ""))
        ctx.battle.emit("shriek", "%s shrieks for help." % ctx.actor.name, {"enemy": ctx.actor.id})
        ctx.battle.summon(enemy_type, int(ctx.effect.get("count", 1)), ctx.actor)
    else:
        CardRunner.run_effects(ctx, ctx.effect.get("otherwise", []))

static func will_summon(battle: Battle, enemy: EnemyState, effect: Dictionary) -> bool:
    var enemy_type: String = String(effect.get("type", ""))
    var size: Vector2i = BattleSetup.size_of(battle.enemy_defs[enemy_type])
    return CardRunner.is_last_of_type(battle, enemy, enemy_type) and not BattleSetup.first_free_cells(battle, size).is_empty()
