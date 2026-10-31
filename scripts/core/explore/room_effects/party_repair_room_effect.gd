class_name PartyRepairRoomEffect
extends RoomEffect

## "party_repair_armor": each hero repairs armor damage (the Baths, Bubbling Cauldron).

func op_name() -> String:
    return "party_repair_armor"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    for h in ctx.run.party.heroes:
        var n: int = ctx.run.party.repair_armor(h, int(effect.get("amount", 1)))
        if n > 0:
            ctx.run.log.record("repair", "%s repairs %d armor." % [h.name, n], {"hero": h.hero_id, "amount": n})
