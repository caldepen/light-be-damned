class_name RunSession
extends BattleSession

## Plays a whole run (HutRun.play) on a worker thread for the table. Like BattleSession it pauses
## whenever the person must choose, for run choices (HumanRunDecisionProvider: doorways,
## placements, campsites, rolls, the formation...) as well as battle choices, and after enemy
## turns. `run` is the run, `battle` the fight in progress or the last one; the scene reads them
## only between begin_view() and end_view(). "AI plays heroes" lets the AI make every choice.

const PAUSE_RUN := "run"

var run: HutRun = null

func start_run(data: Dictionary, seed_value: int, dm_mode: String, components: Array = []) -> void:
    _thread = Thread.new()
    _thread.start(_play_run.bind(data, seed_value, dm_mode, components))

func pending_run_request() -> RunRequest:
    _mutex.lock()
    var r: RunRequest = _request as RunRequest if not _answered else null
    _mutex.unlock()
    return r

## Called by HumanRunDecisionProvider. Returns an option index, or -1 to let the AI decide.
func ask_human_run(request: RunRequest) -> int:
    _mutex.lock()
    var use_ai: bool = _ai_heroes or _aborting
    _mutex.unlock()
    if use_ai:
        return -1
    return _pause(PAUSE_RUN, request, {})

func _play_run(data: Dictionary, seed_value: int, dm_mode: String, components: Array) -> void:
    _state_lock.lock()
    var r := HutRun.new(data, seed_value, HumanRunDecisionProvider.new(self), components)
    r.battle_decisions = HumanDecisionProvider.new(self)
    r.dm_mode = dm_mode
    run = r
    r.log.listeners.append(_on_event)
    r.play()
    _mutex.lock()
    _finished = true
    _serial += 1
    _mutex.unlock()
    _state_lock.unlock()
