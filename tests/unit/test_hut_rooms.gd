extends GutTest

## RULES §8 Room types, Walking through the Hut, Leaving, Traps, Camping; §10 Components, Hut track,
## Hut Whims and the Hut deck (HutRun): rooms resolve once (Whim, then Hut card), component rooms
## and their guardians, the Kitchen and the Baths, the Inner Study entering the bag, Whims printed
## on rooms, locked chests and traps, walking checks per tile, the Hut waking and throwing the party
## out, camping. Battles are recorded by a stub fight runner.

var run: HutRun
var provider: ScriptedRunProvider
var fights: Array = []

func before_each():
    _new_run([])

func _new_run(components: Array) -> void:
    provider = ScriptedRunProvider.new()
    run = HutRun.new(BattleFixture.data(), 1, provider, components)
    fights = []
    run.fight_runner = func(_r: HutRun, encounter: String, rewards: bool) -> String:
        fights.append("%s%s" % [encounter, "" if rewards else " (no rewards)"])
        return HutRun.FIGHT_WON

func _entry(id: String, moon: bool = false) -> Dictionary:
    for def in run.module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": moon}
    return {"def": run.explorer.special_def(id), "moon": false}

## A room tile off on its own (rooms resolve without needing a path).
func _room(id: String, at: Vector2i = Vector2i(10, 10)) -> PlacedTile:
    return run.explorer.map.add(TilePlacement.make(_entry(id), 0, at, null, {}))

## A room joined to `doorway`, explored.
func _joined(id: String, doorway: MapDoorway) -> PlacedTile:
    var t: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry(id), doorway)[0])
    t.explored = true
    t.room_state["resolved"] = true
    return t

func _door(tile: PlacedTile, side: String) -> MapDoorway:
    for d in run.explorer.map.open_doorways(tile):
        if d.side == side:
            return d
    return null

func _hero(id: String) -> HeroState:
    return run.party.hero(id)

func _top(h: HeroState, skill: int) -> void:
    for c in BattleFixture.data()["heroes"][h.hero_id]["deck"]:
        if int(c["skill"]) == skill:
            h.deck.append(Card.new(run.party.new_uid(), c))
            return

func _empty_deck(h: HeroState) -> void:
    h.discard.append_array(h.deck)
    h.deck.clear()

func _bag_ids() -> Array:
    return run.explorer.bag.entries.map(func(x: Dictionary) -> String: return x["def"]["id"])

func _types() -> Array:
    return run.log.entries.map(func(e: Dictionary) -> String: return e["type"])

## The Terrarium north of the Front Door and the Well Room beyond it; the party in the Well Room.
func _two_rooms_north() -> Array[PlacedTile]:
    var terrarium: PlacedTile = run.explorer.map.add(TilePlacement.make(_entry("terrarium"), 0, Vector2i(0, 1), null, {}))  # (0,1)-(0,2), doorways S, E, N
    var well: PlacedTile = run.explorer.map.add(TilePlacement.make(_entry("well_room"), 0, Vector2i(0, 3), null, {}))     # doorways S, E
    for t in [terrarium, well]:
        t.explored = true
        t.room_state["resolved"] = true
    run.explorer.party_tile = well
    assert_eq(run.explorer.map.route(well, run.explorer.front_door), [terrarium, run.explorer.front_door] as Array[PlacedTile])
    return [terrarium, well]

# ------------------------------------------------------------------ rooms and the Hut deck

func test_a_room_without_a_whim_draws_a_hut_card_once():
    run.hut_deck.stack("ogre_and_goblins")
    var well: PlacedTile = _room("well_room")
    assert_eq(run.enter_room(well), HutRun.ROOM_RESOLVED)
    assert_eq(fights, ["tough"])
    assert_eq(run.enter_room(well), HutRun.ROOM_REVISITED, "re-entering never resolves it again")
    assert_eq(fights.size(), 1)
    assert_eq(run.log.of_type("hut_card").size(), 1)

func test_a_whim_room_resolves_its_whim_first_then_draws_a_hut_card():
    run.hut_deck.stack("chest")
    run.enter_room(_room("garden"))
    assert_eq(run.rations, 9, "Gingerbread Garden")
    assert_eq(run.loot_drawn, 2, "then the chest")
    assert_lt(_types().find("whim"), _types().find("hut_card"))
    assert_eq(run.log.of_type("whim")[0]["details"]["whim"], "gingerbread_garden")

