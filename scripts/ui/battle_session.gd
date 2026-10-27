class_name BattleSession
extends RefCounted

## Runs one battle on a worker thread for the battle scene. The engine stays a plain synchronous
## loop: the worker pauses whenever a person must choose (HumanDecisionProvider) or follow along
## (the end of an enemy turn, or of an AI hero turn), and the scene reads battle state only while
## the worker is paused. The worker holds `_state_lock` whenever engine code runs; the scene takes
## it with begin_view() / end_view() to read.

const PAUSE_DECISION := "decision"
const PAUSE_CONTINUE := "continue"
const POLL_MS := 10

var battle: Battle = null
var auto_delay_ms: int = 700

var _thread: Thread = null
var _state_lock := Mutex.new()
var _mutex := Mutex.new()  # guards everything below
var _ai_heroes: bool = false
var _auto_continue: bool = false
var _pause_kind: String = ""
var _request: DecisionRequest = null
var _pause_entry: Dictionary = {}
var _answer: int = -1
var _answered: bool = false
var _aborting: bool = false
var _finished: bool = false
var _serial: int = 0

# ------------------------------------------------------------------ scene side (main thread)

func start(data: Dictionary, encounter: Array, seed_value: int, dm_mode: String) -> void:
    _thread = Thread.new()
    _thread.start(_run.bind(data, encounter, seed_value, dm_mode))

## Try to take the state lock for reading; false while the engine is running.
func begin_view() -> bool:
    return _state_lock.try_lock()

func end_view() -> void:
    _state_lock.unlock()

## Bumped at every new pause, so the scene knows when to redraw.
func serial() -> int:
    _mutex.lock()
    var s: int = _serial
    _mutex.unlock()
    return s

func pause_kind() -> String:
    _mutex.lock()
    var k: String = _pause_kind if not _answered else ""
    _mutex.unlock()
    return k

func pending_request() -> DecisionRequest:
    _mutex.lock()
    var r: DecisionRequest = _request if not _answered else null
    _mutex.unlock()
    return r

## The turn_end entry for a Continue pause.
func pause_entry() -> Dictionary:
    _mutex.lock()
    var e: Dictionary = _pause_entry
    _mutex.unlock()
    return e

func is_finished() -> bool:
    _mutex.lock()
    var f: bool = _finished
    _mutex.unlock()
    return f

## Answer the pending decision with an option index, or end a Continue pause (any index).
func answer(index: int) -> void:
    _mutex.lock()
    if not _pause_kind.is_empty() and not _answered:
        _answer = index
        _answered = true
    _mutex.unlock()

func set_ai_heroes(value: bool) -> void:
    _mutex.lock()
    _ai_heroes = value
    _mutex.unlock()

func set_auto_continue(value: bool) -> void:
    _mutex.lock()
    _auto_continue = value
    _mutex.unlock()

## Stop pausing, let the AI answer everything, and wait for the battle to finish (the round cap
## guarantees it does). Safe to call at any time, and more than once.
func abort() -> void:
    _mutex.lock()
    _aborting = true
    _mutex.unlock()
    if _thread != null and _thread.is_started():
        _thread.wait_to_finish()
    _thread = null

# ------------------------------------------------------------------ worker side

func _run(data: Dictionary, encounter: Array, seed_value: int, dm_mode: String) -> void:
    _state_lock.lock()
    var provider := HumanDecisionProvider.new(self)
    var b: Battle = BattleSetup.create(data, encounter, seed_value, provider)
    battle = b
    b.dm_mode = dm_mode
    b.log.listeners.append(_on_event)
    b.run()
    _mutex.lock()
    _finished = true
    _serial += 1
    _mutex.unlock()
    _state_lock.unlock()

## Called by HumanDecisionProvider. Returns an option index, or -1 to let the AI decide.
func ask_human(request: DecisionRequest, b: Battle) -> int:
    if battle == null:
        battle = b  # signature choices are asked while the battle is still being set up
    _mutex.lock()
    var use_ai: bool = _ai_heroes or _aborting
    _mutex.unlock()
    if use_ai:
        return -1
    return _pause(PAUSE_DECISION, request, {})

func _on_event(entry: Dictionary) -> void:
    if entry["type"] != "turn_end":
        return
    _mutex.lock()
    var follow: bool = entry["details"].get("side", "") == FigureState.SIDE_ENEMIES or _ai_heroes
    _mutex.unlock()
    if follow:
        _pause(PAUSE_CONTINUE, null, entry)

func _pause(kind: String, request: DecisionRequest, entry: Dictionary) -> int:
    _mutex.lock()
    if _aborting:
        _mutex.unlock()
        return -1
    _pause_kind = kind
    _request = request
    _pause_entry = entry
    _answer = -1
    _answered = false
    _serial += 1
    _mutex.unlock()
    _state_lock.unlock()
    var waited: int = 0
    while true:
        OS.delay_msec(POLL_MS)
        waited += POLL_MS
        _mutex.lock()
        var done: bool = _answered or _aborting
        if kind == PAUSE_CONTINUE and _auto_continue and waited >= auto_delay_ms:
            done = true
        if kind == PAUSE_DECISION and _ai_heroes:
            done = true  # switched to AI while waiting: the AI answers this one
        _mutex.unlock()
        if done:
            break
    _state_lock.lock()
    _mutex.lock()
    var result: int = _answer if _answered else -1
    _pause_kind = ""
    _request = null
    _pause_entry = {}
    _answered = false
    _mutex.unlock()
    return result
