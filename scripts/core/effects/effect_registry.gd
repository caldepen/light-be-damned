class_name EffectRegistry
extends RefCounted

## Maps each effect `op` in the data to its handler (CLAUDE.md, rule 2). The data validator uses
## known_ops(), so an op in the JSON without a handler fails loading instead of being skipped.

var _handlers: Dictionary = {}

func _init() -> void:
    for handler in [
        # Hero ops
        DamageEffect.new(), DamageChoiceEffect.new(), BleedEffect.new(), StunEffect.new(),
        GuardEffect.new(), ProvokeEffect.new(), ProvokeHalveEffect.new(), HealWoundEffect.new(),
        CleanseEffect.new(), RepairArmorEffect.new(), TransferWoundsEffect.new(), ConsecrateEffect.new(),
        DrawEffect.new(), MoveEffect.new(), StatusEffect.new(), BuffNextEffect.new(),
        WeakenNextAttackEffect.new(), PeekEffect.new(), RecoverEffect.new(), SignatureChoiceEffect.new(),
        # Enemy ops (guard, stun, bleed, move and status are shared)
        AttackEffect.new(), AttackAreaEffect.new(), SplashEffect.new(), DiscardRandomEffect.new(),
        DiscardEffect.new(), SummonEffect.new(), SummonIfLastEffect.new(), ThrowAllyEffect.new(),
        FleeIfEffect.new(), HealHdEffect.new(), RepairSelfArmorEffect.new(), ProvokeAllHeroesEffect.new(),
        PolymorphEffect.new(),
    ]:
        _handlers[handler.op_name()] = handler

func has(op: String) -> bool:
    return _handlers.has(op)

func handler(op: String) -> EffectHandler:
    if not _handlers.has(op):
        push_error("No effect handler for op '%s'." % op)
        return EffectHandler.new()
    return _handlers[op]

func known_ops() -> Array:
    return _handlers.keys()
