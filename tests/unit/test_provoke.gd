extends GutTest

## RULES §6 Provoke: +1 per damage point that lands and per Wound or armor point healed, at least
## +1 for a damage, heal or repair card on a legal target; card-named Provoke last; ties go to the
## token that arrived last; limits 0 and 20.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func test_a_token_moving_onto_an_occupied_space_goes_on_top():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, [])
    var thief := BattleFixture.hero(b, "thief", 0, 0, [])
    b.provoke.move(thief, 3)
    b.provoke.move(fighter, 3)
    assert_eq(b.top_hero(), fighter)
    b.provoke.move(thief, 1)
    b.provoke.move(thief, -1)
    assert_eq(b.top_hero(), thief, "moving back down onto 3 also lands on top")

func test_a_gain_at_the_cap_goes_on_top_and_a_loss_at_zero_does_nothing():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, [])
    var thief := BattleFixture.hero(b, "thief", 0, 0, [])
    assert_eq(b.top_hero(), fighter)
    assert_eq(b.provoke.move(fighter, -1), 0)
    assert_eq(b.top_hero(), fighter, "a loss at 0 leaves the stack as it was")
    b.provoke.move(fighter, 25)
    b.provoke.move(thief, 20)
    assert_eq(b.provoke.value_of(fighter), 20)
    assert_eq(b.top_hero(), thief)
    b.provoke.move(fighter, 1)
    assert_eq(b.top_hero(), fighter)

func test_one_provoke_per_damage_point_that_lands():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["steady_strike"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, fighter, "steady_strike")
    assert_eq(goblin.armor_damage + goblin.marked_hd, 3)
    assert_eq(b.provoke.value_of(fighter), 3, "3 damage on a fresh goblin: +3")

func test_overkill_earns_nothing():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["steady_strike"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    goblin.armor_damage = 1
    goblin.marked_hd = 3
    BattleFixture.play(b, fighter, "steady_strike")
    assert_true(goblin.down)
    assert_eq(b.provoke.value_of(fighter), 1, "only the last Hd landed")

func test_guard_absorbed_points_earn_nothing():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["steady_strike"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    b.add_guard(goblin, 2, goblin)
    BattleFixture.play(b, fighter, "steady_strike")
    assert_eq(b.provoke.value_of(fighter), 1, "2 absorbed, 1 lands")

func test_points_on_every_target_add_up_then_the_named_provoke():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["cleave"])
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, fighter, "cleave")
    assert_eq(b.provoke.value_of(fighter), 4, "1 landed on each goblin (+2), Bleed earns nothing, then +2 named")

func test_plus_one_even_when_guard_absorbs_everything():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    b.add_guard(goblin, 5, goblin)
    BattleFixture.play(b, fighter, "bash")
    assert_eq(goblin.marked_hd, 0)
    assert_eq(b.provoke.value_of(fighter), 1)

func test_a_bleed_only_card_earns_no_provoke():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["burn"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.play(b, wizard, "burn")
    assert_eq(goblin.bleeds, [2])
    assert_eq(b.provoke.value_of(wizard), 0)

func test_a_heal_earns_plus_one():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["healing_word"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "bash"])
    BattleFixture.enemy(b, "goblin", 0, 1)
    provider.then(DecisionRequest.TARGET, fighter.id)
    BattleFixture.play(b, cleric, "healing_word")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(b.provoke.value_of(cleric), 1)

func test_each_wound_moved_by_lay_on_hands_earns_one():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["lay_on_hands", "smite"])
    BattleFixture.hero(b, "fighter", 0, 1, ["wound", "wound", "bash"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, cleric, "lay_on_hands")
    assert_eq(b.provoke.value_of(cleric), 2)

func test_wounds_removed_and_armor_repaired_each_earn_one():
    var cleric := BattleFixture.hero(b, "cleric", 0, 2, ["cleanse_armor"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "bash"])
    fighter.armor_damage = 3
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TARGET, "fighter").then(DecisionRequest.CLEANSE_SPLIT, 1)
    BattleFixture.play(b, cleric, "cleanse_armor")
    assert_eq(fighter.wound_count(), 0)
    assert_eq(fighter.armor_damage, 2)
    assert_eq(b.provoke.value_of(cleric), 2, "1 Wound + 1 armor point")

func test_vanish_moves_down_three():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["vanish"])
    BattleFixture.enemy(b, "goblin", 0, 1)
    b.provoke.move(thief, 5)
    BattleFixture.play(b, thief, "vanish")
    assert_eq(b.provoke.value_of(thief), 2)

func test_the_provoke_for_points_comes_before_the_cards_own_provoke():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["backstab"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 0)
    goblin.marked_hd = 2
    b.provoke.move(thief, 5)
    BattleFixture.play(b, thief, "backstab")
    assert_eq(b.provoke.value_of(thief), 4, "6 damage lands 3 (1 armor, 2 Hd) -> 8, then Backstab halves it -> 4")
    var reasons: Array = []
    for entry in b.log.of_type("provoke"):
        reasons.append(entry["details"]["delta"])
    assert_eq(reasons, [3, -4], "the card's own Provoke resolves last")

func test_the_cards_own_provoke_is_last_even_when_listed_first():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    var card := Card.new(b.new_uid(), {"id": "test_card", "name": "Test", "effects": [
        {"op": "provoke", "amount": -3},
        {"op": "damage", "amount": 1, "range": "melee", "area": "single"}]})
    b.provoke.move(fighter, 5)
    CardRunner.resolve_hero_card(b, fighter, card)
    assert_eq(goblin.armor_damage, 1)
    assert_eq(b.provoke.value_of(fighter), 3, "5 +1 = 6, then -3")

func test_vanish_at_zero_is_not_a_legal_play():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["vanish"])
    BattleFixture.enemy(b, "goblin", 0, 1)
    assert_false(CardRunner.is_card_legal(b, thief, thief.hand[0]))
