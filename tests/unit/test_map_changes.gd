extends GutTest

## RULES §10 Hut Whims, the map side: turning a tile in place (Shifting Walls), swapping two
## same-shape tiles (Hall of Mirrors), removing a dead end (Collapse), wall tokens (Vanishing Door,
## Doors Slam). Each refuses the party's room, the Front Door, special tiles and cutting the party
## off, and says why. Plus saving the exploration state to plain data and loading it back.

var module: Dictionary
var ex: HutExplorer
var den: PlacedTile    # (0, 1), doorways S and E: joined to the Front Door's N doorway
var vault: PlacedTile  # (1, 0), turned so its one doorway faces W: a dead end off the Front Door
var dark: PlacedTile   # (-1, 0), doorways S, E, W: joined to the Front Door's W doorway

func before_each():
    module = BattleFixture.data()["module_witch_hut"]
    ex = HutExplorer.new(module, SeededRng.new(1), 1)
    den = _put("lair_den", 0, Vector2i(0, 1))
    vault = _put("vault", 1, Vector2i(1, 0))
    dark = _put("dark_small", 0, Vector2i(-1, 0))

func _entry(id: String) -> Dictionary:
    for def in module["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": false}
    return {"def": ex.special_def(id), "moon": false}

func _put(id: String, rotation: int, anchor: Vector2i, explored: bool = true) -> PlacedTile:
    var t: PlacedTile = ex.map.add(TilePlacement.make(_entry(id), rotation, anchor, null, {}))
    t.explored = explored
    return t

func _sides(t: PlacedTile) -> Array:
    var s: Array = t.doors.map(func(d: Dictionary) -> String: return d["side"])
    s.sort()
    return s

func test_the_hut_never_makes_a_door_through_a_wall_token():
    assert_eq(ex.map.close_doorway(Vector2i(-1, 0), "W"), "")
    var placements: Array[TilePlacement] = ex.map.wall_placements(_entry("witchs_workshop"), ex.party_tile)
    assert_gt(placements.size(), 0)
    for p in placements:
        assert_false(p.hut_door.get("cell") == Vector2i(-1, 0) and p.hut_door.get("side") == "W", "the sealed edge stays sealed")

func test_a_dead_end_turned_away_from_the_map_offers_no_doorways_to_the_party():
    # Open question #77: the vault turned so its doorway faces east is cut off from everything.
    assert_eq(ex.rotate_tile(vault, 3), "")
    assert_false(ex.map.reachable_from(ex.front_door).has(vault))
    for d in ex.map.explored_open_doorways(ex.party_tile):
        assert_ne(d.tile, vault, "the party can't walk to it, so it can't backtrack there")
    var any_vault: bool = ex.map.explored_open_doorways().any(func(d: MapDoorway) -> bool: return d.tile == vault)
    assert_true(any_vault, "it still has an open doorway on the map")

## The party in a room east of the den, reachable only through it.
func _party_beyond_the_den() -> PlacedTile:
    var beyond: PlacedTile = _put("dark_small", 0, Vector2i(1, 1))
    ex.party_tile = beyond
    assert_true(ex.map.reachable_from(ex.front_door).has(beyond))
    return beyond

func test_a_tile_turns_in_place_and_its_doorways_open_or_close():
    assert_eq(ex.rotate_tile(den, 2), "")
    assert_eq(den.cells, [Vector2i(0, 1)] as Array[Vector2i])
    assert_eq(_sides(den), ["N", "W"])
    assert_false(ex.map.connected(ex.front_door, den), "its south doorway is gone")
    assert_true(ex.log.has_type("tile_rotated"))

func test_straight_tiles_only_turn_half_round_and_the_bent_corridor_never():
    var hall: PlacedTile = _put("lair_long_hall", 0, Vector2i(3, 3))
    assert_eq(ex.rotate_tile(hall, 1), "turned that way it wouldn't cover its own squares")
    assert_eq(ex.rotate_tile(hall, 2), "")
    assert_eq(hall.cells.size(), 2)
    assert_true(hall.has_cell(Vector2i(3, 3)) and hall.has_cell(Vector2i(3, 4)))
    var tee: PlacedTile = _put("corridor_t", 0, Vector2i(6, 6))
    assert_eq(ex.rotate_tile(tee, 1), "turned that way it wouldn't cover its own squares")
    assert_eq(ex.rotate_tile(tee, 2), "", "three squares in a row: its N doorway becomes S")
    assert_eq(_sides(tee), ["E", "S", "W"])
    var bend: PlacedTile = _put("corridor_bend", 0, Vector2i(9, 9))
    for r in [1, 2, 3]:
        assert_eq(ex.rotate_tile(bend, r), "turned that way it wouldn't cover its own squares")

func test_turning_refuses_the_front_door_the_partys_room_special_and_unexplored_tiles():
    assert_eq(ex.rotate_tile(ex.front_door, 1), "the Front Door never moves")
    ex.party_tile = den
    assert_eq(ex.rotate_tile(den, 1), "the party is in that room")
    var study: PlacedTile = _put("inner_study", 0, Vector2i(5, 5))
    assert_eq(ex.rotate_tile(study, 1), "special tiles never move")
    var unseen: PlacedTile = _put("vault", 0, Vector2i(-5, -5), false)
    assert_eq(ex.rotate_tile(unseen, 1), "only explored tiles")
    assert_eq(ex.rotate_tile(vault, 1), "it already faces that way")
    assert_eq(ex.log.of_type("map_change_refused").size(), 5)

