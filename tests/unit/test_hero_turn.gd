extends GutTest

## RULES §4-5: play a card with a legal effect, flip, or pass; draw back up to hand size, but not
## while at or above it; empty deck; cards owed are drawn at turn start; Stun skips the turn.

var b: Battle
var provider: ScriptedProvider

func before_each():
    provider = ScriptedProvider.new()
    b = BattleFixture.battle(provider)

func _offered(kind: String) -> Array:
    var result: Array = []
    for option in provider.requests_of(DecisionRequest.TURN)[-1].options:
        var turn: TurnOption = option
        result.append(turn.card.id if turn.kind == TurnOption.PLAY else turn.kind)
    return result

func test_only_cards_with_a_legal_effect_are_offered():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["fix_armor", "bash", "wound", "challenge"], ["raise_shield"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TURN, TurnOption.PASS)
    HeroTurn.take(b, fighter)
    assert_eq(_offered(DecisionRequest.TURN), ["challenge", "flip", "pass"],
        "no Fix Armor (no armor damage), no Bash (nothing in reach), never a Wound")

func test_playing_a_card_draws_back_up_to_hand_size():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["challenge", "bash", "bash", "bash", "bash", "bash"], ["raise_shield", "war_cry"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "challenge")
    assert_eq(fighter.hand.size(), 6)
    assert_eq(fighter.deck.size(), 1)
    assert_true(BattleFixture.card_in(fighter.discard, "challenge"))

func test_no_replacement_draw_at_or_above_hand_size():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["pick_lock", "stab", "stab", "stab", "stab", "stab"], ["dodge", "dodge", "dodge"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, thief, "pick_lock")
    assert_eq(thief.hand.size(), 6, "5 left + 1 drawn by Pick Lock; at or above 5, no refill")
    assert_eq(thief.deck.size(), 2)

func test_an_empty_deck_draws_nothing():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["challenge", "bash"], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "challenge")
    assert_eq(fighter.hand.size(), 1)
    assert_true(b.log.has_type("deck_empty"))

func test_a_flipped_card_with_a_legal_effect_is_played():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], ["war_cry", "bash"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TURN, TurnOption.FLIP)
    HeroTurn.take(b, fighter)
    assert_eq(b.provoke.value_of(fighter), 5)
    assert_true(BattleFixture.card_in(fighter.discard, "war_cry"))
    assert_eq(fighter.hand.size(), 1, "a flip draws no replacement")

func test_a_flipped_card_with_no_legal_effect_is_discarded_and_top_tier_exhausts():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], ["fix_armor", "iron_skin"])
    fighter.statuses["ignore_next_attack"] = {}
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TURN, TurnOption.FLIP)
    HeroTurn.take(b, fighter)
    assert_true(BattleFixture.card_in(fighter.discard, "fix_armor"))
    provider.then(DecisionRequest.TURN, TurnOption.FLIP)
    HeroTurn.take(b, fighter)
    assert_true(BattleFixture.card_in(fighter.exhausted, "iron_skin"), "Iron Skin always Exhausts, even unused")

func test_owed_cards_are_drawn_at_the_start_of_the_turn():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["bash"], ["war_cry", "challenge", "bash"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    fighter.owed_draws = 2
    provider.then(DecisionRequest.TURN, TurnOption.PASS)
    HeroTurn.take(b, fighter)
    assert_eq(fighter.hand.size(), 3)
    assert_eq(fighter.owed_draws, 0)

func test_a_stunned_hero_skips_the_turn():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["challenge"], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    fighter.stunned = true
    HeroTurn.take(b, fighter)
    assert_eq(provider.requests_of(DecisionRequest.TURN).size(), 0)
    assert_false(fighter.stunned)
    assert_eq(b.provoke.value_of(fighter), 0)

func test_playing_the_last_non_wound_card_with_an_empty_deck_is_down():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["challenge", "wound"], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "challenge")
    assert_true(fighter.down, "only a Wound left and nothing to draw")
    assert_eq(fighter.cells.size(), 0)

func test_a_hand_of_only_wounds_is_down_even_with_cards_in_the_deck():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab", "wound", "wound", "wound", "wound", "wound"], ["dodge"])
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.play(b, thief, "stab")
    assert_eq(thief.deck.size(), 1, "5 Wounds is at hand size, so no refill")
    assert_true(thief.down)

func test_the_down_check_waits_for_the_refill_draw():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab", "wound", "wound", "wound", "wound"], ["dodge"])
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.play(b, thief, "stab")
    assert_false(thief.down, "4 Wounds for a moment, then the refill draws Dodge")
    assert_true(BattleFixture.card_in(thief.hand, "dodge"))
    assert_eq(thief.wound_count(), 4)

func test_no_cards_in_hand_or_deck_is_down():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["challenge"], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    BattleFixture.play(b, fighter, "challenge")
    assert_true(fighter.down, "a spent hero leaves the board")

func test_flipping_the_last_card_with_an_empty_hand_is_down():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, [], ["challenge"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TURN, TurnOption.FLIP)
    HeroTurn.take(b, fighter)
    assert_eq(b.provoke.value_of(fighter), 3, "the flipped card still resolves")
    assert_true(fighter.down)

func test_a_spent_hero_is_down_at_the_start_of_their_turn():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, [], [])
    BattleFixture.enemy(b, "goblin", 2, 2)
    HeroTurn.take(b, fighter)
    assert_true(fighter.down)
    assert_eq(provider.requests_of(DecisionRequest.TURN).size(), 0)

func test_an_empty_hand_can_still_flip():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, [], ["challenge"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    provider.then(DecisionRequest.TURN, TurnOption.FLIP)
    HeroTurn.take(b, fighter)
    assert_eq(_offered(DecisionRequest.TURN), ["flip", "pass"])
    assert_eq(b.provoke.value_of(fighter), 3)
