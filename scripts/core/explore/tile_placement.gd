class_name TilePlacement
extends RefCounted

## One legal way to lay a drawn tile: its rotation and squares, the doorway it meets (null when
## the Hut places it against a wall) and the door the Hut makes, if any.

var def: Dictionary = {}
var moon: bool = false
var rotation: int = 0
var anchor: Vector2i = Vector2i.ZERO
var cells: Array[Vector2i] = []
var doors: Array[Dictionary] = []
var doorway: MapDoorway = null
## The Hut's door: {"cell", "side"} on the existing room's edge (the new tile gets the facing
## side). Empty when the tile's own doorway meets the doorway.
var hut_door: Dictionary = {}

static func make(entry: Dictionary, rotation_in: int, anchor_in: Vector2i, doorway_in: MapDoorway, hut_door_in: Dictionary) -> TilePlacement:
    var p := TilePlacement.new()
    p.def = entry["def"]
    p.moon = bool(entry.get("moon", false))
    p.rotation = rotation_in
    p.anchor = anchor_in
    p.cells = TileGeometry.placed_cells(TileGeometry.cells_from_data(p.def.get("cells", [])), rotation_in, anchor_in)
    p.doors = TileGeometry.placed_doors(TileGeometry.doors_from_data(p.def.get("doors", [])), rotation_in, anchor_in)
    p.doorway = doorway_in
    p.hut_door = hut_door_in
    return p

## Same squares, doorways and Hut door: two rotations of a symmetric tile are one choice.
func signature() -> String:
    var parts: PackedStringArray = []
    for c in cells:
        parts.append("%d,%d" % [c.x, c.y])
    parts.sort()
    var door_parts: PackedStringArray = []
    for d in doors:
        door_parts.append(TileGeometry.door_key(d["cell"], d["side"]))
    door_parts.sort()
    var hut: String = "" if hut_door.is_empty() else TileGeometry.door_key(hut_door["cell"], hut_door["side"])
    return "|".join(parts) + "/" + "|".join(door_parts) + "/" + hut

func describe() -> String:
    return "%s at %s, turned %d" % [String(def.get("name", def.get("id", "?"))), str(anchor), rotation]
