class_name LockInRoomEffect
extends RoomEffect

## "lock_in" (Locked In, ruling #58): the party's room seals until one of `types` beats `target`.
## Rolled at once and retried until it succeeds; each failure raises the Hut track. A hero rolls
## their own Type if it is listed, else the first listed Type (at -2).

func op_name() -> String:
    return "lock_in"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var types: Array = effect.get("types", ["strength"])
    var target: int = int(effect.get("target", 4))
    run.log.record("locked_in", "The doorways seal shut.", {})
    while not ctx.stopped and not run.wiped:
        var pool: Array[HeroState] = run.party.can_roll()
        if pool.is_empty():
            run.log.record("no_roll", "Nobody can roll; the doorways stay sealed.", {})
            return
        var hero: HeroState = run.ask(RunRequest.ROLLER, null, pool, {"type": String(types[0]), "types": types, "target": target, "purpose": "locked in"})
        var type: String = hero.hero_type if types.has(hero.hero_type) else String(types[0])
        if bool(SkillRoll.roll(run, type, target, "locked in", true, hero).get("success", false)):
            run.log.record("unlocked", "The doorways open again.", {})
            return
