class_name HutExplorer
extends RefCounted

## Building the Hut one room at a time (RULES §8 Exploring, Nothing fits; §10 Special tiles and
## Hut track). Owns the map, the tile bag and the Hut track for one run; draws use the run's
## gameplay RNG, map features the cosmetic stream. Everything that happens goes to `log`.
##
## Choices among legal placements go through `chooser`: func(kind: String, options: Array) -> int
## (kind "placement"). The default takes the first option; run decisions arrive in Milestone 4.5.

const CHOICE_PLACEMENT := "placement"

var module: Dictionary
var map := HutMap.new()
var bag: TileBag
var rng: SeededRng
var cosmetic_rng: SeededRng
var log: EventLog
var chooser: Callable = func(_kind: String, _options: Array) -> int: return 0
var hut_track: int = 0
var party_level: int = 1
var has_key: bool = false
var front_door: PlacedTile
var party_tile: PlacedTile
## Called after every change of the Hut track with (before, after): the run resolves Whims and the
## Hut waking here.
var hut_listener: Callable = Callable()
## Crooked Corridor: the next tile goes as far from the Front Door as it can (then clears).
var crooked: bool = false
var _peeked: Dictionary = {}            # Keyhole: the tile already drawn for the next exploration
var _specials_entered: Dictionary = {}  # special tile id -> true

func _init(module_in: Dictionary, rng_in: SeededRng, run_seed: int, log_in: EventLog = null) -> void:
    module = module_in
    rng = rng_in
    cosmetic_rng = SeededRng.new(MapFeatures.cosmetic_seed(run_seed))
    log = log_in if log_in != null else EventLog.new()
    hut_track = int(module.get("hut_track", {}).get("start", 0))
    bag = TileBag.from_module(module)
    bag.shuffle(rng)
    var entrance: Dictionary = special_def(String(module.get("map", {}).get("entrance_tile", "front_door")))
    var fixed: Array = entrance.get("fixed_at", [0, 0])
    var p := TilePlacement.make({"def": entrance, "moon": bool(entrance.get("moon", false))}, 0, Vector2i(int(fixed[0]), int(fixed[1])), null, {})
    front_door = _lay(p)
    front_door.explored = true
    party_tile = front_door
    log.record("map_start", "The party stands at the %s. %d tiles in the bag." % [String(entrance.get("name", "entrance")), bag.size()],
        {"tile": front_door.uid, "bag": bag.size()})

func special_def(id: String) -> Dictionary:
    for s in module.get("special_tiles", []):
        if String(s.get("id", "")) == id:
            return s
    push_error("Unknown special tile '%s'." % id)
    return {}

## Open doorways of the room the party is in (the usual choice for exploring).
func party_doorways() -> Array[MapDoorway]:
    return map.open_doorways(party_tile)

## The party moves into `tile`; it counts as explored from now on.
func enter(tile: PlacedTile) -> void:
    tile.explored = true
    party_tile = tile
    log.record("enter_room", "The party enters the %s." % String(tile.def.get("name", tile.tile_id)), {"tile": tile.uid, "type": tile.room_type})

## Walk through explored rooms to `tile` (free, RULES §8 Walking). Returns "" or why not.
func walk_to(tile: PlacedTile) -> String:
    if tile == party_tile:
        return ""
    if not tile.explored or not map.reachable_from(party_tile).has(tile):
        return "the party can't walk there"
    party_tile = tile
    log.record("walk", "The party walks to the %s." % String(tile.def.get("name", tile.tile_id)), {"tile": tile.uid})
    return ""

## Keyhole: draw the next tile now so the party sees it before choosing a doorway.
func peek() -> Dictionary:
    if _peeked.is_empty() and not bag.is_empty():
        _peeked = bag.draw()
        log.record("tile_peeked", "Through the keyhole: %s." % _entry_name(_peeked), {"tile": String(_peeked["def"].get("id", ""))})
    return _peeked

