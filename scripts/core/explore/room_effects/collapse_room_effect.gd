class_name CollapseRoomEffect
extends RoomEffect

## "collapse" (Collapse): the Hut removes a random dead-end room for the rest of the run.

func op_name() -> String:
    return "collapse"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var options: Array[PlacedTile] = ctx.run.explorer.collapse_options()
    if options.is_empty():
        ctx.run.log.record("whim_nothing", "No dead end to collapse.", {})
        return
    ctx.run.explorer.remove_tile(ctx.run.rng.pick(options))
