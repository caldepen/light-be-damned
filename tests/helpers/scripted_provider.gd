class_name ScriptedProvider
extends DecisionProvider

## Test provider: answers queued choices (matched by request kind, in order) and defers
## everything else to `fallback` (the AI by default). Records every request it sees.

var fallback: DecisionProvider = SimpleAiProvider.new()
var requests: Array[DecisionRequest] = []
var _queue: Array[Dictionary] = []

## Queue an answer. `pick` is an option value, a card id for Card/TurnOption options ("flip" and
## "pass" for turns), a figure id for figure options, or a Callable(option) -> bool.
func then(kind: String, pick: Variant) -> ScriptedProvider:
    _queue.append({"kind": kind, "pick": pick})
    return self

## Always pass on hero turns, and pick heroes in the old fixed order (the first offered).
func always_pass() -> ScriptedProvider:
    fallback = PassProvider.new()
    return self

func pending() -> int:
    return _queue.size()

func requests_of(kind: String) -> Array[DecisionRequest]:
    var result: Array[DecisionRequest] = []
    for r in requests:
        if r.kind == kind:
            result.append(r)
    return result

func decide(request: DecisionRequest, battle: Battle) -> int:
    requests.append(request)
    for i in range(_queue.size()):
        if _queue[i]["kind"] == request.kind:
            var pick: Variant = _queue[i]["pick"]
            _queue.remove_at(i)
            for j in range(request.options.size()):
                if _matches(request.options[j], pick):
                    return j
            push_error("ScriptedProvider: %s is not an option for %s (%s)." % [str(pick), request.kind, str(request.options)])
            return 0
    return fallback.decide(request, battle)

func _matches(option: Variant, pick: Variant) -> bool:
    if pick is Callable:
        return (pick as Callable).call(option)
    if option is TurnOption:
        var turn: TurnOption = option
        if pick == TurnOption.FLIP or pick == TurnOption.PASS:
            return turn.kind == pick
        return turn.kind == TurnOption.PLAY and turn.card.id == pick
    if option is Card and pick is String:
        return (option as Card).id == pick
    if option is FigureState and pick is String:
        return (option as FigureState).id == pick
    return typeof(option) == typeof(pick) and option == pick

class PassProvider:
    extends DecisionProvider
    var ai := SimpleAiProvider.new()

    func decide(request: DecisionRequest, battle: Battle) -> int:
        if request.kind == DecisionRequest.NEXT_HERO:
            return 0
        if request.kind == DecisionRequest.TURN:
            for i in range(request.options.size()):
                if (request.options[i] as TurnOption).kind == TurnOption.PASS:
                    return i
        return ai.decide(request, battle)
