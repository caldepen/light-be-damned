class_name Field
extends RefCounted

## The two 3x3 battle boards as one 6x3 grid seen from above (RULES §5, Lanes).
## A cell is Vector2i(lane, y). Lane 0 is the players' left on both boards.
## y 0..2 is the enemy board (0 = enemy back row, 2 = enemy front row);
## y 3..5 is the hero board (3 = hero front row, 5 = hero back row).
## Reach is Chebyshev distance 1; movement is straight (orthogonal) unless a card says otherwise.

const LANES := 3
const HEIGHT := 6
const ENEMY_FRONT_Y := 2
const HERO_FRONT_Y := 3
const STRAIGHT_DIRECTIONS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]

var _occupants: Dictionary = {}  # Vector2i -> FigureState

## Cell for a [row, lane] position on one side's own board (row 0 = front).
static func cell_for(side: String, row: int, lane: int) -> Vector2i:
    if side == FigureState.SIDE_HEROES:
        return Vector2i(lane, HERO_FRONT_Y + row)
    return Vector2i(lane, ENEMY_FRONT_Y - row)

static func board_of(cell: Vector2i) -> String:
    return FigureState.SIDE_HEROES if cell.y >= HERO_FRONT_Y else FigureState.SIDE_ENEMIES

## Row on the board the cell belongs to (0 = that board's front row).
static func row_of(cell: Vector2i) -> int:
    if cell.y >= HERO_FRONT_Y:
        return cell.y - HERO_FRONT_Y
    return ENEMY_FRONT_Y - cell.y

## How far a figure of `side` is from the front line: 0 = its own front row,
## negative = standing on the other side's board.
static func depth_for(side: String, cell: Vector2i) -> int:
    if side == FigureState.SIDE_HEROES:
        return cell.y - HERO_FRONT_Y
    return ENEMY_FRONT_Y - cell.y

static func in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.x < LANES and cell.y >= 0 and cell.y < HEIGHT

static func distance(a: Vector2i, b: Vector2i) -> int:
    return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func cells_distance(a: Array[Vector2i], b: Array[Vector2i]) -> int:
    var best: int = 1000
    for p in a:
        for q in b:
            best = mini(best, distance(p, q))
    return best

static func board_cells(side: String) -> Array[Vector2i]:
    ## Front row first, then left to right.
    var cells: Array[Vector2i] = []
    for row in range(3):
        for lane in range(LANES):
            cells.append(cell_for(side, row, lane))
    return cells

static func all_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for y in range(HEIGHT):
        for lane in range(LANES):
            cells.append(Vector2i(lane, y))
    return cells

static func shifted(cells: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for c in cells:
        result.append(c + offset)
    return result

## Top-left cells of every 2x2 block in the grid (blocks starting at y 2 straddle both front rows).
static func block_corners() -> Array[Vector2i]:
    var corners: Array[Vector2i] = []
    for y in range(HEIGHT - 1):
        for lane in range(LANES - 1):
            corners.append(Vector2i(lane, y))
    return corners

static func block_cells(corner: Vector2i) -> Array[Vector2i]:
    return [corner, corner + Vector2i(1, 0), corner + Vector2i(0, 1), corner + Vector2i(1, 1)]

func figure_at(cell: Vector2i) -> FigureState:
    return _occupants.get(cell, null)

func is_empty(cell: Vector2i, ignore: FigureState = null) -> bool:
    if not in_bounds(cell):
        return false
    var occupant: FigureState = _occupants.get(cell, null)
    return occupant == null or occupant == ignore

func are_empty(cells: Array[Vector2i], ignore: FigureState = null) -> bool:
    for c in cells:
        if not is_empty(c, ignore):
            return false
    return true

func place(figure: FigureState, cells: Array[Vector2i]) -> void:
    remove(figure)
    figure.cells = cells.duplicate()
    for c in cells:
        _occupants[c] = figure

func remove(figure: FigureState) -> void:
    for c in figure.cells:
        if _occupants.get(c, null) == figure:
            _occupants.erase(c)
    figure.cells = []

func empty_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for c in cells:
        if is_empty(c):
            result.append(c)
    return result

## Empty cells one straight step from a single-square figure.
func straight_steps(from_cell: Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for d in STRAIGHT_DIRECTIONS:
        if is_empty(from_cell + d):
            result.append(from_cell + d)
    return result

## Cells reachable in 1..max_steps straight steps through empty squares (breadth first).
func cells_within_steps(from_cell: Vector2i, max_steps: int) -> Array[Vector2i]:
    var seen: Dictionary = {from_cell: 0}
    var frontier: Array[Vector2i] = [from_cell]
    var result: Array[Vector2i] = []
    for step in range(max_steps):
        var next: Array[Vector2i] = []
        for c in frontier:
            for n in straight_steps(c):
                if not seen.has(n):
                    seen[n] = step + 1
                    next.append(n)
                    result.append(n)
        frontier = next
    return result
