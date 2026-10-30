class_name TileBag
extends RefCounted

## The tile bag (RULES §8, §10): room tiles drawn blind. Each entry is {"def": tile data,
## "moon": bool}; a tile with `qty` copies and `moon_qty` moons gives that many entries. All
## shuffles use the run's seeded RNG. draw() takes the last entry.

var entries: Array[Dictionary] = []

static func from_module(module: Dictionary) -> TileBag:
    var bag := TileBag.new()
    for def in module.get("tiles", []):
        for i in range(int(def.get("qty", 1))):
            bag.entries.append({"def": def, "moon": i < int(def.get("moon_qty", 0))})
    return bag

func size() -> int:
    return entries.size()

func is_empty() -> bool:
    return entries.is_empty()

func shuffle(rng: SeededRng) -> void:
    rng.shuffle(entries)

func draw() -> Dictionary:
    if entries.is_empty():
        return {}
    return entries.pop_back()

## Put tiles back (set-aside tiles, a special tile entering) and shuffle the bag.
func put_back(more: Array[Dictionary], rng: SeededRng) -> void:
    entries.append_array(more)
    shuffle(rng)

func moons() -> int:
    var n: int = 0
    for e in entries:
        if bool(e["moon"]):
            n += 1
    return n
