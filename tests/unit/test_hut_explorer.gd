extends GutTest

## RULES §8 Exploring and Nothing fits, §10 Special tiles and Hut track (HutExplorer): the
## seeded bag, moons, another doorway when the chosen one doesn't fit, the Hut stirring once,
## set-aside tiles, break-through, closed in, specials entering the bag, goal tiles ignoring
## doorway matching, the placement chooser, and cosmetic features on their own stream.

var module: Dictionary
var ex: HutExplorer

func before_each():
    module = BattleFixture.data()["module_witch_hut"]
    ex = HutExplorer.new(module, SeededRng.new(1), 1)

func _entry(id: String, moon: bool = false) -> Dictionary:
    for def in module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": moon}
    return {"def": ex.special_def(id), "moon": false}

func _stack(entries_top_first: Array) -> void:
    ex.bag.entries.clear()
    for i in range(entries_top_first.size() - 1, -1, -1):
        ex.bag.entries.append(entries_top_first[i])

func _doorway(side: String) -> MapDoorway:
    for d in ex.party_doorways():
        if d.side == side:
            return d
    return null

## Unexplored filler squares, so two-square tiles fit nowhere around the Front Door's doorways.
func _box_in(leave_free: Array = []) -> void:
    for c in [Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(1, -1), Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(0, -2)]:
        if not leave_free.has(c):
            ex.map.add(TilePlacement.make(_entry("vault"), 0, c, null, {}))

func test_the_bag_holds_26_tiles_with_11_moons_shuffled_by_the_seed():
    assert_eq(ex.bag.size(), 26)
    assert_eq(ex.bag.moons(), 11)
    var same := HutExplorer.new(module, SeededRng.new(1), 1)
    var other := HutExplorer.new(module, SeededRng.new(2), 2)
    var ids := func(e: HutExplorer) -> Array: return e.bag.entries.map(func(x: Dictionary) -> String: return x["def"]["id"])
    assert_eq(ids.call(same), ids.call(ex))
    assert_ne(ids.call(other), ids.call(ex))

func test_a_moon_raises_the_hut_track():
    _stack([_entry("vault", true)])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_true(result.placed())
    assert_eq(ex.hut_track, 1)
    assert_eq(ex.log.of_type("hut_track")[0]["details"]["reason"], "moon on the Vault")

func test_the_party_does_not_enter_until_told():
    _stack([_entry("vault")])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_false(result.tile.explored)
    ex.enter(result.tile)
    assert_true(result.tile.explored)
    assert_eq(ex.party_tile, result.tile)

func test_a_tile_that_does_not_fit_the_chosen_doorway_goes_to_another_of_the_same_room():
    for c in [Vector2i(0, 2), Vector2i(-1, 1), Vector2i(1, 1)]:
        ex.map.add(TilePlacement.make(_entry("vault"), 0, c, null, {}))
    _stack([_entry("lair_long_hall")])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_true(result.placed())
    assert_false(result.stirred)
    assert_false(result.tile.has_cell(Vector2i(0, 1)), "it couldn't fit north")
    assert_true(ex.map.connected(ex.front_door, result.tile))

func test_nothing_fits_the_hut_stirs_once_and_set_aside_tiles_go_back():
    _box_in()
    _stack([_entry("lair_long_hall"), _entry("dark_long"), _entry("vault")])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_true(result.placed())
    assert_eq(result.tile.tile_id, "vault")
    assert_true(result.stirred)
    assert_eq(result.set_aside, 2)
    assert_eq(ex.hut_track, 1, "only once per exploration")
    assert_eq(ex.log.of_type("hut_track").size(), 1)
    assert_eq(ex.bag.size(), 2, "the two set-aside tiles are back in the bag")

func test_with_nothing_left_that_fits_the_party_breaks_through_with_the_first_tile_set_aside():
    _box_in([Vector2i(0, -2)])
    _stack([_entry("lair_long_hall"), _entry("dark_long")])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_true(result.broke_through)
    assert_eq(result.tile.tile_id, "lair_long_hall")
    assert_true(result.tile.has_cell(Vector2i(0, -1)), "against the Front Door's south wall")
    assert_true(ex.front_door.has_door(Vector2i.ZERO, "S"), "the Hut made a door")
    assert_true(ex.map.connected(ex.front_door, result.tile))
    assert_eq(ex.bag.size(), 1, "the other set-aside tile goes back")
    assert_eq(ex.hut_track, 1, "no Hut +1 beyond the one stir")

