class_name RunDecisionProvider
extends RefCounted

## Every choice the party makes while exploring goes through a provider (CLAUDE.md rule 5): a
## human provider (the table UI) and an AI implement the same method. Return the index into
## request.options. The base class takes the first option.

func decide(_request: RunRequest, _run: HutRun) -> int:
    return 0
