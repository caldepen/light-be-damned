class_name StatusEffect
extends EffectHandler

## "status": an ongoing effect on the actor, stored under its `name` with the effect's fields.
## Heroes: berserk, thorns, ignore_next_attack, lightning_orb. Enemies: rage, extra_turn_each_round.
## `duration_rounds` becomes a `rounds_left` counter.

func op_name() -> String:
    return "status"

func is_legal(ctx: EffectContext) -> bool:
    return not ctx.actor.statuses.has(String(ctx.effect.get("name", "")))

func resolve(ctx: EffectContext) -> void:
    var status_name: String = String(ctx.effect.get("name", ""))
    var status: Dictionary = ctx.effect.duplicate()
    if status.has("duration_rounds"):
        status["rounds_left"] = int(status["duration_rounds"])
    status["gained"] = ctx.battle.new_uid()  # order of gaining, e.g. for extra turns (RULES §5)
    ctx.actor.statuses[status_name] = status
    ctx.battle.emit("status", "%s gains %s." % [ctx.actor.name, status_name], {"figure": ctx.actor.id, "status": status_name})
