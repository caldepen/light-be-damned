class_name UiScenes
extends RefCounted

## The reusable table pieces (scenes/components/). Views build themselves from these, so the art
## pass (Milestone 7) can restyle a piece by changing its scene without touching the views.

const PANEL_FRAME := preload("res://scenes/components/panel_frame.tscn")
const BOARD_SQUARE := preload("res://scenes/components/board_square.tscn")
const FIGURE_TOKEN := preload("res://scenes/components/figure_token.tscn")
const CARD_VIEW := preload("res://scenes/components/card_view.tscn")
const DECK_PILE := preload("res://scenes/components/deck_pile.tscn")
const TILE_VIEW := preload("res://scenes/components/tile_view.tscn")
const COLLAPSIBLE_PANEL := preload("res://scenes/components/collapsible_panel.tscn")

static func panel(title: String) -> PanelFrame:
    var p: PanelFrame = PANEL_FRAME.instantiate()
    p.set_title(title)
    return p

## `kind`: CollapsiblePanel.STRIP_COLUMN or STRIP_ROW.
static func collapsible_panel(key: String, title: String, kind: String) -> CollapsiblePanel:
    var p: CollapsiblePanel = COLLAPSIBLE_PANEL.instantiate()
    p.setup(key, title, kind)
    return p

static func board_square() -> BoardSquare:
    return BOARD_SQUARE.instantiate()

static func figure_token() -> FigureToken:
    return FIGURE_TOKEN.instantiate()

static func card_view() -> CardView:
    return CARD_VIEW.instantiate()

static func deck_pile() -> DeckPile:
    return DECK_PILE.instantiate()

static func tile_view() -> TileView:
    return TILE_VIEW.instantiate()
