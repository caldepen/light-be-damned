extends GutTest

## RULES §2 (starting hands), §5 Placement, §6 armor table, §6 Provoke start.

func _battle(encounter_name: String) -> Battle:
    var data: Dictionary = BattleFixture.data()
    return BattleSetup.create(data, data["encounters"][encounter_name], 5, SimpleAiProvider.new())

func _hero(b: Battle, key: String) -> HeroState:
    for h in b.heroes:
        if h.id == key:
            return h
    return null

func test_heroes_stand_in_the_default_formation():
    var b := _battle("standard")
    assert_eq(_hero(b, "thief").cells[0], Vector2i(0, 3))
    assert_eq(_hero(b, "fighter").cells[0], Vector2i(1, 3))
    assert_eq(_hero(b, "cleric").cells[0], Vector2i(2, 3))
    assert_eq(_hero(b, "wizard").cells[0], Vector2i(1, 5))

func test_armor_slots_come_from_white_gear():
    var b := _battle("standard")
    assert_eq(_hero(b, "fighter").armor_slots, 5, "Chainmail 4 + Shield 1")
    assert_eq(_hero(b, "cleric").armor_slots, 4)
    assert_eq(_hero(b, "thief").armor_slots, 2)
    assert_eq(_hero(b, "wizard").armor_slots, 0)

func test_heroes_draw_their_hand_size():
    var b := _battle("standard")
    for key in {"fighter": 6, "cleric": 5, "thief": 5, "wizard": 4}:
        var h := _hero(b, key)
        assert_eq(h.hand.size(), h.hand_size, key)
        assert_eq(h.deck.size(), 30 - h.hand_size, key)

func test_enemies_fill_the_front_row_first():
    var b := _battle("standard")
    var cells: Array = []
    for e in b.enemies:
        cells.append(e.cells[0])
    assert_eq(cells, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 1), Vector2i(1, 1)])
    assert_eq(b.enemies[0].armor_slots, 1)
    assert_eq(b.enemies[0].hit_dice, 4)

func test_ogre_takes_left_and_centre_of_front_and_middle_rows():
    var b := _battle("tough")
    var ogre: EnemyState = b.enemies[0]
    assert_eq(ogre.enemy_type, "ogre")
    for c in [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 1), Vector2i(1, 1)]:
        assert_true(ogre.cells.has(c), "ogre on %s" % str(c))
    var goblin_cells: Array = []
    for e in b.enemies.slice(1):
        goblin_cells.append(e.cells[0])
    assert_eq(goblin_cells, [Vector2i(2, 2), Vector2i(2, 1), Vector2i(0, 0), Vector2i(1, 0)])

func test_provoke_starts_on_zero_fighter_on_top():
    var b := _battle("standard")
    var order: Array = []
    for h in b.provoke.ordered(b.heroes):
        order.append(h.id)
        assert_eq(b.provoke.value_of(h), 0)
    assert_eq(order, ["fighter", "cleric", "thief", "wizard"])
