class_name CleanseEffect
extends EffectHandler

## "cleanse": remove `amount` points from one hero, any mix of Wounds and armor damage.

func op_name() -> String:
    return "cleanse"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var target: HeroState = ctx.battle.ask(DecisionRequest.TARGET, ctx.hero, candidates(ctx), ctx.card, {"purpose": "cleanse", "amount": ctx.amount()})
    apply(ctx, target, ctx.amount(1))
    ctx.set_targets([target])
    ctx.earned_provoke = true

func candidates(ctx: EffectContext) -> Array:
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if h.wound_count() > 0 or h.armor_damage > 0:
            result.append(h)
    return result

## Ask how many of the points remove Wounds (the rest repair armor), then apply them.
static func apply(ctx: EffectContext, target: HeroState, points: int) -> void:
    var wounds: int = target.wound_count()
    var armor: int = target.armor_damage
    var most: int = mini(points, wounds)
    var least: int = mini(most, maxi(0, points - armor))
    var options: Array = []
    for k in range(most, least - 1, -1):
        options.append(k)
    var to_wounds: int = ctx.battle.ask(DecisionRequest.CLEANSE_SPLIT, ctx.hero, options, ctx.card, {"target": target})
    ctx.battle.heal_wounds(target, to_wounds, ctx.actor)
    ctx.battle.repair_armor(target, points - to_wounds, ctx.actor)
