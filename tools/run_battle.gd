extends SceneTree

## Headless battle runner: plays seeded battles with AI heroes. Usage (see CLAUDE.md, Commands):
##   godot --headless --path . --script tools/run_battle.gd                       # standard and tough, seed 1, full log
##   godot --headless --path . --script tools/run_battle.gd -- tough 42           # one encounter, one seed, full log
##   godot --headless --path . --script tools/run_battle.gd -- --batch            # 500 seeds per encounter, summary table
## Batch options: --battles N (default 500), --seed S (first seed, default 1), encounter names (default all).
## Either mode takes --dm automated|standard|ruthless (default automated).

const DEFAULT_BATTLES := 500

func _init() -> void:
    var loader := DataLoader.new()
    var data: Dictionary = loader.load_all()
    if data.is_empty():
        printerr("Data did not load:\n  " + "\n  ".join(loader.errors))
        quit(1)
        return
    var options: Dictionary = _parse(OS.get_cmdline_user_args())
    if options.has("error"):
        printerr(options["error"])
        quit(1)
        return
    var encounter_names: Array = options["encounters"]
    if encounter_names.is_empty():
        encounter_names = data["encounters"].keys() if options["batch"] else ["standard", "tough"]
    for encounter_name in encounter_names:
        if not data["encounters"].has(encounter_name):
            printerr("Unknown encounter '%s'. Known: %s" % [encounter_name, ", ".join(PackedStringArray(data["encounters"].keys()))])
            quit(1)
            return
    if options["batch"]:
        _run_batch(data, encounter_names, options)
    else:
        for encounter_name in encounter_names:
            var battle: Battle = _play(data, encounter_name, options["seed"], options["dm"])
            print(battle.log.to_text())
            print("")
    quit(0)

func _run_batch(data: Dictionary, encounter_names: Array, options: Dictionary) -> void:
    var count: int = options["battles"]
    var first_seed: int = options["seed"]
    var dm_label: String = options["dm"]
    if options["dm"] != Battle.DM_AUTOMATED:
        dm_label += " (%s policy)" % Battle.DM_POLICY_GREEDY
    print("%d battles per encounter, seeds %d-%d, DM: %s. Wounds, armor and exhaust are party averages per battle." %
        [count, first_seed, first_seed + count - 1, dm_label])
    print(BatchStats.header())
    for encounter_name in encounter_names:
        var stats := BatchStats.new()
        for i in range(count):
            stats.add(_play(data, encounter_name, first_seed + i, options["dm"]))
        print(stats.row(encounter_name))

func _play(data: Dictionary, encounter_name: String, seed_value: int, dm_mode: String) -> Battle:
    var battle: Battle = BattleSetup.create(data, data["encounters"][encounter_name], seed_value, SimpleAiProvider.new())
    battle.dm_mode = dm_mode
    battle.run()
    return battle

## Flags anywhere; the remaining words are encounter names, except that outside batch mode a
## second word is the seed (the old "tough 42" form).
func _parse(args: PackedStringArray) -> Dictionary:
    var options: Dictionary = {"batch": false, "battles": DEFAULT_BATTLES, "seed": 1, "dm": Battle.DM_AUTOMATED, "encounters": []}
    var words: Array = []
    var i: int = 0
    while i < args.size():
        var arg: String = args[i]
        if arg == "--batch":
            options["batch"] = true
        elif arg in ["--battles", "--seed", "--dm"]:
            if i + 1 >= args.size():
                return {"error": "%s needs a value." % arg}
            i += 1
            var value: String = args[i]
            if arg == "--dm":
                if not value in Battle.DM_MODES:
                    return {"error": "Unknown DM mode '%s'. Known: %s" % [value, ", ".join(PackedStringArray(Battle.DM_MODES))]}
                options["dm"] = value
            elif not value.is_valid_int():
                return {"error": "%s needs a whole number, got '%s'." % [arg, value]}
            else:
                options[arg.trim_prefix("--")] = int(value)
        elif arg.begins_with("--"):
            return {"error": "Unknown option '%s'." % arg}
        else:
            words.append(arg)
        i += 1
    if options["battles"] < 1:
        return {"error": "--battles must be at least 1."}
    if not options["batch"] and words.size() >= 2 and String(words[1]).is_valid_int():
        options["seed"] = int(words[1])
        words.remove_at(1)
    options["encounters"] = words
    return options
