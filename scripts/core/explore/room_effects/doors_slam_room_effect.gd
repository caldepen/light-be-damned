class_name DoorsSlamRoomEffect
extends RoomEffect

## "doors_slam" (Doors Slam): every open doorway of the party's room closes except one, at random.

func op_name() -> String:
    return "doors_slam"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var open: Array[MapDoorway] = ctx.run.explorer.party_doorways()
    if open.size() <= 1:
        ctx.run.log.record("whim_nothing", "The party's room has no doorway to slam.", {})
        return
    var keep: MapDoorway = ctx.run.rng.pick(open)
    for d in open:
        if d != keep:
            ctx.run.explorer.close_doorway(d)
