class_name PlacedTile
extends RefCounted

## A room tile on the map (RULES §8 The map): where it lies in map squares, its doorways, the
## doors the Hut made for it (break-through, Workshop, Inner Study) and its cosmetic features.

var uid: int = 0
var tile_id: String = ""
var def: Dictionary = {}
var room_type: String = ""
var moon: bool = false
var anchor: Vector2i = Vector2i.ZERO
var rotation: int = 0
var cells: Array[Vector2i] = []
var doors: Array[Dictionary] = []      # {"cell": Vector2i, "side": String}, map squares
var hut_doors: Array[Dictionary] = []  # doors the Hut made on this tile, same shape
var features: Array[Dictionary] = []   # {"cell": Vector2i, "id": String}; cosmetic only
var explored: bool = false

func has_cell(cell: Vector2i) -> bool:
    return cells.has(cell)

func is_special() -> bool:
    return not def.has("qty")

## Every way through this tile's edge: its own doorways and the Hut's doors.
func all_doors() -> Array[Dictionary]:
    var result: Array[Dictionary] = doors.duplicate()
    result.append_array(hut_doors)
    return result

func has_door(cell: Vector2i, side: String) -> bool:
    for d in all_doors():
        if d["cell"] == cell and d["side"] == side:
            return true
    return false

func describe() -> String:
    return "%s at %s" % [String(def.get("name", tile_id)), str(anchor)]
