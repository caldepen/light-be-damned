class_name TrapRoomEffect
extends RoomEffect

## "trap" (RULES §8 Traps, ruling #55): the party may spend a Wits roll to spot it. Spotted: avoid
## it, or disarm it with an Agility roll for its salvage (a failed disarm springs it on the
## disarmer). Not spotted: it springs on the party's leader. The victim may roll Agility to dodge.
## All rolls at the trap's target; spotting and dodging never give XP.

func op_name() -> String:
    return "trap"

func resolve(ctx: RoomContext, effect: Dictionary) -> void:
    var run: HutRun = ctx.run
    var target: int = int(effect.get("target", 4))
    var spotted: bool = false
    if not run.party.can_roll().is_empty() and run.ask_yes(RunRequest.SPOT_TRAP, null, {"target": target}):
        spotted = bool(SkillRoll.roll(run, "wits", target, "spot", false).get("success", false))
    if spotted:
        run.log.record("trap_spotted", "The party spots the trap.", {"target": target})
        if run.party.can_roll().is_empty() or not run.ask_yes(RunRequest.DISARM, null, {"target": target}):
            run.log.record("trap_avoided", "The party steps around it.", {})
            return
        var disarm: Dictionary = SkillRoll.roll(run, "agility", target, "disarm", true)
        if disarm.is_empty():
            return
        if bool(disarm["success"]):
            run.log.record("trap_disarmed", "Disarmed.", {})
            run.loot(int(effect.get("salvage_loot", 0)), "trap salvage")
            return
        _spring(ctx, effect, disarm["heroes"][0])
        return
    _spring(ctx, effect, run.leader())

func _spring(ctx: RoomContext, effect: Dictionary, victim: HeroState) -> void:
    var run: HutRun = ctx.run
    if victim == null:
        return
    var target: int = int(effect.get("target", 4))
    run.log.record("trap_springs", "The trap springs on %s." % victim.name, {"hero": victim.hero_id})
    if victim.standing and not victim.deck.is_empty() and run.ask_yes(RunRequest.DODGE, victim, {"target": target}):
        if bool(SkillRoll.roll(run, "agility", target, "dodge", false, victim).get("success", false)):
            run.log.record("trap_dodged", "%s dodges it." % victim.name, {"hero": victim.hero_id})
            return
    run.damage_hero(victim, int(effect.get("damage", 0)), "trap")
    run.check_wipe(ctx)
