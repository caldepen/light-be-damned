class_name KeyholeRoomEffect
extends RoomEffect

## "keyhole": the next exploration draws the tile before the doorway is chosen.

func op_name() -> String:
    return "keyhole"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    ctx.run.keyhole = true
    ctx.run.log.record("keyhole", "Next time, the party sees the room before choosing the doorway.", {})
