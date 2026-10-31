extends GutTest

## RULES §8 Battles in a run, After a won battle, Wandering monsters; ruling #65 (RunFight, PatchUp)
## and the run loop (HutRun.play): battles use the party's carried state, sitting-out heroes,
## bandage and patch up after wins, loot and XP except from wandering fights, a loss is a wipe, the
## round cap makes the enemies withdraw, the party's formation, leaving and the boss.

## Hero AI that never patches up, so tests can watch the carried state.
class NoPatchAi extends TacticalAiProvider:
    func decide(request: DecisionRequest, battle: Battle) -> int:
        return 0 if request.kind == DecisionRequest.PATCH_UP else super.decide(request, battle)

## Records the patch-up offers and stops.
class PatchRecorder extends DecisionProvider:
    var offers: Array = []
    func decide(request: DecisionRequest, _battle: Battle) -> int:
        if request.kind == DecisionRequest.PATCH_UP:
            offers.append(request.options.duplicate())
        return 0

var run: HutRun
var provider: ScriptedRunProvider
var at_start: Dictionary = {}

func before_each():
    provider = ScriptedRunProvider.new()
    run = HutRun.new(BattleFixture.data(), 3, provider)
    run.rules = run.rules.duplicate(true)  # some tests change rule numbers
    run.battle_decisions = NoPatchAi.new()
    run.dm_mode = Battle.DM_AUTOMATED
    at_start = {}
    run.log.listeners.append(func(entry: Dictionary) -> void:
        if entry["type"] == "battle_start" and at_start.is_empty():
            for h in run.party.heroes:
                at_start[h.hero_id] = {"armor": h.armor_damage, "wounds": h.wound_count(), "discard": h.discard.size(),
                    "exhausted": h.exhausted.size(), "guard": h.guard_tokens, "stunned": h.stunned, "statuses": h.statuses.size(),
                    "cells": h.cells.duplicate()})

func _hero(id: String) -> HeroState:
    return run.party.hero(id)

func _card(h: HeroState, card_id: String) -> Card:
    for c in BattleFixture.data()["heroes"][h.hero_id]["deck"]:
        if c["id"] == card_id:
            return Card.new(run.party.new_uid(), c)
    return null

func _wound(h: HeroState, n: int = 1) -> void:
    for i in range(n):
        h.hand.append(Card.make_wound(run.party.new_uid()))

func _set_hand(h: HeroState, cards: Array) -> void:
    h.hand.clear()
    for c in cards:
        h.hand.append(c)

func _keep_only_wounds(h: HeroState) -> void:
    var wounds: Array = []
    for c in h.hand:
        if c.is_wound:
            wounds.append(c)
    _set_hand(h, wounds)

func _offered_cards(offers: Array) -> Array:
    var ids: Array = []
    for list in offers:
        for option in list:
            if not option.is_empty():
                ids.append((option["card"] as Card).id)
    return ids

func _empty_deck(h: HeroState) -> void:
    h.discard.append_array(h.deck)
    h.deck.clear()

func _entry(id: String) -> Dictionary:
    for def in run.module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": false}
    return {"def": run.explorer.special_def(id), "moon": false}

# ------------------------------------------------------------------ carried state

func test_a_battle_starts_from_the_party_s_carried_state():
    var fighter: HeroState = _hero("fighter")
    var cleric: HeroState = _hero("cleric")
    fighter.armor_damage = 2
    _wound(cleric, 1)
    for i in range(4):
        cleric.discard.append(cleric.deck.pop_back())
    cleric.exhausted.append(cleric.deck.pop_back())
    assert_eq(run.fight("bones_stir", false), HutRun.FIGHT_WON)
    assert_eq(at_start["fighter"]["armor"], 2, "armor damage carried in")
    assert_eq(at_start["cleric"]["wounds"], 1, "Wounds carried in")
    assert_eq(at_start["cleric"]["discard"], 4, "the discard pile carried in")
    assert_eq(at_start["cleric"]["exhausted"], 1, "Exhausted cards carried in")
    assert_true(run.last_battle.heroes.has(fighter), "the party's own heroes fight")
    assert_gte(cleric.discard.size() + cleric.exhausted.size(), 5, "and the piles carry out again")

func test_battle_effects_end_with_each_battle():
    var fighter: HeroState = _hero("fighter")
    fighter.guard_tokens = 3
    fighter.guard_expires_round = 5
    fighter.stunned = true
    fighter.statuses["berserk"] = {"damage_bonus": 1}
    run.fight("bones_stir", false)
    assert_eq(at_start["fighter"]["guard"], 0)
    assert_false(at_start["fighter"]["stunned"])
    assert_eq(at_start["fighter"]["statuses"], 0)
    for h in run.party.heroes:
        assert_eq(h.cells.size(), 0, "off the board after the battle")
        assert_eq(h.statuses.size(), 0)
    assert_eq(run.last_battle.heroes.size(), 4)

