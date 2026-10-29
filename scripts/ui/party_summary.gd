class_name PartySummary
extends BoxContainer

## A compact line per hero (name, Wounds, armor damaged / slots, Down) shown in the collapsed
## battle strip while exploring. Stacks the heroes vertically in a thin column strip.

func _init() -> void:
    add_theme_constant_override("separation", 6)
    mouse_filter = Control.MOUSE_FILTER_IGNORE

func refresh(heroes: Array[HeroState]) -> void:
    while get_child_count() < heroes.size():
        var label := Label.new()
        label.add_theme_font_size_override("font_size", 12)
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(label)
    for i in range(get_child_count()):
        var label: Label = get_child(i)
        label.visible = i < heroes.size()
        if i < heroes.size():
            label.text = hero_text(heroes[i], vertical)

## "Fighter  W1  A 2/4" in a row strip; name above the numbers in a column strip.
static func hero_text(hero: HeroState, stacked: bool) -> String:
    var numbers: String = "Down" if hero.down else "W%d  A %d/%d" % [hero.wound_count(), hero.armor_slots - hero.armor_damage, hero.armor_slots]
    return ("%s\n%s" if stacked else "%s  %s") % [hero.name, numbers]
