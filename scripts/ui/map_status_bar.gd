class_name MapStatusBar
extends PanelContainer

## The strip above the map: the Hut track (0-10, with Whim, special-tile and waking marks), the
## party's rations, and a party armor meter (all heroes' armor and shield slots together) that warns
## when most of it is damaged: "armor gone means leave" (RULES §8 tip). Before a run exists the Hut
## track and rations show a dash.

## The meter warns once more than this share of the party's armor slots is damaged.
const ARMOR_WARNING_SHARE := 0.5

var _hut := HutTrackView.new()
var _rations := Label.new()
var _armor := ArmorMeter.new()
var _warning := Label.new()

func _init() -> void:
    theme_type_variation = &"TableBar"
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    var hut_label := Label.new()
    hut_label.text = "Hut"
    row.add_child(hut_label)
    _hut.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_hut)
    row.add_child(_rations)
    var armor_label := Label.new()
    armor_label.text = "Armor"
    row.add_child(armor_label)
    _armor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(_armor)
    var box := VBoxContainer.new()
    box.add_child(row)
    _warning.add_theme_color_override("font_color", Color(1, 0.6, 0.35))
    _warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _warning.visible = false
    box.add_child(_warning)
    add_child(box)

## `hut` and `rations` are -1 when there is no run (a single battle).
func refresh(hut: int, hut_max: int, marks: Dictionary, rations: int, heroes: Array[HeroState]) -> void:
    _hut.show_track(hut, hut_max, marks)
    _rations.text = "Rations %s" % ("-" if rations < 0 else str(rations))
    var slots: int = 0
    var damaged: int = 0
    for h in heroes:
        slots += h.armor_slots
        damaged += h.armor_damage
    _armor.show_armor(slots, damaged)
    var warn: bool = slots > 0 and float(damaged) > float(slots) * ARMOR_WARNING_SHARE
    _warning.visible = warn
    _warning.text = "%d of %d armor slots damaged. Armor gone means leave: the next fight hits your hand." % [damaged, slots]
    _armor.warning = warn