func test_down_heroes_and_empty_decks_sit_out_and_bandaging_gets_the_down_hero_up():
    var thief: HeroState = _hero("thief")
    var wizard: HeroState = _hero("wizard")
    _empty_deck(thief)
    wizard.down = true
    assert_eq(run.fight("bones_stir", false), HutRun.FIGHT_WON)
    assert_eq(run.last_battle.heroes.size(), 2, "only the Fighter and the Cleric fight")
    assert_false(run.last_battle.heroes.has(thief))
    assert_eq(run.log.of_type("sits_out").size(), 2)
    assert_true(wizard.standing, "bandaging after a won battle gets Down heroes up")

func test_if_nobody_can_fight_it_is_a_wipe():
    for h in run.party.heroes:
        _empty_deck(h)
    assert_eq(run.fight("wandering", false), HutRun.FIGHT_WIPE)
    assert_true(run.wiped)
    assert_true(run.log.has_type("nobody_fights"))

func test_losing_a_battle_is_a_wipe():
    for id in ["cleric", "thief", "wizard"]:
        _hero(id).down = true
    var fighter: HeroState = _hero("fighter")
    fighter.armor_damage = fighter.armor_slots
    _set_hand(fighter, [fighter.hand[0]])
    _wound(fighter, 4)
    run.dm_mode = Battle.DM_RUTHLESS
    assert_eq(run.fight("tough", true), HutRun.FIGHT_WIPE)
    assert_true(run.wiped)
    assert_eq(run.loot_drawn, 0)

func test_at_the_round_cap_the_enemies_withdraw_without_loot_xp_or_bandage():
    run.rules["battle"]["round_cap"] = 1
    _wound(_hero("wizard"), 1)
    assert_eq(run.fight("tough", true), HutRun.FIGHT_WITHDREW)
    assert_false(run.wiped)
    assert_eq(run.loot_drawn, 0)
    assert_eq(run.xp, 0)
    assert_false(run.log.has_type("bandage"), "not a won battle (open question #76)")

func test_wound_cards_from_battle_never_reuse_the_party_s_card_uids():
    _hero("fighter").armor_damage = _hero("fighter").armor_slots
    run.fight("tough", true)
    var seen: Dictionary = {}
    for h in run.party.heroes:
        for c in h.deck + h.hand + h.discard + h.exhausted:
            assert_false(seen.has(c.uid), "uid %d appears once" % c.uid)
            seen[c.uid] = true

# ------------------------------------------------------------------ after a won battle

func _won_battle(encounter: String) -> Battle:
    var battle := Battle.new(run.rules, run.data["enemies"], 1, run.battle_decisions)
    BattleSetup.add_encounter(battle, run.data["encounters"][encounter])
    return battle

func test_bandage_removes_2_wounds_from_every_hero_with_replacements():
    var cleric: HeroState = _hero("cleric")
    for i in range(3):
        cleric.discard.append(cleric.hand.pop_back())
    _wound(cleric, 3)
    var deck_before: int = cleric.deck.size()
    RunFight.after_win(run, _won_battle("standard"), true)
    assert_eq(cleric.wound_count(), 1)
    assert_eq(cleric.hand.size(), cleric.hand_size, "each healed Wound is replaced by a draw")
    assert_eq(cleric.deck.size(), deck_before - 2)

func test_a_won_fight_gives_loot_and_xp_and_a_draw_2_monster_gives_2_loot():
    RunFight.after_win(run, _won_battle("standard"), true)
    assert_eq(run.loot_drawn, 1)
    assert_eq(run.xp, 1)
    RunFight.after_win(run, _won_battle("tough"), true)
    assert_eq(run.loot_drawn, 3, "the ogre draws 2")
    assert_eq(run.xp, 2)

func test_wandering_fights_give_no_loot_or_xp_but_still_bandage():
    _wound(_hero("thief"), 2)
    assert_eq(run.fight("wandering", false), HutRun.FIGHT_WON)
    assert_eq(run.loot_drawn, 0)
    assert_eq(run.xp, 0)
    assert_true(run.log.has_type("bandage"))

func test_patch_up_fix_armor_between_battles_removes_all_armor_damage():
    run.battle_decisions = TacticalAiProvider.new()
    var fighter: HeroState = _hero("fighter")
    fighter.armor_damage = 4
    fighter.hand.append(_card(fighter, "fix_armor"))
    RunFight.after_win(run, _won_battle("standard"), false)
    assert_eq(fighter.armor_damage, 0, "Fix Armor's between-battles text")
    assert_true(run.log.has_type("patch_up"))

