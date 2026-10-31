class_name LockRoomEffect
extends RoomEffect

## "lock": an obstacle the party may attempt, a locked chest (RULES §8, ruling #57). Each failure raises the Hut
## track; `retries` is a number or "unlimited". Stopping leaves it shut for good.

func op_name() -> String:
    return "lock"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var type: String = String(effect["type"])
    var target: int = int(effect["target"])
    var retries: Variant = effect.get("retries", 0)
    if run.party.can_roll().is_empty() or not run.ask_yes(RunRequest.ATTEMPT, null, {"type": type, "target": target, "purpose": "lock"}):
        run.log.record("lock_left", "The party leaves the %s %d shut." % [type.capitalize(), target], {})
        return
    var failures: int = 0
    while not ctx.stopped and not run.wiped:
        var result: Dictionary = SkillRoll.roll(run, type, target, "lock", true)
        if result.is_empty():
            return
        if bool(result["success"]):
            run.run_effects(ctx, effect.get("success", []))
            return
        failures += 1
        if typeof(retries) != TYPE_STRING and failures > int(retries):
            run.log.record("lock_jammed", "It stays shut for good.", {})
            return
        if run.party.can_roll().is_empty() or not run.ask_yes(RunRequest.RETRY, null, {"type": type, "target": target, "failures": failures}):
            run.log.record("lock_left", "The party gives up on it.", {})
            return
