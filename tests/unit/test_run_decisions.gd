extends GutTest

## Milestone 4.5: run decisions go through the RunDecisionProvider (placements, the formation) and
## ExplorationAi's choices: rest or explore against the monsters left in the Hut deck, camp or walk
## out, doorways, placements, optional rolls, dodging, the formation.

var run: HutRun
var provider: ScriptedRunProvider

func before_each():
    provider = ScriptedRunProvider.new()
    run = HutRun.new(BattleFixture.data(), 1, provider)
    run.fight_runner = func(_r: HutRun, _e: String, _rw: bool) -> String: return HutRun.FIGHT_WON

func _entry(id: String) -> Dictionary:
    for def in run.module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": false}
    return {"def": run.explorer.special_def(id), "moon": false}

func _door(side: String) -> MapDoorway:
    for d in run.explorer.party_doorways():
        if d.side == side:
            return d
    return null

func _request(kind: String, options: Array, details: Dictionary = {}, hero: HeroState = null) -> RunRequest:
    return RunRequest.new(kind, hero, options, details)

# ------------------------------------------------------------------ decisions through the provider

func test_the_party_chooses_among_legal_placements():
    var options: Array[TilePlacement] = run.explorer.placement_options(_entry("root_cellar"), _door("E"))
    assert_eq(options.size(), 3)
    run.explorer.bag.entries.push_back(_entry("root_cellar"))
    provider.then(RunRequest.DOORWAY, func(d: MapDoorway) -> bool: return d.side == "E")
    provider.then(RunRequest.PLACEMENT, func(p: TilePlacement) -> bool: return p.rotation == options[2].rotation)
    run.explore_step()
    assert_eq(provider.requests_of(RunRequest.PLACEMENT).size(), 1)
    assert_eq(run.explorer.map.tiles.back().rotation, options[2].rotation)

func test_the_formation_is_chosen_when_the_run_starts():
    provider.then(RunRequest.FORMATION, "back_row").then(RunRequest.ACTION, HutRun.ACT_LEAVE)
    run.play()
    assert_eq(provider.requests_of(RunRequest.FORMATION)[0].options, ["default", "back_row"])
    assert_eq(run.formation, run.rules["formations"]["back_row"])
    assert_true(run.log.has_type("formation"))

func test_the_back_row_formation_puts_three_heroes_in_the_back_row_and_the_fighter_before_them():
    var back: Dictionary = run.rules["formations"]["back_row"]
    var rows: Array = ["fighter", "thief", "cleric", "wizard"].map(func(id: String) -> int: return int(back[id][0]))
    assert_eq(rows, [1, 2, 2, 2])
    assert_eq(run.set_formation(back), "")

# ------------------------------------------------------------------ ExplorationAi

func test_the_ai_picks_its_formation_or_the_default():
    var ai := ExplorationAi.new()
    var options: Array = ["default", "back_row"]
    assert_eq(ai.decide(_request(RunRequest.FORMATION, options), run), 0)
    ai.formation_name = "back_row"
    assert_eq(ai.decide(_request(RunRequest.FORMATION, options), run), 1)

func test_the_monster_chance_counts_the_hut_cards_not_yet_seen():
    assert_almost_eq(ExplorationAi.monster_chance(run), 9.0 / 21.0, 0.001)
    for id in ["goblin_band", "goblin_band", "chest"]:
        run.hut_deck.discard(run.hut_deck.card(id))
    assert_almost_eq(ExplorationAi.monster_chance(run), 7.0 / 18.0, 0.001)

func test_a_fresh_party_explores_and_a_worn_one_camps_or_walks_out():
    var ai := ExplorationAi.new()
    var all: Array = [HutRun.ACT_EXPLORE, HutRun.ACT_CAMP, HutRun.ACT_LEAVE]
    assert_eq(ai.decide(_request(RunRequest.ACTION, all), run), 0, "fresh: explore")
    for h in run.party.heroes:
        h.armor_damage = h.armor_slots
    assert_true(ExplorationAi.needs_rest(run), "no armor left")
    assert_eq(ai.decide(_request(RunRequest.ACTION, all), run), 1, "camp")
    assert_eq(ai.decide(_request(RunRequest.ACTION, [HutRun.ACT_EXPLORE, HutRun.ACT_LEAVE]), run), 1, "no campsite: walk out")
    run.explorer.hut_track = 8
    assert_eq(ai.decide(_request(RunRequest.ACTION, all), run), 2, "too close to eviction to camp")

