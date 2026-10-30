class_name SkillCheckRoomEffect
extends RoomEffect

## "skill_check": one roll with `success` and `failure` effects. `optional: true` lets the party
## decline and come back later (the Shrine, the Strange font; ruling #56). Nobody able to roll
## counts as a failure.

func op_name() -> String:
    return "skill_check"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var type: String = String(effect["type"])
    var target: int = int(effect["target"])
    if bool(effect.get("optional", false)) and not run.ask_yes(RunRequest.ATTEMPT, null, {"type": type, "target": target, "purpose": "optional"}):
        ctx.declined = true
        run.log.record("declined", "The party leaves it for later.", {})
        return
    var result: Dictionary = SkillRoll.roll(run, type, target, "check", true)
    var success: bool = bool(result.get("success", false))
    run.run_effects(ctx, effect.get("success" if success else "failure", []))
