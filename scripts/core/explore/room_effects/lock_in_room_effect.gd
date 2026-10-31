class_name LockInRoomEffect
extends RoomEffect

## "lock_in" (Locked In, ruling #58): the door slams shut; bash it with a `type` roll at `target`.
## Rolled at once and retried until it gives way; each failure raises the Hut track. Any hero may
## bash, at -2 if it isn't their Type (open question #84). If nobody can roll, the door gives way
## on its own and the Hut track rises by 1 (ruling #72).

func op_name() -> String:
    return "lock_in"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var type: String = String(effect.get("type", "strength"))
    var target: int = int(effect.get("target", 4))
    run.log.record("locked_in", "The door slams shut.", {})
    while not ctx.stopped and not run.wiped:
        if run.party.can_roll().is_empty():
            run.log.record("door_gives_way", "Nobody can bash it: the door gives way on its own.", {})
            run.raise_hut(int(effect.get("hut_if_nobody_rolls", 1)), "the door gives way")
            return
        if bool(SkillRoll.roll(run, type, target, "bash", true).get("success", false)):
            run.log.record("unlocked", "The door gives way.", {})
            return
