class_name RoomContext
extends RefCounted

## What room effects work on: the run, the room being resolved (null for a Hut Whim) and where the
## effects come from. Handlers set `declined` (an optional room the party may come back to) or
## `stopped` (a wipe or the boss: nothing more resolves).

var run: HutRun
var tile: PlacedTile
var source: String = ""
var declined: bool = false
var stopped: bool = false

func _init(run_in: HutRun, tile_in: PlacedTile, source_in: String) -> void:
    run = run_in
    tile = tile_in
    source = source_in
