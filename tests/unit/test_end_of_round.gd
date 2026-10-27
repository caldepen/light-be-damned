extends GutTest

## RULES §4 end of round and §13: Bleed X deals 1 a round for X rounds, Bleeds stack; Stun skips one
## turn and doesn't stack; Lightning Orb strikes enemies in melee for two rounds.

var b: Battle
var fighter: HeroState
var goblin: EnemyState

func before_each():
    b = BattleFixture.battle(ScriptedProvider.new().always_pass())
    fighter = BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    goblin = BattleFixture.enemy(b, "goblin", 0, 1)

func test_bleed_deals_one_a_round_for_x_rounds():
    b.apply_bleed(goblin, 2, fighter)
    b.end_round()
    assert_eq(goblin.armor_damage, 1)
    b.end_round()
    assert_eq(goblin.marked_hd, 1)
    b.end_round()
    assert_eq(goblin.marked_hd, 1, "Bleed 2 is over")
    assert_eq(goblin.bleeds.size(), 0)

func test_bleed_2_played_in_round_1_ticks_at_the_end_of_rounds_1_and_2():
    var provider := ScriptedProvider.new().always_pass()
    var round_b := BattleFixture.battle(provider)
    BattleFixture.hero(round_b, "thief", 0, 0, ["poisoned_blade", "stab"], ["stab", "stab", "stab"])
    var target := BattleFixture.enemy(round_b, "goblin", 0, 0)
    BattleFixture.stack_enemy_deck(round_b, "goblin", ["goblin_shortbow", "goblin_shortbow", "goblin_shortbow"])
    provider.then(DecisionRequest.TURN, "poisoned_blade")
    for round_no in [1, 2, 3]:
        round_b.round_number = round_no
        round_b.play_round()
    var tick_rounds: Array = []
    for entry in round_b.log.of_type("bleed_tick"):
        tick_rounds.append(entry["details"]["round"])
    assert_eq(tick_rounds, [1, 2], "counting from the end of the round it was played in")
    assert_eq(target.armor_damage + target.marked_hd, 3, "1 from the blade, then 2 Bleed")

func test_bleeds_stack_as_separate_tracks():
    b.apply_bleed(goblin, 2, fighter)
    b.apply_bleed(goblin, 2, fighter)
    b.end_round()
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2)

func test_bleed_ticks_earn_no_provoke():
    b.apply_bleed(goblin, 2, fighter)
    b.end_round()
    assert_eq(b.provoke.value_of(fighter), 0)

func test_stuns_do_not_stack():
    BattleFixture.stack_enemy_deck(b, "goblin", ["spear", "spear"])
    b.apply_stun(goblin, fighter)
    b.apply_stun(goblin, fighter)
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 0, "skips one turn")
    EnemyTurn.take(b, goblin)
    assert_eq(fighter.armor_damage, 2, "acts on the next")

func test_lightning_orb_strikes_for_two_rounds():
    var wizard := BattleFixture.hero(b, "wizard", 0, 0, ["lightning_orb"])
    var near := BattleFixture.enemy(b, "goblin", 0, 0)
    (b.decisions as ScriptedProvider).fallback = SimpleAiProvider.new()
    BattleFixture.play(b, wizard, "lightning_orb")
    assert_eq(wizard.guard_tokens, 2)
    b.end_round()
    b.end_round()
    b.end_round()
    assert_eq(near.armor_damage + near.marked_hd, 2, "1 at the end of each of two rounds")