func test_a_quiet_room_does_nothing_and_an_abandoned_pack_gives_one_loot():
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("potion_store"))
    assert_eq(run.loot_drawn, 0)
    run.hut_deck.stack("abandoned_pack")
    run.enter_room(_room("bone_closet", Vector2i(20, 20)))
    assert_eq(run.loot_drawn, 1)

func test_the_hut_deck_holds_21_cards_and_reshuffles_when_empty():
    assert_eq(run.hut_deck.size(), 21)
    for i in range(21):
        run.hut_deck.discard(run.hut_deck.draw(run.rng))
    assert_eq(run.hut_deck.size(), 0)
    assert_false(run.hut_deck.draw(run.rng).is_empty(), "the discards come back")
    assert_eq(run.hut_deck.size(), 20)

func test_a_locked_chest_allows_one_retry_only():
    run.hut_deck.stack("locked_chest")
    var thief: HeroState = _hero("thief")
    _top(thief, 1)
    _top(thief, 1)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.RETRY, true).then(RunRequest.RETRY, true)
    provider.then(RunRequest.ROLLER, thief).then(RunRequest.ROLLER, thief)
    assert_eq(run.enter_room(_room("bone_closet")), HutRun.ROOM_RESOLVED)
    assert_eq(run.explorer.hut_track, 2)
    assert_eq(provider.requests_of(RunRequest.RETRY).size(), 1, "no second retry is offered")
    assert_true(run.log.has_type("lock_jammed"))
    assert_eq(run.loot_drawn, 0)

func test_an_opened_locked_chest_gives_3_loot_and_1_xp():
    run.hut_deck.stack("locked_chest")
    var thief: HeroState = _hero("thief")
    _top(thief, 6)
    provider.then(RunRequest.ATTEMPT, true).then(RunRequest.ROLLER, thief)
    run.enter_room(_room("bone_closet"))
    assert_eq(run.loot_drawn, 3)
    assert_eq(run.xp, 1, "Agility 5 is Hard")

func test_an_unspotted_trap_springs_on_the_leader():
    run.hut_deck.stack("pit")
    run.enter_room(_room("well_room"))
    assert_eq(_hero("fighter").armor_damage, 2, "Pit: 2 damage to the Fighter's armor")

func test_a_spotted_trap_can_be_disarmed_for_its_salvage():
    run.hut_deck.stack("falling_ceiling")
    _top(_hero("wizard"), 6)
    _top(_hero("thief"), 6)
    provider.then(RunRequest.SPOT_TRAP, true).then(RunRequest.DISARM, true)
    provider.then(RunRequest.ROLLER, _hero("wizard")).then(RunRequest.ROLLER, _hero("thief"))
    run.enter_room(_room("well_room"))
    assert_eq(run.loot_drawn, 1)
    assert_eq(run.xp, 1, "disarming a Hard trap gives XP; spotting it doesn't")
    assert_eq(_hero("fighter").armor_damage, 0)

func test_a_failed_disarm_springs_the_trap_on_the_disarmer_who_may_dodge():
    run.hut_deck.stack("poison_needle")
    var thief: HeroState = _hero("thief")
    _top(_hero("wizard"), 6)
    _top(thief, 6)
    _top(thief, 1)
    provider.then(RunRequest.SPOT_TRAP, true).then(RunRequest.DISARM, true).then(RunRequest.DODGE, true)
    provider.then(RunRequest.ROLLER, _hero("wizard")).then(RunRequest.ROLLER, thief)
    run.enter_room(_room("well_room"))
    assert_true(run.log.has_type("trap_dodged"), "the disarm failed, the dodge worked")
    assert_eq(thief.armor_damage, 0)
    assert_eq(run.explorer.hut_track, 1, "one failed roll")

func test_corridors_and_bedchambers_draw_no_hut_card():
    run.enter_room(_room("corridor_bend"))
    run.enter_room(_room("small_bedchamber", Vector2i(20, 20)))
    assert_false(run.log.has_type("hut_card"))
    assert_eq(run.hut_deck.size(), 21)

# ------------------------------------------------------------------ components

func test_a_component_room_fights_its_guardians_then_gives_the_component():
    assert_eq(run.enter_room(_room("library")), HutRun.ROOM_RESOLVED)
    assert_eq(fights, ["skeleton_band"], "the dusty dead, with loot and XP")
    assert_true(run.has_component("library"))
    assert_eq(run.found, ["library"] as Array[String])
    assert_false(run.log.has_type("hut_card"))
    assert_eq(run.log.of_type("fight")[0]["details"]["source"], "guardians")

