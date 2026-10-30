class_name ExploreResult
extends RefCounted

## What one exploration did (HutExplorer.explore).

const PLACED := "placed"
const CLOSED_IN := "closed_in"
const EMPTY_BAG := "empty_bag"

var status: String = PLACED
var tile: PlacedTile = null
var stirred: bool = false       # nothing fitted at first: the Hut stirred (+1)
var broke_through: bool = false # placed against a wall with the first set-aside tile
var set_aside: int = 0          # tiles drawn that fitted nowhere

func placed() -> bool:
    return status == PLACED
