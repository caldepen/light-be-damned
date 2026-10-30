class_name HutRun
extends RefCounted

## One run in the Witch's Hut, outside battle (RULES §8, §10): the map (HutExplorer), the party
## between fights (PartyState), room decks, Hut Whims, rations, XP and the loot count. It enters
## and resolves rooms through the room effect handlers, runs the Whims at Hut 3, 6 and 9 and the
## Hut waking at 10, camping and the backtracking check, and one exploration step.
##
## Battles go through `fight_runner` (func(run, encounter, rewards) -> FIGHT_*); until Milestone 4.4
## the default records the fight and calls it won. Loot is only counted (Milestone 5) and the boss
## stops the run as "boss reached" (Milestone 6). Party choices go through `decisions`.

const FIGHT_WON := "won"
const FIGHT_WIPE := "wipe"
const FIGHT_WITHDREW := "withdrew"

const ROOM_RESOLVED := "resolved"
const ROOM_REVISITED := "revisited"
const ROOM_DECLINED := "declined"
const ROOM_SHUT := "shut"
const ROOM_BOSS := "boss"
const ROOM_WIPE := "wipe"

var data: Dictionary
var rules: Dictionary
var module: Dictionary
var rng: SeededRng
var log: EventLog
var explorer: HutExplorer
var party: PartyState
var decisions: RunDecisionProvider
var room_decks: RoomDecks
var effects := RoomEffectRegistry.new()
var whims: Array[Dictionary] = []  # the Whim deck; draw() takes the last
var fight_runner: Callable = func(_run: HutRun, _encounter: String, _rewards: bool) -> String: return FIGHT_WON
var rations: int = 0
var xp: int = 0
var loot_drawn: int = 0
var awake: bool = false
var keyhole: bool = false
var wiped: bool = false
var boss_reached: bool = false

func _init(data_in: Dictionary, seed_value: int, decisions_in: RunDecisionProvider = null) -> void:
    data = data_in
    rules = data["rules"]
    module = data["module_witch_hut"]
    rng = SeededRng.new(seed_value)
    log = EventLog.new()
    decisions = decisions_in if decisions_in != null else RunDecisionProvider.new()
    party = PartyState.create(data, rng)
    explorer = HutExplorer.new(module, rng, seed_value, log)
    explorer.hut_listener = _on_hut_track
    room_decks = RoomDecks.new(module.get("room_decks", {}), rng)
    for w in module.get("hut_whims", []):
        whims.append(w)
    rng.shuffle(whims)
    rations = int(rules.get("run", {}).get("rations", 8))

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

## A battle. A wipe ends the run.
func fight(encounter: String, rewards: bool) -> String:
    log.record("fight", "Fight: %s%s." % [encounter, "" if rewards else " (no loot, no XP)"], {"encounter": encounter, "rewards": rewards})
    var result: String = String(fight_runner.call(self, encounter, rewards))
    if result == FIGHT_WIPE:
        wiped = true
        log.record("wipe", "The party is wiped out.", {})
    return result

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

## The hero an unspotted trap springs on (ruling #55).
func leader() -> HeroState:
    for key in rules.get("traps", {}).get("leader_order", []):
        var h: HeroState = party.hero(String(key))
        if h != null and h.standing:
            return h
    return null

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

