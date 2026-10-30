extends GutTest

## RULES §8 Room types, Traps, Camping, Backtracking; §10 Room decks, Special tiles, Hut track and
## Hut Whims (HutRun): rooms resolve once, optional rooms wait, traps, locks and retries, the key
## and the Inner Study, the waking Hut, Whims at 3/6/9 without repeats, Keyhole and Crooked
## Corridor, camping and the wandering checks. Battles are recorded by a stub fight runner.

var run: HutRun
var provider: ScriptedRunProvider
var fights: Array = []

func before_each():
    provider = ScriptedRunProvider.new()
    run = HutRun.new(BattleFixture.data(), 1, provider)
    fights = []
    run.fight_runner = func(_r: HutRun, encounter: String, rewards: bool) -> String:
        fights.append("%s%s" % [encounter, "" if rewards else " (no rewards)"])
        return HutRun.FIGHT_WON

func _entry(id: String) -> Dictionary:
    for def in run.module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": false}
    return {"def": run.explorer.special_def(id), "moon": false}

## A room tile off on its own (rooms resolve without needing a path).
func _room(id: String, at: Vector2i = Vector2i(10, 10)) -> PlacedTile:
    return run.explorer.map.add(TilePlacement.make(_entry(id), 0, at, null, {}))

func _hero(id: String) -> HeroState:
    return run.party.hero(id)

func _top(h: HeroState, skill: int) -> void:
    for c in BattleFixture.data()["heroes"][h.hero_id]["deck"]:
        if int(c["skill"]) == skill:
            h.deck.append(Card.new(run.party.new_uid(), c))
            return

func test_a_lair_draws_a_lair_card_and_fights_it_once():
    run.room_decks.stack("lair", "ogre_and_goblins")
    var lair: PlacedTile = _room("lair_den")
    assert_eq(run.enter_room(lair), HutRun.ROOM_RESOLVED)
    assert_eq(fights, ["tough"])
    assert_eq(run.enter_room(lair), HutRun.ROOM_REVISITED, "re-entering never resolves it again")
    assert_eq(fights.size(), 1)

func test_a_vault_chest_draws_two_loot():
    run.room_decks.stack("vault", "chest")
    run.enter_room(_room("vault"))
    assert_eq(run.loot_drawn, 2)

func test_a_library_lock_can_be_retried_and_each_failure_raises_the_hut():
    run.room_decks.stack("library", "rune_lock")
    var wizard: HeroState = _hero("wizard")
    _top(wizard, 6)
    _top(wizard, 1)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.RETRY, true)
    provider.then(RunRequest.ROLLER, wizard).then(RunRequest.ROLLER, wizard)
    run.enter_room(_room("library_long"))
    assert_eq(run.explorer.hut_track, 1, "the first try failed")
    assert_eq(run.loot_drawn, 1, "the retry opened it")

func test_a_locked_chest_allows_one_retry_only():
    run.room_decks.stack("vault", "locked_chest")
    var thief: HeroState = _hero("thief")
    _top(thief, 1)
    _top(thief, 1)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.RETRY, true).then(RunRequest.RETRY, true)
    provider.then(RunRequest.ROLLER, thief).then(RunRequest.ROLLER, thief)
    var vault: PlacedTile = _room("vault")
    assert_eq(run.enter_room(vault), HutRun.ROOM_RESOLVED)
    assert_eq(run.explorer.hut_track, 2)
    assert_eq(provider.requests_of(RunRequest.RETRY).size(), 1, "no second retry is offered")
    assert_true(run.log.has_type("lock_jammed"))
    assert_eq(run.loot_drawn, 0)

func test_an_unspotted_trap_springs_on_the_leader():
    run.room_decks.stack("dark", "pit")
    run.enter_room(_room("dark_small"))
    assert_eq(_hero("fighter").armor_damage, 2, "Pit: 2 damage to the Fighter's armor")

