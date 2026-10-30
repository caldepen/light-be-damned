class_name Battle
extends RefCounted

## One battle: the state, the round loop, and every state change (each of which is logged).
## Plain RefCounted, no Nodes; build one with BattleSetup and call run().

const RESULT_HEROES := "heroes"
const RESULT_ENEMIES := "enemies"
const RESULT_DRAW := "draw"

## Who runs the enemies (RULES §7 DM mode): the automated decks, or a DM flipping extra cards.
const DM_AUTOMATED := "automated"
const DM_STANDARD := "standard"
const DM_RUTHLESS := "ruthless"
const DM_MODES: Array[String] = [DM_AUTOMATED, DM_STANDARD, DM_RUTHLESS]
## How a simulated DM picks among its playable cards (EnemyTurn.choose_for_dm).
const DM_POLICY_GREEDY := "greedy"
const DM_POLICIES: Array[String] = [DM_POLICY_GREEDY]

var rules: Dictionary = {}
var enemy_defs: Dictionary = {}
var rng: SeededRng
var log: EventLog
var field: Field
var provoke: ProvokeTrack
var heroes: Array[HeroState] = []
var enemies: Array[EnemyState] = []
var enemy_decks: Dictionary = {}  # enemy type -> EnemyDeck
var decisions: DecisionProvider
var effects: EffectRegistry
var round_number: int = 0
var result: String = ""
var dm_mode: String = DM_AUTOMATED
var dm_policy: String = DM_POLICY_GREEDY
## True while the party patches up after a won battle (PatchUp): no enemies, and cards use their
## between-battles text (Fix Armor).
var between_battles: bool = false

## The hero whose card is resolving; their Down check waits for the end of the card (RULES §6).
var acting_hero: HeroState = null
## The figure whose turn it is (null between turns).
var active_figure: FigureState = null
## Heroes who have acted (or lost their turn) this round, in order; the UI dims them.
var heroes_acted: Array[HeroState] = []
## While a hero card resolves: whose points count for Provoke, and how many have landed or healed
## so far (RULES §6 Provoke per point). Set by CardRunner.resolve_hero_card.
var point_counter: HeroState = null
var points_landed: int = 0

var _next_uid: int = 1
var _name_counts: Dictionary = {}  # enemy type -> how many have been created

func _init(rules_in: Dictionary, enemy_defs_in: Dictionary, seed_in: int, provider: DecisionProvider) -> void:
    rules = rules_in
    enemy_defs = enemy_defs_in
    rng = SeededRng.new(seed_in)
    log = EventLog.new()
    field = Field.new()
    provoke = ProvokeTrack.new()
    decisions = provider
    effects = EffectRegistry.new()

# ------------------------------------------------------------------ events

func emit(event_type: String, message: String, details: Dictionary = {}) -> void:
    details["round"] = round_number
    log.record(event_type, message, details)

# ------------------------------------------------------------------ queries

func standing_heroes() -> Array[HeroState]:
    var result_list: Array[HeroState] = []
    for h in heroes:
        if h.standing:
            result_list.append(h)
    return result_list

func standing_enemies() -> Array[EnemyState]:
    var result_list: Array[EnemyState] = []
    for e in enemies:
        if e.standing:
            result_list.append(e)
    return result_list

func standing_opponents(figure: FigureState) -> Array[FigureState]:
    var result_list: Array[FigureState] = []
    if figure.is_hero():
        for e in standing_enemies():
            result_list.append(e)
    else:
        for h in standing_heroes():
            result_list.append(h)
    return result_list

func top_hero() -> HeroState:
    return provoke.top(standing_heroes())

func in_reach(a: FigureState, b: FigureState) -> bool:
    return Field.cells_distance(a.cells, b.cells) <= 1

func enemies_within_1_of(cells: Array[Vector2i]) -> Array[EnemyState]:
    var result_list: Array[EnemyState] = []
    for e in standing_enemies():
        if Field.cells_distance(cells, e.cells) <= 1:
            result_list.append(e)
    return result_list

func heroes_within_1_of(cells: Array[Vector2i]) -> Array[HeroState]:
    var result_list: Array[HeroState] = []
    for h in standing_heroes():
        if Field.cells_distance(cells, h.cells) <= 1:
            result_list.append(h)
    return result_list

func enemies_in_cells(cells: Array[Vector2i]) -> Array[EnemyState]:
    var result_list: Array[EnemyState] = []
    for e in standing_enemies():
        for c in e.cells:
            if cells.has(c):
                result_list.append(e)
                break
    return result_list

