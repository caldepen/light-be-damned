extends GutTest

## Milestone 4.6: the table's RunSession plays a whole run on a worker thread, pausing for the
## person's run choices and battle choices. Driven here from code, without the scene.

const SEED := 4
const MAX_WAIT_MS := 120000

func _direct_run() -> HutRun:
    var run := HutRun.new(BattleFixture.data(), SEED, ExplorationAi.new())
    run.battle_decisions = TacticalAiProvider.new()
    run.play()
    return run

func test_with_the_ai_playing_a_session_plays_the_same_run_as_the_engine():
    var session := RunSession.new()
    session.auto_delay_ms = 0
    session.set_ai_heroes(true)
    session.set_auto_continue(true)
    session.start_run(BattleFixture.data(), SEED, Battle.DM_STANDARD)
    var waited: int = 0
    while not session.is_finished() and waited < MAX_WAIT_MS:
        OS.delay_msec(5)
        waited += 5
    session.abort()
    assert_true(session.is_finished())
    assert_eq(session.run.log.to_text(), _direct_run().log.to_text())

func test_run_choices_and_battle_choices_pause_for_the_person():
    var session := RunSession.new()
    session.start_run(BattleFixture.data(), SEED, Battle.DM_STANDARD)
    var run_ai := ExplorationAi.new()
    var hero_ai := TacticalAiProvider.new()
    var run_choices: int = 0
    var battle_choices: int = 0
    var waited: int = 0
    while not session.is_finished() and waited < MAX_WAIT_MS:
        if session.pause_kind().is_empty() or not session.begin_view():
            OS.delay_msec(2)
            waited += 2
            continue
        var index: int = 0
        var run_request: RunRequest = session.pending_run_request()
        var request: DecisionRequest = session.pending_request()
        if run_request != null:
            index = run_ai.decide(run_request, session.run)
            run_choices += 1
        elif request != null:
            index = hero_ai.decide(request, session.battle)
            battle_choices += 1
        session.end_view()
        session.answer(index)
        OS.delay_msec(1)
    session.abort()
    assert_true(session.is_finished(), "the run finished in time")
    assert_gt(run_choices, 0, "the formation, doorways and the next action went through the person")
    assert_gt(battle_choices, 0, "and the heroes' turns")
    assert_eq(session.run.log.to_text(), _direct_run().log.to_text(), "same seed and same choices: same run")

func test_restarting_while_paused_finishes_the_old_run():
    var session := RunSession.new()
    session.start_run(BattleFixture.data(), SEED, Battle.DM_STANDARD)
    var waited: int = 0
    while session.pause_kind() != RunSession.PAUSE_RUN and waited < MAX_WAIT_MS:
        OS.delay_msec(2)
        waited += 2
    assert_eq(session.pause_kind(), RunSession.PAUSE_RUN, "waiting for the first run choice")
    session.abort()
    assert_true(session.is_finished())
    assert_false(session.run.result.is_empty())
