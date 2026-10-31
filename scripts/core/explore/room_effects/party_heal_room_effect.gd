class_name PartyHealRoomEffect
extends RoomEffect

## "party_heal_wounds" (the Baths): each hero removes Wounds, drawing replacements; a Down hero whose hand is
## no longer only Wounds gets up.

func op_name() -> String:
    return "party_heal_wounds"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    for h in ctx.run.party.heroes:
        var was_down: bool = h.down
        var n: int = ctx.run.party.heal_wounds(h, int(effect.get("amount", 1)))
        if n > 0:
            ctx.run.log.record("heal", "%s removes %d Wound%s%s." % [h.name, n, "" if n == 1 else "s", " and gets up" if was_down and h.standing else ""],
                {"hero": h.hero_id, "amount": n})
