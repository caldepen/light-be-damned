extends GutTest

## Milestone 2: the battle scene's BattleSession runs the engine on a worker thread and pauses
## for human decisions and after enemy turns. Driven here from code, without the scene.

const SEED := 7
const MAX_WAIT_MS := 20000

func _encounter(name: String) -> Array:
    return BattleFixture.data()["encounters"][name]

func test_every_turn_start_has_a_turn_end_and_listeners_see_every_entry():
    var battle: Battle = BattleSetup.create(BattleFixture.data(), _encounter("standard"), SEED, SimpleAiProvider.new())
    var seen: Array[String] = []
    battle.log.listeners.append(func(entry: Dictionary) -> void: seen.append(String(entry["type"])))
    battle.run()
    assert_eq(seen.size(), battle.log.count())
    assert_eq(battle.log.of_type("turn_end").size(), battle.log.of_type("turn_start").size())
    assert_false(battle.log.to_text().contains("\n  \n"), "turn_end markers print nothing")

func test_a_session_answered_like_the_ai_plays_the_same_battle():
    var direct: Battle = BattleSetup.create(BattleFixture.data(), _encounter("tough"), SEED, TacticalAiProvider.new())
    direct.dm_mode = Battle.DM_STANDARD
    direct.run()

    var session := BattleSession.new()
    session.start(BattleFixture.data(), _encounter("tough"), SEED, Battle.DM_STANDARD)
    var ai := TacticalAiProvider.new()
    var decisions: int = 0
    var continues: int = 0
    var waited: int = 0
    while not session.is_finished() and waited < MAX_WAIT_MS:
        if session.pause_kind().is_empty() or not session.begin_view():
            OS.delay_msec(2)
            waited += 2
            continue
        var request: DecisionRequest = session.pending_request()
        var index: int = 0
        if request != null:
            index = ai.decide(request, session.battle)
            decisions += 1
        else:
            continues += 1
        session.end_view()
        session.answer(index)
        OS.delay_msec(1)
    session.abort()
    assert_true(session.is_finished(), "the battle finished in time")
    assert_gt(decisions, 0, "hero choices went through the person")
    assert_gt(continues, 0, "enemy turns paused for Continue")
    assert_eq(session.battle.log.to_text(), direct.log.to_text(), "same seed and same choices: same battle")

func test_restarting_while_paused_finishes_the_old_battle():
    var session := BattleSession.new()
    session.start(BattleFixture.data(), _encounter("standard"), SEED, Battle.DM_AUTOMATED)
    var waited: int = 0
    while session.pause_kind() != BattleSession.PAUSE_DECISION and waited < MAX_WAIT_MS:
        OS.delay_msec(2)
        waited += 2
    assert_eq(session.pause_kind(), BattleSession.PAUSE_DECISION, "waiting for the first hero")
    session.abort()
    assert_true(session.is_finished())
    assert_false(session.battle.result.is_empty())

func test_ai_heroes_and_auto_continue_play_a_battle_with_no_answers():
    var session := BattleSession.new()
    session.auto_delay_ms = 0
    session.set_ai_heroes(true)
    session.set_auto_continue(true)
    session.start(BattleFixture.data(), _encounter("standard"), SEED, Battle.DM_AUTOMATED)
    var waited: int = 0
    while not session.is_finished() and waited < MAX_WAIT_MS:
        OS.delay_msec(5)
        waited += 5
    assert_true(session.is_finished())
    session.abort()
    var direct: Battle = BattleSetup.create(BattleFixture.data(), _encounter("standard"), SEED, TacticalAiProvider.new())
    direct.run()
    assert_eq(session.battle.log.to_text(), direct.log.to_text())
