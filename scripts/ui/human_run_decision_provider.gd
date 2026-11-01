class_name HumanRunDecisionProvider
extends RunDecisionProvider

## The person at the table making the party's exploring choices, behind the same interface as
## ExplorationAi. Each request pauses the RunSession's worker thread until the scene answers; when
## "AI plays heroes" is on (or the run is being restarted) ExplorationAi answers instead.

var ai := ExplorationAi.new()
var _session: WeakRef

func _init(session: RunSession) -> void:
    _session = weakref(session)

func decide(request: RunRequest, run: HutRun) -> int:
    var session: RunSession = _session.get_ref()
    if session != null:
        var index: int = session.ask_human_run(request)
        if index >= 0:
            return index
    return ai.decide(request, run)
