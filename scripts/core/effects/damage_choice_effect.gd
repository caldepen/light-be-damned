class_name DamageChoiceEffect
extends EffectHandler

## "damage_choice": the player picks one option, e.g. Twin Daggers: 1 damage to each of two enemies, or 2 to one.
## Always melee, after the card's own move into reach.

func op_name() -> String:
    return "damage_choice"

func is_legal(ctx: EffectContext) -> bool:
    if ctx.dry_run and not ctx.earlier_move().is_empty():
        return not Targeting.reachable_via_move(ctx.battle, ctx.hero, ctx.earlier_move()).is_empty()
    return not ctx.battle.enemies_within_1_of(ctx.hero.cells).is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var options: Array = choice_options(ctx)
    var choice: Dictionary = battle.ask(DecisionRequest.DAMAGE_OPTION, ctx.hero, options, ctx.card, {"purpose": "damage"})
    if choice.is_empty():
        return
    var hits: Array[FigureState] = []
    for target in choice["targets"]:
        var e: EnemyState = target
        battle.damage(e, maxi(0, int(choice["amount"]) + ctx.damage_bonus), ctx.actor, true)
        hits.append(e)
    ctx.set_targets(hits)
    ctx.earned_provoke = true

## Every concrete choice: {"amount": int, "targets": Array} for each listed option and each set of enemies in reach.
func choice_options(ctx: EffectContext) -> Array:
    var pool: Array[EnemyState] = ctx.battle.enemies_within_1_of(ctx.hero.cells)
    var result: Array = []
    for option in ctx.effect.get("options", []):
        var amount: int = int(option.get("amount", 0))
        var count: int = int(option.get("targets", 1))
        if count == 1:
            for e in pool:
                result.append({"amount": amount, "targets": [e]})
        elif count == 2:
            for i in range(pool.size()):
                for j in range(i + 1, pool.size()):
                    result.append({"amount": amount, "targets": [pool[i], pool[j]]})
        else:
            push_error("damage_choice: options with %d targets are not supported." % count)
    return result
