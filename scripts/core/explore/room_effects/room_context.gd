class_name RoomContext
extends RefCounted

## What room effects work on: the run, the room being resolved and where the effects come from
## (the room's name, a Whim's name, "hut card", "guardians"). Handlers set `stopped` (a wipe or the
## boss: nothing more resolves).

var run: HutRun
var tile: PlacedTile
var source: String = ""
var stopped: bool = false

func _init(run_in: HutRun, tile_in: PlacedTile, source_in: String) -> void:
    run = run_in
    tile = tile_in
    source = source_in
