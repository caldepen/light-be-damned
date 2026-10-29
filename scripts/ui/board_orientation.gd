class_name BoardOrientation
extends RefCounted

## Where each battle-board square lands on screen. Only the grid's direction changes between the two
## orientations; text, figures and cards stay upright, and the two boards always stay together with
## their front rows facing in the middle. Positions are [row, lane] on a side's own board (row 0 =
## front, lane 0 = the players' left, RULES §5).
##   Tall: DM board above the player board. Rows run up and down, lanes left to right.
##   Wide: player board left, DM board right. Rows run left and right, lanes top to bottom (a party
##         facing right has its left hand at the top).
## Tooltips name lanes ("lane 1-3") and rows, never screen directions.

const TALL := "tall"
const WIDE := "wide"
const ALL: Array[String] = [TALL, WIDE]

const ROW_NAMES: Array[String] = ["front row", "middle row", "back row"]

## Screen cell (column, row) of [row, lane] inside that side's own 3x3 board.
static func screen_cell(side: String, row: int, lane: int, orientation: String) -> Vector2i:
    var heroes: bool = side == FigureState.SIDE_HEROES
    if orientation == WIDE:
        # Front rows face the middle: the player board's front is its right column, the DM's its left.
        return Vector2i(2 - row if heroes else row, lane)
    # Tall: the DM board's front is its bottom row, the player board's its top row.
    return Vector2i(lane, row if heroes else 2 - row)

## Screen cell of a grid cell inside the board it belongs to.
static func screen_cell_of(cell: Vector2i, orientation: String) -> Vector2i:
    return screen_cell(Field.board_of(cell), Field.row_of(cell), cell.x, orientation)

## The two boards in screen order: top to bottom when tall, left to right when wide.
static func board_order(orientation: String) -> Array[String]:
    if orientation == WIDE:
        return [FigureState.SIDE_HEROES, FigureState.SIDE_ENEMIES]
    return [FigureState.SIDE_ENEMIES, FigureState.SIDE_HEROES]

## "Player board, front row, lane 2" for a square's tooltip.
static func square_label(cell: Vector2i) -> String:
    var board: String = "Player board" if Field.board_of(cell) == FigureState.SIDE_HEROES else "DM board"
    return "%s, %s, lane %d" % [board, ROW_NAMES[Field.row_of(cell)], cell.x + 1]
