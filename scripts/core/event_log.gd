class_name EventLog
extends RefCounted

## Structured record of everything that happens in a battle. The UI animates from
## these entries; tests and the headless runner read them.
## Each entry: {"type": String, "message": String, "details": Dictionary}.

var entries: Array[Dictionary] = []
## Called with each new entry as it is recorded, e.g. by the battle scene to pause after a turn.
var listeners: Array[Callable] = []

func record(event_type: String, message: String, details: Dictionary = {}) -> void:
    var entry: Dictionary = {
        "type": event_type,
        "message": message,
        "details": details,
    }
    entries.append(entry)
    for listener in listeners:
        listener.call(entry)

func clear() -> void:
    entries.clear()

func count() -> int:
    return entries.size()

func of_type(event_type: String) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for entry in entries:
        if entry["type"] == event_type:
            result.append(entry)
    return result

func has_type(event_type: String) -> bool:
    for entry in entries:
        if entry["type"] == event_type:
            return true
    return false

## One line per entry; round headers and results are left unindented. Entries without a
## message (turn_end) are markers and print nothing.
func to_text() -> String:
    var lines: PackedStringArray = []
    for entry in entries:
        var event_type: String = entry["type"]
        if String(entry["message"]).is_empty():
            continue
        if event_type == "round_start" or event_type == "battle_end" or event_type == "battle_start":
            lines.append(String(entry["message"]))
        else:
            lines.append("  " + String(entry["message"]))
    return "\n".join(lines)