func test_a_spotted_trap_can_be_disarmed_for_its_salvage():
    run.room_decks.stack("dark", "falling_ceiling")
    _top(_hero("wizard"), 6)
    _top(_hero("thief"), 6)
    provider.then(RunRequest.SPOT_TRAP, true).then(RunRequest.DISARM, true)
    provider.then(RunRequest.ROLLER, _hero("wizard")).then(RunRequest.ROLLER, _hero("thief"))
    run.enter_room(_room("dark_small"))
    assert_eq(run.loot_drawn, 1)
    assert_eq(run.xp, 1, "disarming a Hard trap gives XP; spotting it doesn't")
    assert_eq(_hero("fighter").armor_damage, 0)

func test_a_failed_disarm_springs_the_trap_on_the_disarmer_who_may_dodge():
    run.room_decks.stack("dark", "pit")
    var thief: HeroState = _hero("thief")
    _top(_hero("wizard"), 6)
    _top(thief, 6)
    _top(thief, 1)
    provider.then(RunRequest.SPOT_TRAP, true).then(RunRequest.DISARM, true).then(RunRequest.DODGE, true)
    provider.then(RunRequest.ROLLER, _hero("wizard")).then(RunRequest.ROLLER, thief)
    run.enter_room(_room("dark_small"))
    assert_true(run.log.has_type("trap_dodged"), "the disarm failed, the dodge worked")
    assert_eq(thief.armor_damage, 0)
    assert_eq(run.explorer.hut_track, 1, "one failed roll")

func test_the_shrine_is_optional_and_waits_for_the_party_to_come_back():
    var shrine: PlacedTile = _room("shrine")
    assert_eq(run.enter_room(shrine), HutRun.ROOM_DECLINED)
    assert_false(bool(shrine.room_state.get("resolved", false)))
    run.damage_hero(_hero("fighter"), 7, "test")
    _top(_hero("cleric"), 6)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.ROLLER, _hero("cleric"))
    assert_eq(run.enter_room(shrine), HutRun.ROOM_RESOLVED)
    assert_eq(_hero("fighter").wound_count(), 0, "2 Wounds removed")
    assert_eq(_hero("fighter").armor_damage, 4, "1 armor repaired")

func test_a_declined_strange_font_stays_in_the_room():
    run.room_decks.stack("dark", "strange_font")
    var dark: PlacedTile = _room("dark_small")
    assert_eq(run.enter_room(dark), HutRun.ROOM_DECLINED)
    assert_eq(dark.room_state.get("card"), "strange_font")
    run.room_decks.stack("dark", "ambush")
    provider.then(RunRequest.ATTEMPT, true)
    run.enter_room(dark)
    assert_true(fights.is_empty(), "it is still the font, not a new card")
    assert_eq(run.log.of_type("room_card").back()["details"]["card"], "strange_font")

func test_the_pantry_gives_a_ration_and_the_workshop_the_key_and_its_guardians():
    run.enter_room(_room("pantry"))
    assert_eq(run.rations, 9)
    run.room_decks.stack("lair", "goblin_band")
    run.enter_room(_room("witchs_workshop", Vector2i(20, 20)))
    assert_true(run.explorer.has_key)
    assert_eq(fights, ["standard"])

func test_the_inner_study_stays_shut_without_the_key_and_opens_the_boss_with_it():
    var study: PlacedTile = _room("inner_study", Vector2i(30, 30))
    assert_eq(run.enter_room(study), HutRun.ROOM_SHUT)
    assert_ne(run.explorer.party_tile, study, "the party doesn't go in")
    run.explorer.has_key = true
    assert_eq(run.enter_room(study), HutRun.ROOM_BOSS)
    assert_true(run.boss_reached)

