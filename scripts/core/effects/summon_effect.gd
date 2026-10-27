class_name SummonEffect
extends EffectHandler

## "summon": place `count` enemies of `type` on empty squares of the enemy board, front row first.
## Needs an empty square (RULES §7). Newcomers first act next round.

func op_name() -> String:
    return "summon"

func is_legal(ctx: EffectContext) -> bool:
    var enemy_type: String = String(ctx.effect.get("type", ""))
    var size: Vector2i = BattleSetup.size_of(ctx.battle.enemy_defs[enemy_type])
    return not BattleSetup.first_free_cells(ctx.battle, size).is_empty()

func resolve(ctx: EffectContext) -> void:
    ctx.battle.summon(String(ctx.effect.get("type", "")), int(ctx.effect.get("count", 1)), ctx.actor)
