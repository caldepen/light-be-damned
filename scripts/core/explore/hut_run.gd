class_name HutRun
extends RefCounted

## One run in the Witch's Hut (RULES §8, §10): the map (HutExplorer), the party between fights
## (PartyState), the Hut deck, the components, rations, XP and the loot count. It enters and
## resolves rooms through the room effect handlers (a room's printed Whim, its own effects, then
## its type's: a Hut card), the walking checks, camping, the Hut waking at 10 and throwing the
## party out, and the run loop (`play`): explore, camp or walk out, until the party leaves, wipes
## or reaches the boss.
##
## Battles go through `fight_runner` (func(run, encounter, rewards) -> FIGHT_*), by default RunFight:
## the party's own heroes in the run's `formation`, `battle_decisions` choosing for them, `dm_mode`
## running the enemies. Loot is only counted (Milestone 5) and the boss stops the run as "boss
## reached" (Milestone 6). Party choices outside battle go through `decisions`.

const FIGHT_WON := "won"
const FIGHT_WIPE := "wipe"
const FIGHT_WITHDREW := "withdrew"

const ROOM_RESOLVED := "resolved"
const ROOM_REVISITED := "revisited"
const ROOM_BOSS := "boss"
const ROOM_WIPE := "wipe"
const ROOM_EVICTED := "evicted"   # a moon woke the Hut: the new room is never entered (#80)

## What the party does next (RunRequest.ACTION).
const ACT_EXPLORE := "explore"
const ACT_CAMP := "camp"
const ACT_LEAVE := "leave"   # walk out through the Front Door

## How a run ended (`result`).
const RUN_LEFT := "left"
const RUN_WIPE := "wipe"
const RUN_BOSS := "boss reached"
const RUN_STALLED := "stalled"   # the step cap in play(); a safety net for simulations

var data: Dictionary
var rules: Dictionary
var module: Dictionary
var rng: SeededRng
var log: EventLog
var explorer: HutExplorer
var party: PartyState
var decisions: RunDecisionProvider
var hut_deck: HutDeck
var effects := RoomEffectRegistry.new()
var fight_runner: Callable = func(run: HutRun, encounter: String, rewards: bool) -> String: return RunFight.play(run, encounter, rewards)
## Who chooses for the heroes in battle and while patching up (an AI, or the UI's human provider).
var battle_decisions: DecisionProvider = DecisionProvider.new()
var dm_mode: String = Battle.DM_STANDARD
## Where each hero stands at the start of every battle: {hero_id: [row, lane]} (set_formation).
var formation: Dictionary = {}
var last_battle: Battle = null
## Components the party holds: from earlier runs, and `found` this run (lost on a wipe).
var components: Array[String] = []
var found: Array[String] = []
var rations: int = 0
var xp: int = 0
var loot_drawn: int = 0
var keyhole: bool = false
var wiped: bool = false
var boss_reached: bool = false
## The Hut woke and threw the party out: it can only walk out, with walking checks (RULES §10).
var evicted: bool = false
var can_explore: bool = true
var result: String = ""

## `components_at_start`: the components the party holds from earlier runs (a run setting until
## Milestone 5). Holding all of them puts the Inner Study in the bag from the start.
func _init(data_in: Dictionary, seed_value: int, decisions_in: RunDecisionProvider = null, components_at_start: Array = []) -> void:
    data = data_in
    rules = data["rules"]
    module = data["module_witch_hut"]
    rng = SeededRng.new(seed_value)
    log = EventLog.new()
    decisions = decisions_in if decisions_in != null else RunDecisionProvider.new()
    party = PartyState.create(data, rng)
    explorer = HutExplorer.new(module, rng, seed_value, log)
    explorer.hut_listener = _on_hut_track
    explorer.chooser = _choose_placement
    hut_deck = HutDeck.new(module.get("hut_deck", []), rng)
    rations = int(rules.get("run", {}).get("rations", 8))
    formation = rules.get("default_formation", {}).duplicate(true)
    for id in components_at_start:
        components.append(String(id))
    _check_inner_study()

## Set where the heroes stand in battle: every hero on a different square of the hero board.
## Returns "" or why not (nothing changes then).
func set_formation(new_formation: Dictionary) -> String:
    var used: Dictionary = {}
    for h in party.heroes:
        if not new_formation.has(h.hero_id):
            return "%s has no square" % h.name
        var pos: Array = new_formation[h.hero_id]
        if pos.size() != 2 or int(pos[0]) < 0 or int(pos[0]) > 2 or int(pos[1]) < 0 or int(pos[1]) > 2:
            return "%s's square isn't on the hero board" % h.name
        var key: Vector2i = Vector2i(int(pos[0]), int(pos[1]))
        if used.has(key):
            return "%s and %s share a square" % [used[key], h.name]
        used[key] = h.name
    formation = new_formation.duplicate(true)
    log.record("formation", "The party's formation: %s." % _formation_text(), {"formation": formation.duplicate(true)})
    return ""

