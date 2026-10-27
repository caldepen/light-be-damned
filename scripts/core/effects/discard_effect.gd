class_name DiscardEffect
extends EffectHandler

## "discard": every hero in `area` discards `count` non-Wound cards of their choice (Roar).
## Not replaced; `cannot_down` stops a discard that would leave the hero Down (RULES §7 Discards).

func op_name() -> String:
    return "discard"

func is_legal(ctx: EffectContext) -> bool:
    return not targets(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    for hero in targets(ctx):
        for i in range(int(ctx.effect.get("count", 1))):
            var pool: Array = hero.non_wound_cards()
            if pool.is_empty():
                break
            if bool(ctx.effect.get("cannot_down", false)) and hero.spent_without(pool[0]):
                battle.emit("discard_prevented", "%s keeps their last card (a discard can't knock them Down)." % hero.name, {"hero": hero.id})
                break
            var card: Card = battle.ask(DecisionRequest.FORCED_DISCARD, hero, pool, null, {"source": ctx.actor.id})
            hero.hand.erase(card)
            hero.discard.append(card)
            battle.emit("discard", "%s makes %s discard %s." % [ctx.actor.name, hero.name, card.name],
                {"hero": hero.id, "card": card.id, "source": ctx.actor.id})
            battle.check_spent(hero)
            if hero.down:
                break

func targets(ctx: EffectContext) -> Array[HeroState]:
    if ctx.area() == "heroes_within_1":
        return ctx.battle.heroes_within_1_of(ctx.actor.cells)
    push_error("discard: unsupported area '%s'." % ctx.area())
    return []