## The party enters `tile` and resolves it (RULES §8 Room types): the waking Hut's extra Lair card
## first, then the room's card or its own rule. Re-entering never resolves a room again; an
## optional room the party declined can be resolved later; the Inner Study stays shut without
## the Iron Key (the party doesn't go in).
func enter_room(tile: PlacedTile) -> String:
    var room_type: Dictionary = module.get("room_types", {}).get(tile.room_type, {})
    if bool(room_type.get("requires_key", false)) and not explorer.has_key:
        log.record("door_shut", "The %s's iron door stays shut: the party has no key." % String(tile.def.get("name", tile.tile_id)), {"tile": tile.uid})
        return ROOM_SHUT
    explorer.enter(tile)
    var state: Dictionary = tile.room_state
    if bool(state.get("resolved", false)):
        return ROOM_REVISITED
    var ctx := RoomContext.new(self, tile, String(room_type.get("name", tile.room_type)))
    var skips: Array = module.get("hut_track", {}).get("wake_skips_types", [])
    if awake and not skips.has(tile.room_type) and not bool(state.get("wake_fought", false)):
        state["wake_fought"] = true
        log.record("hut_awake_room", "The Hut is awake: a Lair card first.", {"tile": tile.uid})
        run_effects(ctx, [{"op": "draw_room_card", "deck": String(module.get("hut_track", {}).get("wake_extra_deck", "lair"))}])
    if not ctx.stopped and room_type.has("deck"):
        var deck_name: String = String(room_type["deck"])
        var card: Dictionary = room_decks.card(deck_name, String(state["card"])) if state.has("card") else room_decks.draw(deck_name, rng)
        if not card.is_empty():
            log.record("room_card", "%s card: %s." % [deck_name.capitalize(), String(card.get("name", "?"))], {"deck": deck_name, "card": String(card.get("id", "")), "tile": tile.uid})
            run_effects(ctx, card.get("effects", []))
            if ctx.declined:
                state["card"] = String(card.get("id", ""))
            else:
                state.erase("card")
                room_decks.discard(deck_name, card)
    elif not ctx.stopped:
        run_effects(ctx, room_type.get("effects", []))
    if wiped:
        return ROOM_WIPE
    if ctx.declined:
        return ROOM_DECLINED
    state["resolved"] = true
    return ROOM_BOSS if boss_reached else ROOM_RESOLVED

# ------------------------------------------------------------------ the Hut track: Whims and waking

func _on_hut_track(before: int, after: int) -> void:
    var hut: Dictionary = module.get("hut_track", {})
    for at in hut.get("whim_at", []):
        if before < int(at) and after >= int(at) and not wiped:
            resolve_whim()
    var wakes: int = int(hut.get("wakes_at", 10))
    if before < wakes and after >= wakes and not awake:
        awake = true
        log.record("hut_wakes", "The Hut wakes: every room from now on also holds a Lair fight.", {})

## Draw the next Hut Whim (no repeats within a run, ruling #53) and resolve it. Never optional;
## where it picks a tile or doorway, the Hut picks at random among the legal ones (ruling #63).
func resolve_whim() -> void:
    if whims.is_empty():
        log.record("whim_none", "No Hut Whims left this run.", {})
        return
    var whim: Dictionary = whims.pop_back()
    log.record("whim", "Hut Whim: %s. %s" % [String(whim.get("name", "?")), String(whim.get("text", ""))], {"whim": String(whim.get("id", ""))})
    var ctx := RoomContext.new(self, null, String(whim.get("name", "Hut Whim")))
    run_effects(ctx, whim.get("effects", []))

## Put a Whim on top of the Whim deck (tests and scripted runs).
func stack_whim(whim_id: String) -> void:
    for w in module.get("hut_whims", []):
        if String(w.get("id", "")) == whim_id:
            whims.erase(w)
            whims.append(w)

# ------------------------------------------------------------------ camping and backtracking

