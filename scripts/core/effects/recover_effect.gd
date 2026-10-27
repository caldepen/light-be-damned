class_name RecoverEffect
extends EffectHandler

## "recover": pull up to `amount` cards back from a discard pile, `to` the deck (then shuffled) or the hand.
## Exhausted cards are never in the discard pile, and the recovery card is still in play, so neither can come back.

func op_name() -> String:
    return "recover"

func is_legal(ctx: EffectContext) -> bool:
    return not candidates(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var target: HeroState = battle.ask(DecisionRequest.TARGET, ctx.hero, candidates(ctx), ctx.card, {"purpose": "recover"})
    var to: String = String(ctx.effect.get("to", "deck"))
    var recovered: PackedStringArray = []
    for i in range(ctx.amount(1)):
        if target.discard.is_empty():
            break
        var options: Array = target.discard.duplicate()
        options.append(null)
        var card: Card = battle.ask(DecisionRequest.RECOVER_CARD, ctx.hero, options, ctx.card, {"target": target, "to": to})
        if card == null:
            break
        target.discard.erase(card)
        if to == "hand":
            target.hand.append(card)
        else:
            target.deck.append(card)
        recovered.append(card.name)
    if to != "hand" and not recovered.is_empty():
        battle.rng.shuffle(target.deck)
    battle.emit("recover", "%s returns %s to %s's %s." % [ctx.actor.name, ", ".join(recovered), target.name, to],
        {"hero": ctx.actor.id, "target": target.id, "cards": recovered, "to": to})

func candidates(ctx: EffectContext) -> Array:
    if String(ctx.effect.get("target", "self")) == "self":
        return [ctx.hero] if not ctx.hero.discard.is_empty() else []
    var result: Array = []
    for h in ctx.battle.standing_heroes():
        if not h.discard.is_empty():
            result.append(h)
    return result
