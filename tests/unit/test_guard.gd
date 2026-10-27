extends GutTest

## RULES §6 Guard: one Guard card per hero; tokens stack; the card turns sideways at the end of the
## round it was played and is discarded at the end of the next round; Guard absorbs Bleed.

var b: Battle
var fighter: HeroState
var goblin: EnemyState

func before_each():
    b = BattleFixture.battle()
    fighter = BattleFixture.hero(b, "fighter", 0, 1, ["bash"], [])
    goblin = BattleFixture.enemy(b, "goblin", 0, 1)

func test_guard_lasts_until_the_end_of_the_next_round():
    b.round_number = 1
    b.add_guard(fighter, 2, fighter)
    b.end_round()
    assert_eq(fighter.guard_tokens, 2, "sideways at the end of round 1, still in play")
    b.round_number = 2
    b.end_round()
    assert_eq(fighter.guard_tokens, 0, "discarded at the end of round 2")

func test_more_guard_adds_tokens_and_keeps_the_cards_timing():
    b.round_number = 1
    b.add_guard(fighter, 2, fighter)
    b.round_number = 2
    b.add_guard(fighter, 1, fighter)
    assert_eq(fighter.guard_tokens, 3)
    b.end_round()
    assert_eq(fighter.guard_tokens, 0, "the tokens added in round 2 go with the round-1 card")

func test_a_new_guard_card_after_the_old_one_is_discarded():
    b.round_number = 1
    b.add_guard(fighter, 1, fighter)
    b.round_number = 2
    b.end_round()
    b.round_number = 3
    b.add_guard(fighter, 1, fighter)
    b.end_round()
    assert_eq(fighter.guard_tokens, 1, "played in round 3, lasts through round 4")

func test_guard_absorbs_bleed():
    b.add_guard(fighter, 1, fighter)
    b.apply_bleed(fighter, 1, goblin)
    b.end_round()
    assert_eq(fighter.armor_damage, 0)
    assert_eq(fighter.guard_tokens, 0)

func test_enemy_guard_uses_the_same_timing():
    b.round_number = 1
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower"])
    EnemyTurn.take(b, goblin)
    assert_eq(goblin.guard_tokens, 1)
    b.end_round()
    assert_eq(goblin.guard_tokens, 1)
    b.round_number = 2
    b.end_round()
    assert_eq(goblin.guard_tokens, 0)
