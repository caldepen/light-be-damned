class_name ComponentRoomEffect
extends RoomEffect

## "component" (RULES §10 Components): while the party lacks `component`, fight its guardians
## (normal loot and XP), then take it; enemies that withdraw at the round cap leave it behind
## (open question #81). Once the party holds it, resolve `otherwise` (a Hut card).

func op_name() -> String:
    return "component"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var id: String = String(effect["component"])
    if run.has_component(id):
        run.run_effects(ctx, effect.get("otherwise", []))
        return
    run.log.record("guardians", "The %s's guardians: %s." % [ctx.source, String(effect.get("guardians", ""))], {"component": id, "encounter": String(effect["encounter"])})
    var source: String = ctx.source
    ctx.source = "guardians"
    var outcome: String = run.fight(String(effect["encounter"]), true, ctx.source)
    ctx.source = source
    if outcome == HutRun.FIGHT_WIPE:
        ctx.stopped = true
        return
    run.gain_component(id)
