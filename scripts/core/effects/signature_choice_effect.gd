class_name SignatureChoiceEffect
extends EffectHandler

## "signature_choice": the wizard's signature. The option is chosen at each campfire (at battle setup
## for now) and stored on the hero; CardRunner.effects_of() then runs that option's effects instead.
## Reaching this handler means no option was chosen, so the card has no legal effect.

func op_name() -> String:
    return "signature_choice"

func is_legal(_ctx: EffectContext) -> bool:
    return false
