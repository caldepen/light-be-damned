class_name StatusView
extends RichTextLabel

## Round number, DM mode, each hero's piles and Exhausted cards, and each enemy type's deck count.

func _init() -> void:
    bbcode_enabled = true
    fit_content = true
    scroll_active = false

func refresh(battle: Battle) -> void:
    if battle == null:
        text = ""
        return
    var lines: PackedStringArray = []
    lines.append("[b]Round %d[/b]   DM: %s" % [battle.round_number, battle.dm_mode])
    if not battle.result.is_empty():
        lines.append("[b]Result: %s[/b]" % _result_text(battle.result))
    for h in battle.heroes:
        var exhausted: PackedStringArray = []
        for c in h.exhausted:
            exhausted.append(c.name)
        var state: String = "  [color=#e66]Down[/color]" if h.down else ""
        lines.append("[color=#%s]%s[/color]%s: deck %d, discard %d, Provoke %d" % [
            UiText.figure_color(h).lightened(0.3).to_html(false), h.name, state, h.deck.size(), h.discard.size(),
            battle.provoke.value_of(h)])
        lines.append("    Exhausted: %s" % (", ".join(exhausted) if not exhausted.is_empty() else "none"))
    var decks: PackedStringArray = []
    for enemy_type in battle.enemy_decks:
        var deck: EnemyDeck = battle.enemy_decks[enemy_type]
        decks.append("%s %d (discard %d)" % [String(enemy_type).capitalize(), deck.draw_pile.size(), deck.discard_pile.size()])
    lines.append("Enemy decks: " + ", ".join(decks))
    text = "\n".join(lines)

static func _result_text(result: String) -> String:
    match result:
        Battle.RESULT_HEROES:
            return "the heroes win"
        Battle.RESULT_ENEMIES:
            return "the party is defeated"
    return "draw (round cap)"
