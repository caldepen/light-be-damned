extends SceneTree

## Dev tool: open the table scene, let the AI play a little, and save screenshots, to check the
## layout at different window sizes (the UI has no automated tests). Needs a real window, so run
## the editor exe without --headless:
##   Godot_v4.7.2-stable_win64.exe --path . --script tools/screenshot_table.gd -- OUT_PREFIX [options] [WIDTHxHEIGHT ...]
## Options: --preset tall|wide (layout preset), --phase exploring (the exploring layout),
##          --dock bottom_full|bottom_boards|left|right (hand dock).
## Writes OUT_PREFIX_<size>_start.png (the first decision) and OUT_PREFIX_<size>_mid.png (a few
## turns in) for each size; default size 1600x940. Uses its own layout file, never the player's.

const SETTLE_SECONDS := 1.0
const PLAY_SECONDS := 0.7
const LAYOUT_PATH := "user://layout_screenshot.cfg"

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var prefix: String = args[0] if args.size() > 0 else "user://table"
    var preset: String = LayoutSettings.PRESET_TALL
    var phase: String = LayoutSettings.PHASE_BATTLE
    var dock: String = ""
    var sizes: Array[Vector2i] = []
    var i: int = 1
    while i < args.size():
        match args[i]:
            "--preset":
                preset = args[i + 1]
                i += 1
            "--phase":
                phase = args[i + 1]
                i += 1
            "--dock":
                dock = args[i + 1]
                i += 1
            _:
                var parts: PackedStringArray = args[i].split("x")
                sizes.append(Vector2i(int(parts[0]), int(parts[1])))
        i += 1
    if sizes.is_empty():
        sizes.append(Vector2i(1600, 940))
    for window_size in sizes:
        DisplayServer.window_set_size(window_size)
        DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT_PATH))
        var table: TableScreen = load("res://scenes/table.tscn").instantiate()
        table.layout_path = LAYOUT_PATH
        root.add_child(table)
        table.apply_preset(preset)
        if not dock.is_empty():
            table._on_layout_chosen(LayoutMenu.ACTION_DOCK, dock)
        table.set_phase(phase)
        await create_timer(SETTLE_SECONDS).timeout
        _save("%s_%dx%d_start.png" % [prefix, window_size.x, window_size.y])
        table._session.auto_delay_ms = 60
        table._session.set_auto_continue(true)
        table._session.set_ai_heroes(true)
        await create_timer(PLAY_SECONDS).timeout
        table._session.set_ai_heroes(false)
        await create_timer(0.5).timeout
        _save("%s_%dx%d_mid.png" % [prefix, window_size.x, window_size.y])
        table._session.abort()
        table.queue_free()
        await process_frame
    quit()

func _save(path: String) -> void:
    var image: Image = root.get_texture().get_image()
    image.save_png(path)
    print("saved ", path)