## Several legal placements for a drawn tile: the party chooses (RunRequest.PLACEMENT, ruling #47).
func _choose_placement(_kind: String, options: Array) -> int:
    return decisions.decide(RunRequest.new(RunRequest.PLACEMENT, null, options, {}), self)

## The party picks one of the rules' formations for the run (RunRequest.FORMATION).
func choose_formation() -> void:
    var presets: Dictionary = rules.get("formations", {})
    var chosen: Variant = ask(RunRequest.FORMATION, null, presets.keys())
    if chosen != null:
        var why: String = set_formation(presets[chosen])
        if not why.is_empty():
            push_error("Formation '%s': %s." % [chosen, why])

func _formation_text() -> String:
    var parts: PackedStringArray = []
    for h in party.heroes:
        var pos: Array = formation[h.hero_id]
        parts.append("%s %s %s" % [h.name, ["front", "middle", "back"][int(pos[0])], ["left", "centre", "right"][int(pos[1])]])
    return ", ".join(parts)

## A fresh seed from the run's stream for each battle, so a run replays exactly from its seed.
func next_seed() -> int:
    return rng.int_range(1, 2147483646)

## Battle events go into the run's log as they happen.
func forward_event(entry: Dictionary) -> void:
    log.record(String(entry["type"]), String(entry["message"]), entry["details"])

# ------------------------------------------------------------------ choices

## Ask the party. A single option is taken without asking; no options gives null.
func ask(kind: String, hero: HeroState, options: Array, details: Dictionary = {}) -> Variant:
    if options.is_empty():
        return null
    if options.size() == 1:
        return options[0]
    var index: int = decisions.decide(RunRequest.new(kind, hero, options, details), self)
    return options[clampi(index, 0, options.size() - 1)]

func ask_yes(kind: String, hero: HeroState, details: Dictionary = {}) -> bool:
    return bool(ask(kind, hero, [false, true], details))

# ------------------------------------------------------------------ the run's counters

func raise_hut(amount: int, reason: String) -> void:
    explorer.raise_hut(amount, reason)

func gain_xp(amount: int, reason: String) -> void:
    xp += amount
    log.record("xp", "The party gains %d XP (%s)." % [amount, reason], {"amount": amount, "total": xp})

func loot(count: int, reason: String) -> void:
    if count <= 0:
        return
    loot_drawn += count
    log.record("loot", "Draw %d loot card%s (%s)." % [count, "" if count == 1 else "s", reason], {"count": count, "total": loot_drawn})

## A battle. `source` says where it came from ("hut card", "guardians", "walking", "campfire", a
## Whim's name) for the reports. A wipe ends the run.
func fight(encounter: String, rewards: bool, source: String = "") -> String:
    log.record("fight", "Fight: %s%s." % [encounter, "" if rewards else " (no loot, no XP)"], {"encounter": encounter, "rewards": rewards, "source": source})
    var outcome: String = String(fight_runner.call(self, encounter, rewards))
    if outcome == FIGHT_WIPE:
        wiped = true
        log.record("wipe", "The party is wiped out.", {})
    return outcome

## Damage outside battle, the party choosing which card each Wound pushes out (RULES §8).
func damage_hero(hero: HeroState, amount: int, reason: String) -> void:
    var was_up: bool = hero.standing
    var armor_before: int = hero.armor_damage
    var wounds: int = party.damage(hero, amount, func(h: HeroState, cards: Array[Card]) -> Card: return ask(RunRequest.WOUND_DISCARD, h, cards))
    log.record("hero_damage", "%s takes %d (%s): armor %d, Wounds %d%s." % [hero.name, amount, reason, hero.armor_damage - armor_before, wounds, " and is Down" if was_up and hero.down else ""],
        {"hero": hero.hero_id, "amount": amount, "wounds": wounds, "down": hero.down})

## Every hero Down outside battle is a wipe (ruling #54).
func check_wipe(ctx: RoomContext) -> void:
    if party.all_down() and not wiped:
        wiped = true
        log.record("wipe", "Every hero is Down: the party is wiped out.", {})
    if wiped and ctx != null:
        ctx.stopped = true

