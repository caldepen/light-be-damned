extends GutTest

## Milestone 4.1: the map view keeps its layers separate (EXPLORATION_SPEC §9a) and every placed
## tile goes through the ink-in hook. 4.6: it draws a run's map (tiles in, moved and removed),
## the pending choice's clickable options, and a camera that follows the party until the person
## pans or zooms. Presentation only; the rest of the table is checked by screenshots
## (tools/screenshot_table.gd).

func _map() -> MapView:
    var map := MapView.new()
    map.size = Vector2(400, 300)
    add_child_autofree(map)
    return map

func test_the_map_draws_in_five_layers_bottom_to_top():
    var map := _map()
    var world: Node = map.paper.get_parent()
    var names: Array[String] = []
    for child in world.get_children():
        if child is Camera2D:
            continue
        names.append(String(child.name))
    assert_eq(names, ["Paper", "Tiles", "Features", "Annotations", "Overlay"])
    assert_true(map.camera.is_current(), "the map has its own camera")

func test_annotations_start_empty_and_tiles_go_on_the_tiles_layer():
    var map := _map()
    assert_eq(map.annotations.get_child_count(), 0)
    var tile: TileView = UiScenes.tile_view()
    map.add_tile(tile)
    assert_eq(tile.get_parent(), map.tiles, "tiles go on the tiles layer")
    assert_eq(map.annotations.get_child_count(), 0)

func test_a_placed_tile_inks_in_from_transparent():
    var map := _map()
    var tile: TileView = UiScenes.tile_view()
    var cells: Array[Vector2i] = [Vector2i(0, 0)]
    var doors: Array[Dictionary] = [{"cell": Vector2i(0, 0), "side": "N"}]
    tile.setup(cells, doors, "Front Door", false, map.palette())
    map.add_tile(tile)
    assert_eq(tile.modulate.a, 0.0, "starts transparent")
    await wait_seconds(MapView.INK_IN_SECONDS + 0.15)
    assert_almost_eq(tile.modulate.a, 1.0, 0.01, "fully inked")

func test_fit_to_centres_and_zooms_on_a_rect():
    var map := _map()
    var rect := Rect2(Vector2(-100, -50), Vector2(800, 600))
    map.fit_to(rect)
    assert_eq(map.camera.position, rect.get_center())
    assert_almost_eq(map.camera.zoom.x, 0.5, 0.001, "400x300 view on an 800x600 rect")
    assert_true(map.visible_world_rect().encloses(rect.grow(-1)))

func test_tile_squares_are_north_up():
    var r0: Rect2 = TileView.square_rect(Vector2i(0, 0))
    var r1: Rect2 = TileView.square_rect(Vector2i(0, 1))
    assert_lt(r1.position.y, r0.position.y, "map y+1 (north) is higher on screen")
    assert_eq(TileView.square_rect(Vector2i(-1, 0)).position.x, -MapView.SQUARE, "negative x is fine")

# ------------------------------------------------------------------ 4.6: a run's map

func _explorer() -> HutExplorer:
    return HutExplorer.new(BattleFixture.data()["module_witch_hut"], SeededRng.new(3), 3)

func _walk(ex: HutExplorer, steps: int) -> void:
    for i in range(steps):
        var result: ExploreResult = ex.explore(ex.map.explored_open_doorways(ex.party_tile)[0])
        ex.enter(result.tile)

func test_show_run_draws_every_placed_tile_and_drops_removed_ones():
    var map := _map()
    var ex := _explorer()
    _walk(ex, 3)
    map.show_run(ex.map, ex.party_tile, null)
    assert_eq(map.tiles.get_child_count(), ex.map.tiles.size(), "the Front Door and three rooms")
    var dead_end: PlacedTile = null
    for t in ex.collapse_options():
        dead_end = t
    if dead_end == null:
        ex.party_tile = ex.front_door
        dead_end = ex.collapse_options()[0] if not ex.collapse_options().is_empty() else null
    if dead_end != null:
        ex.remove_tile(dead_end)
        map.show_run(ex.map, ex.party_tile, null)
        await wait_frames(2)
        assert_eq(map.tiles.get_child_count(), ex.map.tiles.size(), "a collapsed room disappears")