func heroes_in_cells(cells: Array[Vector2i]) -> Array[HeroState]:
    var result_list: Array[HeroState] = []
    for h in standing_heroes():
        if cells.has(h.cells[0]):
            result_list.append(h)
    return result_list

static func row_cells(y: int) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for lane in range(Field.LANES):
        cells.append(Vector2i(lane, y))
    return cells

## Grid y of the enemy board's front row, shifting back when it is empty (RULES §5). -1 if no enemy is on its board.
func enemy_front_row_y() -> int:
    for row in range(3):
        var y: int = Field.ENEMY_FRONT_Y - row
        for e in standing_enemies():
            for c in e.cells:
                if c.y == y:
                    return y
    return -1

## How much damage it takes to put an enemy Down right now.
func toughness(figure: FigureState) -> int:
    if figure is EnemyState:
        var e: EnemyState = figure
        return e.guard_tokens + e.unmarked_armor() + e.unmarked_hd()
    var h: HeroState = figure
    return h.guard_tokens + h.unmarked_armor() + h.non_wound_cards().size()

func deck_for(enemy_type: String) -> EnemyDeck:
    if not enemy_decks.has(enemy_type):
        enemy_decks[enemy_type] = EnemyDeck.new(enemy_type, enemy_defs[enemy_type].get("deck", []), rng)
    return enemy_decks[enemy_type]

func has_dm() -> bool:
    return dm_mode != DM_AUTOMATED

## Cards a DM flips on top of each enemy's Draw (rules.json dm_modes); 0 for the automated decks.
func dm_extra_flips() -> int:
    if not has_dm():
        return 0
    return int(rules.get("dm_modes", {}).get(dm_mode + "_extra_flips", 0))

func new_uid() -> int:
    _next_uid += 1
    return _next_uid

## The last card uid handed out; a battle inside a run continues the party's numbering so Wound
## cards never share a uid with the heroes' cards.
func last_uid() -> int:
    return _next_uid

func continue_uids(after: int) -> void:
    _next_uid = maxi(_next_uid, after)

# ------------------------------------------------------------------ decisions

## Ask the hero's provider to choose among `options`. A single option is taken without asking.
func ask(kind: String, hero: HeroState, options: Array, card: Card = null, details: Dictionary = {}) -> Variant:
    if options.is_empty():
        return null
    if options.size() == 1 and kind != DecisionRequest.TURN:
        return options[0]
    var request := DecisionRequest.new(kind, hero, options, card, details)
    var index: int = decisions.decide(request, self)
    if index < 0 or index >= options.size():
        push_error("Decision provider returned invalid index %d for %s (%d options); using 0." % [index, kind, options.size()])
        index = 0
    return options[index]

# ------------------------------------------------------------------ hero cards and hands

func draw_cards(hero: HeroState, count: int, reason: String) -> int:
    var drawn: int = 0
    for i in range(count):
        if hero.deck.is_empty():
            emit("deck_empty", "%s's deck is empty." % hero.name, {"hero": hero.id})
            break
        hero.hand.append(hero.deck.pop_back())
        drawn += 1
    if drawn > 0:
        emit("draw", "%s draws %d (%s)." % [hero.name, drawn, reason], {"hero": hero.id, "count": drawn, "reason": reason})
    check_spent(hero)
    return drawn

## Draw back up to hand size; no draws while at or above it (RULES §5).
func draw_up_to_hand_size(hero: HeroState) -> int:
    var missing: int = hero.hand_size - hero.hand.size()
    if missing <= 0:
        return 0
    return draw_cards(hero, missing, "refill")

## After playing or flipping: Exhaust ▲/★ cards, discard the rest.
func put_away(hero: HeroState, card: Card) -> void:
    if card.exhausts():
        hero.exhausted.append(card)
        emit("exhaust", "%s exhausts %s." % [hero.name, card.name], {"hero": hero.id, "card": card.id})
    else:
        hero.discard.append(card)

## One Wound into the hand; the hero discards a non-Wound card of their choice if they have one (RULES §6).
## `source` is "damage", or "transfer" for Wounds moved from another hero (Lay on Hands).
func add_wound(hero: HeroState, source: String = "damage") -> void:
    if hero.down:
        return
    var options: Array = hero.non_wound_cards()
    var discarded: Card = null
    if not options.is_empty():
        discarded = ask(DecisionRequest.WOUND_DISCARD, hero, options)
        hero.hand.erase(discarded)
        hero.discard.append(discarded)
    hero.hand.append(Card.make_wound(new_uid()))
    var msg: String = "%s takes a Wound" % hero.name
    if discarded != null:
        msg += " and discards %s" % discarded.name
    emit("wound", msg + ".", {"hero": hero.id, "discarded": discarded.id if discarded != null else "", "wounds": hero.wound_count(), "source": source})
    check_spent(hero)

