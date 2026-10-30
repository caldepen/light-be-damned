class_name TakeKeyRoomEffect
extends RoomEffect

## "take_key": the party takes the Iron Key (the Workshop).

func op_name() -> String:
    return "take_key"

func resolve(ctx: RoomContext, _effect: Dictionary) -> void:
    ctx.run.explorer.has_key = true
    ctx.run.log.record("key_taken", "The party takes the Iron Key.", {})
