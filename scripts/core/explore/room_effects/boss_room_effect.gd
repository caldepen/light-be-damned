class_name BossRoomEffect
extends RoomEffect

## "boss": the boss battle. Milestone 4 stops here with the run marked "boss reached"; the fight
## itself is Milestone 6.

func op_name() -> String:
    return "boss"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    ctx.run.boss_reached = true
    ctx.stopped = true
    ctx.run.log.record("boss_reached", "The iron door opens: the boss battle (%s) waits." % String(effect.get("encounter", "")), {"encounter": String(effect.get("encounter", ""))})
