class_name LogView
extends RichTextLabel

## The event log as scrolling text, appended as new entries arrive. Round headers are bold and
## each turn's first line is coloured by side.

var _shown: int = 0

func _init() -> void:
    bbcode_enabled = true
    scroll_following = true
    selection_enabled = true

func reset() -> void:
    clear()
    text = ""
    _shown = 0

func refresh(battle: Battle) -> void:
    if battle != null:
        refresh_log(battle.log)

## Append what is new in log (a battle's, or a run's with its battles forwarded into it).
func refresh_log(log: EventLog) -> void:
    var entries: Array[Dictionary] = log.entries
    for i in range(_shown, entries.size()):
        var entry: Dictionary = entries[i]
        var message: String = String(entry["message"])
        if message.is_empty():
            continue
        var safe: String = message.replace("[", "[lb]")
        match String(entry["type"]):
            "round_start", "battle_start", "battle_end", "run_start", "run_end", "enter_room", "fight":
                append_text("\n[b]%s[/b]\n" % safe)
            "turn_start":
                var color: String = "#8cf" if entry["details"].get("side", "") == FigureState.SIDE_HEROES else "#fa8"
                append_text("[color=%s]%s[/color]\n" % [color, safe])
            _:
                append_text("    %s\n" % safe)
    _shown = entries.size()