func test_once_the_hut_wakes_every_room_but_corridors_holds_a_lair_fight_first():
    run.awake = true
    run.room_decks.stack("lair", "skeleton_band")
    run.room_decks.stack("vault", "chest")
    run.enter_room(_room("vault"))
    assert_eq(fights, ["skeleton_band"])
    assert_eq(run.loot_drawn, 2, "then the room itself")
    run.enter_room(_room("corridor_straight", Vector2i(40, 40)))
    assert_eq(fights.size(), 1)

func test_whims_come_at_3_6_and_9_without_repeats():
    run.stack_whim("gingerbread_pantry")
    run.raise_hut(2, "test")
    assert_false(run.log.has_type("whim"))
    run.raise_hut(1, "test")
    assert_eq(run.log.of_type("whim").size(), 1)
    assert_eq(run.rations, 9)
    run.raise_hut(6, "test")
    assert_eq(run.log.of_type("whim").size(), 3, "6 and 9 crossed in one jump")
    var ids: Array = run.log.of_type("whim").map(func(e: Dictionary) -> String: return e["details"]["whim"])
    assert_eq(ids.size(), 3)
    assert_ne(ids[1], ids[0])
    assert_ne(ids[2], ids[1])
    assert_eq(run.whims.size(), 9)

func test_the_hut_wakes_at_10():
    run.raise_hut(10, "test")
    assert_true(run.awake)
    assert_true(run.log.has_type("hut_wakes"))

func test_bones_stir_attacks_without_rewards_and_the_black_cat_bargains():
    run.stack_whim("bones_stir")
    run.resolve_whim()
    assert_eq(fights, ["bones_stir (no rewards)"])
    run.stack_whim("black_cat")
    provider.then(RunRequest.ACCEPT, true)
    run.resolve_whim()
    assert_eq(run.explorer.hut_track, 1)
    assert_eq(run.loot_drawn, 1)

func test_locked_in_rolls_until_it_succeeds_each_failure_raising_the_hut():
    var fighter: HeroState = _hero("fighter")
    _top(fighter, 6)
    _top(fighter, 2)
    _top(fighter, 1)
    provider.then(RunRequest.ROLLER, fighter).then(RunRequest.ROLLER, fighter).then(RunRequest.ROLLER, fighter)
    run.stack_whim("locked_in")
    run.resolve_whim()
    assert_eq(run.explorer.hut_track, 2)
    assert_true(run.log.has_type("unlocked"))

func test_locked_in_breaks_on_its_own_with_hut_plus_1_when_nobody_can_roll():
    for h in run.party.heroes:
        h.discard.append_array(h.deck)
        h.deck.clear()
    run.stack_whim("locked_in")
    run.resolve_whim()
    assert_true(run.log.has_type("seal_breaks"), "ruling #72: the seal breaks rather than leaving the party stuck")
    assert_eq(run.explorer.hut_track, 1)
    assert_eq(run.party.can_roll().size(), 0, "nothing was flipped")

func test_failed_lock_rolls_until_the_track_crosses_3_resolve_the_whim_at_once():
    # Ruling #71: Hut 2 -> a failed retry -> 3 draws a Whim mid-room, before the next retry.
    run.explorer.hut_track = 2
    run.stack_whim("bones_stir")
    run.room_decks.stack("library", "rune_lock")
    var wizard: HeroState = _hero("wizard")
    _top(wizard, 6)
    _top(wizard, 1)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.RETRY, true)
    provider.then(RunRequest.ROLLER, wizard).then(RunRequest.ROLLER, wizard)
    run.enter_room(_room("library_long"))
    assert_eq(fights, ["bones_stir (no rewards)"])
    var types: Array = run.log.entries.map(func(e: Dictionary) -> String: return e["type"])
    assert_lt(types.find("whim"), types.rfind("skill_roll"), "the Whim came before the retry")

func test_doors_slam_leaves_one_open_doorway_and_vanishing_door_closes_one():
    run.stack_whim("doors_slam")
    run.resolve_whim()
    assert_eq(run.explorer.party_doorways().size(), 1)
    run.stack_whim("vanishing_door")
    run.resolve_whim()
    assert_eq(run.explorer.party_doorways().size(), 0)

