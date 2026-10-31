extends SceneTree

## Headless map and run runner. Without --rooms it builds the Hut from the tile bag with HutExplorer
## and no rooms resolved (Milestone 4.2): the party walks into each new tile; doorways are picked at
## random (seeded) from the party's room, else from any explored room. With --rooms it plays whole
## runs (see _rooms). Usage:
##   godot --headless --path . --script tools/run_map.gd                 # seed 1: event log and map
##   godot --headless --path . --script tools/run_map.gd -- 7            # seed 7
##   godot --headless --path . --script tools/run_map.gd -- --batch 1000 # how often the safety nets fire
##   godot --headless --path . --script tools/run_map.gd -- --rooms 7    # one whole run, seed 7
##   godot --headless --path . --script tools/run_map.gd -- --rooms --batch 200 --dm standard --components 3

const TYPE_CHARS: Dictionary = {
    "front_door": "F", "corridor": "c", "room": "r", "component": "C", "bedchamber": "b", "inner_study": "I",
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
    elif args.size() >= 1 and args[0] == "--rooms":
        _rooms(data, args)
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

## Whole runs (HutRun.play) with real battles: ExplorationAi (or SimpleRunAi) outside battle, TacticalAiProvider heroes.
##   --rooms [seed]             one run: the event log (battles included), the map, the result
##   --rooms --batch N          N runs (seeds 1-N), a summary
##   options: --dm automated|standard|ruthless (default standard)
##            --components N|all  components held at the start (the first N in the module's
##                        list; all four put the Inner Study in the bag from the start)
##            --run-ai explorer|simple  the party's exploring AI (default ExplorationAi; simple = SimpleRunAi)
##            --formation NAME  a key of rules.json "formations" for every run (default: the AI's choice)
##            --stub      battles are recorded and called won (the 4.3 smoke test)
func _rooms(data: Dictionary, args: PackedStringArray) -> void:
    var options: Dictionary = {"dm": Battle.DM_STANDARD, "components": 0, "stub": false, "batch": 0, "seed": 1, "run_ai": "explorer", "formation": ""}
    var i: int = 1
    while i < args.size():
        match args[i]:
            "--dm":
                i += 1
                options["dm"] = args[i]
            "--components":
                i += 1
                options["components"] = 99 if args[i] == "all" else int(args[i])
            "--batch":
                i += 1
                options["batch"] = int(args[i])
            "--run-ai":
                i += 1
                options["run_ai"] = args[i]
            "--formation":
                i += 1
                options["formation"] = args[i]
            "--stub":
                options["stub"] = true
            _:
                options["seed"] = int(args[i])
        i += 1
    if int(options["batch"]) > 0:
        _rooms_batch(data, options)
        return
    var run: HutRun = play_run(data, int(options["seed"]), options)
    print(run.log.to_text())
    print("")
    print(render(run.explorer))

func _rooms_batch(data: Dictionary, options: Dictionary) -> void:
    var runs: int = int(options["batch"])
    var started: int = Time.get_ticks_msec()
    var results: Dictionary = {}
    var totals: Dictionary = {}
    var keys: Array[String] = ["fight", "enemies_withdraw", "camp", "whim", "skill_roll", "evicted", "patch_up", "bandage", "sits_out", "down"]
    var sums: Dictionary = {"rooms": 0, "xp": 0, "loot": 0, "hut": 0, "rations": 0, "found": 0, "walking_checks": 0, "wandering_fights": 0, "component_fights": 0, "hut_card_fights": 0}
    var stalled: Array[int] = []
    for s in range(1, runs + 1):
        var run: HutRun = play_run(data, s, options)
        results[run.result] = int(results.get(run.result, 0)) + 1
        if run.result == HutRun.RUN_STALLED:
            stalled.append(s)
        for key in keys:
            totals[key] = int(totals.get(key, 0)) + run.log.of_type(key).size()
        for e in run.log.of_type("wandering_check"):
            sums["walking_checks"] += 1 if e["details"]["purpose"] == "walking" else 0
        for e in run.log.of_type("fight"):
            var source: String = String(e["details"].get("source", ""))
            sums["wandering_fights"] += 0 if bool(e["details"]["rewards"]) else 1
            sums["component_fights"] += 1 if source == "guardians" else 0
            sums["hut_card_fights"] += 1 if source == "hut card" else 0
        var rooms: int = 0
        for t in run.explorer.map.tiles:
            rooms += 1 if t.explored and t != run.explorer.front_door else 0
        sums["rooms"] += rooms
        sums["xp"] += run.xp
        sums["loot"] += run.loot_drawn if run.result == HutRun.RUN_LEFT else 0
        sums["hut"] += run.explorer.hut_track
        sums["rations"] += run.rations
        sums["found"] += run.found.size()
    print("%d runs (seeds 1-%d), %s DM, %d components held at the start, formation %s%s, %s run AI + TacticalAiProvider, %.1f s." %
        [runs, runs, options["dm"], mini(int(options["components"]), 4), "AI's choice" if String(options["formation"]).is_empty() else options["formation"],
         ", battles stubbed as won" if options["stub"] else "", options["run_ai"], (Time.get_ticks_msec() - started) / 1000.0])
    var parts: PackedStringArray = []
    for r in results:
        parts.append("%s %.1f%%" % [r, 100.0 * int(results[r]) / runs])
    print("Results: " + ", ".join(parts))
    if not stalled.is_empty():
        print("Stalled (hit the step cap): seeds %s" % str(stalled))
    print("Per run: rooms explored %.1f, XP %.2f, loot kept %.2f, Hut track at the end %.1f, rations left %.1f, components found %.2f." %
        [float(sums["rooms"]) / runs, float(sums["xp"]) / runs, float(sums["loot"]) / runs, float(sums["hut"]) / runs, float(sums["rations"]) / runs, float(sums["found"]) / runs])
    print("Per run: walking checks %.2f, wandering fights %.2f, Hut card fights %.2f, component fights %.2f." %
        [float(sums["walking_checks"]) / runs, float(sums["wandering_fights"]) / runs, float(sums["hut_card_fights"]) / runs, float(sums["component_fights"]) / runs])
    print("Events per run (\"down\" counts heroes and enemies):")
    for key in keys:
        print("  %-18s %.2f" % [key, float(totals[key]) / runs])

static func play_run(data: Dictionary, seed_value: int, options: Dictionary) -> HutRun:
    var held: Array = []
    for c in data["module_witch_hut"]["components"]:
        if held.size() < int(options.get("components", 0)):
            held.append(String(c["id"]))
    var ai: RunDecisionProvider = SimpleRunAi.new() if String(options.get("run_ai", "explorer")) == "simple" else ExplorationAi.new()
    ai.set("formation_name", String(options.get("formation", "")))
    var run := HutRun.new(data, seed_value, ai, held)
    run.battle_decisions = TacticalAiProvider.new()
    run.dm_mode = String(options.get("dm", Battle.DM_STANDARD))
    if bool(options.get("stub", false)):
        run.fight_runner = func(_r: HutRun, _e: String, _rw: bool) -> String: return HutRun.FIGHT_WON
    run.play()
    return run

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