## A hero with nothing but Wounds in hand, or no cards in hand or deck, goes Down (RULES §6).
## Checked as soon as a Wound lands or a card is drawn, except for the acting hero while their
## card resolves: HeroTurn checks them once the card is done and they've drawn to replace.
func check_spent(hero: HeroState) -> void:
    if hero == acting_hero:
        return
    if hero.standing and hero.is_spent():
        knock_down(hero)

## Remove up to `amount` Wounds; each is replaced by a draw unless the hand is at or above size.
func heal_wounds(hero: HeroState, amount: int, healer: FigureState) -> int:
    var healed: int = 0
    for i in range(amount):
        var wound: Card = null
        for c in hero.hand:
            if c.is_wound:
                wound = c
                break
        if wound == null:
            break
        hero.hand.erase(wound)
        healed += 1
        emit("heal", "%s removes a Wound from %s." % [healer.name, hero.name], {"hero": hero.id, "healer": healer.id})
        if hero.hand.size() < hero.hand_size:
            draw_cards(hero, 1, "healed Wound")
    count_points(healer, healed)
    return healed

func repair_armor(figure: FigureState, amount: int, source: FigureState) -> int:
    var repaired: int = mini(amount, figure.armor_damage)
    if repaired > 0:
        figure.armor_damage -= repaired
        emit("repair", "%s repairs %d armor on %s." % [source.name, repaired, figure.name], {"target": figure.id, "amount": repaired, "source": source.id})
    count_points(source, repaired)
    return repaired

## Damage that landed, Wounds removed or armor repaired by the hero whose card is resolving.
func count_points(source: FigureState, points: int) -> void:
    if source != null and source == point_counter:
        points_landed += points

# ------------------------------------------------------------------ combat state changes

func damage(target: FigureState, amount: int, source: FigureState, is_attack: bool) -> int:
    return DamageResolver.apply(self, target, amount, source, is_attack)

## Guard tokens go on the figure's one Guard card; a card already in play keeps its timing (RULES §6).
func add_guard(figure: FigureState, amount: int, source: FigureState) -> void:
    if amount <= 0 or figure.down:
        return
    if figure.guard_expires_round >= round_number:
        figure.guard_tokens += amount
    else:
        figure.guard_tokens = amount
        figure.guard_expires_round = round_number + 1
    emit("guard", "%s gains Guard %d (now %d)." % [figure.name, amount, figure.guard_tokens],
        {"target": figure.id, "amount": amount, "total": figure.guard_tokens, "source": source.id})

func move_provoke(hero: HeroState, delta: int, reason: String) -> int:
    var change: int = provoke.move(hero, delta)
    emit("provoke", "%s Provoke %+d -> %d (%s)." % [hero.name, change, provoke.value_of(hero), reason],
        {"hero": hero.id, "delta": change, "value": provoke.value_of(hero), "reason": reason})
    return change

func apply_stun(figure: FigureState, source: FigureState) -> void:
    if figure.down:
        return
    figure.stunned = true
    emit("stun", "%s is Stunned." % figure.name, {"target": figure.id, "source": source.id})

func apply_bleed(figure: FigureState, rounds: int, source: FigureState) -> void:
    if figure.down or rounds <= 0:
        return
    figure.bleeds.append(rounds)
    emit("bleed", "%s Bleeds %d." % [figure.name, rounds], {"target": figure.id, "rounds": rounds, "source": source.id})

func move_figure(figure: FigureState, cells: Array[Vector2i], reason: String) -> void:
    var from: Array[Vector2i] = figure.cells.duplicate()
    field.place(figure, cells)
    emit("move", "%s moves %s -> %s (%s)." % [figure.name, str(from), str(cells), reason],
        {"figure": figure.id, "from": from, "to": cells, "reason": reason})

func knock_down(figure: FigureState) -> void:
    if figure.down:
        return
    figure.down = true
    field.remove(figure)
    if figure is EnemyState and (figure as EnemyState).fled:
        emit("flee", "%s flees the battle." % figure.name, {"figure": figure.id})
    else:
        emit("down", "%s is Down." % figure.name, {"figure": figure.id, "side": figure.side})

