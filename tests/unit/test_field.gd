extends GutTest

## RULES §5: one 6x3 grid with shared lanes; reach is 1 square including diagonals; shifting front.

func test_board_positions_map_to_one_grid():
    assert_eq(Field.cell_for(FigureState.SIDE_HEROES, 0, 0), Vector2i(0, 3), "hero front left")
    assert_eq(Field.cell_for(FigureState.SIDE_HEROES, 2, 1), Vector2i(1, 5), "hero back centre")
    assert_eq(Field.cell_for(FigureState.SIDE_ENEMIES, 0, 0), Vector2i(0, 2), "enemy front left (same lane 0)")
    assert_eq(Field.cell_for(FigureState.SIDE_ENEMIES, 2, 2), Vector2i(2, 0), "enemy back right")

func test_front_rows_reach_same_and_neighbouring_lanes():
    var hero_front_left := Field.cell_for(FigureState.SIDE_HEROES, 0, 0)
    assert_eq(Field.distance(hero_front_left, Field.cell_for(FigureState.SIDE_ENEMIES, 0, 0)), 1)
    assert_eq(Field.distance(hero_front_left, Field.cell_for(FigureState.SIDE_ENEMIES, 0, 1)), 1, "diagonal")
    assert_eq(Field.distance(hero_front_left, Field.cell_for(FigureState.SIDE_ENEMIES, 0, 2)), 2)

func test_free_step_is_straight_only():
    var b := BattleFixture.battle()
    var h := BattleFixture.hero(b, "fighter", 1, 1, [])
    var steps: Array[Vector2i] = Targeting.free_step_cells(b, h)
    assert_eq(steps.size(), 4)
    for c in steps:
        assert_eq(absi(c.x - 1) + absi(c.y - 4), 1, "%s is a straight step" % str(c))

func test_large_enemy_is_in_reach_if_any_square_is():
    var b := BattleFixture.battle()
    var h := BattleFixture.hero(b, "fighter", 0, 2, [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    assert_true(b.in_reach(h, ogre), "ogre's front-centre square is diagonal to the hero")

func test_front_row_shifts_back_when_empty():
    var b := BattleFixture.battle()
    BattleFixture.hero(b, "fighter", 0, 1, [])
    BattleFixture.enemy(b, "goblin", 1, 0)
    assert_eq(b.enemy_front_row_y(), Field.cell_for(FigureState.SIDE_ENEMIES, 1, 0).y)
