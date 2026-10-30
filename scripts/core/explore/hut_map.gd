class_name HutMap
extends RefCounted

## The map of placed room tiles (RULES §8 The map): which square holds which tile, open
## doorways, connections between rooms, and the legal ways to lay a new tile. No board edges.
## Changes nothing but its own occupancy; the explore flow lives in HutExplorer.

var tiles: Array[PlacedTile] = []
var _owner: Dictionary = {}  # Vector2i -> PlacedTile
var _walls: Dictionary = {}  # door key -> true: doorways closed by a wall token
var _next_uid: int = 0

func tile_at(cell: Vector2i) -> PlacedTile:
    return _owner.get(cell, null)

func is_free(cell: Vector2i) -> bool:
    return not _owner.has(cell)

func are_free(cells: Array[Vector2i]) -> bool:
    for c in cells:
        if _owner.has(c):
            return false
    return true

## Lay a tile. A Hut door is cut on both sides: the existing room's edge and the new tile's.
func add(p: TilePlacement) -> PlacedTile:
    _next_uid += 1
    var t := PlacedTile.new()
    t.uid = _next_uid
    t.def = p.def
    t.tile_id = String(p.def.get("id", ""))
    t.room_type = String(p.def.get("type", ""))
    t.moon = p.moon
    t.anchor = p.anchor
    t.rotation = p.rotation
    t.cells = p.cells.duplicate()
    t.doors = p.doors.duplicate()
    tiles.append(t)
    for c in t.cells:
        _owner[c] = t
    if not p.hut_door.is_empty():
        var cell: Vector2i = p.hut_door["cell"]
        var side: String = p.hut_door["side"]
        var other: PlacedTile = tile_at(cell)
        if other != null and not other.has_door(cell, side):
            other.hut_doors.append({"cell": cell, "side": side})
        var new_cell: Vector2i = TileGeometry.facing_cell(cell, side)
        var new_side: String = TileGeometry.opposite(side)
        if not t.has_door(new_cell, new_side):
            t.hut_doors.append({"cell": new_cell, "side": new_side})
    return t

## A wall token closes an open doorway for good (Vanishing Door, Doors Slam). Returns "" when
## it happened, else why not. The token stays on that edge of the map even if a tile moves.
func close_doorway(cell: Vector2i, side: String, dry_run: bool = false) -> String:
    var tile: PlacedTile = tile_at(cell)
    if tile == null or not tile.has_door(cell, side):
        return "there is no doorway there"
    if is_walled(cell, side):
        return "that doorway is already closed"
    if not is_free(TileGeometry.facing_cell(cell, side)):
        return "that doorway isn't open: a room lies beyond it"
    if not dry_run:
        _walls[TileGeometry.door_key(cell, side)] = true
    return ""

func is_walled(cell: Vector2i, side: String) -> bool:
    return _walls.has(TileGeometry.door_key(cell, side))

## Open doorway: a doorway (or Hut door) whose square beyond is empty and has no wall token.
func open_doorways(tile: PlacedTile) -> Array[MapDoorway]:
    var result: Array[MapDoorway] = []
    for d in tile.all_doors():
        var cell: Vector2i = d["cell"]
        var side: String = d["side"]
        if not is_walled(cell, side) and is_free(TileGeometry.facing_cell(cell, side)):
            result.append(MapDoorway.new(tile, cell, side))
    return result

## Open doorways of every explored tile, in placement order.
func explored_open_doorways() -> Array[MapDoorway]:
    var result: Array[MapDoorway] = []
    for t in tiles:
        if t.explored:
            result.append_array(open_doorways(t))
    return result

## Rooms joined to `tile` by two doorways that face each other (or a Hut door), not walled.
func neighbours(tile: PlacedTile) -> Array[PlacedTile]:
    var result: Array[PlacedTile] = []
    for d in tile.all_doors():
        var cell: Vector2i = d["cell"]
        var side: String = d["side"]
        var beyond: Vector2i = TileGeometry.facing_cell(cell, side)
        var other: PlacedTile = tile_at(beyond)
        if other == null or other == tile or result.has(other):
            continue
        if is_walled(cell, side) or is_walled(beyond, TileGeometry.opposite(side)):
            continue
        if other.has_door(beyond, TileGeometry.opposite(side)):
            result.append(other)
    return result

