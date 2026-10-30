class_name SkillRoll
extends RefCounted

## Skill rolls (RULES §8): flip the top card of a hero's deck and read its skill value, −2 (minimum
## 1) for a hero of another Type; a target above 6 needs two heroes who add their values. The card
## is spent (Exhausted if ▲ or ★). Every failure raises the Hut track by 1. Beating Hard or harder
## gives 1 XP when `gives_xp` (never for spotting or dodging).

## Returns {"success", "value", "heroes"} or {} when nobody can roll. `roller` fixes the hero
## (a trap's victim dodging); otherwise the party chooses.
static func roll(run: HutRun, type: String, target: int, purpose: String, gives_xp: bool, roller: HeroState = null) -> Dictionary:
    var rules: Dictionary = run.rules.get("skill_rolls", {})
    var teamwork: bool = target > int(rules.get("teamwork_above", 6))
    var rollers: Array[HeroState] = []
    if roller != null:
        if roller.standing and not roller.deck.is_empty():
            rollers.append(roller)
    else:
        for i in range(2 if teamwork else 1):
            var pool: Array = run.party.can_roll().filter(func(h: HeroState) -> bool: return not rollers.has(h))
            var chosen: HeroState = run.ask(RunRequest.ROLLER, null, pool, {"type": type, "target": target, "purpose": purpose})
            if chosen != null:
                rollers.append(chosen)
    if rollers.is_empty() or (teamwork and rollers.size() < 2):
        run.log.record("no_roll", "Nobody can roll %s %d." % [type.capitalize(), target], {"type": type, "target": target, "purpose": purpose})
        return {}
    var value: int = 0
    var parts: PackedStringArray = []
    for h in rollers:
        var card: Card = run.party.flip(h)
        var v: int = int(card.def.get("skill", 0))
        if h.hero_type != type:
            v = maxi(int(rules.get("minimum", 1)), v + int(rules.get("off_type_penalty", -2)))
        value += v
        parts.append("%s flips %s (%d)" % [h.name, card.name, v])
    var success: bool = value >= target
    run.log.record("skill_roll", "%s %d (%s): %s, %d -> %s." % [type.capitalize(), target, purpose, ", ".join(parts), value, "success" if success else "failure"],
        {"type": type, "target": target, "purpose": purpose, "value": value, "success": success, "heroes": rollers.map(func(h: HeroState) -> String: return h.hero_id)})
    if not success:
        run.raise_hut(int(rules.get("failure_hut_track", 1)), "failed %s roll" % purpose)
    elif gives_xp and target >= int(rules.get("difficulty", {}).get("hard", 5)):
        run.gain_xp(int(rules.get("xp_for_hard_or_better", 1)), "beat a Hard %s" % purpose)
    return {"success": success, "value": value, "heroes": rollers}