func test_patch_up_offers_only_healing_cards_and_adjacency_uses_the_formation():
    var recorder := PatchRecorder.new()
    run.battle_decisions = recorder
    var cleric: HeroState = _hero("cleric")
    var wizard: HeroState = _hero("wizard")
    _set_hand(cleric, [_card(cleric, "mend"), _card(cleric, "smite")])
    for h in run.party.heroes:
        if h != cleric:
            _keep_only_wounds(h)
    _wound(wizard, 3)  # bandaging removes 2 first
    RunFight.after_win(run, _won_battle("standard"), false)
    assert_false(_offered_cards(recorder.offers).has("mend"), "Mend can't reach the Wizard at the back (Cleric front right, Wizard back centre)")
    assert_eq(wizard.wound_count(), 1)
    assert_eq(run.set_formation({"fighter": [0, 1], "cleric": [0, 2], "thief": [0, 0], "wizard": [1, 2]}), "")
    _wound(wizard, 2)
    recorder.offers.clear()
    RunFight.after_win(run, _won_battle("standard"), false)
    assert_true(_offered_cards(recorder.offers).has("mend"), "now the Wizard stands next to the Cleric")
    assert_false(_offered_cards(recorder.offers).has("smite"), "Smite is no patch-up card")

# ------------------------------------------------------------------ formation

func test_the_party_fights_in_its_formation():
    assert_eq(run.set_formation({"fighter": [2, 0], "cleric": [2, 1], "thief": [2, 2], "wizard": [1, 1]}), "")
    run.fight("bones_stir", false)
    assert_eq(at_start["fighter"]["cells"], [Field.cell_for(FigureState.SIDE_HEROES, 2, 0)])
    assert_eq(at_start["wizard"]["cells"], [Field.cell_for(FigureState.SIDE_HEROES, 1, 1)])

func test_a_formation_needs_every_hero_on_a_different_square_of_the_board():
    var before: Dictionary = run.formation.duplicate(true)
    assert_eq(run.set_formation({"fighter": [0, 0], "cleric": [0, 0], "thief": [1, 0], "wizard": [2, 0]}), "Fighter and Cleric share a square")
    assert_eq(run.set_formation({"fighter": [0, 3], "cleric": [0, 0], "thief": [1, 0], "wizard": [2, 0]}), "Fighter's square isn't on the hero board")
    assert_eq(run.set_formation({"fighter": [0, 1], "cleric": [0, 0], "thief": [1, 0]}), "Wizard has no square")
    assert_eq(run.formation, before, "nothing changed")

# ------------------------------------------------------------------ the run loop

func test_walking_out_ends_the_run_with_the_walking_out_xp():
    provider.then(RunRequest.ACTION, HutRun.ACT_LEAVE)
    assert_eq(run.play(), HutRun.RUN_LEFT)
    assert_eq(run.xp, 2)
    assert_true(run.log.has_type("run_end"))

func test_a_wipe_ends_the_run_and_its_finds_are_lost():
    run.fight_runner = func(_r: HutRun, _e: String, _rw: bool) -> String: return HutRun.FIGHT_WIPE
    run.hut_deck.stack("goblin_band")
    run.explorer.bag.entries.push_back(_entry("well_room"))
    provider.then(RunRequest.ACTION, HutRun.ACT_EXPLORE)
    assert_eq(run.play(), HutRun.RUN_WIPE)
    assert_eq(String(run.log.of_type("run_end")[0]["message"]).contains("(lost)"), true)

func test_camping_is_offered_only_in_an_explored_campsite_with_enough_rations():
    assert_false(run.actions().has(HutRun.ACT_CAMP))
    var kitchen: PlacedTile = run.explorer.map.add(TilePlacement.make(_entry("kitchen"), 0, Vector2i(0, 1), null, {}))
    kitchen.explored = true
    if run.explorer.map.connected(kitchen, run.explorer.front_door):
        assert_true(run.actions().has(HutRun.ACT_CAMP), "the Kitchen is always a campsite")
        run.rations = 3
        assert_false(run.actions().has(HutRun.ACT_CAMP), "4 heroes need 4 rations")
    else:
        fail_test("the kitchen should connect to the Front Door's north doorway")

func test_with_every_component_the_inner_study_comes_out_of_the_bag_and_the_run_stops_at_the_boss():
    for c in run.module["components"]:
        run.gain_component(String(c["id"]))
    var bag: Array[Dictionary] = run.explorer.bag.entries
    var study: Dictionary = {}
    for e in bag:
        if e["def"]["id"] == "inner_study":
            study = e
    assert_false(study.is_empty(), "the fourth component put it in the bag")
    bag.erase(study)
    bag.push_back(study)
    provider.then(RunRequest.ACTION, HutRun.ACT_EXPLORE)
    assert_eq(run.play(), HutRun.RUN_BOSS)

func test_a_whole_run_replays_exactly_from_its_seed():
    var texts: Array[String] = []
    for i in range(2):
        var r := HutRun.new(BattleFixture.data(), 11, SimpleRunAi.new())
        r.battle_decisions = TacticalAiProvider.new()
        r.play()
        texts.append(r.log.to_text())
    assert_eq(texts[0], texts[1])
    assert_gt(texts[0].length(), 1000)
