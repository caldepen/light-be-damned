class_name FightRoomEffect
extends RoomEffect

## "fight": fight a named encounter; `rewards: false` for wandering monsters (no loot, no XP).

func op_name() -> String:
    return "fight"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    if ctx.run.fight(String(effect["encounter"]), bool(effect.get("rewards", true)), ctx.source) == HutRun.FIGHT_WIPE:
        ctx.stopped = true
