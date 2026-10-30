extends GutTest

## RULES §5 Free step (clarified 2026-10-29, rulings #66-67): one free straight step before a melee
## attack only, onto either board. Enemies decide before moving: step and hit if a hero will be in
## reach, else throw from where they stand, else step and end the turn. Occupied squares block and
## a 2×2 enemy moves as a block; card movement replaces the step (cards beat rules, Frost Ray);
## "enemy front row" cards only hit the DM board. The hero stepping onto the DM board is also in
## test_movement.gd.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_an_enemy_steps_onto_the_heroes_board_to_attack():
    var fighter := BattleFixture.hero(b, "fighter", 1, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1), "into the empty hero front row")
    assert_eq(Field.board_of(goblin.cells[0]), FigureState.SIDE_HEROES)
    assert_eq(b.log.of_type("enemy_attack")[0]["details"]["how"], "melee")
    assert_eq(fighter.armor_damage, 2, "Spear Melee 2")

func test_still_out_of_reach_the_enemy_steps_and_the_turn_ends():
    var fighter := BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade", "bone_blade"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1), "one step, onto the heroes' board")
    assert_false(b.in_reach(skeleton, fighter))
    assert_eq(b.log.of_type("enemy_attack").size(), 0, "Bone Blade is melee only")
    assert_eq(b.log.of_type("go_fish").size(), 1, "worth 0, so it Goes Fish (#69): another Bone Blade")
    assert_eq(b.log.of_type("advance").size(), 1)

func test_go_fish_finds_a_card_with_another_use_and_plays_it_instead_of_stepping():
    BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    var start: Array[Vector2i] = skeleton.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade", "rattle"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.guard_tokens, 1, "Rattle")
    assert_eq(skeleton.cells, start)
    assert_false(b.log.has_type("advance"))

func test_a_goblin_with_no_melee_target_throws_without_moving():
    var fighter := BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var start: Array[Vector2i] = goblin.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells, start, "no step before a throw")
    assert_eq(b.log.of_type("move").size(), 0)
    assert_eq(b.log.of_type("enemy_attack")[0]["details"]["how"], "throw")
    assert_eq(fighter.armor_damage, 1, "Throw 1, not Melee 2")

func test_an_enemy_playing_a_card_without_a_melee_attack_does_not_step():
    BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var start: Array[Vector2i] = goblin.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells, start)
    assert_eq(goblin.guard_tokens, 1)

func test_an_occupied_square_blocks_the_step():
    BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    var blocker := BattleFixture.enemy(b, "skeleton", 0, 0)
    var ahead: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_HEROES, 0, 1)]
    b.move_figure(blocker, ahead, "test")
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_ENEMIES, 0, 1), "no diagonal step around the blocker")

func test_the_ogre_steps_as_a_block_when_both_squares_ahead_are_empty():
    BattleFixture.hero(b, "fighter", 2, 0, ["bash"], [])
    var thief := BattleFixture.hero(b, "thief", 0, 2, ["stab"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand"])
    EnemyTurn.take(b, ogre)
    var expected: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)]
    for c in expected:
        assert_true(ogre.cells.has(c), "the ogre covers %s" % str(c))
    assert_eq(ogre.cells.size(), 4)
    assert_eq(thief.armor_damage, 1, "Backhand on the hero in reach")

func test_the_ogre_needs_every_new_square_empty():
    BattleFixture.hero(b, "fighter", 2, 0, ["bash"], [])
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["stab"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    var before: Array[Vector2i] = ogre.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand"])
    EnemyTurn.take(b, ogre)
    assert_eq(ogre.cells, before, "the thief stands in one of the two squares ahead")
    assert_eq(thief.armor_damage, 1, "it hits the thief from where it stands")

func test_a_hero_steps_onto_the_dm_board():
    var fighter := BattleFixture.hero(b, "fighter", 0, 0, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 1, 0)
    BattleFixture.play(b, fighter, "bash")
    assert_eq(fighter.cells[0], Field.cell_for(FigureState.SIDE_ENEMIES, 0, 0))
    assert_eq(Field.board_of(fighter.cells[0]), FigureState.SIDE_ENEMIES)
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2)

func test_frost_ray_still_steps_back_and_then_fires():
    var wizard := BattleFixture.hero(b, "wizard", 0, 1, ["frost_ray"])
    var goblin := BattleFixture.enemy(b, "goblin", 2, 1)
    provider.then(DecisionRequest.OPTIONAL_MOVE, true)
    BattleFixture.play(b, wizard, "frost_ray")
    assert_eq(wizard.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 1, 1), "the card's own step back")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2, "then Ranged 2")

func test_enemy_card_movement_replaces_the_free_step():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 1, 1)
    BattleFixture.stack_enemy_deck(b, "skeleton", ["clatter_forward"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_ENEMIES, 0, 1), "one square: the card's move only")
    assert_eq(b.log.of_type("move").size(), 1)
    assert_eq(fighter.armor_damage, 1, "Clatter Forward Melee 1")

func test_enemy_front_row_cards_skip_enemies_on_the_heroes_board():
    var thief := BattleFixture.hero(b, "thief", 2, 0, ["caltrops", "caltrops"])
    var front := BattleFixture.enemy(b, "goblin", 0, 0)
    var intruder := BattleFixture.enemy(b, "goblin", 0, 2)
    var onto: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_HEROES, 0, 2)]
    b.move_figure(intruder, onto, "test")
    BattleFixture.play(b, thief, "caltrops")
    assert_eq(front.armor_damage, 1)
    assert_eq(intruder.armor_damage, 0, "standing on the heroes' board, not in the DM front row")

func test_enemy_front_row_cards_have_no_target_when_every_enemy_is_on_the_heroes_board():
    var thief := BattleFixture.hero(b, "thief", 2, 0, ["caltrops"])
    var intruder := BattleFixture.enemy(b, "goblin", 0, 2)
    var onto: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_HEROES, 0, 2)]
    b.move_figure(intruder, onto, "test")
    assert_false(CardRunner.is_card_legal(b, thief, thief.hand[0]))
