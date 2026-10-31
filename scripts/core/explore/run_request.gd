class_name RunRequest
extends RefCounted

## A choice the party makes while exploring (CLAUDE.md rule 5). The run lists the legal `options`;
## the provider returns the index of one. Battle choices stay with DecisionRequest.

const DOORWAY := "doorway"              # options: MapDoorway (details.walk: Array[int], tiles to walk per option, 0 for the party's room; details.peeked: tile id or "")
const ROLLER := "roller"                # options: HeroState (who makes a skill roll; details: type, target, purpose)
const ATTEMPT := "attempt"              # options: [false, true] (try a lock: a locked chest)
const RETRY := "retry"                  # options: [false, true] (try a locked chest again)
const SPOT_TRAP := "spot_trap"          # options: [false, true] (spend a Wits roll to spot a hidden trap)
const DISARM := "disarm"                # options: [false, true] (a spotted trap: disarm it, or just avoid it)
const DODGE := "dodge"                  # options: [false, true] (the trap's victim rolls Agility to dodge)
const ACCEPT := "accept"                # options: [false, true] (an optional Whim: The Black Cat)
const WOUND_DISCARD := "wound_discard"  # options: Card (discarded to make room for a Wound outside battle)
const FLIPPER := "flipper"              # options: HeroState (who flips for the campfire check)
const SIGNATURE := "signature"          # options: Dictionary (the wizard's signature, chosen at each campfire)
const ACTION := "action"                # options: String, HutRun.ACT_* (explore, camp, leave)
const CAMPSITE := "campsite"            # options: PlacedTile (where to camp; details.walk: Array[int], tiles to walk per option)

var kind: String = ""
var hero: HeroState = null
var options: Array = []
var details: Dictionary = {}

func _init(request_kind: String, deciding_hero: HeroState, choices: Array, extra: Dictionary = {}) -> void:
    kind = request_kind
    hero = deciding_hero
    options = choices
    details = extra
