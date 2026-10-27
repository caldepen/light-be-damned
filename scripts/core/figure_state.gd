class_name FigureState
extends RefCounted

## State shared by heroes and enemies. Plain data: the Battle changes it and logs events.

const SIDE_HEROES := "heroes"
const SIDE_ENEMIES := "enemies"

var id: String = ""
var name: String = ""
var side: String = SIDE_HEROES
var cells: Array[Vector2i] = []
var down: bool = false

var armor_slots: int = 0
var armor_damage: int = 0

## Guard tokens on this figure's one Guard card, and the round at whose end the card is discarded.
var guard_tokens: int = 0
var guard_expires_round: int = -1

## Rounds left on each Bleed track; each track deals 1 damage at the end of a round.
var bleeds: Array[int] = []
var stunned: bool = false

## Ongoing effects by name (berserk, thorns, ignore_next_attack, lightning_orb, rage, ...),
## each holding the effect object that created it plus any counters.
var statuses: Dictionary = {}

var standing: bool:
    get:
        return not down

func is_hero() -> bool:
    return side == SIDE_HEROES

func unmarked_armor() -> int:
    return armor_slots - armor_damage

## Damage bonus from ongoing statuses (Berserk, Rage).
func status_damage_bonus() -> int:
    var total: int = 0
    for status_name in statuses:
        var status: Dictionary = statuses[status_name]
        total += int(status.get("damage_bonus", 0))
    return total

## Front-left cell: the square a figure acts by and is sorted by (RULES §5 Turn order).
func anchor() -> Vector2i:
    var best: Vector2i = cells[0]
    for c in cells:
        var d: int = Field.depth_for(side, c)
        var best_d: int = Field.depth_for(side, best)
        if d < best_d or (d == best_d and c.x < best.x):
            best = c
    return best

## Unmarked armor plus remaining hit points; overridden by heroes and enemies.
func power() -> int:
    return unmarked_armor()

func _to_string() -> String:
    return name
