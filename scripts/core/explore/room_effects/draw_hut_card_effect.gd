class_name DrawHutCardEffect
extends RoomEffect

## "draw_hut_card": draw a card from the Hut deck and resolve it (every room, RULES §10).

func op_name() -> String:
    return "draw_hut_card"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var card: Dictionary = ctx.run.hut_deck.draw(ctx.run.rng)
    if card.is_empty():
        return
    ctx.run.log.record("hut_card", "Hut card: %s." % String(card.get("name", "?")), {"card": String(card.get("id", "")), "tile": ctx.tile.uid if ctx.tile != null else -1})
    var source: String = ctx.source
    ctx.source = "hut card"
    ctx.run.run_effects(ctx, card.get("effects", []))
    ctx.source = source
    ctx.run.hut_deck.discard(card)
