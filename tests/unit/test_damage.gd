extends GutTest

## RULES §6 Armor and Wounds, Thorns; §7 enemy armor and Hit Dice; Iron Skin.

var b: Battle
var provider: ScriptedProvider
var fighter: HeroState
var goblin: EnemyState

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)
    fighter = BattleFixture.hero(b, "fighter", 0, 1, ["bash", "raise_shield", "challenge"], [])
    goblin = BattleFixture.enemy(b, "goblin", 0, 1)

func test_guard_then_armor_then_wounds():
    b.add_guard(fighter, 2, fighter)
    fighter.armor_damage = 4
    b.damage(fighter, 5, goblin, true)
    assert_eq(fighter.guard_tokens, 0, "Guard absorbs 2")
    assert_eq(fighter.armor_damage, 5, "the last armor slot takes 1")
    assert_eq(fighter.wound_count(), 2, "2 points become Wounds")
    assert_eq(fighter.hand.size(), 3, "each Wound replaces a discarded card")

func test_a_wound_discards_a_non_wound_card_of_the_players_choice():
    fighter.armor_damage = fighter.armor_slots
    provider.then(DecisionRequest.WOUND_DISCARD, "challenge")
    b.damage(fighter, 1, goblin, true)
    assert_false(BattleFixture.card_in(fighter.hand, "challenge"))
    assert_true(BattleFixture.card_in(fighter.discard, "challenge"))
    assert_eq(fighter.wound_count(), 1)
    for option in provider.requests_of(DecisionRequest.WOUND_DISCARD)[0].options:
        assert_false((option as Card).is_wound, "a Wound is never offered as the discard")

func test_down_when_the_hand_is_all_wounds():
    fighter.hand = BattleFixture.cards(b, "fighter", ["wound", "bash"])
    fighter.armor_damage = fighter.armor_slots
    b.damage(fighter, 1, goblin, true)
    assert_true(fighter.down)
    assert_eq(fighter.cells.size(), 0, "a Down hero leaves the board")
    assert_null(b.field.figure_at(Vector2i(1, 3)))

func test_an_empty_hand_with_cards_in_the_deck_is_not_down_but_a_hit_then_downs():
    fighter.hand = []
    fighter.deck = BattleFixture.cards(b, "fighter", ["bash"])
    fighter.armor_damage = fighter.armor_slots
    assert_false(fighter.hand_is_all_wounds())
    b.damage(fighter, 1, goblin, true)
    assert_eq(fighter.wound_count(), 1)
    assert_true(fighter.down, "a hand of just that Wound is Down")

func test_enemy_damage_fills_armor_then_hit_dice_then_down():
    b.damage(goblin, 3, fighter, true)
    assert_eq(goblin.armor_damage, 1)
    assert_eq(goblin.marked_hd, 2)
    assert_eq(goblin.morale(), EnemyState.MORALE_TIMID)
    b.damage(goblin, 2, fighter, true)
    assert_true(goblin.down)

func test_iron_skin_ignores_the_next_attack_only():
    fighter.statuses["ignore_next_attack"] = {}
    b.damage(fighter, 3, goblin, true)
    assert_eq(fighter.armor_damage, 0)
    assert_false(fighter.statuses.has("ignore_next_attack"))
    b.damage(fighter, 1, goblin, true)
    assert_eq(fighter.armor_damage, 1)

func test_thorns_reflects_the_points_past_guard():
    fighter.statuses["thorns"] = {}
    b.add_guard(fighter, 1, fighter)
    b.damage(fighter, 3, goblin, true)
    assert_eq(goblin.armor_damage + goblin.marked_hd, 2, "3 damage - 1 Guard = 2 reflected")
    assert_eq(b.provoke.value_of(fighter), 0, "reflected damage earns no Provoke")

func test_thorns_reflects_nothing_when_iron_skin_cancels():
    fighter.statuses["thorns"] = {}
    fighter.statuses["ignore_next_attack"] = {}
    b.damage(fighter, 3, goblin, true)
    assert_eq(goblin.armor_damage + goblin.marked_hd, 0)

func test_thorns_ignores_damage_that_is_not_an_attack():
    fighter.statuses["thorns"] = {}
    b.damage(fighter, 1, goblin, false)
    assert_eq(goblin.armor_damage, 0)