## The hero leading the party (rules leader_order). An unspotted trap springs on the first standing
## hero (ruling #55); with `can_flip`, the first standing hero with cards in their deck, who makes
## the walking check (open question #78).
func leader(can_flip: bool = false) -> HeroState:
    for key in rules.get("leader_order", []):
        var h: HeroState = party.hero(String(key))
        if h != null and h.standing and (not can_flip or not h.deck.is_empty()):
            return h
    return null

# ------------------------------------------------------------------ components

func has_component(id: String) -> bool:
    return components.has(id)

## The party takes a component (RULES §10 Components); the last one puts the Inner Study in the bag.
func gain_component(id: String) -> void:
    if components.has(id):
        return
    components.append(id)
    found.append(id)
    log.record("component", "The party takes the %s (%d of %d)." % [_component_name(id), components.size(), module.get("components", []).size()],
        {"component": id, "held": components.size()})
    _check_inner_study()

func holds_every_component() -> bool:
    for c in module.get("components", []):
        if not components.has(String(c.get("id", ""))):
            return false
    return true

## Exploring opens again if the bag was empty or the Hut had closed in (open question #83).
func _check_inner_study() -> void:
    if not holds_every_component():
        return
    for s in module.get("special_tiles", []):
        if bool(s.get("enters_bag", {}).get("all_components", false)) and explorer.add_special(String(s["id"])) and not evicted:
            can_explore = true

func _component_name(id: String) -> String:
    for c in module.get("components", []):
        if String(c.get("id", "")) == id:
            return String(c.get("name", id))
    return id

# ------------------------------------------------------------------ effects and rooms

func run_effects(ctx: RoomContext, list: Array) -> void:
    for e in list:
        if ctx.stopped or wiped:
            return
        var handler: RoomEffect = effects.handler(String(e.get("op", "")))
        if handler == null:
            push_error("No room effect handler for op '%s'." % e.get("op", ""))
            continue
        handler.resolve(ctx, e)

## The party enters `tile` and, the first time this run, resolves it (RULES §8 Room types): its
## printed Whim, then the tile's own effects (a component room), then its type's (a Hut card; the
## boss). Re-entering never resolves a room again.
func enter_room(tile: PlacedTile) -> String:
    explorer.enter(tile)
    var state: Dictionary = tile.room_state
    if bool(state.get("resolved", false)):
        return ROOM_REVISITED
    state["resolved"] = true
    var room_name: String = String(tile.def.get("name", tile.tile_id))
    var ctx := RoomContext.new(self, tile, room_name)
    var whim: Dictionary = tile.def.get("whim", {})
    if not whim.is_empty():
        log.record("whim", "Hut Whim: %s. %s" % [String(whim.get("name", "?")), String(whim.get("text", ""))], {"whim": String(whim.get("id", "")), "tile": tile.uid})
        ctx.source = String(whim.get("name", "Hut Whim"))
        run_effects(ctx, whim.get("effects", []))
        ctx.source = room_name
    run_effects(ctx, tile.def.get("effects", []))
    run_effects(ctx, module.get("room_types", {}).get(tile.room_type, {}).get("effects", []))
    if wiped:
        return ROOM_WIPE
    return ROOM_BOSS if boss_reached else ROOM_RESOLVED

# ------------------------------------------------------------------ the Hut wakes

## At the top of the track the Hut wakes and throws the party out (RULES §10): no more exploring or
## camping. A room in progress finishes; a tile just placed is never entered (open question #80).
func _on_hut_track(_before: int, after: int) -> void:
    if after >= int(module.get("hut_track", {}).get("evicts_at", 10)) and not evicted:
        evicted = true
        can_explore = false
        log.record("evicted", "The Hut wakes and throws the party out: walk to the Front Door, checking every room on the way.", {})

# ------------------------------------------------------------------ walking and camping

## Walk through explored rooms to `tile` (RULES §8 Walking through the Hut): the shortest way in
## tiles; for each tile entered the leading hero flips, and on a low skill value wandering monsters
## attack in that room before the party goes on. Returns "" (also after a wipe on the way) or why
## the party can't walk there.
func walk(tile: PlacedTile, purpose: String) -> String:
    if tile == explorer.party_tile:
        return ""
    var way: Array[PlacedTile] = explorer.map.route(explorer.party_tile, tile)
    if way.is_empty():
        return "the party can't walk there"
    log.record("walk", "The party walks to the %s (%d room%s)." % [_name(tile), way.size(), "" if way.size() == 1 else "s"],
        {"tile": tile.uid, "tiles": way.size(), "purpose": purpose})
    var walking: Dictionary = rules.get("walking", {})
    for t in way:
        explorer.party_tile = t
        var flipper: HeroState = leader(true)
        if flipper != null:
            _wandering_flip(flipper, int(walking.get("wandering_on_skill_at_most", 1)), String(walking.get("encounter", "wandering")), "walking", t)
        if wiped:
            return ""
    return ""

