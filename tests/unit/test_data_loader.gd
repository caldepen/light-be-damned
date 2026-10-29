extends GutTest

## Data loading fails loudly on unknown ops, missing references, bad decks and bad skill values.

func _data_copy() -> Dictionary:
    return BattleFixture.data().duplicate(true)

func test_data_loads_without_errors():
    var loader := DataLoader.new()
    var data: Dictionary = loader.load_all()
    assert_eq(loader.errors.size(), 0, "Errors: %s" % str(loader.errors))
    for key in ["rules", "heroes", "enemies", "encounters", "items", "module_witch_hut"]:
        assert_true(data.has(key), "%s should load" % key)
    assert_eq(int(data["rules"]["party_size"]), 4)

func test_every_hero_deck_is_30_cards_with_five_of_each_skill():
    for hero_id in BattleFixture.data()["heroes"]:
        var counts: Dictionary = {}
        var total: int = 0
        for card in BattleFixture.data()["heroes"][hero_id]["deck"]:
            counts[int(card["skill"])] = int(counts.get(int(card["skill"]), 0)) + int(card.get("qty", 1))
            total += int(card.get("qty", 1))
        assert_eq(total, 30, hero_id)
        for value in range(1, 7):
            assert_eq(int(counts.get(value, 0)), 5, "%s skill %d" % [hero_id, value])

func test_unknown_op_is_rejected():
    assert_false(DataLoader.new().validate_effects([{"op": "not_a_real_op"}]).is_empty())

func test_unknown_op_in_a_nested_list_is_rejected():
    var effects: Array = [{"op": "flee_if", "condition": "hd_marked_at_least_half", "otherwise": [{"op": "explode"}]}]
    assert_string_contains(DataLoader.new().validate_effects(effects), "explode")

func test_every_op_in_the_data_has_a_handler():
    var registry := EffectRegistry.new()
    for hero_id in BattleFixture.data()["heroes"]:
        for card in BattleFixture.data()["heroes"][hero_id]["deck"]:
            for e in card["effects"]:
                assert_true(registry.has(e["op"]), "%s: %s" % [card["id"], e["op"]])

func test_a_29_card_deck_is_rejected():
    var data := _data_copy()
    data["heroes"]["fighter"]["deck"][0]["qty"] = int(data["heroes"]["fighter"]["deck"][0]["qty"]) - 1
    var loader := DataLoader.new()
    assert_false(loader.validate(data))
    assert_string_contains("\n".join(loader.errors), "expected 30")

func test_a_wrong_skill_spread_is_rejected():
    var data := _data_copy()
    data["heroes"]["thief"]["deck"][0]["skill"] = 6
    var loader := DataLoader.new()
    assert_false(loader.validate(data))
    assert_string_contains("\n".join(loader.errors), "skill")

func test_missing_gear_reference_is_rejected():
    var data := _data_copy()
    data["heroes"]["wizard"]["starting_gear"]["armor"] = "mithril"
    var loader := DataLoader.new()
    assert_false(loader.validate(data))
    assert_string_contains("\n".join(loader.errors), "mithril")

func _module_errors(data: Dictionary) -> String:
    var loader := DataLoader.new()
    assert_false(loader.validate(data), "validation should fail")
    return "\n".join(loader.errors)

func test_tile_bag_has_26_tiles_and_11_moons():
    var bag: int = 0
    var moons: int = 0
    for tile in BattleFixture.data()["module_witch_hut"]["tiles"]:
        bag += int(tile["qty"])
        moons += int(tile["moon_qty"])
    assert_eq(bag, 26)
    assert_eq(moons, 11)

func test_room_decks_hold_36_cards_and_there_are_12_whims():
    var module: Dictionary = BattleFixture.data()["module_witch_hut"]
    var total: int = 0
    for deck_name in module["room_decks"]:
        total += DataLoader.new().sum_deck_quantity(module["room_decks"][deck_name])
    assert_eq(total, 36)
    assert_eq(module["hut_whims"].size(), 12)

func test_a_missing_bag_tile_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["tiles"][3]["qty"] = 2
    assert_string_contains(_module_errors(data), "bag_size")

func test_a_wrong_moon_count_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["tiles"][3]["moon_qty"] = 3
    assert_string_contains(_module_errors(data), "moon")

func test_a_doorway_inside_the_tile_is_rejected():
    var data := _data_copy()
    # lair_great_hall: [0,0] side E faces its own cell [1,0]
    data["module_witch_hut"]["tiles"][3]["doors"][0] = {"cell": [0, 0], "side": "E"}
    assert_string_contains(_module_errors(data), "not on the tile's edge")

func test_a_doorway_off_the_tile_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["tiles"][5]["doors"][0] = {"cell": [2, 2], "side": "S"}
    assert_string_contains(_module_errors(data), "not one of its cells")

func test_a_duplicate_cell_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["tiles"][0]["cells"] = [[0, 0], [0, 0]]
    assert_string_contains(_module_errors(data), "twice")

func test_an_unknown_room_op_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["room_decks"]["dark"][0]["effects"] = [{"op": "summon_dragon"}]
    assert_string_contains(_module_errors(data), "summon_dragon")

func test_an_unknown_op_nested_in_a_skill_check_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["hut_whims"][9]["effects"][0]["failure"] = [{"op": "explode"}]
    assert_string_contains(_module_errors(data), "explode")

func test_a_room_fight_with_an_unknown_encounter_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["room_decks"]["lair"][0]["effects"][0]["encounter"] = "dragons"
    assert_string_contains(_module_errors(data), "dragons")

func test_the_map_has_no_fixed_board_and_the_front_door_is_at_the_origin():
    var module: Dictionary = BattleFixture.data()["module_witch_hut"]
    assert_false(module["map"].has("width"), "no board width")
    assert_false(module["map"].has("height"), "no board height")
    var front_door: Dictionary = {}
    for tile in module["special_tiles"]:
        if tile["id"] == module["map"]["entrance_tile"]:
            front_door = tile
    assert_eq(TileGeometry.cells_from_data([front_door["fixed_at"]])[0], Vector2i(0, 0))

func test_a_bad_fixed_at_is_rejected():
    var data := _data_copy()
    data["module_witch_hut"]["special_tiles"][0]["fixed_at"] = [0]
    assert_string_contains(_module_errors(data), "fixed_at")

func test_tile_rotation_turns_clockwise_with_y_up():
    assert_eq(TileGeometry.rotate_cell(Vector2i(0, 1), 1), Vector2i(1, 0), "north of the anchor turns to east")
    assert_eq(TileGeometry.rotate_cell(Vector2i(1, 0), 1), Vector2i(0, -1), "east turns to south")
    assert_eq(TileGeometry.rotate_cell(Vector2i(1, 1), 2), Vector2i(-1, -1))
    assert_eq(TileGeometry.rotate_cell(Vector2i(1, 1), 4), Vector2i(1, 1))
    assert_eq(TileGeometry.rotate_side("N", 1), "E")
    assert_eq(TileGeometry.rotate_side("W", 1), "N")
    assert_eq(TileGeometry.rotate_side("S", 3), "E")
    assert_eq(TileGeometry.opposite("E"), "W")

func test_unknown_enemy_in_an_encounter_is_rejected():
    var data := _data_copy()
    data["encounters"]["standard"] = [{"type": "dragon", "count": 1}]
    var loader := DataLoader.new()
    assert_false(loader.validate(data))
    assert_string_contains("\n".join(loader.errors), "dragon")