func test_once_the_component_is_held_its_room_draws_a_hut_card_instead():
    _new_run(["armory"])
    run.hut_deck.stack("skeleton_band")
    run.enter_room(_room("armory"))
    assert_eq(fights, ["skeleton_band"], "the Hut card's band, not the ogre")
    assert_false(run.log.has_type("guardians"))
    assert_eq(run.found.size(), 0)

func test_the_kitchen_is_always_a_campsite_and_gives_a_ration_after_the_cooks():
    var kitchen: PlacedTile = _room("kitchen")
    assert_true(run.is_campsite(kitchen))
    run.enter_room(kitchen)
    assert_eq(fights, ["standard"], "the cooks")
    assert_eq(run.rations, 9)
    assert_true(run.has_component("kitchen"))

func test_the_baths_heal_every_hero_after_their_guardians():
    var fighter: HeroState = _hero("fighter")
    run.damage_hero(fighter, 7, "test")
    assert_eq(fighter.wound_count(), 2)
    run.enter_room(_room("baths"))
    assert_eq(fights, ["baths_guardians"])
    assert_eq(fighter.wound_count(), 0, "2 Wounds removed")
    assert_eq(fighter.armor_damage, fighter.armor_slots - 1, "1 armor repaired")
    assert_lt(_types().find("fight"), _types().find("repair"), "after the fight")

func test_the_baths_keep_their_healing_once_the_component_is_held():
    _new_run(["baths"])
    run.hut_deck.stack("quiet_room")
    _hero("cleric").armor_damage = 2
    run.enter_room(_room("baths"))
    assert_true(fights.is_empty())
    assert_eq(_hero("cleric").armor_damage, 1)

func test_guardians_that_withdraw_at_the_round_cap_leave_the_component():
    run.fight_runner = func(_r: HutRun, _e: String, _rw: bool) -> String: return HutRun.FIGHT_WITHDREW
    run.enter_room(_room("library"))
    assert_true(run.has_component("library"), "open question #81")

func test_a_wipe_against_the_guardians_ends_it_without_the_component():
    run.fight_runner = func(_r: HutRun, _e: String, _rw: bool) -> String: return HutRun.FIGHT_WIPE
    assert_eq(run.enter_room(_room("kitchen")), HutRun.ROOM_WIPE)
    assert_false(run.has_component("kitchen"))
    assert_eq(run.rations, 8, "no ration either")

func test_the_fourth_component_shuffles_the_inner_study_into_the_bag():
    _new_run(["library", "kitchen", "armory"])
    assert_false(_bag_ids().has("inner_study"))
    run.enter_room(_room("baths"))
    assert_true(_bag_ids().has("inner_study"))
    assert_eq(run.explorer.bag.size(), 27)
    assert_true(run.log.has_type("special_enters_bag"))

func test_holding_all_four_at_the_start_puts_the_inner_study_in_the_bag_from_the_start():
    _new_run(["library", "kitchen", "armory", "baths"])
    assert_true(_bag_ids().has("inner_study"))
    assert_eq(run.explorer.bag.size(), 27)

func test_the_fourth_component_reopens_exploring_after_the_bag_ran_out():
    _new_run(["library", "kitchen", "armory"])
    run.explorer.bag.entries.clear()
    run.can_explore = false
    run.enter_room(_room("baths"))
    assert_true(run.can_explore, "open question #83")
    assert_eq(_bag_ids(), ["inner_study"])

func test_entering_the_inner_study_reaches_the_boss():
    assert_eq(run.enter_room(_room("inner_study", Vector2i(30, 30))), HutRun.ROOM_BOSS)
    assert_true(run.boss_reached)

func test_components_found_on_a_wiped_run_are_lost_but_earlier_ones_kept():
    _new_run(["armory"])
    run.enter_room(_room("library"))
    run.wiped = true
    run.play()
    assert_eq(run.result, HutRun.RUN_WIPE)
    assert_eq(run.components_after(), ["armory"] as Array[String])

# ------------------------------------------------------------------ Whims on their rooms

func test_bones_stir_attacks_without_rewards_and_the_black_cat_bargains():
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("crypt"))
    assert_eq(fights, ["bones_stir (no rewards)"])
    assert_eq(run.log.of_type("fight")[0]["details"]["source"], "Bones Stir")
    run.hut_deck.stack("quiet_room")
    provider.then(RunRequest.ACCEPT, true)
    run.enter_room(_room("candle_nook", Vector2i(20, 20)))
    assert_eq(run.explorer.hut_track, 1)
    assert_eq(run.loot_drawn, 1)