func connected(a: PlacedTile, b: PlacedTile) -> bool:
    return neighbours(a).has(b)

## Every room the party can walk to from `start` (start included).
func reachable_from(start: PlacedTile) -> Array[PlacedTile]:
    var seen: Array[PlacedTile] = [start]
    var frontier: Array[PlacedTile] = [start]
    while not frontier.is_empty():
        var t: PlacedTile = frontier.pop_front()
        for n in neighbours(t):
            if not seen.has(n):
                seen.append(n)
                frontier.append(n)
    return seen

# ------------------------------------------------------------------ Whim operations
# Shifting Walls, Hall of Mirrors and Collapse (RULES §10 Hut Whims). Each returns "" when it
# happened (or, with dry_run, would happen), else why not, and then changes nothing. None may
# move the party's room, the Front Door or a special tile, or cut the party off from the Front Door.

## Turn `tile` to `rotation` on exactly the squares it covers now (1x1 and 2x2 tiles any way,
## straight tiles such as 1x2 and the T corridor half round, the bent corridor never). Its Hut
## doors turn with it.
func rotate_tile(tile: PlacedTile, rotation: int, party: PlacedTile, front: PlacedTile, dry_run: bool = false) -> String:
    var why: String = _fixed_reason(tile, party, front, true)
    if not why.is_empty():
        return why
    var r: int = posmod(rotation, 4)
    if r == tile.rotation:
        return "it already faces that way"
    var anchor: Variant = _anchor_in_place(tile, r)
    if anchor == null:
        return "turned that way it wouldn't cover its own squares"
    var was_reachable: bool = _party_reachable(party, front)
    var saved: Dictionary = _pose_of(tile)
    _set_pose(tile, r, anchor as Vector2i)
    if was_reachable and not _party_reachable(party, front):
        _restore_pose(tile, saved)
        return "it would cut the party off from the Front Door"
    if dry_run:
        _restore_pose(tile, saved)
    return ""

## Swap two explored tiles whose squares match by sliding one onto the other; each keeps its
## orientation, doorways and all.
func swap_tiles(a: PlacedTile, b: PlacedTile, party: PlacedTile, front: PlacedTile, dry_run: bool = false) -> String:
    for t in [a, b]:
        var why: String = _fixed_reason(t, party, front, true)
        if not why.is_empty():
            return why
    if a == b:
        return "a tile can't swap with itself"
    var offset: Vector2i = _min_cell(b.cells) - _min_cell(a.cells)
    if not _same_squares(TileGeometry.placed_cells(a.cells, 0, offset), b.cells):
        return "the two tiles aren't the same size and shape"
    var was_reachable: bool = _party_reachable(party, front)
    _shift(a, offset)
    _shift(b, -offset)
    if was_reachable and not _party_reachable(party, front):
        _shift(a, -offset)
        _shift(b, offset)
        return "it would cut the party off from the Front Door"
    if dry_run:
        _shift(a, -offset)
        _shift(b, offset)
    return ""

## Collapse: remove a dead end (connected to exactly one other room, no open doorways). It
## leaves the game for this run. A dead end can never cut the map in two.
func remove_tile(tile: PlacedTile, party: PlacedTile, front: PlacedTile, dry_run: bool = false) -> String:
    var why: String = _fixed_reason(tile, party, front, false)
    if not why.is_empty():
        return why
    if neighbours(tile).size() != 1:
        return "it isn't a dead end: it connects to %d rooms" % neighbours(tile).size()
    if not open_doorways(tile).is_empty():
        return "it isn't a dead end: it still has an open doorway"
    if not dry_run:
        for c in tile.cells:
            _owner.erase(c)
        tiles.erase(tile)
    return ""

func _fixed_reason(tile: PlacedTile, party: PlacedTile, front: PlacedTile, must_be_explored: bool) -> String:
    if tile == null or not tiles.has(tile):
        return "that tile isn't on the map"
    if tile == front:
        return "the Front Door never moves"
    if tile.is_special():
        return "special tiles never move"
    if tile == party:
        return "the party is in that room"
    if must_be_explored and not tile.explored:
        return "only explored tiles"
    return ""

func _party_reachable(party: PlacedTile, front: PlacedTile) -> bool:
    return party == null or front == null or reachable_from(front).has(party)