## Place `count` new enemies of `type` on empty squares of the enemy board, front row first.
func summon(enemy_type: String, count: int, source: FigureState) -> Array[EnemyState]:
    var placed: Array[EnemyState] = []
    for i in range(count):
        var enemy: EnemyState = BattleSetup.make_enemy(self, enemy_type)
        var cells: Array[Vector2i] = BattleSetup.first_free_cells(self, enemy.size)
        if cells.is_empty():
            break
        enemies.append(enemy)
        field.place(enemy, cells)
        placed.append(enemy)
        emit("summon", "%s joins the fight at %s." % [enemy.name, str(cells)], {"figure": enemy.id, "type": enemy_type, "source": source.id, "cells": cells})
    return placed

func make_enemy_name(enemy_type: String) -> String:
    var n: int = int(_name_counts.get(enemy_type, 0)) + 1
    _name_counts[enemy_type] = n
    return "%s %d" % [String(enemy_defs[enemy_type].get("name", enemy_type.capitalize())), n]

# ------------------------------------------------------------------ the round loop

func run() -> String:
    emit("battle_start", "== Battle (seed %d): %s vs %s ==" % [rng.seed_value, _names(heroes), _names(enemies)], {"seed": rng.seed_value})
    var cap: int = int(rules.get("battle", {}).get("round_cap", 30))
    while result.is_empty():
        if round_number >= cap:
            result = RESULT_DRAW
            break
        round_number += 1
        play_round()
    emit("battle_end", "== Result: %s after %d rounds ==" % [result, round_number], {"result": result, "rounds": round_number})
    return result

## Heroes and enemies alternate one figure at a time, starting with a hero (RULES §5). The party
## chooses which hero acts next; enemies act front row first, then left to right, in an order
## fixed at the start of the round. Lost turns (Stun, toad) take no place in the alternation, and
## the side with figures left finishes the round. Extra turns come last, before the end of round.
func play_round() -> void:
    emit("round_start", "-- Round %d --" % round_number, {})
    heroes_acted.clear()
    var hero_pool: Array[FigureState] = sorted_for_turn_order(standing_heroes())
    var enemy_queue: Array[FigureState] = sorted_for_turn_order(standing_enemies())
    var side_to_act: String = FigureState.SIDE_HEROES
    while result.is_empty():
        var heroes_left: Array[HeroState] = _heroes_to_act(hero_pool)
        _drop_lost_enemy_turns(enemy_queue)
        if heroes_left.is_empty() and enemy_queue.is_empty():
            break
        if side_to_act == FigureState.SIDE_HEROES and heroes_left.is_empty():
            side_to_act = FigureState.SIDE_ENEMIES
        elif side_to_act == FigureState.SIDE_ENEMIES and enemy_queue.is_empty():
            side_to_act = FigureState.SIDE_HEROES
        var figure: FigureState = null
        if side_to_act == FigureState.SIDE_HEROES:
            var hero: HeroState = _choose_next_hero(heroes_left)
            hero_pool.erase(hero)
            heroes_acted.append(hero)
            figure = hero
        else:
            figure = enemy_queue.pop_front()
        _take_turn(figure)
        side_to_act = FigureState.SIDE_ENEMIES if side_to_act == FigureState.SIDE_HEROES else FigureState.SIDE_HEROES
    for figure in _extra_turn_figures():
        if not result.is_empty():
            break
        if figure.standing:
            _take_turn(figure)
    if result.is_empty():
        end_round()
        check_end()

func _take_turn(figure: FigureState) -> void:
    active_figure = figure
    emit("turn_start", "%s's turn." % figure.name, {"figure": figure.id, "side": figure.side})
    if figure is HeroState:
        HeroTurn.take(self, figure)
    else:
        EnemyTurn.take(self, figure)
    check_end()
    emit("turn_end", "", {"figure": figure.id, "side": figure.side})
    active_figure = null

## Figures with an extra turn each round (Bone Storm), in the order they gained it (RULES §5).
func _extra_turn_figures() -> Array[FigureState]:
    var result_list: Array[FigureState] = []
    for f in _all_figures():
        if f.statuses.has("extra_turn_each_round"):
            result_list.append(f)
    result_list.sort_custom(func(a: FigureState, b: FigureState) -> bool:
        return int(a.statuses["extra_turn_each_round"].get("gained", 0)) < int(b.statuses["extra_turn_each_round"].get("gained", 0)))
    return result_list

func sorted_for_turn_order(figures: Array) -> Array[FigureState]:
    var result_list: Array[FigureState] = []
    for f in figures:
        result_list.append(f)
    result_list.sort_custom(func(a: FigureState, b: FigureState) -> bool:
        var ca: Vector2i = a.anchor()
        var cb: Vector2i = b.anchor()
        var da: int = Field.depth_for(a.side, ca)
        var db: int = Field.depth_for(b.side, cb)
        if da != db:
            return da < db
        return ca.x < cb.x)
    return result_list

