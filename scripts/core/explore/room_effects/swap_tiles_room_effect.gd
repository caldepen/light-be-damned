class_name SwapTilesRoomEffect
extends RoomEffect

## "swap_tiles" (Hall of Mirrors): the Hut swaps a random legal pair of same-shape tiles.

func op_name() -> String:
    return "swap_tiles"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var options: Array[Dictionary] = ctx.run.explorer.swap_options()
    if options.is_empty():
        ctx.run.log.record("whim_nothing", "No two tiles can swap.", {})
        return
    var pick: Dictionary = ctx.run.rng.pick(options)
    ctx.run.explorer.swap_tiles(pick["a"], pick["b"])
