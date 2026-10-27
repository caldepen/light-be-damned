class_name BatchStats
extends RefCounted

## Totals over a batch of finished battles for one encounter, for tools/run_battle.gd --batch.
## Wounds, armor damage and Exhausted cards are party totals per battle.

var battles: int = 0
var wins: int = 0
var draws: int = 0
var battles_with_a_down: int = 0
var rounds: int = 0
var wounds_taken: int = 0
var armor_damage_left: int = 0
var cards_exhausted: int = 0

## Wounds taken counts Wounds from damage, not Wounds moved between heroes (Lay on Hands).
func add(battle: Battle) -> void:
    battles += 1
    if battle.result == Battle.RESULT_HEROES:
        wins += 1
    elif battle.result == Battle.RESULT_DRAW:
        draws += 1
    for entry in battle.log.of_type("down"):
        if entry["details"].get("side", "") == FigureState.SIDE_HEROES:
            battles_with_a_down += 1
            break
    rounds += battle.round_number
    for entry in battle.log.of_type("wound"):
        if entry["details"].get("source", "damage") == "damage":
            wounds_taken += 1
    for hero in battle.heroes:
        armor_damage_left += hero.armor_damage
        cards_exhausted += hero.exhausted.size()

static func header() -> String:
    return "%-16s %7s %7s %7s %7s %7s %7s %7s" % ["encounter", "win%", "draw%", "down%", "rounds", "wounds", "armor", "exhaust"]

func row(encounter_name: String) -> String:
    return "%-16s %6.1f%% %6.1f%% %6.1f%% %7.2f %7.2f %7.2f %7.2f" % [encounter_name,
        _percent(wins), _percent(draws), _percent(battles_with_a_down),
        _mean(rounds), _mean(wounds_taken), _mean(armor_damage_left), _mean(cards_exhausted)]

func _percent(count: int) -> float:
    return 100.0 * count / maxi(battles, 1)

func _mean(total: int) -> float:
    return float(total) / maxi(battles, 1)
