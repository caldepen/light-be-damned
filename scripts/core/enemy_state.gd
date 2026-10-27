class_name EnemyState
extends FigureState

## An enemy: armor and Hit Dice, no hand. Its cards come from its type's shared EnemyDeck.

const MORALE_BOLD := "bold"
const MORALE_TIMID := "timid"
const MORALE_DESPERATE := "desperate"

var enemy_type: String = ""
var def: Dictionary = {}
var hit_dice: int = 0
var marked_hd: int = 0
var draw_count: int = 1
var undead: bool = false
var size: Vector2i = Vector2i(1, 1)

## Ids of ▲ cards this enemy has played and ◆ cards that have taken effect for it.
var used_top: Dictionary = {}
var used_phase: Dictionary = {}
## Damage taken off this enemy's next attack card (Frost Ray).
var weaken_next: int = 0
var fled: bool = false

func _init() -> void:
    side = FigureState.SIDE_ENEMIES

func unmarked_hd() -> int:
    return hit_dice - marked_hd

func power() -> int:
    return unmarked_armor() + unmarked_hd()

func is_melee() -> bool:
    return String(def.get("ai", "melee")) == "melee"

## Morale read off the Hit Dice (RULES §7). Desperate overrides Timid.
func morale() -> String:
    if hit_dice > 1 and unmarked_hd() == 1:
        return MORALE_DESPERATE
    if marked_hd * 2 >= hit_dice:
        return MORALE_TIMID
    return MORALE_BOLD
