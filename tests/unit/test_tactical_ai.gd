extends GutTest

## The tactical hero AI (scripts/ai): ThreatModel's expected enemy damage and who it lands on,
## TacticalScorer's Provoke projection (RULES §6), and the choices TacticalAiProvider makes from them.

var b: Battle
var ai: TacticalAiProvider

func before_each():
    ai = TacticalAiProvider.new()
    b = BattleFixture.battle(ai)

func _scorer() -> TacticalScorer:
    var scorer := TacticalScorer.new()
    scorer.prepare(ThreatModel.new(b))
    return scorer

func test_expected_hit_is_the_deck_average_for_one_flip_and_the_expected_best_for_more():
    var skeleton := BattleFixture.enemy(b, "skeleton", 0, 1)
    # Skeleton deck: Bone Blade 2 (x4), Clatter Forward 1 (x2), Reassemble 0.2 (x2), Rattle 0 (x2).
    assert_almost_eq(ThreatModel.expected_hit(b, skeleton), 1.04, 0.001, "Draw 1, Bold: the deck average")
    b.dm_mode = Battle.DM_STANDARD
    # Two flips, the DM plays the best: 0.2 x (0.4^2 - 0.2^2) + 1 x (0.6^2 - 0.4^2) + 2 x (1 - 0.6^2).
    assert_almost_eq(ThreatModel.expected_hit(b, skeleton), 1.504, 0.001, "the best of two flips")

func test_a_melee_enemy_is_expected_to_hit_the_highest_hero_in_its_reach_not_the_top_hero():
    var fighter := BattleFixture.hero(b, "fighter", 0, 0)
    var wizard := BattleFixture.hero(b, "wizard", 2, 2)
    BattleFixture.enemy(b, "skeleton", 0, 0)
    b.provoke.move(wizard, 5)
    # All 1.04 goes to the fighter (Chainmail + Shield 5, hand 6), the only hero in reach.
    assert_almost_eq(ThreatModel.new(b).party_danger(), pow(1.04 / 11.0, 2), 0.0001)

func test_a_melee_enemy_with_no_hero_near_is_expected_to_go_for_the_top_hero():
    BattleFixture.hero(b, "fighter", 0, 0)
    var wizard := BattleFixture.hero(b, "wizard", 2, 2)
    BattleFixture.enemy(b, "skeleton", 2, 2)
    b.provoke.move(wizard, 5)
    # Robes 0, hand 4.
    assert_almost_eq(ThreatModel.new(b).party_danger(), pow(1.04 / 4.0, 2), 0.0001)

func test_projected_provoke_follows_the_backstab_example_in_the_rules():
    var thief := BattleFixture.hero(b, "thief", 0, 1, ["backstab"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 1)
    goblin.marked_hd = 2
    b.provoke.move(thief, 5)
    # RULES §6 Order: lands 3 (1 armor, 2 Hd): 5 + 3 = 8, then halve -> 4.
    assert_eq(_scorer().projected_provoke(b, thief, thief.hand[0]), 4)

func test_climbing_above_the_tank_in_reach_of_an_enemy_costs_and_the_tank_climbing_back_pays():
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["war_cry"])
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["stab"])
    BattleFixture.enemy(b, "goblin", 0, 0)
    var scorer := _scorer()
    assert_lt(scorer.track_value(b, thief, 2), 0.0, "the goblin would turn from the fighter to the thief")
    b.provoke.move(thief, 2)
    scorer.prepare(ThreatModel.new(b))
    var climbs_back: float = scorer.track_value(b, fighter, scorer.projected_provoke(b, fighter, fighter.hand[0]))
    assert_gt(climbs_back, 0.0, "War Cry takes the goblin's attention back")

func test_the_hero_with_the_stronger_play_acts_first_rather_than_the_first_listed():
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["pick_lock", "pick_lock", "pick_lock", "pick_lock", "pick_lock"])
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt", "study", "study", "study"])
    var goblin := BattleFixture.enemy(b, "goblin", 0, 0)
    goblin.marked_hd = 3
    # Thief: Pick Lock 1.2; wizard: Fire Bolt kills the goblin, 3 + 3. Counted in full, either order
    # adds up to 7.2 and the tie would go to the thief; the follow-up counts at FOLLOW_WEIGHT, so
    # the kill comes first.
    var request := DecisionRequest.new(DecisionRequest.NEXT_HERO, null, [thief, wizard])
    assert_eq(ai.decide(request, b), 1, "the wizard acts first")

func test_healing_goes_to_the_hero_closest_to_down():
    var cleric := BattleFixture.hero(b, "cleric", 1, 1, ["healing_word"])
    var fighter := BattleFixture.hero(b, "fighter", 0, 1, ["wound", "wound", "bash", "bash", "bash", "bash"])
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["wound", "wound", "fire_bolt", "fire_bolt"])
    BattleFixture.enemy(b, "goblin", 2, 2)
    HeroTurn.take(b, cleric)
    assert_eq(wizard.wound_count(), 1, "2 Wounds in a hand of 4 is closer to Down than 2 in 6")
    assert_eq(fighter.wound_count(), 2)

func test_damage_that_kills_nothing_goes_where_it_removes_the_most_threat():
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"])
    var ogre := BattleFixture.enemy(b, "ogre", 0, 0)
    var goblin := BattleFixture.enemy(b, "goblin", 0, 2)
    HeroTurn.take(b, wizard)
    assert_eq(ogre.armor_damage, 3, "Fire Bolt hits the ogre, the bigger threat per point of toughness")
    assert_eq(goblin.armor_damage, 0, "the simple AI would hit the goblin, the lowest power")

func test_guard_goes_to_the_hero_the_enemies_will_hit():
    var cleric := BattleFixture.hero(b, "cleric", 1, 1, ["shield_of_faith"])
    var fighter := BattleFixture.hero(b, "fighter", 1, 2)
    var thief := BattleFixture.hero(b, "thief", 0, 0, ["wound", "wound", "stab", "stab", "stab"])
    thief.armor_damage = 2
    BattleFixture.enemy(b, "ogre", 0, 0)
    b.provoke.move(fighter, 3)
    b.provoke.move(thief, 1)
    HeroTurn.take(b, cleric)
    assert_eq(thief.guard_tokens, 2, "the ogre can reach only the thief")
    assert_eq(fighter.guard_tokens, 0, "the simple AI would guard the top hero")
