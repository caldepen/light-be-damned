class_name UiText
extends RefCounted

## Labels, prompts and colours for the table scene. Read-only helpers; nothing here changes state.

const HERO_COLORS := {
    "fighter": Color(0.75, 0.25, 0.2),
    "cleric": Color(0.8, 0.65, 0.15),
    "thief": Color(0.2, 0.6, 0.3),
    "wizard": Color(0.25, 0.45, 0.8),
}
const ENEMY_COLORS := {
    "goblin": Color(0.45, 0.5, 0.2),
    "ogre": Color(0.5, 0.35, 0.2),
    "skeleton": Color(0.6, 0.6, 0.55),
}
const ENCOUNTERS := [["standard", "5 goblins"], ["tough", "Ogre + 4 goblins"], ["skeleton_band", "5 skeletons"]]

static func figure_color(figure: FigureState) -> Color:
    if figure is HeroState:
        return HERO_COLORS.get((figure as HeroState).hero_id, Color(0.4, 0.4, 0.6))
    return ENEMY_COLORS.get((figure as EnemyState).enemy_type, Color(0.45, 0.4, 0.4))

static func result_text(result: String) -> String:
    match result:
        Battle.RESULT_HEROES:
            return "the heroes win"
        Battle.RESULT_ENEMIES:
            return "the party is defeated"
    return "draw (round cap)"

static func short_name(hero: HeroState) -> String:
    return hero.name.substr(0, 2)

## "Bash (skill 3): Melee: 2 damage" style card text for the hand.
static func card_face(card: Card) -> String:
    if card.is_wound:
        return "Wound\n\nCan't be played"
    var raw_skill: Variant = card.def.get("skill", "-")
    var skill: String = str(int(raw_skill)) if raw_skill is float or raw_skill is int else str(raw_skill)
    var tag: String = ""
    if card.exhausts():
        tag = "  [Exhaust]"
    return "%s\nSkill %s%s\n%s" % [card.name, skill, tag, String(card.def.get("text", ""))]

static func cell_label(cell: Vector2i) -> String:
    var board: String = "hero" if Field.board_of(cell) == FigureState.SIDE_HEROES else "enemy"
    var rows: Array[String] = ["front", "middle", "back"]
    var lanes: Array[String] = ["left", "centre", "right"]
    return "%s %s %s" % [board, rows[Field.row_of(cell)], lanes[cell.x]]

static func row_label(y: int) -> String:
    return cell_label(Vector2i(0, y)).trim_suffix(" left") + " row"

static func option_label(request: DecisionRequest, option: Variant) -> String:
    if option == null:
        return "Stop"
    if option is TurnOption:
        var turn: TurnOption = option
        return "Play %s" % turn.card.name if turn.kind == TurnOption.PLAY else turn.kind.capitalize()
    if option is FigureState:
        return (option as FigureState).name
    if option is Card:
        return (option as Card).name
    if option is Vector2i:
        var cell: Vector2i = option
        if request.kind == DecisionRequest.AREA:
            return "2x2 block from %s" % cell_label(cell)
        if request.hero != null and request.hero.cells.has(cell):
            return "Stay (%s)" % cell_label(cell)
        return cell_label(cell)
    if option is bool:
        return "Yes, move" if option else "No"
    if option is int:
        if request.kind == DecisionRequest.ROW:
            return row_label(option)
        if request.kind == DecisionRequest.CLEANSE_SPLIT:
            return "%d to Wounds, the rest to armor" % option
        return str(option)
    if option is Dictionary:
        var d: Dictionary = option
        if d.has("targets"):
            var names: PackedStringArray = []
            for t in d["targets"]:
                names.append((t as FigureState).name)
            return "%d damage to %s" % [int(d["amount"]), ", ".join(names)]
        if request.kind == DecisionRequest.PATCH_UP:
            return "Done" if d.is_empty() else "%s plays %s" % [(d["hero"] as HeroState).name, (d["card"] as Card).name]
        return String(d.get("name", d.get("id", str(d))))
    if option is Array:
        var names: PackedStringArray = []
        for c in option:
            names.append(String((c as Dictionary).get("name", "?")))
        return " > ".join(names)
    return str(option)