func is_campsite(tile: PlacedTile) -> bool:
    return bool(tile.def.get("campsite", module.get("room_types", {}).get(tile.room_type, {}).get("campsite", false)))

## Camp in an explored campsite (RULES §8 Camping, rulings #60, #62): walk there (walking checks),
## 1 ration per hero (Down heroes too), Hut +1, the campfire resets everyone, then the
## wandering-monster flip. Returns "" or why the party can't camp there.
func camp(tile: PlacedTile) -> String:
    var camping: Dictionary = rules.get("camping", {})
    if not is_campsite(tile):
        return "not a campsite"
    if not tile.explored:
        return "the party hasn't explored it"
    if evicted:
        return "the Hut has thrown the party out"
    var cost: int = int(camping.get("rations_per_hero", 1)) * party.heroes.size()
    if rations < cost:
        return "not enough rations (%d for %d)" % [rations, cost]
    var walked: String = walk(tile, "campsite")
    if not walked.is_empty():
        return walked
    if wiped:
        return ""
    rations -= cost
    log.record("camp", "The party camps in the %s: %d rations (%d left)." % [_name(tile), cost, rations], {"tile": tile.uid, "rations": rations})
    raise_hut(int(camping.get("hut_track", 1)), "campfire")
    for h in party.heroes:
        party.campfire_reset(h, rng)
        _choose_signature(h)
    log.record("campfire", "The campfire: every hero is fresh again.", {})
    if bool(module.get("room_types", {}).get(tile.room_type, {}).get("wandering_check", true)):
        var flipper: HeroState = ask(RunRequest.FLIPPER, null, party.can_roll(), {"purpose": "campfire"})
        if flipper != null:
            _wandering_flip(flipper, int(camping.get("wandering_on_skill_at_most", 3)), String(camping.get("wandering_encounter", "wandering")), "campfire", tile)
    return ""

func _choose_signature(hero: HeroState) -> void:
    for card in hero.deck + hero.hand:
        for e in card.effects:
            if String(e.get("op", "")) == "signature_choice":
                hero.signature_option = ask(RunRequest.SIGNATURE, hero, e.get("options", []), {})
                return

func _wandering_flip(hero: HeroState, at_most: int, encounter: String, purpose: String, tile: PlacedTile) -> void:
    var card: Card = party.flip(hero)
    var value: int = int(card.def.get("skill", 0))
    var monsters: bool = value <= at_most
    log.record("wandering_check", "%s flips %s (%d) in the %s (%s): %s." % [hero.name, card.name, value, _name(tile), purpose, "wandering monsters!" if monsters else "all quiet"],
        {"hero": hero.hero_id, "value": value, "monsters": monsters, "purpose": purpose, "tile": tile.uid})
    if monsters:
        fight(encounter, false, purpose)

static func _name(tile: PlacedTile) -> String:
    return String(tile.def.get("name", tile.tile_id))

# ------------------------------------------------------------------ one exploration

## Pick a doorway (Keyhole shows the tile first; Crooked Corridor takes the choice away), walk to
## it if it is in another room (walking checks), draw and place, then enter and resolve the new
## room. Returns a ROOM_* status, or the ExploreResult status when no tile was placed.
func explore_step() -> String:
    var peeked: String = ""
    if keyhole:
        keyhole = false
        var entry: Dictionary = explorer.peek()
        peeked = "" if entry.is_empty() else String(entry["def"].get("id", ""))
    var doorway: MapDoorway = null
    if not explorer.crooked:
        var options: Array = []
        var walks: Array = []
        for d in explorer.party_doorways():
            options.append(d)
            walks.append(0)
        for d in explorer.map.explored_open_doorways(explorer.party_tile):
            if d.tile == explorer.party_tile:
                continue
            var way: Array[PlacedTile] = explorer.map.route(explorer.party_tile, d.tile)
            if not way.is_empty():
                options.append(d)
                walks.append(way.size())
        doorway = ask(RunRequest.DOORWAY, null, options, {"walk": walks, "peeked": peeked})
        if doorway != null and doorway.tile != explorer.party_tile:
            var why: String = walk(doorway.tile, "doorway")
            if wiped:
                return ROOM_WIPE
            if not why.is_empty():
                push_error("Walk to an unreachable doorway: %s." % why)
    var explored: ExploreResult = explorer.explore(doorway)
    if not explored.placed():
        can_explore = false
        return explored.status
    if evicted:
        log.record("not_entered", "The party never enters the %s." % _name(explored.tile), {"tile": explored.tile.uid})
        return ROOM_EVICTED
    return enter_room(explored.tile)

