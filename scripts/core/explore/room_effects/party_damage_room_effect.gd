class_name PartyDamageRoomEffect
extends RoomEffect

## "party_damage": each standing hero takes damage, not an attack: armor first, then Wounds.

func op_name() -> String:
    return "party_damage"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    for h in ctx.run.party.standing():
        ctx.run.damage_hero(h, int(effect.get("amount", 1)), ctx.source)
    ctx.run.check_wipe(ctx)
