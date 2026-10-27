class_name DiscardRandomEffect
extends EffectHandler

## "discard_random": the target discards `count` random non-Wound cards (Disarm, Hex).
## Without `target` it hits the previous effect's target. `replace_next_turn`: each is owed back at the
## start of their next turn. `cannot_down`: a discard that would leave the hero Down doesn't happen (RULES §7 Discards).

func op_name() -> String:
    return "discard_random"

func is_follow_up(ctx: EffectContext) -> bool:
    return not ctx.effect.has("target")

func is_legal(ctx: EffectContext) -> bool:
    return not ctx.battle.standing_heroes().is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var hero: HeroState = null
    if ctx.effect.has("target"):
        hero = battle.top_hero()
    else:
        for t in ctx.standing_last_targets():
            if t is HeroState:
                hero = t
                break
    if hero == null:
        return
    for i in range(int(ctx.effect.get("count", 1))):
        var pool: Array[Card] = hero.non_wound_cards()
        if pool.is_empty():
            break
        var card: Card = battle.rng.pick(pool)
        if bool(ctx.effect.get("cannot_down", false)) and hero.spent_without(card):
            battle.emit("discard_prevented", "%s keeps their last card (a discard can't knock them Down)." % hero.name, {"hero": hero.id})
            break
        hero.hand.erase(card)
        hero.discard.append(card)
        if bool(ctx.effect.get("replace_next_turn", false)):
            hero.owed_draws += 1
        battle.emit("discard", "%s makes %s discard %s." % [ctx.actor.name, hero.name, card.name],
            {"hero": hero.id, "card": card.id, "source": ctx.actor.id, "owed": hero.owed_draws})
        battle.check_spent(hero)
        if hero.down:
            break
