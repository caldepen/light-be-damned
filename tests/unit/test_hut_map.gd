extends GutTest

## RULES §8 The map: rotations, open doorways, placing a tile at a doorway (any rotation, no
## overlap, symmetric rotations offered once), doorways facing a wall, connections (HutMap).

var ex: HutExplorer

func before_each():
    ex = HutExplorer.new(BattleFixture.data()["module_witch_hut"], SeededRng.new(1), 1)

func _entry(id: String, moon: bool = false) -> Dictionary:
    for def in BattleFixture.data()["module_witch_hut"]["tiles"]:
        if def["id"] == id:
            return {"def": def, "moon": moon}
    return {"def": ex.special_def(id), "moon": false}

func _doorway(tile: PlacedTile, side: String) -> MapDoorway:
    for d in ex.map.open_doorways(tile):
        if d.side == side:
            return d
    return null

## An unexplored filler tile on `cell` (the Storeroom, one square).
func _block(cell: Vector2i) -> void:
    ex.map.add(TilePlacement.make(_entry("storeroom"), 0, cell, null, {}))

func test_rotation_turns_cells_and_doorways_clockwise():
    var p := TilePlacement.make(_entry("corridor_straight"), 1, Vector2i.ZERO, null, {})
    assert_eq(p.cells, [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i], "north becomes east")
    var sides: Array = p.doors.map(func(d: Dictionary) -> String: return "%s@%d,%d" % [d["side"], d["cell"].x, d["cell"].y])
    assert_eq(sides, ["W@0,0", "E@1,0", "S@1,0"])

func test_the_front_door_starts_at_the_origin_with_three_open_doorways():
    assert_eq(ex.front_door.cells, [Vector2i.ZERO] as Array[Vector2i])
    var sides: Array = ex.party_doorways().map(func(d: MapDoorway) -> String: return d.side)
    assert_eq(sides, ["N", "E", "W"])
    assert_true(ex.front_door.explored)

func test_a_tile_meets_the_chosen_doorway_and_the_rooms_connect():
    var options: Array[TilePlacement] = ex.map.doorway_placements(_entry("storeroom"), _doorway(ex.front_door, "N"))
    assert_eq(options.size(), 1, "the Storeroom's only doorway must face south")
    assert_eq(options[0].anchor, Vector2i(0, 1))
    assert_eq(options[0].rotation, 0)
    var store: PlacedTile = ex.map.add(options[0])
    assert_null(_doorway(ex.front_door, "N"), "no longer open")
    assert_true(ex.map.connected(ex.front_door, store))
    assert_eq(ex.map.open_doorways(store).size(), 0, "the Storeroom is a dead end")

func test_every_rotation_that_fits_is_offered_once():
    var east: MapDoorway = _doorway(ex.front_door, "E")
    assert_eq(ex.map.doorway_placements(_entry("root_cellar"), east).size(), 3, "doorways S, E, W: three ways to face west")
    var north: MapDoorway = _doorway(ex.front_door, "N")
    assert_eq(ex.map.doorway_placements(_entry("small_bedchamber"), north).size(), 1, "turned half round it is the same tile")

func test_a_tile_never_overlaps_another():
    var west: MapDoorway = _doorway(ex.front_door, "W")
    var free_count: int = ex.map.doorway_placements(_entry("laundry"), west).size()
    _block(Vector2i(-1, -1))
    var options: Array[TilePlacement] = ex.map.doorway_placements(_entry("laundry"), west)
    assert_lt(options.size(), free_count)
    assert_gt(options.size(), 0)
    for p in options:
        assert_false(p.cells.has(Vector2i(-1, -1)))

func test_a_doorway_facing_a_wall_is_closed_and_does_not_connect():
    var store: PlacedTile = ex.map.add(TilePlacement.make(_entry("storeroom"), 2, Vector2i(0, 1), null, {}))
    assert_eq(store.doors[0]["side"], "N", "turned half round, its doorway faces away")
    assert_null(_doorway(ex.front_door, "N"), "the square beyond is taken")
    assert_false(ex.map.connected(ex.front_door, store))

func test_rooms_reachable_through_connected_doorways():
    var hall: PlacedTile = ex.map.add(ex.map.doorway_placements(_entry("laundry"), _doorway(ex.front_door, "N"))[0])
    var walled: PlacedTile = ex.map.add(TilePlacement.make(_entry("storeroom"), 3, Vector2i(1, 0), null, {}))
    var reach: Array[PlacedTile] = ex.map.reachable_from(ex.front_door)
    assert_true(reach.has(hall))
    assert_false(reach.has(walled), "its doorway faces east, away from the front door")

func test_a_wall_token_closes_a_doorway():
    var north: MapDoorway = _doorway(ex.front_door, "N")
    ex.map.close_doorway(north.cell, north.side)
    assert_null(_doorway(ex.front_door, "N"))
    assert_eq(ex.party_doorways().size(), 2)