func _anchor_in_place(tile: PlacedTile, r: int) -> Variant:
    var turned: Array[Vector2i] = TileGeometry.placed_cells(TileGeometry.cells_from_data(tile.def.get("cells", [])), r, Vector2i.ZERO)
    for c in tile.cells:
        var anchor: Vector2i = c - turned[0]
        if _same_squares(TileGeometry.placed_cells(turned, 0, anchor), tile.cells):
            return anchor
    return null

func _pose_of(tile: PlacedTile) -> Dictionary:
    return {"rotation": tile.rotation, "anchor": tile.anchor, "cells": tile.cells.duplicate(), "doors": tile.doors.duplicate(true), "hut_doors": tile.hut_doors.duplicate(true)}

func _restore_pose(tile: PlacedTile, pose: Dictionary) -> void:
    tile.rotation = pose["rotation"]
    tile.anchor = pose["anchor"]
    tile.cells = pose["cells"]
    tile.doors = pose["doors"]
    tile.hut_doors = pose["hut_doors"]

## New rotation and anchor on the same squares; Hut doors keep their place on the tile.
func _set_pose(tile: PlacedTile, r: int, anchor: Vector2i) -> void:
    var turned_hut: Array[Dictionary] = []
    for d in tile.hut_doors:
        var local: Vector2i = TileGeometry.rotate_cell(d["cell"] - tile.anchor, -tile.rotation)
        var side: String = TileGeometry.rotate_side(d["side"], -tile.rotation)
        turned_hut.append({"cell": TileGeometry.rotate_cell(local, r) + anchor, "side": TileGeometry.rotate_side(side, r)})
    tile.rotation = r
    tile.anchor = anchor
    tile.cells = TileGeometry.placed_cells(TileGeometry.cells_from_data(tile.def.get("cells", [])), r, anchor)
    tile.doors = TileGeometry.placed_doors(TileGeometry.doors_from_data(tile.def.get("doors", [])), r, anchor)
    tile.hut_doors = turned_hut

func _shift(tile: PlacedTile, offset: Vector2i) -> void:
    tile.anchor += offset
    tile.cells = TileGeometry.placed_cells(tile.cells, 0, offset)
    for list in [tile.doors, tile.hut_doors]:
        for d in list:
            d["cell"] = d["cell"] + offset
    for c in tile.cells:
        _owner[c] = tile

static func _min_cell(cells: Array[Vector2i]) -> Vector2i:
    var m: Vector2i = cells[0]
    for c in cells:
        m = Vector2i(mini(m.x, c.x), mini(m.y, c.y))
    return m

