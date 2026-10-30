class_name GainRationRoomEffect
extends RoomEffect

## "gain_ration": rations +amount (the Pantry, Gingerbread Pantry).

func op_name() -> String:
    return "gain_ration"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    ctx.run.rations += int(effect.get("amount", 1))
    ctx.run.log.record("rations", "Rations +%d (%d)." % [int(effect.get("amount", 1)), ctx.run.rations], {"rations": ctx.run.rations})
