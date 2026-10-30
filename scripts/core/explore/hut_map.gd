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

## A wall token closes a doorway for good (Vanishing Door, Doors Slam).
func close_doorway(cell: Vector2i, side: String) -> void:
    _walls[TileGeometry.door_key(cell, side)] = true

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
