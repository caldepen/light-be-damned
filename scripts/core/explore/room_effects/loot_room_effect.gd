class_name LootRoomEffect
extends RoomEffect

## "loot": draw loot cards. Milestone 4 only counts them (real loot is Milestone 5).

func op_name() -> String:
    return "loot"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    ctx.run.loot(int(effect.get("count", 1)), ctx.source)