## Draw a tile blind and lay it at `doorway` (an open doorway of an explored room, or null when
## there is none), or wherever the rules send it. The party doesn't enter here; the caller
## resolves the room.
func explore(doorway: MapDoorway) -> ExploreResult:
    var result := ExploreResult.new()
    if bag.is_empty() and _peeked.is_empty():
        result.status = ExploreResult.EMPTY_BAG
        log.record("bag_empty", "The tile bag is empty: no more exploring this run.", {})
        return result
    var set_aside: Array[Dictionary] = []
    var forced: bool = crooked
    crooked = false
    while not bag.is_empty() or not _peeked.is_empty():
        var entry: Dictionary = _peeked if not _peeked.is_empty() else bag.draw()
        _peeked = {}
        log.record("tile_drawn", "Drawn: %s%s." % [_entry_name(entry), " (moon)" if bool(entry["moon"]) else ""],
            {"tile": String(entry["def"].get("id", "")), "moon": entry["moon"]})
        var options: Array[TilePlacement] = farthest_options(entry) if forced else placement_options(entry, doorway)
        if not options.is_empty():
            result.tile = _place(rng.pick(options) if forced else _choose(options))
            _return_set_aside(set_aside)
            result.set_aside = set_aside.size()
            return result
        set_aside.append(entry)
        log.record("tile_set_aside", "The %s fits nowhere; it is set aside." % _entry_name(entry), {"tile": String(entry["def"].get("id", ""))})
        if not result.stirred:
            result.stirred = true
            raise_hut(1, "nothing fits")
    result.set_aside = set_aside.size()
    var first: Dictionary = set_aside.pop_front()
    var walls: Array[TilePlacement] = map.wall_placements(first, party_tile)
    if walls.is_empty():
        set_aside.push_front(first)
        _return_set_aside(set_aside)
        result.status = ExploreResult.CLOSED_IN
        log.record("closed_in", "The Hut has closed in: no more exploring this run.", {})
        return result
    log.record("break_through", "The party breaks through a wall with the %s." % _entry_name(first), {"tile": String(first["def"].get("id", ""))})
    result.broke_through = true
    result.tile = _place(_choose(walls))
    _return_set_aside(set_aside)
    return result

## Where a drawn tile may go, in the rules' order: at the chosen doorway; else at another open
## doorway of the same room; else of any explored room. Goal tiles (ignores_doorway_matching)
## go at the chosen doorway if they fit, else against any wall of an explored room (ruling #48).
## "Explored room" here means one the party can walk to (open question #77).
func placement_options(entry: Dictionary, doorway: MapDoorway) -> Array[TilePlacement]:
    var options: Array[TilePlacement] = []
    if bool(entry["def"].get("ignores_doorway_matching", false)):
        if doorway != null:
            options = map.hut_placements_at(entry, doorway)
        return options if not options.is_empty() else map.wall_placements(entry, party_tile)
    if doorway != null:
        options = map.doorway_placements(entry, doorway)
        if not options.is_empty():
            return options
        for d in map.open_doorways(doorway.tile):
            if d.key() != doorway.key():
                options.append_array(map.doorway_placements(entry, d))
        if not options.is_empty():
            return options
    for d in map.explored_open_doorways(party_tile):
        if doorway == null or d.tile != doorway.tile:
            options.append_array(map.doorway_placements(entry, d))
    return options

## Crooked Corridor: of every legal placement on the map, those whose doorway (or Hut door) is
## farthest from the Front Door by path in squares. The Hut picks among ties at random (#63).
func farthest_options(entry: Dictionary) -> Array[TilePlacement]:
    var all: Array[TilePlacement] = []
    if bool(entry["def"].get("ignores_doorway_matching", false)):
        all = map.wall_placements(entry, party_tile)
    else:
        for d in map.explored_open_doorways(party_tile):
            all.append_array(map.doorway_placements(entry, d))
    var dist: Dictionary = map.path_distances(front_door.cells[0])
    var best: int = -1
    var result: Array[TilePlacement] = []
    for p in all:
        var at: Vector2i = p.doorway.cell if p.doorway != null else p.hut_door["cell"]
        var d: int = int(dist.get(at, -1))
        if d > best:
            best = d
            result.clear()
            result.append(p)
        elif d == best:
            result.append(p)
    return result