func test_with_nothing_left_to_explore_the_ai_walks_out():
    var ai := ExplorationAi.new()
    assert_eq(ai.decide(_request(RunRequest.ACTION, [HutRun.ACT_CAMP, HutRun.ACT_LEAVE]), run), 1)

func test_the_armor_the_ai_wants_grows_with_the_monsters_left():
    for h in run.party.heroes:
        h.armor_damage = int(h.armor_slots * 0.7)
    var left: float = float(run.party.armor_left()) / 11.0
    assert_true(left > 0.2 and left < 0.5, "about a third of the armor left")
    for c in run.module["hut_deck"]:
        var fights: bool = c["effects"].any(func(e: Dictionary) -> bool: return e["op"] == "fight")
        for i in range(int(c["qty"]) if fights else 0):
            run.hut_deck.discard(c)
    assert_false(ExplorationAi.needs_rest(run), "no monsters left in the Hut deck: keep going")

func test_the_ai_takes_the_doorway_with_the_least_walking():
    var ai := ExplorationAi.new()
    var doors: Array = run.explorer.party_doorways()
    assert_eq(ai.decide(_request(RunRequest.DOORWAY, doors, {"walk": [2, 0, 1]}), run), 1)
    assert_eq(ai.decide(_request(RunRequest.CAMPSITE, [null, null], {"walk": [3, 1]}), run), 1)

func test_the_ai_picks_a_placement_that_opens_the_most_doorways():
    var ai := ExplorationAi.new()
    var options: Array[TilePlacement] = run.explorer.placement_options(_entry("great_hall"), _door("N"))
    assert_gt(options.size(), 1)
    var opened := func(p: TilePlacement) -> int:
        var n: int = 0
        for d in p.doors:
            var beyond: Vector2i = TileGeometry.facing_cell(d["cell"], d["side"])
            n += 1 if run.explorer.map.is_free(beyond) and not p.cells.has(beyond) else 0
        return n
    var chosen: TilePlacement = options[ai.decide(_request(RunRequest.PLACEMENT, options), run)]
    for p in options:
        assert_gte(opened.call(chosen), opened.call(p))

func test_optional_rolls_only_while_the_hut_track_has_room():
    var ai := ExplorationAi.new()
    var yes_no: Array = [false, true]
    assert_eq(ai.decide(_request(RunRequest.ATTEMPT, yes_no, {"type": "agility", "target": 5}), run), 1)
    assert_eq(ai.decide(_request(RunRequest.SPOT_TRAP, yes_no, {"target": 4}), run), 1)
    assert_eq(ai.decide(_request(RunRequest.ACCEPT, yes_no), run), 1)
    run.explorer.hut_track = 8
    assert_eq(ai.decide(_request(RunRequest.ATTEMPT, yes_no, {"type": "agility", "target": 5}), run), 0)
    assert_eq(ai.decide(_request(RunRequest.SPOT_TRAP, yes_no, {"target": 4}), run), 1, "2 below eviction: still worth a look")
    assert_eq(ai.decide(_request(RunRequest.ACCEPT, yes_no), run), 0)

func test_dodging_with_the_thief_or_when_the_trap_would_reach_the_hand():
    var ai := ExplorationAi.new()
    var yes_no: Array = [false, true]
    var fighter: HeroState = run.party.hero("fighter")
    assert_eq(ai.decide(_request(RunRequest.DODGE, yes_no, {"target": 4}, run.party.hero("thief")), run), 1)
    assert_eq(ai.decide(_request(RunRequest.DODGE, yes_no, {"target": 4}, fighter), run), 0, "armor will take it")
    fighter.armor_damage = fighter.armor_slots - 1
    assert_eq(ai.decide(_request(RunRequest.DODGE, yes_no, {"target": 4}, fighter), run), 1)

func test_a_whole_run_with_the_exploration_ai_replays_exactly_from_its_seed():
    var texts: Array[String] = []
    for i in range(2):
        var r := HutRun.new(BattleFixture.data(), 5, ExplorationAi.new())
        r.battle_decisions = TacticalAiProvider.new()
        r.play()
        texts.append(r.log.to_text())
    assert_eq(texts[0], texts[1])
    assert_gt(texts[0].length(), 1000)
