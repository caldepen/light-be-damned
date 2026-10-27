extends GutTest

## RULES §6 Who enemies attack, §7 enemy turns: free step, targets, morale, playable cards,
## ▲ once per battle, ◆ once per enemy, Go Fish, reshuffles; §12 goblin and ogre cards.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_free_step_toward_the_top_provoke_hero():
    BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 2, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.cells[0], Field.cell_for(FigureState.SIDE_ENEMIES, 1, 1))

func test_melee_hits_the_highest_provoke_hero_in_reach():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    b.provoke.move(thief, 3)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(thief.armor_damage, 2)
    assert_eq(fighter.armor_damage, 0)

func test_melee_throw_card_throws_at_the_top_hero_when_nobody_is_in_reach():
    var fighter := BattleFixture.hero(b, "fighter", 2, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 2, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 1, "Throw 1, not Melee 2")
    assert_eq(b.log.of_type("enemy_attack")[0]["details"]["how"], "throw")

func test_goblin_shortbow_hits_the_lowest_provoke_hero():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["smite"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    b.provoke.move(fighter, 2)
    BattleFixture.stack_enemy_deck(b, "goblin", ["goblin_shortbow"])
    EnemyTurn.take(b, goblin)
    assert_eq(cleric.armor_damage, 1)
    assert_eq(fighter.armor_damage, 0)

func test_gang_up_adds_one_per_other_goblin():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.enemy(b, "goblin", 0, 2)
    BattleFixture.stack_enemy_deck(b, "goblin", ["gang_up"])
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 3)

func test_morale_bold_and_desperate_play_highest_timid_lowest():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    fighter.armor_slots = 20
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand", "crushing_blow", "backhand", "crushing_blow", "backhand", "crushing_blow"])
    EnemyTurn.take(b, ogre)
    assert_eq(fighter.armor_damage, 5, "Bold: Crushing Blow")
    ogre.marked_hd = 3
    EnemyTurn.take(b, ogre)
    assert_eq(fighter.armor_damage, 6, "Timid (3 of 5 marked): Backhand")
    ogre.marked_hd = 4
    EnemyTurn.take(b, ogre)
    assert_eq(fighter.armor_damage, 11, "Desperate (last Hd): Crushing Blow")

func test_a_dm_flips_extra_cards():
    BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower", "cower", "cower", "cower", "cower", "cower", "cower", "cower"])
    EnemyTurn.take(b, goblin)
    assert_eq(b.log.of_type("enemy_flip").size(), 1, "automated: Draw 1")
    b.dm_mode = Battle.DM_STANDARD
    EnemyTurn.take(b, goblin)
    assert_eq(b.log.of_type("enemy_flip").size(), 3, "standard DM: Draw +1")
    b.dm_mode = Battle.DM_RUTHLESS
    EnemyTurn.take(b, goblin)
    assert_eq(b.log.of_type("enemy_flip").size(), 7, "ruthless DM: Draw +3")

func test_the_greedy_dm_ignores_morale():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    fighter.armor_slots = 20
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    ogre.marked_hd = 3
    b.dm_mode = Battle.DM_STANDARD
    BattleFixture.stack_enemy_deck(b, "ogre", ["backhand", "crushing_blow", "backhand"])
    EnemyTurn.take(b, ogre)
    assert_eq(b.dm_policy, Battle.DM_POLICY_GREEDY, "greedy is the default policy")
    assert_eq(fighter.armor_damage, 5, "Timid, but the greedy DM plays Crushing Blow")

func test_top_tier_card_once_per_battle_then_go_fish():
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["stab", "dodge", "stab"], [])
    thief.armor_slots = 10
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["disarm", "disarm", "spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(thief.hand.size(), 2, "Disarm made the thief discard")
    assert_eq(thief.owed_draws, 1, "replaced at the start of the thief's next turn")
    EnemyTurn.take(b, goblin)
    assert_true(b.log.has_type("go_fish"), "Disarm again is unplayable, so the goblin Goes Fish")
    assert_eq(thief.armor_damage, 3, "Disarm 1, then Spear 2")

func test_disarm_never_knocks_a_hero_down():
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["stab", "wound", "wound"], [])
    thief.armor_slots = 10
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["disarm"])
    EnemyTurn.take(b, goblin)
    assert_false(thief.down)
    assert_true(BattleFixture.card_in(thief.hand, "stab"))
    assert_true(b.log.has_type("discard_prevented"))

func test_disarm_wont_discard_a_last_card_when_the_deck_is_empty():
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["stab"], [])
    thief.armor_slots = 10
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["disarm"])
    EnemyTurn.take(b, goblin)
    assert_false(thief.down, "an empty hand and deck would be Down, so nothing is discarded")
    assert_eq(thief.hand.size(), 1)

func test_hex_discards_but_never_knocks_a_hero_down():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash", "challenge", "wound"], [])
    var witch := BattleFixture.enemy(b, "witch", 2, 1)
    CardRunner.resolve_enemy_card(b, witch, BattleFixture.enemy_card("witch", "hex"))
    assert_false(fighter.down)
    assert_eq(fighter.non_wound_cards().size(), 1, "the first discard happens; the second would leave only a Wound")
    assert_eq(fighter.owed_draws, 1)
    assert_true(b.log.has_type("discard_prevented"))

func test_roar_discards_a_card_of_choice_but_never_downs():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash", "challenge"], [])
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["smite", "wound"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["roar", "dim_witted"])
    provider.then(DecisionRequest.FORCED_DISCARD, "challenge")
    EnemyTurn.take(b, ogre)
    assert_eq(fighter.hand.size(), 1)
    assert_true(BattleFixture.card_in(fighter.discard, "challenge"))
    assert_false(cleric.down, "Roar can't leave the cleric with only Wounds")
    assert_true(BattleFixture.card_in(cleric.hand, "smite"))

