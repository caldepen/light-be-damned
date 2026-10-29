class_name TileGeometry
extends RefCounted

## Map-board geometry for room tiles (RULES §8, DATA_SCHEMA "Room tiles"). Squares are
## Vector2i(x, y): x is the column from the left, y the row up from the bottom edge, so N is +y.
## A rotation r (0-3) turns a tile r quarter turns clockwise about its anchor cell [0, 0].

const SIDES: Array[String] = ["N", "E", "S", "W"]
const OFFSETS: Dictionary = {
    "N": Vector2i(0, 1),
    "E": Vector2i(1, 0),
    "S": Vector2i(0, -1),
    "W": Vector2i(-1, 0),
}

static func is_side(side: String) -> bool:
    return OFFSETS.has(side)

static func offset(side: String) -> Vector2i:
    return OFFSETS[side]

static func opposite(side: String) -> String:
    return SIDES[(SIDES.find(side) + 2) % 4]

## One quarter turn clockwise with y up is (x, y) -> (y, -x); `rotation` quarter turns in all.
static func rotate_cell(cell: Vector2i, rotation: int) -> Vector2i:
    var c: Vector2i = cell
    for i in range(posmod(rotation, 4)):
        c = Vector2i(c.y, -c.x)
    return c

static func rotate_side(side: String, rotation: int) -> String:
    return SIDES[(SIDES.find(side) + posmod(rotation, 4)) % 4]

## The square a doorway on `cell`'s `side` opens onto.
static func facing_cell(cell: Vector2i, side: String) -> Vector2i:
    return cell + offset(side)

static func cells_from_data(raw: Array) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for c in raw:
        cells.append(Vector2i(int(c[0]), int(c[1])))
    return cells
