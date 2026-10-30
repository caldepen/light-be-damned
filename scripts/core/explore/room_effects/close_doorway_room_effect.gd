class_name CloseDoorwayRoomEffect
extends RoomEffect

## "close_doorway" (Vanishing Door): a random open doorway on the map gets a wall token.

func op_name() -> String:
    return "close_doorway"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var options: Array[MapDoorway] = ctx.run.explorer.open_doorway_options()
    if options.is_empty():
        ctx.run.log.record("whim_nothing", "No open doorway to close.", {})
        return
    ctx.run.explorer.close_doorway(ctx.run.rng.pick(options))