func test_doorway_options_are_clickable_where_they_are_drawn():
    var map := _map()
    var ex := _explorer()
    var doors: Array = ex.party_doorways()
    var request := RunRequest.new(RunRequest.DOORWAY, null, doors, {"walk": [0, 0, 0], "peeked": ""})
    map.show_run(ex.map, ex.party_tile, request)
    for i in range(doors.size()):
        var d: MapDoorway = doors[i]
        assert_eq(map.marks.option_at(MapOverlayLayer.doorway_point(d.cell, d.side)), i)
    assert_eq(map.marks.option_at(TileView.square_rect(Vector2i(5, 5)).get_center()), -1, "nothing there")

func test_placement_previews_are_clickable_and_the_camera_zooms_toward_them():
    var map := _map()
    var ex := _explorer()
    var entry: Dictionary = {"def": BattleFixture.data()["module_witch_hut"]["tiles"][3], "moon": false}  # the Great Hall
    var options: Array[TilePlacement] = ex.map.doorway_placements(entry, ex.party_doorways()[0])
    var request := RunRequest.new(RunRequest.PLACEMENT, null, options, {})
    map.show_run(ex.map, ex.party_tile, request)
    var cell: Vector2i = options[0].cells[0]
    var first: int = map.marks.option_at(TileView.square_rect(cell).get_center())
    assert_gte(first, 0)
    assert_true(options[first].cells.has(cell))
    for p in options:
        for c in p.cells:
            assert_true(map.visible_world_rect().encloses(TileView.square_rect(c)), "every preview in view")

func test_a_click_on_an_option_emits_its_index():
    var map := _map()
    var ex := _explorer()
    var doors: Array = ex.party_doorways()
    map.show_run(ex.map, ex.party_tile, RunRequest.new(RunRequest.DOORWAY, null, doors, {}))
    watch_signals(map)
    var d: MapDoorway = doors[1]
    var world: Vector2 = MapOverlayLayer.doorway_point(d.cell, d.side)
    var local: Vector2 = (world - map.camera.position) * map.camera.zoom + map.size * 0.5
    for pressed in [true, false]:
        var click := InputEventMouseButton.new()
        click.button_index = MOUSE_BUTTON_LEFT
        click.pressed = pressed
        click.position = local
        map._gui_input(click)
    assert_signal_emitted_with_parameters(map, "option_chosen", [1])

func test_the_camera_follows_the_whole_map_until_the_person_zooms_then_centre_brings_it_back():
    var map := _map()
    var ex := _explorer()
    _walk(ex, 6)
    map.show_run(ex.map, ex.party_tile, null)
    assert_true(map.follow)
    var party_rect := Rect2()
    for i in range(ex.party_tile.cells.size()):
        var r: Rect2 = TileView.square_rect(ex.party_tile.cells[i])
        party_rect = r if i == 0 else party_rect.merge(r)
    assert_true(map.visible_world_rect().encloses(party_rect), "the party's room is in view")
    map.zoom_at(map.size * 0.5, 3.0)
    assert_false(map.follow, "zooming by hand stops following")
    var zoomed: Vector2 = map.camera.zoom
    map.show_run(ex.map, ex.party_tile, null)
    assert_eq(map.camera.zoom, zoomed, "a redraw leaves the person's view alone")
    map.pan_by(Vector2(500, 0))
    map.centre_on_party()
    assert_true(map.follow)
    assert_true(map.visible_world_rect().encloses(party_rect))

func test_wall_tokens_and_the_party_marker_go_on_the_overlay():
    var map := _map()
    var ex := _explorer()
    ex.close_doorway(ex.party_doorways()[0])
    map.show_run(ex.map, ex.party_tile, null)
    assert_eq(map.marks.walls.size(), 1)
    assert_eq(map.marks.party_rect, TileView.square_rect(Vector2i.ZERO))
    assert_eq(map.marks.get_parent(), map.overlay)