func test_the_bubbling_cauldron_repairs_1_armor_each_and_raises_the_hut_without_a_roll():
    run.hut_deck.stack("quiet_room")
    _hero("fighter").armor_damage = 2
    run.enter_room(_room("cauldron_room"))
    assert_eq(_hero("fighter").armor_damage, 1)
    assert_eq(run.explorer.hut_track, 1)
    assert_false(run.log.has_type("skill_roll"))

func test_locked_in_bashes_the_door_until_it_gives_way_then_the_hut_card():
    var fighter: HeroState = _hero("fighter")
    _top(fighter, 6)
    _top(fighter, 2)
    _top(fighter, 1)
    run.hut_deck.stack("chest")
    run.enter_room(_room("storeroom"))
    assert_eq(run.explorer.hut_track, 2)
    assert_true(run.log.has_type("unlocked"))
    assert_eq(run.log.of_type("skill_roll").size(), 3)
    assert_eq(run.log.of_type("skill_roll")[0]["details"]["type"], "strength")
    assert_eq(run.loot_drawn, 2, "then the room's Hut card")

func test_locked_in_gives_way_with_hut_plus_1_when_nobody_can_bash():
    for h in run.party.heroes:
        _empty_deck(h)
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("storeroom"))
    assert_true(run.log.has_type("door_gives_way"), "ruling #72: the door gives way rather than leaving the party stuck")
    assert_eq(run.explorer.hut_track, 1)

func test_doors_slam_leaves_one_open_doorway_and_vanishing_door_closes_one():
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("great_hall"))
    assert_eq(run.explorer.party_doorways().size(), 1, "the Great Hall itself")
    var open_before: int = run.explorer.open_doorway_options().size()
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("gallery", Vector2i(20, 20)))
    assert_eq(run.explorer.open_doorway_options().size(), open_before + 2 - 1, "the Gallery's two, less one wall token")

func test_the_laundry_s_keyhole_shows_the_next_tile_before_the_doorway_is_chosen():
    run.hut_deck.stack("quiet_room")
    run.enter_room(_room("laundry"))
    assert_true(run.keyhole)
    run.explorer.party_tile = run.explorer.front_door
    var next_id: String = run.explorer.bag.entries.back()["def"]["id"]
    run.explore_step()
    var asked: Array[RunRequest] = provider.requests_of(RunRequest.DOORWAY)
    assert_eq(asked.size(), 1)
    assert_eq(asked[0].details["peeked"], next_id)
    assert_eq(run.log.of_type("tile_placed").back()["details"]["id"], next_id)

func test_crooked_corridor_lays_the_next_tile_as_far_from_the_front_door_as_it_can():
    var hall: PlacedTile = run.explorer.map.add(TilePlacement.make(_entry("terrarium"), 0, Vector2i(0, 1), null, {}))  # (0,1)-(0,2)
    hall.explored = true
    run.explorer.crooked = true
    run.explore_step()
    assert_true(provider.requests_of(RunRequest.DOORWAY).is_empty(), "the Hut decides where it goes")
    var cells: Array = run.log.of_type("tile_placed").back()["details"]["cells"]
    assert_true(cells.has(Vector2i(0, 3)) or cells.has(Vector2i(1, 2)), "at a doorway of the Terrarium's far end, the farthest from the Front Door")

# ------------------------------------------------------------------ walking and leaving

func test_walking_to_another_room_s_doorway_flips_for_each_tile_entered():
    var rooms: Array[PlacedTile] = _two_rooms_north()
    var fighter: HeroState = _hero("fighter")
    _top(fighter, 5)
    _top(fighter, 1)
    provider.then(RunRequest.DOORWAY, func(d: MapDoorway) -> bool: return d.tile == run.explorer.front_door and d.side == "W")
    run.explore_step()
    var checks: Array = run.log.of_type("wandering_check")
    assert_eq(checks.size(), 2, "the Terrarium and the Front Door; not the Well Room it starts in")
    assert_eq(checks[0]["details"]["tile"], rooms[0].uid)
    assert_eq(checks[0]["details"]["hero"], "fighter", "the leading hero flips")
    assert_eq(checks[0]["details"]["value"], 1)
    assert_eq(fights[0], "wandering (no rewards)", "a 1 brings wandering monsters, fought in the Terrarium")
    assert_lt(_types().find("fight"), _types().rfind("wandering_check"), "before walking on")
    assert_eq(run.log.of_type("fight")[0]["details"]["source"], "walking")

func test_doorway_options_say_how_many_tiles_away_they_are():
    _two_rooms_north()
    run.explore_step()
    var walks: Array = provider.requests_of(RunRequest.DOORWAY)[0].details["walk"]
    assert_eq(walks[0], 0, "the Well Room's own doorway first")
    assert_true(walks.has(1), "the Terrarium's east doorway")
    assert_true(walks.has(2), "the Front Door's")