static func prompt(request: DecisionRequest) -> String:
    var who: String = request.hero.name if request.hero != null else "Hero"
    var card_name: String = " for %s" % request.card.name if request.card != null else ""
    match request.kind:
        DecisionRequest.NEXT_HERO:
            return "Hero turn: choose who acts next (click a highlighted hero). Dimmed heroes have acted this round."
        DecisionRequest.TURN:
            return "%s's turn: pick a card and press Play, or Flip or Pass." % who
        DecisionRequest.TARGET:
            var purpose: String = String(request.details.get("purpose", "target"))
            return "%s: choose a target (%s)%s." % [who, purpose, card_name]
        DecisionRequest.FREE_STEP:
            return "%s: choose where to step before attacking%s." % [who, card_name]
        DecisionRequest.MELEE_POSITION:
            return "%s: stay or step for the attack%s." % [who, card_name]
        DecisionRequest.MOVE_SQUARE:
            return "%s: choose a square to move to%s." % [who, card_name]
        DecisionRequest.MOVE_TARGET:
            return "%s: choose an enemy to move into reach of%s." % [who, card_name]
        DecisionRequest.OPTIONAL_MOVE:
            return "%s: move%s?" % [who, card_name]
        DecisionRequest.ROW:
            return "%s: choose a row%s." % [who, card_name]
        DecisionRequest.AREA:
            return "%s: choose a 2x2 block (click its top-left square)%s." % [who, card_name]
        DecisionRequest.DAMAGE_OPTION:
            return "%s: choose how to deal the damage%s." % [who, card_name]
        DecisionRequest.WOUND_DISCARD:
            return "%s takes a Wound: choose a card to discard." % who
        DecisionRequest.FORCED_DISCARD:
            return "%s must discard a card." % who
        DecisionRequest.CLEANSE_SPLIT:
            return "%s: split the cleanse between Wounds and armor%s." % [who, card_name]
        DecisionRequest.RECOVER_CARD:
            return "%s: choose a card to recover%s." % [who, card_name]
        DecisionRequest.PEEK_TYPE:
            return "%s: choose an enemy deck to peek at%s." % [who, card_name]
        DecisionRequest.PEEK_ORDER:
            return "%s: put the peeked cards back in an order (top first)%s." % [who, card_name]
        DecisionRequest.SIGNATURE_OPTION:
            return "%s: choose a signature option%s." % [who, card_name]
        DecisionRequest.PATCH_UP:
            return "Patch up: play a healing, repair or recovery card, or Done."
    return "%s: choose (%s)%s." % [who, request.kind, card_name]

## What happened in the turn that just ended, from its turn_start to its turn_end entry.
static func turn_summary(battle: Battle, end_entry: Dictionary) -> String:
    var figure_id: String = String(end_entry["details"].get("figure", ""))
    var entries: Array[Dictionary] = battle.log.entries
    var start: int = entries.size() - 1
    while start > 0:
        var e: Dictionary = entries[start]
        if e["type"] == "turn_start" and e["details"].get("figure", "") == figure_id:
            break
        start -= 1
    var flipped: PackedStringArray = []
    var played: String = ""
    var lines: PackedStringArray = []
    for i in range(start + 1, entries.size()):
        var e: Dictionary = entries[i]
        match String(e["type"]):
            "enemy_flip":
                flipped.append(String(e["details"].get("name", "?")))
            "enemy_card":
                played = String(e["details"].get("name", "?"))
        if not String(e["message"]).is_empty():
            lines.append(String(e["message"]))
    var head: String = String(entries[start]["message"]) if start >= 0 and not entries.is_empty() else ""
    if not flipped.is_empty():
        head += "  Flipped: %s." % ", ".join(flipped)
        head += "  Played: %s." % played if not played.is_empty() else "  Nothing played."
    return head + "\n" + "\n".join(lines)