func test_turning_never_cuts_the_party_off_from_the_front_door():
    _party_beyond_the_den()
    for r in [1, 2, 3]:
        assert_eq(ex.rotate_tile(den, r), "it would cut the party off from the Front Door")
    assert_eq(den.rotation, 0, "unchanged")
    assert_eq(_sides(den), ["E", "S"])

func test_two_tiles_of_the_same_shape_swap_doorways_and_all():
    assert_eq(ex.swap_tiles(den, vault), "")
    assert_eq(den.cells, [Vector2i(1, 0)] as Array[Vector2i])
    assert_eq(vault.cells, [Vector2i(0, 1)] as Array[Vector2i])
    assert_eq(_sides(den), ["E", "S"], "same orientation")
    assert_eq(ex.map.tile_at(Vector2i(1, 0)), den)
    assert_eq(ex.map.tile_at(Vector2i(0, 1)), vault)
    assert_false(ex.map.connected(ex.front_door, vault), "the vault's doorway faces west now")

func test_swapping_refuses_different_shapes_fixed_tiles_and_cutting_the_party_off():
    var hall: PlacedTile = _put("lair_long_hall", 0, Vector2i(3, 3))
    assert_eq(ex.swap_tiles(den, hall), "the two tiles aren't the same size and shape")
    assert_eq(ex.swap_tiles(den, ex.front_door), "the Front Door never moves")
    assert_eq(ex.swap_tiles(den, den), "a tile can't swap with itself")
    _party_beyond_the_den()
    assert_eq(ex.swap_tiles(den, vault), "it would cut the party off from the Front Door")
    assert_eq(den.cells, [Vector2i(0, 1)] as Array[Vector2i], "unchanged")

func test_collapse_removes_a_dead_end_for_the_run():
    assert_eq(ex.remove_tile(vault), "")
    assert_false(ex.map.tiles.has(vault))
    assert_true(ex.map.is_free(Vector2i(1, 0)))
    assert_eq(ex.party_doorways().size(), 1, "the Front Door's east doorway is open again")

func test_collapse_refuses_rooms_that_are_not_dead_ends_and_fixed_tiles():
    assert_eq(ex.remove_tile(den), "it isn't a dead end: it still has an open doorway")
    _put("vault", 3, Vector2i(-2, 0))   # doorway E, meets the dark room's W
    _put("vault", 2, Vector2i(-1, -1))  # doorway N, meets the dark room's S
    assert_eq(ex.remove_tile(dark), "it isn't a dead end: it connects to 3 rooms")
    assert_eq(ex.remove_tile(ex.front_door), "the Front Door never moves")
    ex.party_tile = vault
    assert_eq(ex.remove_tile(vault), "the party is in that room")

func test_a_wall_token_closes_only_an_open_doorway():
    var west: MapDoorway = MapDoorway.new(dark, Vector2i(-1, 0), "W")
    assert_eq(ex.close_doorway(west), "")
    assert_false(ex.map.open_doorways(dark).any(func(d: MapDoorway) -> bool: return d.side == "W"))
    assert_eq(ex.close_doorway(west), "that doorway is already closed")
    assert_eq(ex.close_doorway(MapDoorway.new(dark, Vector2i(-1, 0), "E")), "that doorway isn't open: a room lies beyond it")
    assert_eq(ex.close_doorway(MapDoorway.new(dark, Vector2i(-1, 0), "N")), "there is no doorway there")

func test_whim_option_lists_hold_only_legal_changes():
    var turns: Array = ex.rotation_options().map(func(o: Dictionary) -> String: return "%s:%d" % [o["tile"].tile_id, o["rotation"]])
    assert_true(turns.has("lair_den:1"))
    assert_false(turns.any(func(s: String) -> bool: return s.begins_with("front_door")))
    assert_eq(ex.collapse_options(), [vault] as Array[PlacedTile])
    assert_eq(ex.swap_options().size(), 3, "den, vault and dark room are all 1x1")
    assert_eq(ex.open_doorway_options().size(), 3, "the den's E, the dark room's S and W; the Front Door's all lead somewhere")

# ------------------------------------------------------------------ save and load

func _walk(e: HutExplorer, picker: SeededRng, steps: int) -> Array:
    var placed: Array = []
    for i in range(steps):
        var doors: Array[MapDoorway] = e.party_doorways()
        if doors.is_empty():
            doors = e.map.explored_open_doorways()
        var result: ExploreResult = e.explore(doors[picker.next_index(doors.size())])
        if not result.placed():
            break
        e.enter(result.tile)
        placed.append("%s@%s/%d/%s" % [result.tile.tile_id, str(result.tile.anchor), result.tile.rotation, str(result.tile.features)])
    return placed

func test_the_exploration_state_round_trips_through_plain_data():
    var built := HutExplorer.new(module, SeededRng.new(5), 5)
    _walk(built, SeededRng.new(9), 6)
    built.close_doorway(built.open_doorway_options()[0])
    built.raise_hut(3, "test")
    var saved: Dictionary = built.to_dict()
    var text: String = JSON.stringify(saved)
    var loaded := HutExplorer.from_dict(JSON.parse_string(text), module, SeededRng.new(1))
    assert_eq(JSON.stringify(loaded.to_dict()), text, "save -> JSON -> load -> save is unchanged")
    assert_eq(loaded.map.tiles.size(), built.map.tiles.size())
    assert_eq(loaded.party_tile.uid, built.party_tile.uid)
    assert_eq(loaded.hut_track, built.hut_track)
    var picker_a := SeededRng.new(77)
    var picker_b := SeededRng.new(77)
    assert_eq(_walk(loaded, picker_b, 6), _walk(built, picker_a, 6), "the loaded run carries on exactly as the original")
