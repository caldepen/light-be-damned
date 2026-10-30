class_name CrookedCorridorRoomEffect
extends RoomEffect

## "crooked_corridor": the next tile goes as far from the Front Door (by path, in squares) as it can.

func op_name() -> String:
    return "crooked_corridor"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    ctx.run.explorer.crooked = true
    ctx.run.log.record("crooked_corridor", "The next room will be laid as far from the Front Door as it can go.", {})
