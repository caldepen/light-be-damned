class_name SimpleRunAi
extends RunDecisionProvider

## Plain heuristics for the party's exploring choices, enough to play a run headless. Milestone 4.5
## replaces this with the real exploration AI.
## - Doorways: the party's own room first (no backtrack), in the order offered.
## - Rolls: the hero whose Type matches, else the one with most cards in deck; ties in party order.
## - Locks and retries: try while the party's average deck is 8 or more (ruling #57); retry at most
##   twice, and not once the Hut track reaches 8.
## - Traps: spot, dodge and disarm (Normal traps only) when someone of the right Type can roll.
## - Optional rolls: the Shrine and Strange font when anyone is hurt; the Black Cat below Hut 8.
## - Wound discards: the card with the lowest skill value; flips: the first offered.
## - Next action: the boss once the key and the Inner Study are there; rest when worn down (camp,
##   at the Hearth if possible, or walk out without the rations); otherwise explore; else leave.
##   Worn down: a hero sitting out, a hero with 3 or more Wounds, the fighters' average deck below
##   8, or less than a quarter of the party's armor left ("armor gone means leave").

const KEEP_GOING_DECK := 8.0
const CAT_HUT_LIMIT := 8
const REST_WOUNDS := 3
## Give up on a lock after this many failures, or once the Hut track is this high.
const MAX_LOCK_FAILURES := 3
const RETRY_HUT_LIMIT := 8

func decide(request: RunRequest, run: HutRun) -> int:
    match request.kind:
        RunRequest.ACTION:
            var options: Array = request.options
            if options.has(HutRun.ACT_STUDY):
                return options.find(HutRun.ACT_STUDY)
            if worn_down(run):
                return options.find(HutRun.ACT_CAMP) if options.has(HutRun.ACT_CAMP) else options.find(HutRun.ACT_LEAVE)
            if options.has(HutRun.ACT_EXPLORE):
                return options.find(HutRun.ACT_EXPLORE)
            return options.find(HutRun.ACT_LEAVE)
        RunRequest.CAMPSITE:
            for i in range(request.options.size()):
                if not bool(run.module["room_types"].get((request.options[i] as PlacedTile).room_type, {}).get("wandering_check", true)):
                    return i
            return 0
        RunRequest.DOORWAY:
            var backtrack: Array = request.details.get("backtrack", [])
            for i in range(request.options.size()):
                if i >= backtrack.size() or not bool(backtrack[i]):
                    return i
            return 0
        RunRequest.ROLLER:
            return _best_roller(request.options, String(request.details.get("type", "")))
        RunRequest.ATTEMPT:
            if String(request.details.get("purpose", "")) == "optional":
                return 1 if _anyone_hurt(run) else 0
            return 1 if run.party.average_deck() >= KEEP_GOING_DECK else 0
        RunRequest.RETRY:
            var keep_trying: bool = int(request.details.get("failures", 0)) < MAX_LOCK_FAILURES and run.explorer.hut_track < RETRY_HUT_LIMIT
            return 1 if keep_trying and run.party.average_deck() >= KEEP_GOING_DECK else 0
        RunRequest.SPOT_TRAP:
            return 1 if _has_type(run, "wits") else 0
        RunRequest.DISARM:
            return 1 if _has_type(run, "agility") and int(request.details.get("target", 9)) <= 4 else 0
        RunRequest.DODGE:
            return 1
        RunRequest.ACCEPT:
            return 1 if run.explorer.hut_track < CAT_HUT_LIMIT else 0
        RunRequest.WOUND_DISCARD:
            var best: int = 0
            for i in range(request.options.size()):
                if int((request.options[i] as Card).def.get("skill", 0)) < int((request.options[best] as Card).def.get("skill", 0)):
                    best = i
            return best
    return 0

static func worn_down(run: HutRun) -> bool:
    var fighters: Array[HeroState] = run.party.fighters()
    if fighters.size() < run.party.heroes.size():
        return true
    var deck: int = 0
    var slots: int = 0
    for h in fighters:
        deck += h.deck.size()
        slots += h.armor_slots
        if h.wound_count() >= REST_WOUNDS:
            return true
    return float(deck) / fighters.size() < KEEP_GOING_DECK or run.party.armor_left() * 4 < slots

static func _best_roller(options: Array, type: String) -> int:
    var best: int = 0
    for i in range(options.size()):
        var h: HeroState = options[i]
        var b: HeroState = options[best]
        var hm: bool = h.hero_type == type
        var bm: bool = b.hero_type == type
        if (hm and not bm) or (hm == bm and h.deck.size() > b.deck.size()):
            best = i
    return best

static func _has_type(run: HutRun, type: String) -> bool:
    return run.party.can_roll().any(func(h: HeroState) -> bool: return h.hero_type == type)

static func _anyone_hurt(run: HutRun) -> bool:
    return run.party.heroes.any(func(h: HeroState) -> bool: return h.wound_count() > 0 or h.armor_damage > 0)
