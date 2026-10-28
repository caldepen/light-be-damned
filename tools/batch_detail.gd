class_name BatchDetail
extends RefCounted

## Per-hero and per-enemy-type breakdown of a batch, for tools/run_battle.gd --batch --detail.
## Damage counts the points that landed (armor slots filled plus Wounds or Hit Dice marked).
## Figures are averages per battle unless a column says otherwise.

const TOP_CARDS := 3

var battles: int = 0
var _heroes: Dictionary = {}       # hero id -> totals (see _new_hero)
var _hero_order: Array[String] = []
var _enemy_types: Dictionary = {}  # enemy type -> totals (see _new_enemy_type)
var _card_names: Dictionary = {}   # card id -> name

func add(battle: Battle) -> void:
    battles += 1
    var figures: Dictionary = {}  # figure id -> FigureState
    for h in battle.heroes:
        figures[h.id] = h
        var totals: Dictionary = _hero(h)
        if h.down:
            totals["downs"] += 1
        for pile in [h.deck, h.hand, h.discard, h.exhausted]:
            for c in pile:
                _card_names[c.id] = c.name
    for e in battle.enemies:
        figures[e.id] = e
        var totals: Dictionary = _enemy_type(e.enemy_type)
        totals["count"] += 1
        if e.fled:
            totals["fled"] += 1
        elif e.down:
            totals["downs"] += 1
    for entry in battle.log.entries:
        _count(entry, figures)

func _count(entry: Dictionary, figures: Dictionary) -> void:
    var d: Dictionary = entry["details"]
    match String(entry["type"]):
        "damage":
            var landed: int = int(d["armor"]) + int(d["rest"])
            var target: FigureState = figures.get(d["target"])
            var source: FigureState = figures.get(d["source"])
            if target is HeroState:
                _hero(target)["taken"] += landed
                if source is EnemyState:
                    _enemy_type((source as EnemyState).enemy_type)["dealt"] += landed
            elif source is HeroState:
                _hero(source)["dealt"] += landed
        "wound":
            if String(d.get("source", "damage")) == "damage":
                _hero(figures[d["hero"]])["wounds"] += 1
        "heal":
            var healer: FigureState = figures.get(d["healer"])
            if healer is HeroState:
                _hero(healer)["healed"] += 1
        "repair":
            var source: FigureState = figures.get(d["source"])
            if source is HeroState:
                _hero(source)["healed"] += int(d["amount"])
        "turn_start":
            var figure: FigureState = figures.get(d["figure"])
            if figure is HeroState:
                _hero(figure)["turns"] += 1
        "card_played":
            var totals: Dictionary = _hero(figures[d["hero"]])
            totals["plays"] += 1
            totals["cards"][d["card"]] = int(totals["cards"].get(d["card"], 0)) + 1
        "card_flipped":
            _hero(figures[d["hero"]])["flips"] += 1
        "pass":
            _hero(figures[d["hero"]])["passes"] += 1

func _hero(h: HeroState) -> Dictionary:
    if not _heroes.has(h.id):
        _hero_order.append(h.id)
        _heroes[h.id] = {"name": h.name, "downs": 0, "wounds": 0, "taken": 0, "dealt": 0, "healed": 0,
            "turns": 0, "plays": 0, "flips": 0, "passes": 0, "cards": {}}
    return _heroes[h.id]

func _enemy_type(enemy_type: String) -> Dictionary:
    if not _enemy_types.has(enemy_type):
        _enemy_types[enemy_type] = {"count": 0, "downs": 0, "fled": 0, "dealt": 0}
    return _enemy_types[enemy_type]

## Hero table, then enemy table. "Share" is the hero's part of all damage the party took;
## "heal" counts Wounds removed plus armor repaired; play/flip/pass are shares of turns taken.
func lines() -> PackedStringArray:
    var out: PackedStringArray = []
    var party_taken: int = 0
    for id in _hero_order:
        party_taken += int(_heroes[id]["taken"])
    out.append("  %-10s %6s %6s %6s %6s %6s %6s %6s %5s %5s %5s  %s" % ["hero", "down%", "wounds", "taken", "share",
        "dealt", "heal", "turns", "play", "flip", "pass", "most played (per battle)"])
    for id in _hero_order:
        var t: Dictionary = _heroes[id]
        var turns: int = maxi(int(t["turns"]), 1)
        out.append("  %-10s %5.1f%% %6.2f %6.2f %5.0f%% %6.2f %6.2f %6.2f %4.0f%% %4.0f%% %4.0f%%  %s" % [t["name"],
            _percent(t["downs"]), _mean(t["wounds"]), _mean(t["taken"]), 100.0 * int(t["taken"]) / maxi(party_taken, 1),
            _mean(t["dealt"]), _mean(t["healed"]), _mean(t["turns"]),
            100.0 * int(t["plays"]) / turns, 100.0 * int(t["flips"]) / turns, 100.0 * int(t["passes"]) / turns,
            _top_cards(t["cards"])])
    out.append("  %-10s %6s %6s %6s %6s" % ["enemy", "count", "down%", "fled%", "dealt"])
    for enemy_type in _enemy_types:
        var t: Dictionary = _enemy_types[enemy_type]
        var count: int = maxi(int(t["count"]), 1)
        out.append("  %-10s %6.2f %5.1f%% %5.1f%% %6.2f" % [enemy_type, _mean(t["count"]),
            100.0 * int(t["downs"]) / count, 100.0 * int(t["fled"]) / count, _mean(t["dealt"])])
    return out

func _top_cards(cards: Dictionary) -> String:
    var ids: Array = cards.keys()
    ids.sort_custom(func(a: String, b: String) -> bool: return int(cards[a]) > int(cards[b]))
    var parts: PackedStringArray = []
    for i in range(mini(TOP_CARDS, ids.size())):
        parts.append("%s %.2f" % [_card_names.get(ids[i], ids[i]), _mean(cards[ids[i]])])
    return ", ".join(parts)

func _percent(count: int) -> float:
    return 100.0 * count / maxi(battles, 1)

func _mean(total: int) -> float:
    return float(total) / maxi(battles, 1)
