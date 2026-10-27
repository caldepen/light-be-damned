class_name PeekEffect
extends EffectHandler

## "peek": look at the top `count` cards of an enemy type's deck; with `reorder`, put them back in any order.

func op_name() -> String:
    return "peek"

func is_legal(ctx: EffectContext) -> bool:
    return not enemy_types(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var enemy_type: String = battle.ask(DecisionRequest.PEEK_TYPE, ctx.hero, enemy_types(ctx), ctx.card)
    var deck: EnemyDeck = battle.deck_for(enemy_type)
    var cards: Array[Dictionary] = deck.peek(int(ctx.effect.get("count", 1)))
    var names: PackedStringArray = []
    for c in cards:
        names.append(String(c.get("name", "?")))
    battle.emit("peek", "%s looks at the %s deck: %s." % [ctx.actor.name, enemy_type, ", ".join(names)],
        {"hero": ctx.actor.id, "type": enemy_type, "cards": names})
    if bool(ctx.effect.get("reorder", false)) and cards.size() > 1:
        var order: Array = battle.ask(DecisionRequest.PEEK_ORDER, ctx.hero, permutations(cards), ctx.card, {"type": enemy_type})
        var typed: Array[Dictionary] = []
        for c in order:
            typed.append(c)
        deck.reorder_top(typed)
        battle.emit("reorder", "%s reorders the %s deck." % [ctx.actor.name, enemy_type], {"hero": ctx.actor.id, "type": enemy_type})

func enemy_types(ctx: EffectContext) -> Array:
    var types: Array = []
    for e in ctx.battle.standing_enemies():
        if not types.has(e.enemy_type):
            types.append(e.enemy_type)
    return types

static func permutations(items: Array) -> Array:
    if items.size() <= 1:
        return [items.duplicate()]
    var result: Array = []
    for i in range(items.size()):
        var rest: Array = items.duplicate()
        var first: Variant = rest.pop_at(i)
        for p in permutations(rest):
            result.append([first] + p)
    return result