static func _same_squares(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
    if a.size() != b.size():
        return false
    for c in a:
        if not b.has(c):
            return false
    return true

# ------------------------------------------------------------------ save and load

## Plain data (ints, strings, bools, arrays; JSON-safe). Tile data is looked up again by id.
func to_dict() -> Dictionary:
    var out_tiles: Array = []
    for t in tiles:
        out_tiles.append({
            "uid": t.uid, "id": t.tile_id, "moon": t.moon, "explored": t.explored,
            "anchor": [t.anchor.x, t.anchor.y], "rotation": t.rotation,
            "cells": _cells_out(t.cells), "doors": _doors_out(t.doors), "hut_doors": _doors_out(t.hut_doors),
            "features": t.features.map(func(f: Dictionary) -> Dictionary: return {"cell": [f["cell"].x, f["cell"].y], "id": f["id"]}),
        })
    var walls: Array = _walls.keys()
    walls.sort()
    return {"tiles": out_tiles, "walls": walls, "next_uid": _next_uid}

static func from_dict(data: Dictionary, module: Dictionary) -> HutMap:
    var defs: Dictionary = {}
    for def in module.get("tiles", []) + module.get("special_tiles", []):
        defs[String(def["id"])] = def
    var m := HutMap.new()
    for raw in data.get("tiles", []):
        var t := PlacedTile.new()
        t.uid = int(raw["uid"])
        t.tile_id = String(raw["id"])
        t.def = defs.get(t.tile_id, {})
        t.room_type = String(t.def.get("type", ""))
        t.moon = bool(raw["moon"])
        t.explored = bool(raw["explored"])
        t.anchor = Vector2i(int(raw["anchor"][0]), int(raw["anchor"][1]))
        t.rotation = int(raw["rotation"])
        t.cells = TileGeometry.cells_from_data(raw["cells"])
        t.doors = TileGeometry.doors_from_data(raw["doors"])
        t.hut_doors = TileGeometry.doors_from_data(raw["hut_doors"])
        for f in raw.get("features", []):
            t.features.append({"cell": Vector2i(int(f["cell"][0]), int(f["cell"][1])), "id": String(f["id"])})
        m.tiles.append(t)
        for c in t.cells:
            m._owner[c] = t
    for key in data.get("walls", []):
        m._walls[String(key)] = true
    m._next_uid = int(data.get("next_uid", m.tiles.size()))
    return m

func tile_by_uid(uid: int) -> PlacedTile:
    for t in tiles:
        if t.uid == uid:
            return t
    return null

static func _cells_out(cells: Array[Vector2i]) -> Array:
    return cells.map(func(c: Vector2i) -> Array: return [c.x, c.y])

static func _doors_out(doors: Array[Dictionary]) -> Array:
    return doors.map(func(d: Dictionary) -> Dictionary: return {"cell": [d["cell"].x, d["cell"].y], "side": d["side"]})

# ------------------------------------------------------------------ placement options

## Ways to lay `entry` ({"def", "moon"}) so one of its doorways meets `doorway`, any of 4 rotations,
## without overlapping (RULES §8 Exploring, step 3).
func doorway_placements(entry: Dictionary, doorway: MapDoorway) -> Array[TilePlacement]:
    var options: Array[TilePlacement] = []
    var seen: Dictionary = {}
    var target: Vector2i = doorway.facing()
    var need: String = TileGeometry.opposite(doorway.side)
    var doors: Array[Dictionary] = TileGeometry.doors_from_data(entry["def"].get("doors", []))
    for r in range(4):
        for d in doors:
            if TileGeometry.rotate_side(d["side"], r) != need:
                continue
            var anchor: Vector2i = target - TileGeometry.rotate_cell(d["cell"], r)
            _add_if_free(options, seen, TilePlacement.make(entry, r, anchor, doorway, {}))
    return options

## Ways to lay `entry` on the square beyond `doorway` ignoring doorway matching (Workshop,
## Inner Study): any rotation that covers that square; the Hut makes the door if needed.
func hut_placements_at(entry: Dictionary, doorway: MapDoorway) -> Array[TilePlacement]:
    var options: Array[TilePlacement] = []
    var seen: Dictionary = {}
    _add_against(options, seen, entry, doorway.cell, doorway.side, doorway)
    return options

## Ways to lay `entry` against any edge of an explored room that faces an empty square; the
## Hut makes the door (break-through, and the goal tiles when they don't fit at the doorway).
func wall_placements(entry: Dictionary) -> Array[TilePlacement]:
    var options: Array[TilePlacement] = []
    var seen: Dictionary = {}
    for t in tiles:
        if not t.explored:
            continue
        for cell in t.cells:
            for side in TileGeometry.SIDES:
                if is_free(TileGeometry.facing_cell(cell, side)):
                    _add_against(options, seen, entry, cell, side, null)
    return options

func _add_against(options: Array[TilePlacement], seen: Dictionary, entry: Dictionary, cell: Vector2i, side: String, doorway: MapDoorway) -> void:
    var target: Vector2i = TileGeometry.facing_cell(cell, side)
    var own_cells: Array[Vector2i] = TileGeometry.cells_from_data(entry["def"].get("cells", []))
    for r in range(4):
        for c in own_cells:
            var anchor: Vector2i = target - TileGeometry.rotate_cell(c, r)
            var p := TilePlacement.make(entry, r, anchor, doorway, {"cell": cell, "side": side})
            if _meets_naturally(p, target, side):
                p.hut_door = {}
            _add_if_free(options, seen, p)

## The new tile's own doorway already meets the existing room's doorway: no Hut door needed.
func _meets_naturally(p: TilePlacement, target: Vector2i, side: String) -> bool:
    if p.doorway == null:
        return false
    for d in p.doors:
        if d["cell"] == target and d["side"] == TileGeometry.opposite(side):
            return true
    return false

func _add_if_free(options: Array[TilePlacement], seen: Dictionary, p: TilePlacement) -> void:
    if not are_free(p.cells):
        return
    var sig: String = p.signature()
    if seen.has(sig):
        return
    seen[sig] = true
    options.append(p)
