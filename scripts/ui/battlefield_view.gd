class_name BattlefieldView
extends VBoxContainer

## The two battle boards and the Provoke strip, always kept together with the front rows facing:
##   tall: DM board, Provoke strip, player board, top to bottom
##   wide: player board and DM board side by side, the Provoke strip along the top or bottom edge
## Changing the orientation only rearranges these pieces and the squares' direction (BoardOrientation).

const EDGE_TOP := "top"
const EDGE_BOTTOM := "bottom"

var dm_board := BoardView.new(FigureState.SIDE_ENEMIES)
var hero_board := BoardView.new(FigureState.SIDE_HEROES)
var provoke := ProvokeView.new()
var orientation: String = BoardOrientation.TALL
var provoke_edge: String = EDGE_BOTTOM

var _dm_panel: PanelFrame = UiScenes.panel("DM board")
var _hero_panel: PanelFrame = UiScenes.panel("Player board")
var _track := PanelContainer.new()
var _row := HBoxContainer.new()

func _init() -> void:
    add_theme_constant_override("separation", 6)
    _dm_panel.add_content(dm_board, true)
    _hero_panel.add_content(hero_board, true)
    _track.theme_type_variation = &"TableBar"
    _track.add_child(provoke)
    _row.add_theme_constant_override("separation", 8)
    _row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    for panel in [_dm_panel, _hero_panel]:
        (panel as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
    arrange(orientation, provoke_edge)

## Rearrange for `value` (BoardOrientation.TALL / WIDE); `edge` places the Provoke strip when wide.
func arrange(value: String, edge: String = EDGE_BOTTOM) -> void:
    orientation = value
    provoke_edge = edge
    for node in [_dm_panel, _hero_panel, _track, _row]:
        var c := node as Control
        if c.get_parent() != null:
            c.get_parent().remove_child(c)
    var panels: Dictionary = {FigureState.SIDE_ENEMIES: _dm_panel, FigureState.SIDE_HEROES: _hero_panel}
    var order: Array[String] = BoardOrientation.board_order(orientation)
    if orientation == BoardOrientation.WIDE:
        for side in order:
            (panels[side] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
            _row.add_child(panels[side])
        if provoke_edge == EDGE_TOP:
            add_child(_track)
        add_child(_row)
        if provoke_edge != EDGE_TOP:
            add_child(_track)
    else:
        (panels[order[0]] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
        (panels[order[1]] as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
        add_child(panels[order[0]])
        add_child(_track)
        add_child(panels[order[1]])
    dm_board.set_orientation(orientation)
    hero_board.set_orientation(orientation)

func refresh(battle: Battle, request: DecisionRequest) -> void:
    dm_board.refresh(battle, request)
    hero_board.refresh(battle, request)
    provoke.refresh(battle)

func clear_options() -> void:
    dm_board.clear_options()
    hero_board.clear_options()
