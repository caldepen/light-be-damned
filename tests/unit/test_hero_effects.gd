extends GutTest

## Hero effect ops from heroes.json (RULES §6, §11): healing, cleansing, bonuses, areas, undead, recovery.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_a_healed_wound_is_replaced_by_a_draw():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["healing_word", "smite"], ["smite", "mend"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "bash", "bash", "bash", "bash", "bash"], ["challenge"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "healing_word")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(fighter.hand.size(), 6)
    assert_true(BattleFixture.card_in(fighter.hand, "challenge"))

func test_mend_needs_a_hero_within_one_square_and_includes_the_cleric():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["mend", "healing_word"])
    BattleFixture.hero(b, "wizard", 2, 0, ["wound", "fire_bolt"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    assert_false(CardRunner.is_card_legal(b, cleric, cleric.hand[0]), "the wizard is too far for Mend")
    assert_true(CardRunner.is_card_legal(b, cleric, cleric.hand[1]))
    cleric.hand.append(Card.make_wound(b.new_uid()))
    assert_true(CardRunner.is_card_legal(b, cleric, cleric.hand[0]), "Mend can heal the cleric")

func test_lay_on_hands_wounds_wait_for_the_clerics_refill():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["lay_on_hands", "wound"], ["smite", "mend", "smite"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "wound", "bash"], ["challenge", "bash"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "lay_on_hands")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(fighter.hand.size(), 3, "the fighter drew a replacement for each Wound")
    assert_false(cleric.down, "3 Wounds for a moment, then the refill draws 2")
    assert_eq(cleric.wound_count(), 3)
    assert_eq(cleric.hand.size(), 5)
    assert_false(b.log.has_type("down"))

func test_lay_on_hands_filling_the_hand_with_wounds_downs_the_cleric():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["lay_on_hands", "wound", "wound", "wound"], ["smite"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "wound", "bash"], ["challenge", "bash"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "lay_on_hands")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(cleric.wound_count(), 5, "Wounds count toward hand size")
    assert_eq(cleric.deck.size(), 1, "a hand full of Wounds gets no refill")
    assert_true(cleric.down, "a deliberate sacrifice")

func test_cleanse_removes_any_mix_of_wounds_and_armor():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["cleanse_armor"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "bash"], ["challenge"])
    fighter.armor_damage = 3
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TARGET, "fighter").then(DecisionRequest.CLEANSE_SPLIT, 1)
    BattleFixture.play(b, cleric, "cleanse_armor")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(fighter.armor_damage, 2)
    assert_eq(provider.requests_of(DecisionRequest.CLEANSE_SPLIT)[0].options, [1, 0])

func test_bless_adds_two_to_each_target_hit():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["bless"])
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["spark"])
    var g1 := BattleFixture.enemy(b, "goblin", 2, 0)
    var g2 := BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "bless")
    BattleFixture.play(b, wizard, "spark")
    assert_eq(g1.armor_damage + g1.marked_hd, 3, "Spark 1 + Bless 2")
    assert_eq(g2.armor_damage + g2.marked_hd, 3)
    assert_eq(wizard.buffs.size(), 0, "used up")

func test_bless_targets_an_ally_never_the_cleric():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["bless"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    assert_false(CardRunner.is_card_legal(b, cleric, cleric.hand[0]), "no ally to Bless")
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    BattleFixture.hero(b, "wizard", 2, 1, ["spark"])
    provider.then(DecisionRequest.TARGET, "fighter")
    BattleFixture.play(b, cleric, "bless")
    var options: Array = provider.requests_of(DecisionRequest.TARGET)[0].options
    assert_false(options.has(cleric))
    assert_eq(fighter.buffs.size(), 1)

func test_bless_on_a_guard_card_adds_two_guard_tokens():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["bless"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["raise_shield"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "bless")
    BattleFixture.play(b, fighter, "raise_shield")
    assert_eq(fighter.guard_tokens, 4)

func test_bless_on_battle_cry_adds_two_to_every_hero():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["bless"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["battle_cry"])
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TARGET, "fighter")
    BattleFixture.play(b, cleric, "bless")
    BattleFixture.play(b, fighter, "battle_cry")
    assert_eq(fighter.guard_tokens, 3, "Guard 1 + Bless 2")
    assert_eq(thief.guard_tokens, 3)
    assert_eq(cleric.guard_tokens, 3)

func test_arcane_surge_adds_two_to_each_spark_target():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["arcane_surge", "spark"])
    var g1 := BattleFixture.enemy(b, "goblin", 2, 0)
    var g2 := BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, wizard, "arcane_surge")
    BattleFixture.play(b, wizard, "spark")
    assert_eq(g1.armor_damage + g1.marked_hd, 3)
    assert_eq(g2.armor_damage + g2.marked_hd, 3)

