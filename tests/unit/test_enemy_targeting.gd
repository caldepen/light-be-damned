extends GutTest

## RULES §7 Targeting priority (ruling #70): the top-Provoke hero in melee reach after the step,
## else a throw at them from where the enemy stands, else (melee only) the step toward them and
## the best hero then in reach. The step is never skipped to hit a hero already in reach.
## Ruling #69: only 0-value melee cards means Go Fish, then step. Ruling #68: a large enemy in a
## row or area takes the effect once.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_steps_and_stabs_the_top_hero_rather_than_throwing():
    var fighter := BattleFixture.hero(b, "fighter", 1, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1))
    assert_eq(b.log.of_type("enemy_attack")[0]["details"]["how"], "melee")
    assert_eq(fighter.armor_damage, 2, "Spear Melee 2, not Throw 1")

func test_cant_reach_the_top_hero_so_it_throws_at_them_without_moving():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab"], [])
    var wizard := BattleFixture.hero(b, "wizard", 2, 2, ["fire_bolt"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var start: Array[Vector2i] = goblin.cells.duplicate()
    b.provoke.move(wizard, 5)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells, start, "no step before a throw")
    var attack: Dictionary = b.log.of_type("enemy_attack")[0]["details"]
    assert_eq(attack["how"], "throw")
    assert_eq(attack["target"], wizard.id, "the top hero, though the thief is in reach")
    assert_eq(thief.armor_damage, 0)

func test_melee_only_steps_toward_the_top_hero_then_hits_the_best_hero_in_reach():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"], [])
    var cleric := BattleFixture.hero(b, "cleric", 1, 0, ["smite"], [])
    var thief := BattleFixture.hero(b, "thief", 1, 2, ["stab"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    b.provoke.move(thief, 1)
    b.provoke.move(cleric, 2)
    b.provoke.move(wizard, 5)
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1), "toward the wizard")
    assert_false(b.in_reach(skeleton, wizard))
    assert_eq(cleric.armor_damage, 2, "the highest-Provoke hero in reach after the step")
    assert_eq(thief.armor_damage, 0)

func test_a_lower_provoke_hero_already_adjacent_does_not_pull_it_off_course():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"], [])
    var thief := BattleFixture.hero(b, "thief", 0, 2, ["stab"], [])
    var behind_lines: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_ENEMIES, 1, 2)]
    b.move_figure(thief, behind_lines, "test")
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    b.provoke.move(wizard, 5)
    assert_true(b.in_reach(skeleton, thief), "the thief is adjacent before the turn")
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1), "it must step toward the wizard")
    assert_eq(thief.armor_damage, 0, "out of reach after the step")
    assert_eq(b.log.of_type("advance").size(), 1)

func test_only_zero_value_melee_cards_so_it_goes_fish_and_plays_what_it_finds():
    var wizard := BattleFixture.hero(b, "wizard", 2, 2, ["fire_bolt", "fire_bolt", "fire_bolt", "fire_bolt"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 1, 0)
    var start: Array[Vector2i] = ogre.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand", "club_swing", "throw_goblin"])
    EnemyTurn.take(b, ogre)
    assert_true(b.log.has_type("go_fish"), "both flipped cards are worth 0")
    assert_eq(ogre.cells, start, "Throw Goblin's rock is thrown from where it stands")
    assert_eq(wizard.wound_count(), 2, "Ranged 2 on Robes 0")
    assert_false(b.log.has_type("advance"))

func test_still_worth_0_after_go_fish_so_it_steps_and_the_turn_ends():
    BattleFixture.hero(b, "wizard", 2, 2, ["fire_bolt"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 1, 0)
    var start: Array[Vector2i] = ogre.cells.duplicate()
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand", "club_swing", "crushing_blow"])
    EnemyTurn.take(b, ogre)
    assert_true(b.log.has_type("go_fish"))
    assert_eq(b.log.of_type("advance").size(), 1)
    assert_ne(ogre.cells, start, "it takes the step toward the top hero")
    assert_eq(b.log.of_type("enemy_attack").size(), 0)

func test_a_timid_enemy_picks_the_zero_card_and_just_advances():
    var wizard := BattleFixture.hero(b, "wizard", 2, 2, ["fire_bolt"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 1, 0)
    ogre.marked_hd = 3
    assert_eq(ogre.morale(), EnemyState.MORALE_TIMID)
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand", "throw_goblin"])
    EnemyTurn.take(b, ogre)
    assert_false(b.log.has_type("go_fish"), "Throw Goblin is worth 2, so there is something to play")
    assert_eq(b.log.of_type("advance").size(), 1, "Timid plays the lowest: Backhand, worth 0")
    assert_eq(wizard.wound_count(), 0)

func test_an_ogre_straddling_both_front_rows_takes_quake_once():
    var fighter := BattleFixture.hero(b, "fighter", 1, 2, ["quake"])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    var straddle: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3), Vector2i(1, 3)]
    b.move_figure(ogre, straddle, "test")
    BattleFixture.play(b, fighter, "quake")
    assert_eq(ogre.armor_damage, 1, "two of its squares are in the row, but it is hit once")
    assert_true(ogre.stunned)

func test_an_area_covering_all_four_ogre_squares_hits_it_once():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["firestorm"])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    provider.then(DecisionRequest.AREA, Vector2i(0, 1))
    BattleFixture.play(b, wizard, "firestorm")
    assert_eq(ogre.armor_damage, 2, "Firestorm 2, once")

func test_no_one_in_reach_after_the_step_so_the_turn_ends():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    BattleFixture.stack_enemy_deck(b, "skeleton", ["bone_blade"])
    EnemyTurn.take(b, skeleton)
    assert_eq(skeleton.cells[0], Field.cell_for(FigureState.SIDE_HEROES, 0, 1))
    assert_eq(b.log.of_type("enemy_attack").size(), 0)
    assert_eq(b.log.of_type("advance").size(), 1)
    assert_eq(wizard.armor_damage + wizard.wound_count(), 0)
