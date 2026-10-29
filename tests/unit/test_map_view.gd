extends GutTest

## Milestone 4.1: the map view keeps its layers separate (EXPLORATION_SPEC §9a) and every placed
## tile goes through the ink-in hook. Presentation only; the rest of the table is checked by
## screenshots (tools/screenshot_table.gd).

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