func test_phase_card_takes_effect_once_per_enemy():
    var fighter := BattleFixture.hero(b, "fighter", 2, 0, ["bash"], [])
    fighter.armor_slots = 30
    var ogre_1 := BattleFixture.enemy(b, "ogre", 0, 0)
    # Two 2x2 ogres can't share the enemy board, so the second stands on the hero board.
    var ogre_2 := BattleSetup.make_enemy(b, "ogre")
    var cells: Array[Vector2i] = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4)]
    b.enemies.append(ogre_2)
    b.field.place(ogre_2, cells)
    BattleFixture.stack_enemy_deck(b, "ogre", ["rage", "dim_witted", "rage", "dim_witted", "rage", "dim_witted"])
    EnemyTurn.take(b, ogre_1)
    EnemyTurn.take(b, ogre_2)
    assert_true(ogre_1.statuses.has("rage"))
    assert_true(ogre_2.statuses.has("rage"), "a second ogre can Rage too")
    EnemyTurn.take(b, ogre_1)
    assert_true(b.log.has_type("phase_repeat"), "the third Rage counts as unflipped for ogre 1")

func test_a_used_phase_card_with_no_other_card_goes_fish():
    var fighter := BattleFixture.hero(b, "fighter", 0, 0, ["bash"], [])
    fighter.armor_slots = 30
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    ogre.draw_count = 1
    ogre.used_phase["rage"] = true
    BattleFixture.stack_enemy_deck(b, "ogre", ["rage", "club_swing"])
    EnemyTurn.take(b, ogre)
    assert_true(b.log.has_type("go_fish"))
    assert_eq(fighter.armor_damage, 3)

func test_go_fish_then_the_turn_is_lost():
    BattleFixture.hero(b, "wizard", 2, 2, ["fire_bolt"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 1, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["club_swing", "backhand", "crushing_blow"])
    EnemyTurn.take(b, ogre)
    assert_true(b.log.has_type("go_fish"))
    assert_true(b.log.has_type("turn_lost"))

func test_an_empty_deck_reshuffles_its_discards():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var deck: EnemyDeck = b.deck_for("goblin")
    deck.draw_pile.clear()
    deck.discard_pile.clear()
    deck.discard_pile.append(BattleFixture.enemy_card("goblin", "spear"))
    EnemyTurn.take(b, goblin)
    assert_true(b.log.has_type("reshuffle"))
    assert_eq(fighter.armor_damage, 2)

func test_flee_when_half_or_more_hd_are_marked_otherwise_attack():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["flee", "flee"])
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 1, "unhurt: Melee 1")
    goblin.marked_hd = 2
    EnemyTurn.take(b, goblin)
    assert_true(goblin.fled)
    assert_true(goblin.down)

func test_shriek_brings_a_goblin_only_for_the_last_goblin():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var other := BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.stack_enemy_deck(b, "goblin", ["shriek", "shriek"])
    EnemyTurn.take(b, goblin)
    assert_eq(b.enemies.size(), 2)
    assert_eq(fighter.armor_damage, 1, "not last: Melee 1")
    other.down = true
    b.field.remove(other)
    EnemyTurn.take(b, goblin)
    assert_eq(b.enemies.size(), 3)

func test_heal_cards_need_something_damaged():
    BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    var card := BattleFixture.enemy_card("skeleton", "reassemble")
    assert_false(CardRunner.enemy_card_playable(b, skeleton, card))
    skeleton.marked_hd = 1
    assert_true(CardRunner.enemy_card_playable(b, skeleton, card))

func test_vault_needs_the_square_behind_a_front_row_hero():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    BattleFixture.hero(b, "cleric", 1, 1, ["smite"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var vault := BattleFixture.enemy_card("goblin", "vault")
    assert_false(CardRunner.enemy_card_playable(b, goblin, vault), "the square behind the fighter is taken")
    var front_left: Array[Vector2i] = [Vector2i(0, 3)]
    b.field.place(fighter, front_left)
    assert_true(CardRunner.enemy_card_playable(b, goblin, vault))
    CardRunner.resolve_enemy_card(b, goblin, vault)
    assert_eq(goblin.cells[0], Vector2i(0, 4))

func test_a_stunned_enemy_skips_its_turn():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    goblin.stunned = true
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 0)
    assert_false(goblin.stunned)

func test_stomp_hits_every_hero_within_one_square():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["smite"], [])
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    CardRunner.resolve_enemy_card(b, ogre, BattleFixture.enemy_card("ogre", "stomp"))
    assert_eq(fighter.armor_damage, 2)
    assert_eq(cleric.armor_damage, 2)
    assert_eq(wizard.wound_count(), 0)

func test_rampage_splashes_a_hero_next_to_the_target():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["smite"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    CardRunner.resolve_enemy_card(b, ogre, BattleFixture.enemy_card("ogre", "rampage"))
    assert_eq(fighter.armor_damage, 4)
    assert_eq(cleric.armor_damage, 2)

func test_throw_goblin_lands_in_the_heroes_back_row():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt", "study"], [])
    BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    var goblin := BattleFixture.enemy(b, "goblin", 0, 2)
    b.provoke.move(wizard, 5)
    CardRunner.resolve_enemy_card(b, ogre, BattleFixture.enemy_card("ogre", "throw_goblin"))
    assert_eq(Field.board_of(goblin.cells[0]), FigureState.SIDE_HEROES)
    assert_eq(Field.row_of(goblin.cells[0]), 2)
    assert_eq(wizard.wound_count(), 1, "1 landing damage, no armor")
    assert_true(ogre.used_top.has("throw_goblin"))
