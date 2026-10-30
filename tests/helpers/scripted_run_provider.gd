class_name ScriptedRunProvider
extends RunDecisionProvider

## Test provider for exploring choices: answers queued per kind with then(kind, value), where the
## value is an option or a func(option) -> bool picking the first match; anything not scripted
## takes the first option (so yes/no questions default to "no"). Records every request.

var answers: Dictionary = {}  # kind -> Array of values, first used first
var asked: Array[RunRequest] = []

func then(kind: String, value: Variant) -> ScriptedRunProvider:
    if not answers.has(kind):
        answers[kind] = []
    (answers[kind] as Array).append(value)
    return self

func decide(request: RunRequest, _run: HutRun) -> int:
    asked.append(request)
    var queue: Array = answers.get(request.kind, [])
    if not queue.is_empty():
        var answer: Variant = queue.pop_front()
        if answer is Callable:
            for i in range(request.options.size()):
                if (answer as Callable).call(request.options[i]):
                    return i
        var i: int = request.options.find(answer)
        if i >= 0:
            return i
    return 0

func requests_of(kind: String) -> Array[RunRequest]:
    var result: Array[RunRequest] = []
    for r in asked:
        if r.kind == kind:
            result.append(r)
    return result