## Camp in an explored campsite (RULES §8 Camping, rulings #60, #62): walk there (free), 1 ration per
## hero (Down heroes too), Hut +1, the campfire resets everyone, then the wandering-monster flip
## (not at the Hearth). Returns "" or why the party can't camp there.
func camp(tile: PlacedTile) -> String:
    var room_type: Dictionary = module.get("room_types", {}).get(tile.room_type, {})
    var camping: Dictionary = rules.get("camping", {})
    if not bool(room_type.get("campsite", false)):
        return "not a campsite"
    if not tile.explored:
        return "the party hasn't explored it"
    var cost: int = int(camping.get("rations_per_hero", 1)) * party.heroes.size()
    if rations < cost:
        return "not enough rations (%d for %d)" % [rations, cost]
    var walk: String = explorer.walk_to(tile)
    if not walk.is_empty():
        return walk
    rations -= cost
    log.record("camp", "The party camps in the %s: %d rations (%d left)." % [String(tile.def.get("name", tile.tile_id)), cost, rations], {"tile": tile.uid, "rations": rations})
    raise_hut(int(camping.get("hut_track", 1)), "campfire")
    if wiped:
        return ""
    for h in party.heroes:
        party.campfire_reset(h, rng)
        _choose_signature(h)
    log.record("campfire", "The campfire: every hero is fresh again.", {})
    if bool(room_type.get("wandering_check", true)):
        var flipper: HeroState = ask(RunRequest.FLIPPER, null, party.can_roll(), {"purpose": "campfire"})
        if flipper != null:
            _wandering_flip(flipper, int(camping.get("wandering_on_skill_at_most", 3)), String(camping.get("wandering_encounter", "wandering")), "campfire")
    return ""

func _choose_signature(hero: HeroState) -> void:
    for card in hero.deck + hero.hand:
        for e in card.effects:
            if String(e.get("op", "")) == "signature_choice":
                hero.signature_option = ask(RunRequest.SIGNATURE, hero, e.get("options", []), {})
                return

## Backtracking (RULES §8, rulings #46, #59): the hero with the most cards in their deck flips
## (ties: the party chooses); on a low skill value wandering monsters attack (no loot, no XP).
func backtrack_check() -> void:
    var most: int = -1
    var tied: Array[HeroState] = []
    for h in party.can_roll():
        if h.deck.size() > most:
            most = h.deck.size()
            tied.clear()
            tied.append(h)
        elif h.deck.size() == most:
            tied.append(h)
    var flipper: HeroState = ask(RunRequest.FLIPPER, null, tied, {"purpose": "backtrack"})
    if flipper == null:
        return
    var b: Dictionary = rules.get("backtracking", {})
    _wandering_flip(flipper, int(b.get("wandering_on_skill_at_most", 2)), String(b.get("encounter", "wandering")), "backtrack")

func _wandering_flip(hero: HeroState, at_most: int, encounter: String, purpose: String) -> void:
    var card: Card = party.flip(hero)
    var value: int = int(card.def.get("skill", 0))
    var monsters: bool = value <= at_most
    log.record("wandering_check", "%s flips %s (%d) for the %s: %s." % [hero.name, card.name, value, purpose, "wandering monsters!" if monsters else "all quiet"],
        {"hero": hero.hero_id, "value": value, "monsters": monsters, "purpose": purpose})
    if monsters:
        fight(encounter, false)

# ------------------------------------------------------------------ one exploration

## Pick a doorway (Keyhole shows the tile first; Crooked Corridor takes the choice away), pay the
## backtracking check for a doorway outside the party's room, draw and place, then enter and
## resolve the new room. Returns a ROOM_* status, or the ExploreResult status when no tile was placed.
func explore_step() -> String:
    var peeked: String = ""
    if keyhole:
        keyhole = false
        var entry: Dictionary = explorer.peek()
        peeked = "" if entry.is_empty() else String(entry["def"].get("id", ""))
    var doorway: MapDoorway = null
    if not explorer.crooked:
        var options: Array = []
        var backtrack: Array = []
        for d in explorer.party_doorways():
            options.append(d)
            backtrack.append(false)
        for d in explorer.map.explored_open_doorways():
            if d.tile != explorer.party_tile:
                options.append(d)
                backtrack.append(true)
        doorway = ask(RunRequest.DOORWAY, null, options, {"backtrack": backtrack, "peeked": peeked})
        if doorway != null and doorway.tile != explorer.party_tile:
            log.record("backtrack", "The party backtracks to the %s." % doorway.describe(), {"tile": doorway.tile.uid})
            backtrack_check()
            if wiped:
                return ROOM_WIPE
            explorer.walk_to(doorway.tile)
    var result: ExploreResult = explorer.explore(doorway)
    if wiped:
        return ROOM_WIPE
    if not result.placed():
        return result.status
    return enter_room(result.tile)
