class_name MapDoorway
extends RefCounted

## One doorway of a placed tile, in map squares: the side of `cell` it opens through.

var tile: PlacedTile
var cell: Vector2i
var side: String

func _init(tile_in: PlacedTile, cell_in: Vector2i, side_in: String) -> void:
    tile = tile_in
    cell = cell_in
    side = side_in

## The square this doorway opens onto.
func facing() -> Vector2i:
    return TileGeometry.facing_cell(cell, side)

func key() -> String:
    return TileGeometry.door_key(cell, side)

func describe() -> String:
    return "%s %s doorway of %s" % [str(cell), side, String(tile.def.get("name", tile.tile_id))]