## The Hut track rises (moons, failed rolls, campfires, a stir). Special tiles whose time has
## come enter the bag. Whims and the Hut waking are Milestone 4.3.
func raise_hut(amount: int, reason: String) -> void:
    var hut: Dictionary = module.get("hut_track", {})
    var before: int = hut_track
    hut_track = clampi(hut_track + amount, 0, int(hut.get("max", 10)))
    log.record("hut_track", "Hut track %d -> %d (%s)." % [before, hut_track, reason], {"from": before, "to": hut_track, "reason": reason})
    _check_specials()
    if hut_listener.is_valid() and hut_track != before:
        hut_listener.call(before, hut_track)

func _check_specials() -> void:
    for s in module.get("special_tiles", []):
        var rule: Dictionary = s.get("enters_bag", {})
        var id: String = String(s.get("id", ""))
        if rule.is_empty() or _specials_entered.has(id) or hut_track < int(rule.get("at_hut", 0)):
            continue
        if party_level < int(rule.get("min_party_level", 0)):
            continue
        if bool(rule.get("unless_party_has_key", false)) and has_key:
            continue
        _specials_entered[id] = true
        var more: Array[Dictionary] = [{"def": s, "moon": bool(s.get("moon", false))}]
        bag.put_back(more, rng)
        log.record("special_enters_bag", "The %s is shuffled into the bag." % String(s.get("name", id)), {"tile": id})

# ------------------------------------------------------------------ map changes (Hut Whims)
# Each returns "" when the change happened, else why not; both are logged.

func rotate_tile(tile: PlacedTile, rotation: int) -> String:
    return _logged(map.rotate_tile(tile, rotation, party_tile, front_door), "tile_rotated",
        "The %s turns in place." % _tile_name(tile), {"tile": _uid(tile), "rotation": rotation})

func swap_tiles(a: PlacedTile, b: PlacedTile) -> String:
    return _logged(map.swap_tiles(a, b, party_tile, front_door), "tiles_swapped",
        "The %s and the %s trade places." % [_tile_name(a), _tile_name(b)], {"tiles": [_uid(a), _uid(b)]})

func remove_tile(tile: PlacedTile) -> String:
    return _logged(map.remove_tile(tile, party_tile, front_door), "tile_removed",
        "The %s collapses and is gone for this run." % _tile_name(tile), {"tile": _uid(tile)})

func close_doorway(doorway: MapDoorway) -> String:
    return _logged(map.close_doorway(doorway.cell, doorway.side), "doorway_closed",
        "A wall seals the %s." % doorway.describe(), {"cell": doorway.cell, "side": doorway.side})

## Every legal turn of an explored tile: [{"tile", "rotation"}] (Shifting Walls).
func rotation_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for t in map.tiles:
        for r in range(4):
            if map.rotate_tile(t, r, party_tile, front_door, true).is_empty():
                result.append({"tile": t, "rotation": r})
    return result

## Every legal pair for Hall of Mirrors: [{"a", "b"}], each pair once.
func swap_options() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for i in range(map.tiles.size()):
        for j in range(i + 1, map.tiles.size()):
            if map.swap_tiles(map.tiles[i], map.tiles[j], party_tile, front_door, true).is_empty():
                result.append({"a": map.tiles[i], "b": map.tiles[j]})
    return result

## Dead ends Collapse may remove.
func collapse_options() -> Array[PlacedTile]:
    var result: Array[PlacedTile] = []
    for t in map.tiles:
        if map.remove_tile(t, party_tile, front_door, true).is_empty():
            result.append(t)
    return result

## Every open doorway on the map (Vanishing Door).
func open_doorway_options() -> Array[MapDoorway]:
    var result: Array[MapDoorway] = []
    for t in map.tiles:
        result.append_array(map.open_doorways(t))
    return result

func _logged(why: String, event_type: String, message: String, details: Dictionary) -> String:
    if why.is_empty():
        log.record(event_type, message, details)
    else:
        var refused: Dictionary = details.duplicate()
        refused["change"] = event_type
        refused["reason"] = why
        log.record("map_change_refused", "No change (%s): %s." % [event_type.replace("_", " "), why], refused)
    return why

static func _tile_name(tile: PlacedTile) -> String:
    return "?" if tile == null else String(tile.def.get("name", tile.tile_id))

static func _uid(tile: PlacedTile) -> int:
    return -1 if tile == null else tile.uid

# ------------------------------------------------------------------ save and load

