class_name RunFight
extends RefCounted

## A battle inside a run (RULES §8 Battles in a run, After a won battle; ruling #65). The party's own
## heroes fight, carrying their hands, decks, discards, Exhausted cards, Wounds and armor damage in
## and out; Down heroes and heroes with empty decks sit out, and if nobody can fight it is a wipe.
## Heroes stand in the run's formation. Battle effects (Provoke, Guard, Bleed, Stun, statuses) end
## with the battle and enemy decks are fresh. After a win: bandage, patch up, then loot and XP
## unless the fight is a wandering one. At the round cap the enemies withdraw. Every battle event
## is forwarded to the run's log.

## HutRun.fight_runner: func(run, encounter, rewards) -> HutRun.FIGHT_*.
static func play(run: HutRun, encounter_name: String, rewards: bool) -> String:
    var encounter: Array = run.data["encounters"].get(encounter_name, [])
    if encounter.is_empty():
        push_error("Unknown encounter '%s'." % encounter_name)
        return HutRun.FIGHT_WON
    var fighters: Array[HeroState] = run.party.fighters()
    for h in run.party.heroes:
        if not fighters.has(h):
            run.log.record("sits_out", "%s sits out (%s)." % [h.name, "Down" if h.down else "no cards in deck"], {"hero": h.hero_id})
    if fighters.is_empty():
        run.log.record("nobody_fights", "Nobody can fight.", {})
        return HutRun.FIGHT_WIPE
    for h in run.party.heroes:
        run.party.clear_battle_state(h)
    var battle := Battle.new(run.rules, run.data["enemies"], run.next_seed(), run.battle_decisions)
    battle.dm_mode = run.dm_mode
    battle.continue_uids(run.party.last_uid())
    battle.log.listeners.append(run.forward_event)
    BattleSetup.add_heroes(battle, fighters, run.formation)
    BattleSetup.add_encounter(battle, encounter)
    var result: String = battle.run()
    run.last_battle = battle
    for h in run.party.heroes:
        run.party.clear_battle_state(h)
    run.party.continue_uids(battle.last_uid())
    match result:
        Battle.RESULT_HEROES:
            after_win(run, battle, rewards)
            return HutRun.FIGHT_WON
        Battle.RESULT_DRAW:
            run.log.record("enemies_withdraw", "The enemies withdraw: no loot, no XP (ruling #65).", {})
            return HutRun.FIGHT_WITHDREW
    return HutRun.FIGHT_WIPE

## RULES §8 After a won battle: bandage every hero (Down heroes too), patch up, loot and XP.
static func after_win(run: HutRun, battle: Battle, rewards: bool) -> void:
    var after: Dictionary = run.rules.get("after_battle", {})
    for h in run.party.heroes:
        var was_down: bool = h.down
        var healed: int = run.party.heal_wounds(h, int(after.get("bandage_wounds", 2)))
        if was_down and bool(after.get("bandage_revives_down", true)) and not h.is_spent():
            h.down = false
        if healed > 0 or was_down:
            run.log.record("bandage", "%s bandages %d Wound%s%s." % [h.name, healed, "" if healed == 1 else "s", " and gets up" if was_down and h.standing else ""],
                {"hero": h.hero_id, "healed": healed, "up": was_down and h.standing})
    PatchUp.play(run, run.next_seed(), run.forward_event)
    if not rewards:
        return
    var draw2: bool = false
    for e in battle.enemies:
        if int(e.def.get("draw", 1)) >= 2:
            draw2 = true
    run.loot(int(after.get("loot_if_draw2_monster", 2)) if draw2 else int(after.get("loot", 1)), "battle won")
    run.gain_xp(int(after.get("xp", 1)), "battle won")
