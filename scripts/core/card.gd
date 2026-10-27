class_name Card
extends RefCounted

## One physical hero card, or a Wound. `def` is the card object from heroes.json.

const WOUND_ID := "wound"

var uid: int = 0
var def: Dictionary = {}

var id: String:
    get:
        return String(def.get("id", ""))

var name: String:
    get:
        return String(def.get("name", id))

var tier: String:
    get:
        return String(def.get("tier", "basic"))

var effects: Array:
    get:
        return def.get("effects", [])

var is_wound: bool:
    get:
        return id == WOUND_ID

func _init(card_uid: int, card_def: Dictionary) -> void:
    uid = card_uid
    def = card_def

static func make_wound(card_uid: int) -> Card:
    return Card.new(card_uid, {"id": WOUND_ID, "name": "Wound", "tier": "wound", "effects": []})

## Top-tier and signature cards always Exhaust (RULES §3); others only if marked.
func exhausts() -> bool:
    return bool(def.get("exhaust", false)) or tier == "top" or tier == "signature"

func _to_string() -> String:
    return name
