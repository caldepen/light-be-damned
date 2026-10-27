class_name DecisionProvider
extends RefCounted

## Every choice a hero makes goes through a provider (CLAUDE.md, rule 5). A human provider
## (UI) and an AI provider implement the same method. The engine only offers legal options
## and checks the answer, so a provider can never break the rules. Besides each hero's choices,
## the party's choice of who acts next (DecisionRequest.NEXT_HERO, request.hero null) comes here too.

## Return the index into request.options of the chosen option.
func decide(_request: DecisionRequest, _battle: Battle) -> int:
    return 0
