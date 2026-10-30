extends SceneTree

## Headless map runner (Milestone 4.2): builds the Hut from the tile bag with HutExplorer and no
## rooms resolved. The party walks into each new tile; doorways are picked at random (seeded) from
## the party's room, else from any explored room. Usage:
##   godot --headless --path . --script tools/run_map.gd                 # seed 1: event log and map
##   godot --headless --path . --script tools/run_map.gd -- 7            # seed 7
##   godot --headless --path . --script tools/run_map.gd -- --batch 1000 # how often the safety nets fire

const TYPE_CHARS: Dictionary = {
    "front_door": "F", "corridor": "c", "lair": "L", "dark": "?", "vault": "V", "library": "B",
    "shrine": "S", "pantry": "P", "empty": "e", "hearth": "H", "workshop": "W", "inner_study": "I",
}

func _init() -> void:
    var loader := DataLoader.new()
    var data: Dictionary = loader.load_all()
    if data.is_empty():
        printerr("Data did not load:\n  " + "\n  ".join(loader.errors))
        quit(1)
        return
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var module: Dictionary = data["module_witch_hut"]
    if args.size() >= 2 and args[0] == "--batch":
        _batch(module, int(args[1]))
    else:
        var seed_value: int = int(args[0]) if args.size() >= 1 else 1
        var ex: HutExplorer = build(module, seed_value)
        print(ex.log.to_text())
        print("")
        print(render(ex))
    quit(0)

## Explore until the bag is empty or the Hut closes in.
static func build(module: Dictionary, seed_value: int) -> HutExplorer:
    var ex := HutExplorer.new(module, SeededRng.new(seed_value), seed_value)
    var picker := SeededRng.new(seed_value + 100003)
    while true:
        var doors: Array[MapDoorway] = ex.party_doorways()
        if doors.is_empty():
            doors = ex.map.explored_open_doorways()
        if doors.is_empty():
            break
        var result: ExploreResult = ex.explore(doors[picker.next_index(doors.size())])
        if not result.placed():
            break
        ex.enter(result.tile)
    return ex

func _batch(module: Dictionary, runs: int) -> void:
    var stirs: int = 0
    var breaks: int = 0
    var closed: int = 0
    var tiles: int = 0
    var width: int = 0
    var height: int = 0
    for s in range(1, runs + 1):
        var ex: HutExplorer = build(module, s)
        stirs += 1 if ex.log.has_type("tile_set_aside") else 0
        breaks += 1 if ex.log.has_type("break_through") else 0
        closed += 1 if ex.log.has_type("closed_in") else 0
        tiles += ex.map.tiles.size() - 1
        var box: Rect2i = _bounds(ex)
        width += box.size.x
        height += box.size.y
    print("%d maps built from the whole bag (seeds 1-%d), doorways picked at random." % [runs, runs])
    print("Runs with a 'nothing fits' redraw: %.1f%%; a break-through: %.1f%%; closed in: %.1f%%." %
        [100.0 * stirs / runs, 100.0 * breaks / runs, 100.0 * closed / runs])
    print("Tiles placed per run: %.1f. Average map size: %.1f x %.1f squares." % [float(tiles) / runs, float(width) / runs, float(height) / runs])

static func _bounds(ex: HutExplorer) -> Rect2i:
    var box := Rect2i(ex.front_door.cells[0], Vector2i.ONE)
    for t in ex.map.tiles:
        for c in t.cells:
            box = box.expand(c)
    box.size += Vector2i.ONE
    return box

## One character per square, north at the top; the party's room in upper case is the Front Door.
static func render(ex: HutExplorer) -> String:
    var box: Rect2i = _bounds(ex)
    var lines: PackedStringArray = []
    for y in range(box.end.y - 1, box.position.y - 1, -1):
        var row: String = ""
        for x in range(box.position.x, box.end.x):
            var t: PlacedTile = ex.map.tile_at(Vector2i(x, y))
            row += "." if t == null else String(TYPE_CHARS.get(t.room_type, "#"))
        lines.append(row)
    return "\n".join(lines)
