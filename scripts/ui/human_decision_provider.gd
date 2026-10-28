class_name HumanDecisionProvider
extends DecisionProvider

## The person at the battle scene, behind the same interface as the AI. Each request pauses the
## BattleSession's worker thread until the scene answers. When "AI plays heroes" is on (or the
## session is being restarted) the AI answers instead.

var ai := TacticalAiProvider.new()
var _session: WeakRef

func _init(session: BattleSession) -> void:
    _session = weakref(session)

func decide(request: DecisionRequest, battle: Battle) -> int:
    var session: BattleSession = _session.get_ref()
    if session != null:
        var index: int = session.ask_human(request, battle)
        if index >= 0:
            return index
    return ai.decide(request, battle)