func test_divine_light_with_bless_vs_undead_adds_first_then_doubles():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["divine_light"])
    var skeleton := BattleFixture.enemy(b, "skeleton", 2, 0)
    cleric.buffs.append({"amount": 2, "applies_to": "damage_or_guard", "source": "Bless"})
    skeleton.armor_slots = 10
    BattleFixture.play(b, cleric, "divine_light")
    assert_eq(skeleton.armor_damage, 8, "(2 + 2) x 2")

func test_taunt_is_provoke_three_and_guard_one():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["taunt"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "taunt")
    assert_eq(b.provoke.value_of(fighter), 3)
    assert_eq(fighter.guard_tokens, 1)
    assert_eq(fighter.cells[0], Vector2i(1, 3), "no step")

func test_brace_is_guard_three():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["brace"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "brace")
    assert_eq(fighter.guard_tokens, 3)
    assert_eq(fighter.statuses.size(), 0)

func test_caltrops_hits_the_enemy_front_row_without_reach():
    var thief := BattleFixture.hero(b, "thief", 2, 0, ["caltrops"])
    var front := BattleFixture.enemy(b, "goblin", 0, 2)
    assert_true(CardRunner.is_card_legal(b, thief, thief.hand[0]), "from the back row, nowhere near")
    BattleFixture.play(b, thief, "caltrops")
    assert_eq(front.armor_damage, 1)

func test_feint_waits_for_the_next_attack_card():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["feint", "dodge", "stab"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.play(b, thief, "feint")
    BattleFixture.play(b, thief, "dodge")
    assert_eq(thief.guard_tokens, 2, "Feint doesn't apply to Guard")
    BattleFixture.play(b, thief, "stab")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 4, "Stab 2 + Feint 2, a turn later")

func test_berserk_attacks_the_strongest_enemy_in_reach_with_plus_one():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["berserk", "bash"])
    var hurt := BattleFixture.enemy(b, "goblin", 0, 0)
    var fresh := BattleFixture.enemy(b, "goblin", 0, 1)
    hurt.marked_hd = 2
    BattleFixture.play(b, fighter, "berserk")
    BattleFixture.play(b, fighter, "bash")
    assert_eq(fresh.armor_damage + fresh.marked_hd, 3)
    assert_eq(hurt.marked_hd, 2)

func test_spark_hits_two_different_enemies():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["spark"])
    var g1 := BattleFixture.enemy(b, "goblin", 2, 0)
    var g2 := BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, wizard, "spark")
    assert_eq(g1.armor_damage, 1)
    assert_eq(g2.armor_damage, 1)

func test_elemental_missile_bolts_can_all_hit_one_enemy():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["elemental_missile"])
    var goblin := BattleFixture.enemy(b, "goblin", 2, 1)
    BattleFixture.play(b, wizard, "elemental_missile")
    assert_true(goblin.down, "3 bolts x 2 = 6 beats armor 1 + 4 Hd")

func test_divine_light_deals_double_to_undead():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["divine_light"])
    var skeleton := BattleFixture.enemy(b, "skeleton", 2, 0)
    BattleFixture.play(b, cleric, "divine_light")
    assert_true(skeleton.down, "4 damage: armor 1 + 3 Hd")

func test_quake_hits_and_stuns_the_shifting_front_row():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["quake"])
    var middle := BattleFixture.enemy(b, "goblin", 1, 0)
    var back := BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "quake")
    assert_true(middle.stunned, "the middle row is the front row while the front is empty")
    assert_false(back.stunned)
    assert_eq(middle.armor_damage, 1)

func test_turn_undead_stuns_only_undead_in_the_front_row():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["turn_undead"])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 0)
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, cleric, "turn_undead")
    assert_true(skeleton.stunned)
    assert_false(goblin.stunned)

func test_consecrate_can_straddle_both_front_rows():
    var cleric := BattleFixture.hero(b, "cleric", 1, 2, ["consecrate"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "bash"], ["challenge"])
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    provider.then(DecisionRequest.AREA, Vector2i(0, 2))
    BattleFixture.play(b, cleric, "consecrate")
    assert_true(skeleton.down, "2 radiant x2 vs undead = 4")
    assert_eq(fighter.wound_count(), 0)

