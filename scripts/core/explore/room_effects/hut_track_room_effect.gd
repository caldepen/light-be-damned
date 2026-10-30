class_name HutTrackRoomEffect
extends RoomEffect

## "hut_track": raise the Hut track (a secret told to the Black Cat).

func op_name() -> String:
    return "hut_track"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    ctx.run.raise_hut(int(effect.get("amount", 1)), ctx.source)
