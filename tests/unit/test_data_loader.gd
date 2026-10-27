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

func test_unknown_enemy_in_an_encounter_is_rejected():
    var data := _data_copy()
    data["encounters"]["standard"] = [{"type": "dragon", "count": 1}]
    var loader := DataLoader.new()
    assert_false(loader.validate(data))
    assert_string_contains("\n".join(loader.errors), "dragon")
