extends GutTest

## RULES §8 outside battle: the party between fights (damage armor first then Wounds, Down when
## the hand is only Wounds, healing gets a hero up, the campfire reset) and skill rolls (flip and
## read the skill value, off-Type −2 with a minimum of 1, the card spent or Exhausted, teamwork
## above 6, a failure raises the Hut track, Hard or harder gives XP).

var run: HutRun
var provider: ScriptedRunProvider

func before_each():
    provider = ScriptedRunProvider.new()
    run = HutRun.new(BattleFixture.data(), 1, provider)

func _hero(id: String) -> HeroState:
    return run.party.hero(id)

## Put a card with this skill value on top of the hero's deck (a basic card if there is one).
func _top(h: HeroState, skill: int, tier: String = "basic") -> Card:
    var fallback: Dictionary = {}
    for c in BattleFixture.data()["heroes"][h.hero_id]["deck"]:
        if int(c["skill"]) == skill:
            if String(c.get("tier", "basic")) == tier:
                var card := Card.new(run.party.new_uid(), c)
                h.deck.append(card)
                return card
            fallback = c
    var other := Card.new(run.party.new_uid(), fallback)
    h.deck.append(other)
    return other

func test_the_party_starts_in_white_gear_with_fresh_hands():
    var sizes: Array = run.party.heroes.map(func(h: HeroState) -> int: return h.hand.size())
    assert_eq(sizes, [6, 5, 5, 4])
    var armor: Array = run.party.heroes.map(func(h: HeroState) -> int: return h.armor_slots)
    assert_eq(armor, [5, 4, 2, 0], "chainmail + shield, chainmail, leather, robes")
    assert_eq(_hero("fighter").deck.size(), 24)
    assert_eq(run.rations, 8)

func test_damage_outside_battle_fills_armor_then_pushes_cards_out_with_wounds():
    var thief: HeroState = _hero("thief")
    run.damage_hero(thief, 4, "test")
    assert_eq(thief.armor_damage, 2)
    assert_eq(thief.wound_count(), 2)
    assert_eq(thief.hand.size(), 5, "each Wound pushed a card out")
    assert_eq(thief.discard.size(), 2)
    assert_eq(provider.requests_of(RunRequest.WOUND_DISCARD).size(), 2, "the party chooses what to discard")

func test_a_hand_of_only_wounds_is_down_until_healed():
    var wizard: HeroState = _hero("wizard")
    run.damage_hero(wizard, 4, "test")
    assert_true(wizard.down)
    run.party.heal_wounds(wizard, 2)
    assert_false(wizard.down, "no longer only Wounds")
    assert_eq(wizard.wound_count(), 2)
    assert_eq(wizard.hand.size(), 4, "a replacement drawn for each Wound removed")

func test_the_campfire_resets_every_hero():
    var fighter: HeroState = _hero("fighter")
    run.damage_hero(fighter, 8, "test")
    run.party.flip(fighter)
    run.party.campfire_reset(fighter, run.rng)
    assert_eq(fighter.armor_damage, 0)
    assert_eq(fighter.wound_count(), 0)
    assert_eq(fighter.hand.size(), 6)
    assert_eq(fighter.deck.size() + fighter.hand.size(), 30, "discards and Exhausted cards back in the deck")
    assert_true(fighter.discard.is_empty() and fighter.exhausted.is_empty())

func test_a_roll_reads_the_skill_value_and_spends_the_card():
    var thief: HeroState = _hero("thief")
    var card: Card = _top(thief, 5)
    provider.then(RunRequest.ROLLER, thief)
    var result: Dictionary = SkillRoll.roll(run, "agility", 4, "lock", true)
    assert_true(result["success"])
    assert_eq(result["value"], 5)
    assert_true(thief.discard.has(card))
    assert_eq(run.explorer.hut_track, 0)

func test_another_type_rolls_at_minus_2_with_a_minimum_of_1():
    var fighter: HeroState = _hero("fighter")
    _top(fighter, 5)
    provider.then(RunRequest.ROLLER, fighter)
    assert_eq(SkillRoll.roll(run, "agility", 4, "lock", true)["value"], 3)
    _top(fighter, 1)
    provider.then(RunRequest.ROLLER, fighter)
    assert_eq(SkillRoll.roll(run, "agility", 4, "lock", true)["value"], 1)

func test_a_failed_roll_raises_the_hut_track_and_a_top_tier_card_is_exhausted():
    var thief: HeroState = _hero("thief")
    var card: Card = _top(thief, 2)
    provider.then(RunRequest.ROLLER, thief)
    var result: Dictionary = SkillRoll.roll(run, "agility", 4, "lock", true)
    assert_false(result["success"])
    assert_eq(run.explorer.hut_track, 1)
    var top: Card = _top(thief, 6, "top")
    provider.then(RunRequest.ROLLER, thief)
    SkillRoll.roll(run, "agility", 4, "lock", true)
    if top.exhausts():
        assert_true(thief.exhausted.has(top), "a ▲ card flipped for a roll is Exhausted")
    assert_true(thief.discard.has(card))

func test_beating_a_hard_obstacle_gives_xp_but_spotting_never_does():
    var thief: HeroState = _hero("thief")
    _top(thief, 6)
    provider.then(RunRequest.ROLLER, thief)
    SkillRoll.roll(run, "agility", 5, "lock", true)
    assert_eq(run.xp, 1)
    var wizard: HeroState = _hero("wizard")
    _top(wizard, 6)
    provider.then(RunRequest.ROLLER, wizard)
    SkillRoll.roll(run, "wits", 5, "spot", false)
    assert_eq(run.xp, 1)

func test_a_target_above_6_needs_two_heroes_who_add_their_values():
    var fighter: HeroState = _hero("fighter")
    var cleric: HeroState = _hero("cleric")
    _top(fighter, 4)
    _top(cleric, 4)
    provider.then(RunRequest.ROLLER, fighter).then(RunRequest.ROLLER, cleric)
    var result: Dictionary = SkillRoll.roll(run, "strength", 7, "teamwork", true)
    assert_eq(result["value"], 4 + 2, "the cleric rolls Strength at -2")
    assert_eq((result["heroes"] as Array).size(), 2)
    assert_false(result["success"])

func test_a_down_hero_or_one_with_no_deck_cannot_roll():
    var thief: HeroState = _hero("thief")
    thief.down = true
    _hero("wizard").deck.clear()
    var pool: Array[HeroState] = run.party.can_roll()
    assert_false(pool.has(thief))
    assert_false(pool.has(_hero("wizard")))
    assert_eq(pool.size(), 2)