func test_keyhole_shows_the_tile_before_the_doorway_is_chosen():
    run.keyhole = true
    var next_id: String = run.explorer.bag.entries.back()["def"]["id"]
    run.explore_step()
    var asked: Array[RunRequest] = provider.requests_of(RunRequest.DOORWAY)
    assert_eq(asked.size(), 1)
    assert_eq(asked[0].details["peeked"], next_id)
    assert_eq(run.log.of_type("tile_placed").back()["details"]["id"], next_id)

func test_crooked_corridor_lays_the_next_tile_as_far_from_the_front_door_as_it_can():
    var hall: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry("lair_long_hall"), run.explorer.party_doorways()[0])[0])
    hall.explored = true
    hall.room_state["resolved"] = true
    run.explorer.crooked = true
    run.explore_step()
    assert_true(provider.requests_of(RunRequest.DOORWAY).is_empty(), "the Hut decides where it goes")
    var placed: Dictionary = run.log.of_type("tile_placed").back()["details"]
    var far: int = 0
    for c in placed["cells"]:
        far = maxi(far, (c as Vector2i).y)
    assert_gt(far, 2, "beyond the long hall's far end")

func test_camping_costs_a_ration_each_raises_the_hut_resets_and_checks_for_wanderers():
    var camp: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry("empty_chamber"), run.explorer.party_doorways()[0])[0])
    camp.explored = true
    run.damage_hero(_hero("fighter"), 7, "test")
    assert_eq(run.camp(camp), "")
    assert_eq(run.rations, 4)
    assert_eq(run.explorer.hut_track, 1)
    assert_eq(_hero("fighter").wound_count(), 0)
    assert_eq(run.explorer.party_tile, camp, "the party walked there")
    assert_true(run.log.has_type("wandering_check"))
    var value: int = int(run.log.of_type("wandering_check")[0]["details"]["value"])
    assert_eq(fights, ["wandering (no rewards)"] if value <= 3 else [])

func test_camping_needs_a_campsite_and_enough_rations():
    var den: PlacedTile = _room("lair_den")
    den.explored = true
    assert_eq(run.camp(den), "not a campsite")
    var hearth: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry("hearth"), run.explorer.party_doorways()[0])[0])
    assert_eq(run.camp(hearth), "the party hasn't explored it")
    hearth.explored = true
    run.rations = 3
    assert_eq(run.camp(hearth), "not enough rations (3 for 4)")
    run.rations = 4
    assert_eq(run.camp(hearth), "")
    assert_false(run.log.has_type("wandering_check"), "no check at the Hearth")

func test_backtracking_flips_for_the_hero_with_the_most_cards_and_may_bring_wanderers():
    var east: MapDoorway = null
    for d in run.explorer.party_doorways():
        if d.side == "E":
            east = d
    var room: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry("dark_small"), east)[0])
    run.explorer.enter(room)
    room.room_state["resolved"] = true
    var wizard: HeroState = _hero("wizard")
    _top(wizard, 1)
    provider.then(RunRequest.DOORWAY, func(d: MapDoorway) -> bool: return d.tile == run.explorer.front_door and d.side == "N")
    run.explore_step()
    assert_true(run.log.has_type("backtrack"))
    var check: Dictionary = run.log.of_type("wandering_check")[0]["details"]
    assert_eq(check["hero"], "wizard", "a hand of 4 leaves 26 cards in deck plus the one on top: the most")
    assert_eq(check["value"], 1)
    assert_eq(fights[0], "wandering (no rewards)")

func test_every_hero_down_outside_battle_is_a_wipe():
    for h in run.party.heroes:
        run.damage_hero(h, 20, "test")
    run.check_wipe(null)
    assert_true(run.wiped)
