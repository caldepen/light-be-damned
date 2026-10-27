class_name PolymorphEffect
extends EffectHandler

## "polymorph": the top-Provoke hero becomes a toad and skips their next `turns` turns.

func op_name() -> String:
    return "polymorph"

func is_legal(ctx: EffectContext) -> bool:
    return ctx.battle.top_hero() != null

func resolve(ctx: EffectContext) -> void:
    var target: HeroState = ctx.battle.top_hero()
    target.toad_turns = int(ctx.effect.get("turns", 1))
    ctx.battle.emit("polymorph", "%s turns %s into a toad." % [ctx.actor.name, target.name], {"enemy": ctx.actor.id, "target": target.id})
