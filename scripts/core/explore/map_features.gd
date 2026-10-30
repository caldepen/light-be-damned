class_name MapFeatures
extends RefCounted

## Cosmetic decorations for a placed tile (DATA_SCHEMA "Map features"). Picks come from the run's
## cosmetic RNG stream, never the gameplay RNG, so feature data can't change how a run plays.

## The cosmetic stream's seed, derived from the run seed.
static func cosmetic_seed(run_seed: int) -> int:
    return absi(hash("map_features:%d" % run_seed))

## Walk the tile's slots in data order (cells, then count), roll `chance` for each and make a
## weighted pick from the pool. Returns [{"cell": map square, "id": String}].
static func pick(tile: PlacedTile, room_type: Dictionary, rng: SeededRng) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var type_features: Dictionary = room_type.get("features", {})
    var tile_features: Dictionary = tile.def.get("features", {})
    var pool: Array = type_features.get("pool", []).duplicate()
    pool.append_array(tile_features.get("pool", []))
    if pool.is_empty():
        return result
    var chance: float = float(type_features.get("chance", 1.0))
    for slot in _slots(tile, type_features, tile_features):
        var cell: Vector2i = slot["cell"]
        for i in range(int(slot["count"])):
            if rng.next_float() >= chance:
                continue
            result.append({"cell": TileGeometry.rotate_cell(cell, tile.rotation) + tile.anchor, "id": _weighted(pool, rng)})
    return result

## Slots on the tile's own cells: the tile's `slots` if it has them, else `slots_per_cell` per cell.
static func _slots(tile: PlacedTile, type_features: Dictionary, tile_features: Dictionary) -> Array[Dictionary]:
    var slots: Array[Dictionary] = []
    if tile_features.has("slots"):
        for s in tile_features["slots"]:
            slots.append({"cell": Vector2i(int(s["cell"][0]), int(s["cell"][1])), "count": int(s.get("count", 1))})
        return slots
    var per_cell: int = int(type_features.get("slots_per_cell", 1))
    for c in TileGeometry.cells_from_data(tile.def.get("cells", [])):
        slots.append({"cell": c, "count": per_cell})
    return slots

static func _weighted(pool: Array, rng: SeededRng) -> String:
    var total: float = 0.0
    for p in pool:
        total += float(p.get("weight", 1))
    var roll: float = rng.next_float() * total
    for p in pool:
        roll -= float(p.get("weight", 1))
        if roll < 0.0:
            return String(p["id"])
    return String(pool[pool.size() - 1]["id"])
