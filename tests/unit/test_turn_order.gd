extends GutTest

## RULES §5 Turn order: alternate one figure at a time starting with a hero; the party chooses
## which hero acts next, each once per round; enemies act front row first, then left to right, in an
## order fixed per round; Down, Stunned and toad heroes aren't offered; the side with figures left
## finishes the round. §4 "next turn": a Stun before acting costs this round's turn, after it next round's.

func _turns(b: Battle, round_no: int) -> Array:
    var ids: Array = []
    for entry in b.log.of_type("turn_start"):
        if entry["details"]["round"] == round_no:
            ids.append(entry["details"]["figure"])
    return ids

func _offered(provider: ScriptedProvider) -> Array:
    var offers: Array = []
    for r in provider.requests_of(DecisionRequest.NEXT_HERO):
        var ids: Array = []
        for h in r.options:
            ids.append((h as HeroState).id)
        offers.append(ids)
    return offers

func _cowering_goblins(b: Battle, count: int, rounds: int = 1) -> void:
    for i in range(count):
        BattleFixture.enemy(b, "goblin", 0 if i < 3 else 1, i % 3)
    var cower: Array = []
    for i in range(count * rounds):
        cower.append("cower")
    BattleFixture.stack_enemy_deck(b, "goblin", cower)

func test_heroes_in_the_old_fixed_order_and_enemies_front_row_first_then_left_to_right():
    var data: Dictionary = BattleFixture.data()
    var b := BattleSetup.create(data, data["encounters"]["standard"], 3, ScriptedProvider.new().always_pass())
    b.round_number = 1
    b.play_round()
    assert_eq(_turns(b, 1), ["thief", "goblin_1", "fighter", "goblin_2", "cleric", "goblin_3", "wizard", "goblin_4", "goblin_5"],
        "always_pass picks the first hero offered, and heroes are offered in the old fixed order")

func test_the_party_chooses_any_order_and_each_hero_acts_once():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 0, 2)
    BattleFixture.hero(b, "thief", 0, 0)
    BattleFixture.hero(b, "wizard", 1, 1)
    _cowering_goblins(b, 4, 2)
    provider.then(DecisionRequest.NEXT_HERO, "wizard").then(DecisionRequest.NEXT_HERO, "cleric").then(DecisionRequest.NEXT_HERO, "fighter")
    b.play_round()
    assert_eq(_turns(b, 1), ["wizard", "goblin_1", "cleric", "goblin_2", "fighter", "goblin_3", "thief", "goblin_4"],
        "alternating, a hero first, heroes in the chosen order")
    assert_eq(_offered(provider), [["thief", "fighter", "cleric", "wizard"], ["thief", "fighter", "cleric"], ["thief", "fighter"]],
        "only heroes who haven't acted are offered; the last one acts without asking")
    assert_eq(b.heroes_acted.size(), 4)
    var chosen: Array = b.log.of_type("hero_chosen")
    assert_eq(chosen[0]["message"], "The party chooses Wizard (3 heroes left to act).")
    assert_eq(chosen[3]["message"], "Thief acts (the last hero to act this round).")
    provider.then(DecisionRequest.NEXT_HERO, "thief")
    b.round_number = 2
    b.play_round()
    assert_eq(_turns(b, 2)[0], "thief", "a new round: every hero can be chosen again")
    assert_eq(_offered(provider)[3].size(), 4)

func test_down_stunned_and_toad_heroes_are_not_offered():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    var fighter := BattleFixture.hero(b, "fighter", 0, 1)
    var cleric := BattleFixture.hero(b, "cleric", 0, 2)
    BattleFixture.hero(b, "thief", 0, 0)
    var wizard := BattleFixture.hero(b, "wizard", 1, 1)
    _cowering_goblins(b, 1, 2)
    b.knock_down(fighter)
    cleric.stunned = true
    b.play_round()
    assert_eq(_offered(provider)[0], ["thief", "wizard"], "not the Down Fighter or the Stunned Cleric")
    assert_false(cleric.stunned, "the Stun is used up")
    assert_true(b.heroes_acted.has(cleric), "marked as acted")
    assert_eq(_turns(b, 1), ["thief", "goblin_1", "wizard"], "the lost turn uses no turn in the alternation")
    wizard.toad_turns = 1
    b.round_number = 2
    b.play_round()
    assert_eq(_offered(provider)[1], ["thief", "cleric"], "a toad isn't offered either")
    assert_eq(wizard.toad_turns, 0)
    var skipped: Array = []
    for entry in b.log.of_type("skip_turn"):
        skipped.append(entry["details"]["hero"])
    assert_eq(skipped, ["cleric", "wizard"])