func test_closed_in_when_even_a_break_through_is_impossible():
    _box_in()
    _stack([_entry("lair_long_hall")])
    var result: ExploreResult = ex.explore(_doorway("N"))
    assert_eq(result.status, ExploreResult.CLOSED_IN)
    assert_null(result.tile)
    assert_eq(ex.bag.size(), 1)
    assert_true(ex.log.has_type("closed_in"))

func test_an_empty_bag_ends_exploring():
    _stack([])
    assert_eq(ex.explore(_doorway("N")).status, ExploreResult.EMPTY_BAG)

func test_the_inner_study_enters_the_bag_at_hut_4_and_the_workshop_needs_level_3():
    ex.raise_hut(4, "test")
    var ids: Array = ex.bag.entries.map(func(x: Dictionary) -> String: return x["def"]["id"])
    assert_true(ids.has("inner_study"))
    assert_false(ids.has("witchs_workshop"), "a level 1 party")
    assert_eq(ex.bag.size(), 27)
    var veterans := HutExplorer.new(module, SeededRng.new(1), 1)
    veterans.party_level = 3
    veterans.raise_hut(2, "test")
    assert_true(veterans.bag.entries.any(func(x: Dictionary) -> bool: return x["def"]["id"] == "witchs_workshop"))
    var keyholders := HutExplorer.new(module, SeededRng.new(1), 1)
    keyholders.party_level = 3
    keyholders.has_key = true
    keyholders.raise_hut(2, "test")
    assert_false(keyholders.bag.entries.any(func(x: Dictionary) -> bool: return x["def"]["id"] == "witchs_workshop"))

func test_a_goal_tile_ignores_doorway_matching_and_the_hut_makes_the_door():
    _stack([_entry("inner_study")])
    var result: ExploreResult = ex.explore(_doorway("E"))
    assert_true(result.tile.has_cell(Vector2i(1, 0)), "on the square beyond the chosen doorway")
    assert_eq(result.tile.cells.size(), 4)
    assert_true(ex.map.connected(ex.front_door, result.tile))

func test_the_chooser_picks_among_legal_placements():
    var seen: Array = []
    ex.chooser = func(kind: String, _options: Array) -> int:
        seen.append(kind)
        return 2
    _stack([_entry("dark_small")])
    var options: Array[TilePlacement] = ex.placement_options(_entry("dark_small"), _doorway("E"))
    var result: ExploreResult = ex.explore(_doorway("E"))
    assert_eq(seen, [HutExplorer.CHOICE_PLACEMENT])
    assert_eq(result.tile.rotation, options[2].rotation)

func _walk(e: HutExplorer, steps: int) -> Array:
    var placed: Array = []
    for i in range(steps):
        var doors: Array[MapDoorway] = e.party_doorways()
        if doors.is_empty():
            doors = e.map.explored_open_doorways()
        var result: ExploreResult = e.explore(doors[0])
        if not result.placed():
            break
        e.enter(result.tile)
        placed.append(result.tile)
    return placed

func test_features_come_from_the_cosmetic_stream_and_never_change_play():
    var a: Array = _walk(ex, 8)
    var again: Array = _walk(HutExplorer.new(module, SeededRng.new(1), 1), 8)
    var plain_module: Dictionary = module.duplicate(true)
    for type_id in plain_module["room_types"]:
        plain_module["room_types"][type_id].erase("features")
    var plain: Array = _walk(HutExplorer.new(plain_module, SeededRng.new(1), 1), 8)
    assert_eq(a.size(), 8)
    for i in range(a.size()):
        assert_eq((a[i] as PlacedTile).features, (again[i] as PlacedTile).features, "same seed, same decorations")
        assert_eq((a[i] as PlacedTile).tile_id, (plain[i] as PlacedTile).tile_id, "decorations never change the draws")
        assert_eq((a[i] as PlacedTile).anchor, (plain[i] as PlacedTile).anchor)
        assert_eq((plain[i] as PlacedTile).features.size(), 0)
    var any_features: bool = a.any(func(t: PlacedTile) -> bool: return not t.features.is_empty())
    assert_true(any_features)