# ------------------------------------------------------------------ the run loop

## Play the run from where it stands until the party walks out, wipes or reaches the boss: each
## step the party picks an action (RunRequest.ACTION). `max_steps` stops a simulation that never
## ends (RUN_STALLED). Returns `result`.
func play(max_steps: int = 300) -> String:
    choose_formation()
    log.record("run_start", "== Run (seed %d): %s; components %s ==" % [rng.seed_value, _formation_text(), _components_text(components)], {"seed": rng.seed_value, "components": components.duplicate()})
    var steps: int = 0
    while result.is_empty():
        if wiped:
            _finish(RUN_WIPE)
        elif boss_reached:
            _finish(RUN_BOSS)
        elif steps >= max_steps:
            _finish(RUN_STALLED)
        else:
            steps += 1
            take_action(String(ask(RunRequest.ACTION, null, actions())))
    return result

## What the party can do now. Leaving is always possible, and the only thing once the Hut has
## thrown the party out; exploring until the bag is empty or the Hut closes in (ruling #50);
## camping in an explored campsite with enough rations.
func actions() -> Array:
    var list: Array = []
    if not evicted:
        if can_explore:
            list.append(ACT_EXPLORE)
        if not campsites().is_empty():
            list.append(ACT_CAMP)
    list.append(ACT_LEAVE)
    return list

func take_action(action: String) -> void:
    match action:
        ACT_EXPLORE:
            explore_step()
        ACT_CAMP:
            var sites: Array[PlacedTile] = campsites()
            var walks: Array = sites.map(func(t: PlacedTile) -> int: return explorer.map.route(explorer.party_tile, t).size())
            var site: PlacedTile = ask(RunRequest.CAMPSITE, null, sites, {"walk": walks})
            var why: String = camp(site)
            if not why.is_empty():
                log.record("cant_camp", "The party can't camp there: %s." % why, {"tile": site.uid})
        ACT_LEAVE:
            leave()

## Explored campsites the party can walk to and afford to camp in.
func campsites() -> Array[PlacedTile]:
    var result_list: Array[PlacedTile] = []
    var cost: int = int(rules.get("camping", {}).get("rations_per_hero", 1)) * party.heroes.size()
    if rations < cost or evicted:
        return result_list
    for t in explorer.map.tiles:
        if t.explored and is_campsite(t) and (t == explorer.party_tile or not explorer.map.route(explorer.party_tile, t).is_empty()):
            result_list.append(t)
    return result_list

## Walk back to the Front Door and out (RULES §8 Leaving, §9): free, unless the Hut has thrown the
## party out, when every tile on the way gets a walking check. The run ends well and the party
## gains its walking-out XP.
func leave() -> void:
    var why: String = walk(explorer.front_door, "evicted") if evicted else explorer.walk_to(explorer.front_door)
    if wiped:
        return
    if not why.is_empty():
        log.record("cant_leave", "The party can't reach the Front Door: %s." % why, {})
        return
    log.record("leave", "The party walks out through the Front Door.", {})
    gain_xp(int(rules.get("run", {}).get("xp_for_walking_out", 2)), "walked out")
    _finish(RUN_LEFT)

## Components the party holds after the run: those found this run are lost on a wipe.
func components_after() -> Array[String]:
    var kept: Array[String] = []
    for id in components:
        if result != RUN_WIPE or not found.has(id):
            kept.append(id)
    return kept

func _components_text(ids: Array[String]) -> String:
    return "none" if ids.is_empty() else ", ".join(PackedStringArray(ids))

func _finish(how: String) -> void:
    result = how
    var kept: String = "kept" if how == RUN_LEFT else ("lost" if how == RUN_WIPE else "not yet counted")
    log.record("run_end", "== Run over: %s. Hut track %d, rations %d, XP %d, loot %d (%s), components found %s, held now %s ==" % [how, explorer.hut_track, rations, xp, loot_drawn, kept, _components_text(found), _components_text(components_after())],
        {"result": how, "hut_track": explorer.hut_track, "rations": rations, "xp": xp, "loot": loot_drawn, "found": found.duplicate(), "components": components_after()})
