class_name ProvokeAllHeroesEffect
extends EffectHandler

## "provoke_all_heroes": move every standing hero's token by `amount` (Cackle). Tokens move bottom first,
## so heroes on the same space keep their order.

func op_name() -> String:
    return "provoke_all_heroes"

func resolve(ctx: EffectContext) -> void:
    var order: Array[HeroState] = ctx.battle.provoke.ordered(ctx.battle.standing_heroes())
    order.reverse()
    for h in order:
        ctx.battle.move_provoke(h, ctx.amount(), ctx.card_name)
