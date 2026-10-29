extends GutTest

## Milestone 4.1b: the table layout is saved to a user settings file and restored on launch;
## presets, phase states and bad files behave. Also the divider maths of TableSplit.

const PATH := "user://test_layout.cfg"

func after_each():
    if FileAccess.file_exists(PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func test_defaults_are_the_tall_preset_with_automatic_phases():
    var s: LayoutSettings = LayoutSettings.defaults()
    assert_eq(s.preset, LayoutSettings.PRESET_TALL)
    assert_eq(s.orientation, BoardOrientation.TALL)
    assert_eq(s.hand_dock, LayoutSettings.DOCK_BOTTOM_BOARDS)
    assert_eq(s.phase_mode, LayoutSettings.MODE_AUTOMATIC)
    assert_true(s.hand_auto_open)
    assert_true(s.is_collapsed(LayoutSettings.PHASE_EXPLORING, "battle"), "exploring: boards collapse")
    assert_true(s.is_collapsed(LayoutSettings.PHASE_EXPLORING, "hand"), "exploring: hand collapses")
    assert_false(s.is_collapsed(LayoutSettings.PHASE_BATTLE, "battle"))
    assert_gt(s.split_fraction(LayoutSettings.PHASE_EXPLORING, "map"), s.split_fraction(LayoutSettings.PHASE_BATTLE, "map"),
        "the map takes more room while exploring")

func test_save_and_restore_round_trip():
    var s: LayoutSettings = LayoutSettings.defaults()
    s.apply_preset(LayoutSettings.PRESET_WIDE)
    s.provoke_edge = BattlefieldView.EDGE_TOP
    s.hand_dock = LayoutSettings.DOCK_RIGHT
    s.phase_mode = LayoutSettings.MODE_BOTH
    s.hand_auto_open = false
    s.set_split_fraction(LayoutSettings.PHASE_BATTLE, "map", 0.4)
    s.set_split_fraction(LayoutSettings.PHASE_EXPLORING, "dock", 0.3)
    s.set_collapsed(LayoutSettings.PHASE_BATTLE, "log", true)
    s.set_collapsed(LayoutSettings.PHASE_BATTLE, "side", true)
    assert_eq(s.save(PATH), OK)
    var r: LayoutSettings = LayoutSettings.load_from(PATH)
    assert_eq(r.preset, LayoutSettings.PRESET_WIDE)
    assert_eq(r.orientation, BoardOrientation.WIDE)
    assert_eq(r.provoke_edge, BattlefieldView.EDGE_TOP)
    assert_eq(r.hand_dock, LayoutSettings.DOCK_RIGHT)
    assert_eq(r.phase_mode, LayoutSettings.MODE_BOTH)
    assert_false(r.hand_auto_open)
    assert_almost_eq(r.split_fraction(LayoutSettings.PHASE_BATTLE, "map"), 0.4, 0.0001)
    assert_almost_eq(r.split_fraction(LayoutSettings.PHASE_EXPLORING, "dock"), 0.3, 0.0001)
    assert_true(r.is_collapsed(LayoutSettings.PHASE_BATTLE, "log"))
    assert_true(r.is_collapsed(LayoutSettings.PHASE_BATTLE, "side"))
    assert_false(r.is_collapsed(LayoutSettings.PHASE_EXPLORING, "side"), "phases keep separate states")
    assert_eq(r.to_dict(), s.to_dict())

func test_missing_file_gives_the_defaults():
    var r: LayoutSettings = LayoutSettings.load_from("user://no_such_layout.cfg")
    assert_eq(r.to_dict(), LayoutSettings.defaults().to_dict())

func test_bad_values_fall_back_to_defaults():
    var r: LayoutSettings = LayoutSettings.from_dict({
        "orientation": "sideways", "hand_dock": 3, "phase_mode": "chaos", "preset": "custom",
        "hand_auto_open": "yes", "states": {"battle": {"splits": {"map": 7.0, "side": "x"}, "collapsed": {"map": 1}}},
    })
    var d: LayoutSettings = LayoutSettings.defaults()
    assert_eq(r.orientation, d.orientation)
    assert_eq(r.hand_dock, d.hand_dock)
    assert_eq(r.phase_mode, d.phase_mode)
    assert_eq(r.preset, LayoutSettings.PRESET_TALL, "no saved layout, so not the custom preset")
    assert_true(r.hand_auto_open)
    assert_eq(r.split_fraction(LayoutSettings.PHASE_BATTLE, "map"), LayoutSettings.MAX_FRACTION, "clamped")
    assert_eq(r.split_fraction(LayoutSettings.PHASE_BATTLE, "side"), d.split_fraction(LayoutSettings.PHASE_BATTLE, "side"))
    assert_false(r.is_collapsed(LayoutSettings.PHASE_BATTLE, "map"))

func test_my_layout_is_saved_and_restored_as_a_preset():
    var s: LayoutSettings = LayoutSettings.defaults()
    s.hand_dock = LayoutSettings.DOCK_LEFT
    s.set_split_fraction(LayoutSettings.PHASE_BATTLE, "side", 0.5)
    s.save_custom()
    s.apply_preset(LayoutSettings.PRESET_WIDE)
    assert_eq(s.hand_dock, LayoutSettings.DOCK_BOTTOM_FULL)
    assert_eq(s.save(PATH), OK)
    var r: LayoutSettings = LayoutSettings.load_from(PATH)
    r.apply_preset(LayoutSettings.PRESET_CUSTOM)
    assert_eq(r.preset, LayoutSettings.PRESET_CUSTOM)
    assert_eq(r.hand_dock, LayoutSettings.DOCK_LEFT)
    assert_eq(r.orientation, BoardOrientation.TALL)
    assert_almost_eq(r.split_fraction(LayoutSettings.PHASE_BATTLE, "side"), 0.5, 0.0001)

func test_custom_preset_without_a_saved_layout_changes_nothing():
    var s: LayoutSettings = LayoutSettings.defaults()
    s.apply_preset(LayoutSettings.PRESET_CUSTOM)
    assert_eq(s.preset, LayoutSettings.PRESET_TALL)

func test_manual_mode_shares_one_state_between_phases():
    var s: LayoutSettings = LayoutSettings.defaults()
    s.phase_mode = LayoutSettings.MODE_MANUAL
    s.set_collapsed(LayoutSettings.PHASE_BATTLE, "map", true)
    assert_true(s.is_collapsed(LayoutSettings.PHASE_EXPLORING, "map"), "no change on a phase switch")
    assert_false(s.is_collapsed(LayoutSettings.PHASE_EXPLORING, "battle"))

func test_table_split_keeps_the_first_child_at_its_fraction():
    var split := TableSplit.new("test", false)
    split.size = Vector2(1000, 100)
    var a := Control.new()
    a.custom_minimum_size = Vector2(50, 0)
    var b := Control.new()
    b.custom_minimum_size = Vector2(80, 0)
    split.set_children(a, b)
    add_child_autofree(split)
    split.fraction = 0.3
    split.apply()
    await wait_physics_frames(2)
    assert_almost_eq(a.size.x, 300.0, 1.0, "30% of the width")
    split.squeeze = TableSplit.SQUEEZE_FIRST
    split.apply()
    await wait_physics_frames(2)
    assert_eq(a.size.x, 50.0, "squeezed to its minimum")
    assert_false(split.dragging_enabled, "a squeezed divider is locked")
    split.squeeze = TableSplit.SQUEEZE_SECOND
    split.apply()
    await wait_physics_frames(2)
    assert_eq(b.size.x, 80.0)