func test_a_stun_before_acting_costs_this_rounds_turn():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    var fighter := BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 2, 2)
    BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["grab_and_throw", "dim_witted", "dim_witted", "dim_witted"])
    provider.then(DecisionRequest.NEXT_HERO, "cleric")
    b.play_round()
    assert_eq(_turns(b, 1), ["cleric", "ogre_1"], "the Fighter, Stunned before acting, loses this round's turn")
    assert_false(fighter.stunned)
    b.round_number = 2
    b.play_round()
    assert_eq(_turns(b, 2), ["fighter", "ogre_1", "cleric"], "and acts again next round")

func test_a_stun_after_acting_costs_next_rounds_turn():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    var fighter := BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 2, 2)
    BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "ogre", ["grab_and_throw", "dim_witted", "dim_witted", "dim_witted"])
    provider.then(DecisionRequest.NEXT_HERO, "fighter")
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "ogre_1", "cleric"])
    assert_true(fighter.stunned, "Stunned after acting: the Stun waits for the Fighter's next turn")
    b.round_number = 2
    b.play_round()
    assert_eq(_turns(b, 2), ["cleric", "ogre_1"], "the Fighter loses next round's turn")
    assert_false(fighter.stunned)

func test_more_heroes_left_than_enemies_the_party_still_chooses():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 0, 2)
    BattleFixture.hero(b, "wizard", 1, 1)
    _cowering_goblins(b, 1)
    provider.then(DecisionRequest.NEXT_HERO, "wizard").then(DecisionRequest.NEXT_HERO, "cleric")
    b.play_round()
    assert_eq(_turns(b, 1), ["wizard", "goblin_1", "cleric", "fighter"])
    assert_eq(_offered(provider), [["fighter", "cleric", "wizard"], ["fighter", "cleric"]])

func test_more_enemies_left_than_heroes_the_enemies_finish_in_order():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 0, 2)
    _cowering_goblins(b, 4)
    provider.then(DecisionRequest.NEXT_HERO, "cleric")
    b.play_round()
    assert_eq(_turns(b, 1), ["cleric", "goblin_1", "fighter", "goblin_2", "goblin_3", "goblin_4"])

func test_side_with_figures_left_finishes_the_round():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.enemy(b, "goblin", 0, 2)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower", "cower", "cower"])
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "goblin_1", "goblin_2", "goblin_3"])

func test_a_large_enemy_acts_by_its_front_left_square():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 0, 2)
    BattleFixture.enemy(b, "goblin", 0, 2)
    BattleFixture.enemy(b, "ogre", 0, 0)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower"])
    BattleFixture.stack_enemy_deck(b, "ogre", ["dim_witted", "dim_witted"])
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "ogre_1", "cleric", "goblin_1"])

func test_newcomers_first_act_next_round():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.stack_enemy_deck(b, "goblin", ["shriek", "cower", "cower"])
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "goblin_1"])
    assert_eq(b.enemies.size(), 2, "Shriek brought a second goblin")
    b.round_number = 2
    b.play_round()
    assert_eq(_turns(b, 2), ["fighter", "goblin_1", "goblin_2"])

func test_a_stunned_enemy_loses_its_turn_without_a_place_in_the_alternation():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.hero(b, "cleric", 0, 2)
    var stunned := BattleFixture.enemy(b, "goblin", 0, 0)
    BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower"])
    stunned.stunned = true
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "goblin_2", "cleric"])
    assert_false(stunned.stunned, "the Stun is used up")
    assert_eq(b.log.of_type("skip_turn")[0]["details"]["enemy"], "goblin_1")

