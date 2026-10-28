class_name TacticalAiProvider
extends SimpleAiProvider

## SimpleAiProvider with a sense of who the enemies will hit next (ThreatModel). Plays are scored by
## TacticalScorer, which watches the Provoke track. Who acts next looks one hero turn ahead, so a
## hero whose play would draw the enemies tends to wait for the tank. Attacks go after the enemy
## whose loss removes the most expected damage, and heals to the hero closest to Down.

## An enemy acts between two hero turns, so when choosing who acts next the follow-up play counts
## at FOLLOW_WEIGHT (a kill now beats the same kill later), and its repair to the track (a tank
## climbing back on top) at REPLY_TRACK_WEIGHT of that. Tuned by batch. (Weighing every card of
## the acting hero against every follow-up was no stronger and three times slower.)
const FOLLOW_WEIGHT := 0.8
const REPLY_TRACK_WEIGHT := 0.5

var tactical: TacticalScorer = TacticalScorer.new()

func _init() -> void:
    scorer = tactical

func decide(request: DecisionRequest, battle: Battle) -> int:
    tactical.prepare(ThreatModel.new(battle))
    var choice: int = super.decide(request, battle)
    tactical.prepare(null)  # the model holds the battle, which holds this provider
    return choice

## Who acts next: each hero's best play now, plus the best play another hero could follow it with
## once its Provoke has moved. Ties go to the old fixed order, as in SimpleAiProvider.
func _choose_next_hero(request: DecisionRequest, battle: Battle) -> int:
    return _best_index(request.options, func(h: HeroState) -> float:
        var play: Dictionary = _best_play(battle, h)
        var value: float = float(play.get("effects", 0.0)) + float(play.get("track", 0.0))
        if play.has("provoke"):
            tactical.assumed_moves = {h: play["provoke"]}
        var reply: float = 0.0
        for other in request.options:
            if other != h:
                var next: Dictionary = _best_play(battle, other)
                reply = maxf(reply, float(next.get("effects", 0.0)) + REPLY_TRACK_WEIGHT * float(next.get("track", 0.0)))
        tactical.assumed_moves = {}
        return maxf(value, 0.0) + FOLLOW_WEIGHT * reply)

## The parts (TacticalScorer.evaluate) of the hero's best legal card, or {} if none scores high
## enough to play rather than flip.
func _best_play(battle: Battle, hero: HeroState) -> Dictionary:
    var best: Dictionary = {}
    var best_score: float = FLIP_THRESHOLD
    for card in CardRunner.legal_hand_cards(battle, hero):
        var parts: Dictionary = tactical.evaluate(battle, hero, card)
        var s: float = float(parts["effects"]) + float(parts["track"])
        if s >= best_score:
            best = parts
            best_score = s
    return best

func _choose_target(request: DecisionRequest, battle: Battle) -> int:
    var threat: ThreatModel = tactical.threat
    match String(request.details.get("purpose", "")):
        "damage":
            var amount: int = int(request.details.get("amount", 0))
            return _best_index(request.options, func(f: FigureState) -> float: return _damage_target_value(battle, threat, f, amount))
        "heal", "transfer":
            return _best_index(request.options, func(h: HeroState) -> float:
                return TacticalScorer.heal_value(battle, h, mini(int(request.details.get("amount", 1)), h.wound_count())))
        "guard":
            return _best_index(request.options, func(h: HeroState) -> float: return tactical.guard_value({h: int(request.details.get("amount", 1))}))
        "bleed", "stun":
            return _best_index(request.options, func(f: FigureState) -> float: return threat.threat_of(f) + 0.01 * float(f.power()))
    return super._choose_target(request, battle)

## A kill is worth most, the bigger the threat removed; otherwise damage goes where it removes the
## most threat per point of toughness. Lowest power breaks ties, as in SimpleAiProvider.
func _damage_target_value(battle: Battle, threat: ThreatModel, target: FigureState, amount: int) -> float:
    var toughness: int = maxi(battle.toughness(target), 1)
    var t: float = threat.threat_of(target)
    if amount >= toughness:
        return 100.0 + 10.0 * t - 0.01 * float(target.power())
    return 10.0 * t * float(amount) / float(toughness) - 0.01 * float(target.power())
