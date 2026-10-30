class_name OptionalRoomEffect
extends RoomEffect

## "optional": the party may accept (resolve `effects`) or refuse (The Black Cat, ruling #64).

func op_name() -> String:
    return "optional"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    if ctx.run.ask_yes(RunRequest.ACCEPT, null, {"prompt": String(effect.get("prompt", ""))}):
        ctx.run.run_effects(ctx, effect.get("effects", []))
    else:
        ctx.run.log.record("refused", "The party refuses: %s" % String(effect.get("prompt", "")), {})