func test_twin_daggers_one_each_to_two_or_two_to_one():
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["twin_daggers"])
    var g1 := BattleFixture.enemy(b, "goblin", 0, 0)
    var g2 := BattleFixture.enemy(b, "goblin", 0, 1)
    provider.then(DecisionRequest.MOVE_TARGET, "goblin_1")
    provider.then(DecisionRequest.DAMAGE_OPTION, func(o: Dictionary) -> bool: return o["targets"].size() == 2)
    BattleFixture.play(b, thief, "twin_daggers")
    assert_eq(g1.armor_damage, 1)
    assert_eq(g2.armor_damage, 1)
    var options: Array = provider.requests_of(DecisionRequest.DAMAGE_OPTION)[0].options
    assert_eq(options.size(), 3, "1 to both, or 2 to either")

func test_recovery_never_brings_back_exhausted_cards():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["second_wind"], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    fighter.exhausted = BattleFixture.cards(b, "fighter", ["charge"])
    fighter.discard = BattleFixture.cards(b, "fighter", ["bash", "challenge"])
    BattleFixture.play(b, fighter, "second_wind")
    assert_eq(fighter.discard.size(), 1, "Second Wind itself is discarded after it resolves")
    assert_true(BattleFixture.card_in(fighter.discard, "second_wind"))
    assert_true(BattleFixture.card_in(fighter.exhausted, "charge"))
    assert_true(BattleFixture.card_in(fighter.hand, "bash") or BattleFixture.card_in(fighter.hand, "challenge"), "refilled from the recovered cards")

func test_reveal_weakness_reorders_the_top_of_a_deck():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["reveal_weakness"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear", "rusty_blade", "cower", "spear"])
    BattleFixture.play(b, thief, "reveal_weakness")
    var top: Array[Dictionary] = b.deck_for("goblin").peek(3)
    assert_eq(top[0]["id"], "cower", "the AI puts the weakest card on top")
    assert_eq(b.deck_for("goblin").draw_pile.size(), 4)

func test_frost_ray_weakens_the_targets_next_attack():
    var wizard := BattleFixture.hero(b, "wizard", 1, 1, ["frost_ray"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, wizard, "frost_ray")
    assert_eq(wizard.cells[0], Vector2i(1, 5), "stepped back")
    b.provoke.move(fighter, 5)  # top again, so the goblin stabs the fighter instead of throwing at the wizard
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear"])
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 1, "Spear 2 - 1")

func test_smoke_bomb_stuns_enemies_next_to_the_old_square_and_moves():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["smoke_bomb"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.play(b, thief, "smoke_bomb")
    assert_true(goblin.stunned)
    assert_eq(Field.row_of(thief.cells[0]), 2, "the AI retreats to the back row")

func test_calculated_retreat_moves_to_any_empty_square_of_your_own_board():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["calculated_retreat", "calculated_retreat"])
    BattleFixture.hero(b, "cleric", 1, 1, ["smite"])
    BattleFixture.enemy(b, "goblin", 0, 1)
    provider.then(DecisionRequest.MOVE_SQUARE, Vector2i(2, 5))
    BattleFixture.play(b, fighter, "calculated_retreat")
    assert_eq(fighter.cells[0], Vector2i(2, 5), "from its own front row into the back row")
    assert_eq(provider.requests_of(DecisionRequest.MOVE_SQUARE)[0].options.size(), 7, "every empty square of the hero board")
    var forward: Array[Vector2i] = [Vector2i(1, 2)]
    b.field.place(fighter, forward)
    provider.then(DecisionRequest.MOVE_SQUARE, Vector2i(0, 3))
    BattleFixture.play(b, fighter, "calculated_retreat")
    assert_eq(fighter.cells[0], Vector2i(0, 3), "an escape from the enemy board")

func test_wizard_signature_uses_the_option_chosen_at_setup():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["wizard_signature"])
    wizard.signature_option = BattleFixture.card_def("wizard", "wizard_signature")["effects"][0]["options"][2]
    var goblin := BattleFixture.enemy(b, "goblin", 2, 1)
    BattleFixture.play(b, wizard, "wizard_signature")
    assert_true(goblin.down, "Frost Spike: 5 damage")
    assert_true(BattleFixture.card_in(wizard.exhausted, "wizard_signature"))
