extends GutTest

## Milestone 4.1b: each [row, lane] lands on the right screen cell in the Tall and Wide battlefield
## orientations; the front rows always face each other in the middle and lane 0 lines up across
## both boards. Screen cells are (column, row) inside that side's own 3x3 board.

const H := FigureState.SIDE_HEROES
const E := FigureState.SIDE_ENEMIES

func test_tall_player_board_front_row_on_top_lanes_left_to_right():
    for row in range(3):
        for lane in range(3):
            assert_eq(BoardOrientation.screen_cell(H, row, lane, BoardOrientation.TALL), Vector2i(lane, row),
                "hero [%d, %d]" % [row, lane])

func test_tall_dm_board_front_row_at_the_bottom():
    for row in range(3):
        for lane in range(3):
            assert_eq(BoardOrientation.screen_cell(E, row, lane, BoardOrientation.TALL), Vector2i(lane, 2 - row),
                "enemy [%d, %d]" % [row, lane])

func test_wide_player_board_front_column_on_the_right_lanes_top_to_bottom():
    for row in range(3):
        for lane in range(3):
            assert_eq(BoardOrientation.screen_cell(H, row, lane, BoardOrientation.WIDE), Vector2i(2 - row, lane),
                "hero [%d, %d]" % [row, lane])

func test_wide_dm_board_front_column_on_the_left():
    for row in range(3):
        for lane in range(3):
            assert_eq(BoardOrientation.screen_cell(E, row, lane, BoardOrientation.WIDE), Vector2i(row, lane),
                "enemy [%d, %d]" % [row, lane])

func test_a_few_cells_spelled_out():
    # Player back row, lane 3 (the players' right).
    assert_eq(BoardOrientation.screen_cell(H, 2, 2, BoardOrientation.TALL), Vector2i(2, 2), "tall: bottom right")
    assert_eq(BoardOrientation.screen_cell(H, 2, 2, BoardOrientation.WIDE), Vector2i(0, 2), "wide: far left, bottom")
    # DM front row, lane 1.
    assert_eq(BoardOrientation.screen_cell(E, 0, 0, BoardOrientation.TALL), Vector2i(0, 2), "tall: bottom left")
    assert_eq(BoardOrientation.screen_cell(E, 0, 0, BoardOrientation.WIDE), Vector2i(0, 0), "wide: top left")

func test_grid_cells_map_through_their_board():
    for cell in Field.all_cells():
        var side: String = Field.board_of(cell)
        for o in BoardOrientation.ALL:
            assert_eq(BoardOrientation.screen_cell_of(cell, o),
                BoardOrientation.screen_cell(side, Field.row_of(cell), cell.x, o), "%s %s" % [cell, o])

func test_front_rows_face_each_other_and_lanes_line_up():
    # Tall: boards stacked DM over player; the fronts meet at the DM's bottom and the player's top.
    assert_eq(BoardOrientation.board_order(BoardOrientation.TALL), [E, H] as Array[String])
    # Wide: player left, DM right; the fronts meet at the player's right and the DM's left.
    assert_eq(BoardOrientation.board_order(BoardOrientation.WIDE), [H, E] as Array[String])
    for lane in range(3):
        for o in BoardOrientation.ALL:
            var hero_front: Vector2i = BoardOrientation.screen_cell(H, 0, lane, o)
            var enemy_front: Vector2i = BoardOrientation.screen_cell(E, 0, lane, o)
            if o == BoardOrientation.TALL:
                assert_eq(hero_front.x, enemy_front.x, "same column for lane %d" % lane)
                assert_eq([enemy_front.y, hero_front.y], [2, 0])
            else:
                assert_eq(hero_front.y, enemy_front.y, "same row for lane %d" % lane)
                assert_eq([hero_front.x, enemy_front.x], [2, 0])

func test_square_tooltips_name_lanes_not_screen_directions():
    assert_eq(BoardOrientation.square_label(Field.cell_for(H, 0, 1)), "Player board, front row, lane 2")
    assert_eq(BoardOrientation.square_label(Field.cell_for(E, 2, 0)), "DM board, back row, lane 1")

func test_board_view_places_squares_by_orientation():
    var board := BoardView.new(H)
    add_child_autofree(board)
    board.size = Vector2(480, 300)
    var squares: Dictionary = {}
    for child in board.get_children():
        if child is BoardSquare:
            squares[(child as BoardSquare).cell] = child
    var front_left: BoardSquare = squares[Field.cell_for(H, 0, 0)]
    var back_left: BoardSquare = squares[Field.cell_for(H, 2, 0)]
    assert_lt(front_left.position.y, back_left.position.y, "tall: front row above the back row")
    assert_eq(front_left.tooltip_text, "Player board, front row, lane 1")
    board.set_orientation(BoardOrientation.WIDE)
    assert_gt(front_left.position.x, back_left.position.x, "wide: front column right of the back column")
    assert_almost_eq(front_left.size.x / front_left.size.y, BoardView.ASPECT, 0.01, "squares keep their shape")
