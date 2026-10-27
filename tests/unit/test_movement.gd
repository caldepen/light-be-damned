extends GutTest

## RULES §5 Movement and §6 Attacks: free straight step before melee; melee reach 1 including
## diagonals; ranged reaches anything; card movement replaces the free step; "nearest square in reach".

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_free_step_onto_the_enemy_board_to_get_in_reach():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 1, 1)
    assert_false(b.in_reach(fighter, goblin))
    BattleFixture.play(b, fighter, "bash")
    assert_eq(fighter.cells[0], Field.cell_for(FigureState.SIDE_ENEMIES, 0, 1), "stepped straight into the enemy front row")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2)

func test_melee_reaches_diagonally_without_a_step():
    var fighter := BattleFixture.hero(b, "fighter", 0, 0, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, fighter, "bash")
    assert_eq(fighter.cells[0], Vector2i(0, 3), "no step needed")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2)

func test_melee_out_of_reach_even_after_a_step_is_not_legal():
    var fighter := BattleFixture.hero(b, "fighter", 2, 1, ["bash"])
    BattleFixture.enemy(b, "goblin", 0, 1)
    assert_false(CardRunner.is_card_legal(b, fighter, fighter.hand[0]))

func test_ranged_reaches_any_square():
    var wizard := BattleFixture.hero(b, "wizard", 2, 0, ["fire_bolt"])
    var goblin := BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, wizard, "fire_bolt")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 3)

func test_card_movement_replaces_the_free_step():
    var fighter := BattleFixture.hero(b, "fighter", 2, 1, ["charge", "bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    assert_false(CardRunner.is_card_legal(b, fighter, fighter.hand[1]), "Bash: one free step is not enough")
    assert_true(CardRunner.is_card_legal(b, fighter, fighter.hand[0]), "Charge moves up to 2")
    BattleFixture.play(b, fighter, "charge")
    assert_true(b.in_reach(fighter, goblin))
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2)
    assert_eq(b.provoke.value_of(fighter), 4, "+2 for the 2 points that landed, +2 named")

func test_move_to_the_nearest_empty_square_in_reach():
    var thief := BattleFixture.hero(b, "thief", 2, 0, ["backstab"])
    var goblin := BattleFixture.enemy(b, "goblin", 1, 2)
    BattleFixture.play(b, thief, "backstab")
    var moves: Array = provider.requests_of(DecisionRequest.MOVE_SQUARE)
    assert_eq(moves.size(), 1, "two squares are equally close, so the player chooses")
    assert_eq(moves[0].options, [Vector2i(1, 2), Vector2i(2, 2)])
    assert_true(goblin.down, "6 damage beats armor 1 + 4 Hd")