## The whole exploration state as plain, JSON-safe data: map, bag order, Hut track, party
## position, specials already in the bag, and both RNG streams' positions.
func to_dict() -> Dictionary:
    var specials: Array = _specials_entered.keys()
    specials.sort()
    return {
        "map": map.to_dict(),
        "bag": bag.entries.map(func(e: Dictionary) -> Dictionary: return {"id": String(e["def"]["id"]), "moon": bool(e["moon"])}),
        "hut_track": hut_track, "party_level": party_level, "has_key": has_key,
        "front_door": front_door.uid, "party_tile": party_tile.uid, "specials_entered": specials,
        "crooked": crooked, "peeked": {} if _peeked.is_empty() else {"id": String(_peeked["def"]["id"]), "moon": bool(_peeked["moon"])},
        # 64-bit states as strings: a JSON number would lose precision.
        "rng_state": str(rng.get_state()), "cosmetic_rng_state": str(cosmetic_rng.get_state()),
    }

## Rebuild from to_dict(). `rng_in` is the run's gameplay RNG; its state is restored too.
static func from_dict(data: Dictionary, module_in: Dictionary, rng_in: SeededRng, log_in: EventLog = null) -> HutExplorer:
    var ex := HutExplorer.new(module_in, rng_in, 0, log_in)
    ex.log.entries.clear()
    ex.map = HutMap.from_dict(data["map"], module_in)
    var defs: Dictionary = {}
    for def in module_in.get("tiles", []) + module_in.get("special_tiles", []):
        defs[String(def["id"])] = def
    ex.bag.entries.clear()
    for e in data.get("bag", []):
        ex.bag.entries.append({"def": defs[String(e["id"])], "moon": bool(e["moon"])})
    ex.hut_track = int(data["hut_track"])
    ex.party_level = int(data["party_level"])
    ex.has_key = bool(data["has_key"])
    ex.front_door = ex.map.tile_by_uid(int(data["front_door"]))
    ex.party_tile = ex.map.tile_by_uid(int(data["party_tile"]))
    ex._specials_entered.clear()
    for id in data.get("specials_entered", []):
        ex._specials_entered[String(id)] = true
    ex.crooked = bool(data.get("crooked", false))
    var peeked: Dictionary = data.get("peeked", {})
    if not peeked.is_empty():
        ex._peeked = {"def": defs[String(peeked["id"])], "moon": bool(peeked["moon"])}
    ex.rng.set_state(String(data["rng_state"]).to_int())
    ex.cosmetic_rng.set_state(String(data["cosmetic_rng_state"]).to_int())
    return ex

func _choose(options: Array[TilePlacement]) -> TilePlacement:
    if options.size() == 1:
        return options[0]
    var index: int = int(chooser.call(CHOICE_PLACEMENT, options))
    return options[clampi(index, 0, options.size() - 1)]

## Lay the tile, pick its features, then the moon raises the Hut track (ruling #51).
func _place(p: TilePlacement) -> PlacedTile:
    var tile: PlacedTile = _lay(p)
    if tile.moon:
        raise_hut(1, "moon on the %s" % String(tile.def.get("name", tile.tile_id)))
    return tile

func _lay(p: TilePlacement) -> PlacedTile:
    var tile: PlacedTile = map.add(p)
    tile.features = MapFeatures.pick(tile, module.get("room_types", {}).get(tile.room_type, {}), cosmetic_rng)
    log.record("tile_placed", "Placed: %s." % tile.describe(),
        {"tile": tile.uid, "id": tile.tile_id, "type": tile.room_type, "anchor": tile.anchor, "rotation": tile.rotation,
         "cells": tile.cells.duplicate(), "moon": tile.moon, "hut_door": p.hut_door.duplicate(), "features": tile.features.duplicate(true)})
    return tile

func _return_set_aside(set_aside: Array[Dictionary]) -> void:
    if set_aside.is_empty():
        return
    bag.put_back(set_aside, rng)
    log.record("tiles_returned", "%d set-aside tile%s go back into the bag." % [set_aside.size(), "" if set_aside.size() == 1 else "s"], {"count": set_aside.size()})

static func _entry_name(entry: Dictionary) -> String:
    return String(entry["def"].get("name", entry["def"].get("id", "?")))