## End of round: Bleed, Lightning Orb, then Guard cards played last round are discarded (RULES §4).
func end_round() -> void:
    for f in _all_figures():
        if f.down or f.bleeds.is_empty():
            continue
        var ticks: int = f.bleeds.size()
        var remaining: Array[int] = []
        for rounds_left in f.bleeds:
            if rounds_left - 1 > 0:
                remaining.append(rounds_left - 1)
        f.bleeds = remaining
        emit("bleed_tick", "%s bleeds for %d." % [f.name, ticks], {"target": f.id, "amount": ticks})
        for i in range(ticks):
            damage(f, 1, null, false)
    for h in standing_heroes():
        if h.statuses.has("lightning_orb"):
            var orb: Dictionary = h.statuses["lightning_orb"]
            var orb_damage: int = int(orb.get("end_of_round_damage", 1))
            for e in enemies_within_1_of(h.cells):
                emit("lightning_orb", "%s's Lightning Orb strikes %s." % [h.name, e.name], {"hero": h.id, "target": e.id})
                damage(e, orb_damage, h, false)
            orb["rounds_left"] = int(orb.get("rounds_left", 1)) - 1
            if int(orb["rounds_left"]) <= 0:
                h.statuses.erase("lightning_orb")
    for f in _all_figures():
        if f.guard_expires_round == round_number:
            if f.guard_tokens > 0:
                emit("guard_expired", "%s's Guard card is discarded (%d tokens lost)." % [f.name, f.guard_tokens], {"target": f.id, "lost": f.guard_tokens})
            f.guard_tokens = 0
            f.guard_expires_round = -1
    emit("round_end", "Round %d ends. %s" % [round_number, status_line()], {})

func check_end() -> void:
    if not result.is_empty():
        return
    if standing_heroes().is_empty():
        result = RESULT_ENEMIES
    elif standing_enemies().is_empty():
        result = RESULT_HEROES

func status_line() -> String:
    var parts: PackedStringArray = []
    for h in heroes:
        if h.down:
            parts.append("%s DOWN" % h.name)
        else:
            parts.append("%s A%d/%d W%d P%d" % [h.name, h.armor_damage, h.armor_slots, h.wound_count(), provoke.value_of(h)])
    for e in enemies:
        if e.standing:
            parts.append("%s Hd%d/%d" % [e.name, e.marked_hd, e.hit_dice])
    return "; ".join(parts)

func _all_figures() -> Array[FigureState]:
    var result_list: Array[FigureState] = []
    for h in heroes:
        result_list.append(h)
    for e in enemies:
        result_list.append(e)
    return result_list

func _drop_fallen(queue: Array[FigureState]) -> void:
    for i in range(queue.size() - 1, -1, -1):
        if queue[i].down:
            queue.remove_at(i)

## Heroes who can still be chosen this round, in the old fixed order (the AI's tie-break). Down
## heroes drop out; a Stunned hero or a toad loses this round's turn and counts as acted (RULES §5).
func _heroes_to_act(pool: Array[FigureState]) -> Array[HeroState]:
    _drop_fallen(pool)
    var eligible: Array[HeroState] = []
    for f in pool.duplicate():
        var h: HeroState = f
        if HeroTurn.loses_turn(self, h):
            pool.erase(h)
            heroes_acted.append(h)
        else:
            eligible.append(h)
    return eligible

## Drop Down enemies, and Stunned ones, who lose this round's turn (RULES §5 Lost turns).
func _drop_lost_enemy_turns(queue: Array[FigureState]) -> void:
    _drop_fallen(queue)
    for f in queue.duplicate():
        if EnemyTurn.loses_turn(self, f as EnemyState):
            queue.erase(f)

## The party picks the next hero to act; a single eligible hero acts without asking.
func _choose_next_hero(eligible: Array[HeroState]) -> HeroState:
    var options: Array = []
    for h in eligible:
        options.append(h)
    var hero: HeroState = ask(DecisionRequest.NEXT_HERO, null, options)
    var left: int = eligible.size() - 1
    var msg: String = "%s acts (the last hero to act this round)." % hero.name
    if left > 0:
        msg = "The party chooses %s (%d hero%s left to act)." % [hero.name, left, "" if left == 1 else "es"]
    emit("hero_chosen", msg, {"hero": hero.id, "left": left, "offered": eligible.size()})
    return hero

func _names(figures: Array) -> String:
    var parts: PackedStringArray = []
    for f in figures:
        parts.append(f.name)
    return ", ".join(parts)
