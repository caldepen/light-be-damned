class_name RotateTileRoomEffect
extends RoomEffect

## "rotate_tile" (Shifting Walls): the Hut turns a random legal explored tile in place (ruling #63).

func op_name() -> String:
    return "rotate_tile"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    var options: Array[Dictionary] = ctx.run.explorer.rotation_options()
    if options.is_empty():
        ctx.run.log.record("whim_nothing", "No tile can turn.", {})
        return
    var pick: Dictionary = ctx.run.rng.pick(options)
    ctx.run.explorer.rotate_tile(pick["tile"], int(pick["rotation"]))