func test_a_leader_who_cannot_flip_passes_the_check_on_and_nobody_means_no_check():
    _two_rooms_north()
    _empty_deck(_hero("fighter"))
    run.walk(run.explorer.front_door, "test")
    assert_eq(run.log.of_type("wandering_check")[0]["details"]["hero"], "thief", "open question #78")
    for h in run.party.heroes:
        _empty_deck(h)
    run.explorer.party_tile = run.explorer.map.tiles.back()
    run.walk(run.explorer.front_door, "test")
    assert_eq(run.log.of_type("wandering_check").size(), 2, "nobody can flip: no more checks")

func test_walking_out_to_leave_is_free():
    _two_rooms_north()
    run.leave()
    assert_eq(run.result, HutRun.RUN_LEFT)
    assert_false(run.log.has_type("wandering_check"))

# ------------------------------------------------------------------ the Hut wakes

func test_at_10_the_hut_throws_the_party_out_and_leaving_is_all_it_can_do():
    var camp: PlacedTile = _joined("bedchamber", _door(run.explorer.front_door, "N"))
    run.raise_hut(10, "test")
    assert_true(run.evicted)
    assert_true(run.log.has_type("evicted"))
    assert_eq(run.actions(), [HutRun.ACT_LEAVE])
    assert_eq(run.camp(camp), "the Hut has thrown the party out")

func test_thrown_out_the_party_checks_every_tile_on_the_way_out_front_door_included():
    _two_rooms_north()
    run.raise_hut(10, "test")
    run.leave()
    assert_eq(run.log.of_type("wandering_check").size(), 2)
    assert_eq(run.log.of_type("wandering_check")[1]["details"]["tile"], run.explorer.front_door.uid)
    assert_eq(run.result, HutRun.RUN_LEFT)
    assert_eq(run.xp, 2, "walking out still earns its XP (open question #80)")

func test_a_moon_that_wakes_the_hut_leaves_the_new_room_unentered():
    run.explorer.hut_track = 9
    run.explorer.bag.entries.push_back(_entry("potion_store", true))
    assert_eq(run.explore_step(), HutRun.ROOM_EVICTED)
    var placed: PlacedTile = run.explorer.map.tiles.back()
    assert_eq(placed.tile_id, "potion_store")
    assert_false(placed.explored)
    assert_eq(run.explorer.party_tile, run.explorer.front_door)
    assert_false(run.log.has_type("hut_card"))

func test_a_room_in_progress_finishes_when_the_hut_wakes():
    run.explorer.hut_track = 9
    var fighter: HeroState = _hero("fighter")
    _top(fighter, 6)
    _top(fighter, 1)
    run.hut_deck.stack("chest")
    run.enter_room(_room("storeroom"))
    assert_true(run.evicted)
    assert_true(run.log.has_type("unlocked"), "the door is still bashed open")
    assert_eq(run.loot_drawn, 2, "and the Hut card still drawn")

# ------------------------------------------------------------------ camping

func test_camping_walks_there_with_a_check_costs_rations_raises_the_hut_and_resets():
    var camp: PlacedTile = _joined("bedchamber", _door(run.explorer.front_door, "N"))
    run.damage_hero(_hero("fighter"), 7, "test")
    assert_eq(run.camp(camp), "")
    assert_eq(run.rations, 4)
    assert_eq(run.explorer.hut_track, 1)
    assert_eq(_hero("fighter").wound_count(), 0)
    assert_eq(run.explorer.party_tile, camp, "the party walked there")
    var purposes: Array = run.log.of_type("wandering_check").map(func(e: Dictionary) -> String: return e["details"]["purpose"])
    assert_eq(purposes, ["walking", "campfire"])

func test_camping_needs_a_campsite_and_enough_rations():
    var well: PlacedTile = _room("well_room")
    well.explored = true
    assert_eq(run.camp(well), "not a campsite")
    var bed: PlacedTile = run.explorer.map.add(run.explorer.map.doorway_placements(_entry("small_bedchamber"), _door(run.explorer.front_door, "N"))[0])
    assert_eq(run.camp(bed), "the party hasn't explored it")
    bed.explored = true
    run.rations = 3
    assert_eq(run.camp(bed), "not enough rations (3 for 4)")
    run.rations = 4
    assert_eq(run.camp(bed), "")

func test_every_hero_down_outside_battle_is_a_wipe():
    for h in run.party.heroes:
        run.damage_hero(h, 20, "test")
    run.check_wipe(null)
    assert_true(run.wiped)
