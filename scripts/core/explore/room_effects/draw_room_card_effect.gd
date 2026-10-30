class_name DrawRoomCardEffect
extends RoomEffect

## "draw_room_card": draw a card from a room deck and resolve it (the Workshop's guardians).

func op_name() -> String:
    return "draw_room_card"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var deck_name: String = String(effect["deck"])
    var card: Dictionary = ctx.run.room_decks.draw(deck_name, ctx.run.rng)
    if card.is_empty():
        return
    ctx.run.log.record("room_card", "%s card: %s." % [deck_name.capitalize(), String(card.get("name", "?"))], {"deck": deck_name, "card": String(card.get("id", ""))})
    ctx.run.run_effects(ctx, card.get("effects", []))
    ctx.run.room_decks.discard(deck_name, card)