func test_enemies_stunned_before_acting_let_the_heroes_act_in_a_row():
    var provider := ScriptedProvider.new().always_pass()
    var b := BattleFixture.battle(provider)
    BattleFixture.hero(b, "fighter", 0, 1, ["quake", "bash"])
    BattleFixture.hero(b, "cleric", 0, 2)
    BattleFixture.hero(b, "wizard", 2, 1)
    _cowering_goblins(b, 4)
    provider.then(DecisionRequest.TURN, "quake")
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "goblin_4", "cleric", "wizard"],
        "Quake stuns the front row before it acts; only the middle-row goblin is left to alternate with")

func test_one_lost_turn_uses_up_the_stun_and_a_toad_turn():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    var wizard := BattleFixture.hero(b, "wizard", 2, 1)
    _cowering_goblins(b, 1, 3)
    wizard.toad_turns = 2
    wizard.stunned = true
    b.play_round()
    assert_false(wizard.stunned)
    assert_eq(wizard.toad_turns, 1, "one lost turn used up the Stun and one toad turn")
    b.round_number = 2
    b.play_round()
    assert_eq(wizard.toad_turns, 0)
    b.round_number = 3
    b.play_round()
    assert_eq(_turns(b, 3), ["fighter", "goblin_1", "wizard"], "2 turns lost, not 3")

func test_extra_turns_come_before_the_end_of_round_in_the_order_gained():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    BattleFixture.hero(b, "fighter", 0, 1)
    var first := BattleFixture.enemy(b, "goblin", 0, 0)
    var second := BattleFixture.enemy(b, "goblin", 0, 1)
    BattleFixture.stack_enemy_deck(b, "goblin", ["cower", "cower", "cower", "cower"])
    for gainer in [second, first]:
        var ctx := EffectContext.new(b, gainer, {}, [])
        ctx.effect = {"op": "status", "name": "extra_turn_each_round", "duration": "battle"}
        b.effects.handler("status").resolve(ctx)
    b.play_round()
    assert_eq(_turns(b, 1), ["fighter", "goblin_1", "goblin_2", "goblin_2", "goblin_1"],
        "normal turns first, then the extra turns in the order the status was gained")
    var types: Array[String] = BattleFixture.event_types(b)
    assert_true(types.rfind("turn_start") < types.find("round_end"), "the extra turns come before the end of the round")

func test_the_ai_picks_the_hero_with_the_best_play_ties_in_the_old_order():
    var b := BattleFixture.battle(ScriptedProvider.new())
    BattleFixture.hero(b, "fighter", 0, 1, ["challenge"])
    BattleFixture.hero(b, "thief", 0, 0, ["stab"])
    var wizard := BattleFixture.hero(b, "wizard", 2, 1, ["fire_bolt"])
    BattleFixture.enemy(b, "goblin", 0, 0)
    var fighter: HeroState = b.heroes[0]
    var thief: HeroState = b.heroes[1]
    var options: Array = [thief, fighter, wizard]
    var ai := SimpleAiProvider.new()
    var pick: int = ai.decide(DecisionRequest.new(DecisionRequest.NEXT_HERO, null, options), b)
    assert_eq(options[pick], wizard, "Fire Bolt for 3 scores highest")
    fighter.hand = BattleFixture.cards(b, "fighter", ["bash"])
    options = [thief, fighter]
    pick = ai.decide(DecisionRequest.new(DecisionRequest.NEXT_HERO, null, options), b)
    assert_eq(options[pick], thief, "Stab and Bash both deal 2: the first in the old order wins")

func test_battle_stops_at_the_round_cap_as_a_draw():
    var b := BattleFixture.battle(ScriptedProvider.new().always_pass())
    b.round_number = 0
    BattleFixture.hero(b, "fighter", 0, 1)
    BattleFixture.enemy(b, "goblin", 2, 0)
    var cower: Array = []
    for i in range(40):
        cower.append("cower")
    BattleFixture.stack_enemy_deck(b, "goblin", cower)
    assert_eq(b.run(), Battle.RESULT_DRAW)
    assert_eq(b.round_number, int(b.rules["battle"]["round_cap"]))
