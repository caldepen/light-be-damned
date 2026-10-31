class_name ExplorationAi
extends RunDecisionProvider

## The party's exploring choices (Milestone 4.5), behind the same RunDecisionProvider interface a
## human player will use. Heuristics, using only what the party can see at the table (the map, its
## own heroes, and the Hut deck's discards for counting what is left):
## - Next action: rest when worn down, judged against the chance that the next Hut card is a monster
##   (camp if rations allow and the Hut track leaves room to explore afterwards, else walk out);
##   otherwise explore; walk out when nothing is left to explore.
## - Doorways and campsites: the fewest tiles to walk; among doorways, the one with most free space
##   around it.
## - Placements: the one that opens most new doorways, then the closest to the Front Door.
## - Rolls: the hero of the matching Type with most cards in deck. Locked chests, retries, spotting
##   and the Black Cat only while the Hut track has room; disarm Normal traps; dodge with an Agility
##   hero, or when the trap would reach the victim's hand.
## - Formation: `formation_name` if set (the batch runner's --formation), else "default".

const KEEP_GOING_DECK := 8.0
const REST_WOUNDS := 3
## Rest when the party's armor left falls below ARMOR_REST + ARMOR_PER_MONSTER x (chance of a monster).
const ARMOR_REST := 0.2
const ARMOR_PER_MONSTER := 0.3
## Room the Hut track must leave below eviction for each optional risk.
const CAMP_ROOM := 3
const CHEST_ROOM := 3
const SPOT_ROOM := 2
const CAT_ROOM := 4
## Below this much armor left, a hero dodges a trap even at -2.
const DODGE_ARMOR := 3

var formation_name: String = ""

func decide(request: RunRequest, run: HutRun) -> int:
    match request.kind:
        RunRequest.ACTION:
            return _action(request.options, run)
        RunRequest.FORMATION:
            var wanted: String = formation_name if not formation_name.is_empty() else "default"
            return maxi(0, request.options.find(wanted))
        RunRequest.DOORWAY:
            return _doorway(request, run)
        RunRequest.CAMPSITE:
            return _fewest(request.details.get("walk", []))
        RunRequest.PLACEMENT:
            return _placement(request.options, run)
        RunRequest.ROLLER:
            return _best_roller(request.options, String(request.details.get("type", "")))
        RunRequest.ATTEMPT, RunRequest.RETRY:
            return 1 if _has_type(run, "agility") and _room(run) >= CHEST_ROOM else 0
        RunRequest.SPOT_TRAP:
            return 1 if _has_type(run, "wits") and _room(run) >= SPOT_ROOM else 0
        RunRequest.DISARM:
            return 1 if _has_type(run, "agility") and int(request.details.get("target", 9)) <= 4 else 0
        RunRequest.DODGE:
            var victim: HeroState = request.hero
            return 1 if victim != null and (victim.hero_type == "agility" or victim.armor_slots - victim.armor_damage < DODGE_ARMOR) else 0
        RunRequest.ACCEPT:
            return 1 if _room(run) >= CAT_ROOM else 0
        RunRequest.WOUND_DISCARD:
            var best: int = 0
            for i in range(request.options.size()):
                if int((request.options[i] as Card).def.get("skill", 0)) < int((request.options[best] as Card).def.get("skill", 0)):
                    best = i
            return best
    return 0

func _action(options: Array, run: HutRun) -> int:
    var leave: int = options.find(HutRun.ACT_LEAVE)
    if not options.has(HutRun.ACT_EXPLORE):
        return leave
    if needs_rest(run):
        if options.has(HutRun.ACT_CAMP) and _room(run) >= CAMP_ROOM:
            return options.find(HutRun.ACT_CAMP)
        return leave
    return options.find(HutRun.ACT_EXPLORE)

## Worn down: a hero sitting out, a hero with 3 or more Wounds, the fighters' average deck below 8,
## or too little armor left for the chance of a monster behind the next door.
static func needs_rest(run: HutRun) -> bool:
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
    if float(deck) / fighters.size() < KEEP_GOING_DECK:
        return true
    return float(run.party.armor_left()) / maxf(1.0, slots) < ARMOR_REST + ARMOR_PER_MONSTER * monster_chance(run)

## The chance that the next Hut card is a monster, counted from the cards not yet seen.
static func monster_chance(run: HutRun) -> float:
    var unseen: Dictionary = run.hut_deck.unseen()
    var total: int = 0
    var monsters: int = 0
    for c in run.module.get("hut_deck", []):
        var n: int = int(unseen.get(String(c.get("id", "")), 0))
        total += n
        if c.get("effects", []).any(func(e: Dictionary) -> bool: return String(e.get("op", "")) == "fight"):
            monsters += n
    return 0.0 if total == 0 else float(monsters) / total

static func _room(run: HutRun) -> int:
    return int(run.module.get("hut_track", {}).get("evicts_at", 10)) - run.explorer.hut_track

func _doorway(request: RunRequest, run: HutRun) -> int:
    var walks: Array = request.details.get("walk", [])
    var best: int = 0
    var best_key: Vector2 = Vector2(INF, 0)
    for i in range(request.options.size()):
        var d: MapDoorway = request.options[i]
        var key := Vector2(int(walks[i]) if i < walks.size() else 0, -_space(run.explorer.map, TileGeometry.facing_cell(d.cell, d.side)))
        if key.x < best_key.x or (key.x == best_key.x and key.y < best_key.y):
            best = i
            best_key = key
    return best

## Free squares within 2 steps of `cell`: room for the next tile to fit.
static func _space(map: HutMap, cell: Vector2i) -> int:
    var free: int = 0
    for dx in range(-2, 3):
        for dy in range(-2, 3):
            if absi(dx) + absi(dy) <= 2 and map.is_free(cell + Vector2i(dx, dy)):
                free += 1
    return free

func _placement(options: Array, run: HutRun) -> int:
    var map: HutMap = run.explorer.map
    var best: int = 0
    var best_score: float = -INF
    for i in range(options.size()):
        var p: TilePlacement = options[i]
        var opened: int = 0
        var far: int = 0
        for d in p.doors:
            var beyond: Vector2i = TileGeometry.facing_cell(d["cell"], d["side"])
            if map.is_free(beyond) and not p.cells.has(beyond):
                opened += 1
        for c in p.cells:
            far = maxi(far, absi(c.x) + absi(c.y))
        var score: float = opened * 10.0 - far
        if score > best_score:
            best = i
            best_score = score
    return best

static func _fewest(walks: Array) -> int:
    var best: int = 0
    for i in range(walks.size()):
        if int(walks[i]) < int(walks[best]):
            best = i
    return best

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
