class_name EnemyTurn
extends RefCounted

## An enemy's turn (RULES §7): flip Draw cards from its type's deck. ◆ cards take effect (once per
## enemy per battle); the enemy then plays one playable card chosen by morale, a melee card taking
## its free step first (CardRunner.play_enemy_card). With nothing playable it Goes Fish; with only
## melee cards that can reach nobody it Goes Fish too, and steps if that finds nothing better.
## In DM mode it flips extra cards and the DM picks, ignoring morale.

static func take(battle: Battle, enemy: EnemyState) -> void:
    if loses_turn(battle, enemy):
        return
    var deck: EnemyDeck = battle.deck_for(enemy.enemy_type)
    var flipped: Array[Dictionary] = []
    var candidates: Array[Dictionary] = []
    for i in range(enemy.draw_count + battle.dm_extra_flips()):
        var card: Dictionary = _flip(battle, enemy, deck)
        if card.is_empty():
            break
        flipped.append(card)
        if _is_phase(card):
            _apply_phase(battle, enemy, card)
        elif CardRunner.enemy_card_playable(battle, enemy, card):
            candidates.append(card)
    if candidates.is_empty():
        var extra: Dictionary = _flip(battle, enemy, deck)
        if not extra.is_empty():
            flipped.append(extra)
            battle.emit("go_fish", "%s Goes Fish: %s." % [enemy.name, extra.get("name", "?")], {"enemy": enemy.id, "card": extra.get("id", "")})
            if _is_phase(extra):
                _apply_phase(battle, enemy, extra)
            elif CardRunner.enemy_card_playable(battle, enemy, extra) and enemy.standing:
                _play(battle, enemy, extra)
            else:
                battle.emit("turn_lost", "%s can't play anything; its turn is lost." % enemy.name, {"enemy": enemy.id})
    elif enemy.standing and _all_out_of_reach(battle, enemy, candidates):
        _go_fish_for_reach(battle, enemy, deck, flipped, candidates[0])
    elif enemy.standing:
        var chosen: Dictionary = choose_for_dm(battle, enemy, candidates) if battle.has_dm() else choose_by_morale(battle, enemy, candidates)
        _play(battle, enemy, chosen)
    for card in flipped:
        deck.discard(card)

## Every playable card is a melee card with nobody in reach (worth 0; RULES §7 Nothing in reach).
static func _all_out_of_reach(battle: Battle, enemy: EnemyState, candidates: Array[Dictionary]) -> bool:
    for card in candidates:
        if CardRunner.melee_plan(battle, enemy, card) != CardRunner.PLAN_ADVANCE:
            return false
    return true

## Go Fish for something better; failing that, play `fallback` (take the step, the turn ends).
static func _go_fish_for_reach(battle: Battle, enemy: EnemyState, deck: EnemyDeck, flipped: Array[Dictionary], fallback: Dictionary) -> void:
    var extra: Dictionary = _flip(battle, enemy, deck)
    if not extra.is_empty():
        flipped.append(extra)
        battle.emit("go_fish", "%s can reach nobody and Goes Fish: %s." % [enemy.name, extra.get("name", "?")], {"enemy": enemy.id, "card": extra.get("id", "")})
        if _is_phase(extra):
            _apply_phase(battle, enemy, extra)
        elif enemy.standing and CardRunner.enemy_card_playable(battle, enemy, extra) and CardRunner.melee_plan(battle, enemy, extra) != CardRunner.PLAN_ADVANCE:
            _play(battle, enemy, extra)
            return
    if enemy.standing:
        _play(battle, enemy, fallback)

## A Stunned enemy loses this turn and the Stun is used up (RULES §5 Lost turns).
static func loses_turn(battle: Battle, enemy: EnemyState) -> bool:
    if not enemy.stunned:
        return false
    enemy.stunned = false
    battle.emit("skip_turn", "%s is Stunned and loses the turn." % enemy.name, {"enemy": enemy.id, "reason": "stun"})
    return true

## A simulated DM picks by its policy (Battle.dm_policy); add new policies here.
static func choose_for_dm(battle: Battle, enemy: EnemyState, candidates: Array[Dictionary]) -> Dictionary:
    match battle.dm_policy:
        Battle.DM_POLICY_GREEDY:
            return choose_greedy(battle, enemy, candidates)
    push_error("Unknown DM policy '%s'; using greedy." % battle.dm_policy)
    return choose_greedy(battle, enemy, candidates)

## Greedy DM policy: the highest-damage playable card whatever the morale; ties go to the first flipped.
static func choose_greedy(battle: Battle, enemy: EnemyState, candidates: Array[Dictionary]) -> Dictionary:
    var best: Dictionary = candidates[0]
    var best_value: float = CardRunner.enemy_card_value(battle, enemy, best)
    for card in candidates:
        var value: float = CardRunner.enemy_card_value(battle, enemy, card)
        if value > best_value:
            best = card
            best_value = value
    return best

## Bold and Desperate play the highest-damage card, Timid the lowest; ties go to the first flipped.
static func choose_by_morale(battle: Battle, enemy: EnemyState, candidates: Array[Dictionary]) -> Dictionary:
    var timid: bool = enemy.morale() == EnemyState.MORALE_TIMID
    var best: Dictionary = candidates[0]
    var best_value: float = CardRunner.enemy_card_value(battle, enemy, best)
    for card in candidates:
        var value: float = CardRunner.enemy_card_value(battle, enemy, card)
        if (timid and value < best_value) or (not timid and value > best_value):
            best = card
            best_value = value
    return best

static func _play(battle: Battle, enemy: EnemyState, card: Dictionary) -> void:
    var chooser: String = "DM" if battle.has_dm() else enemy.morale()
    battle.emit("enemy_card", "%s (%s) plays %s." % [enemy.name, chooser, card.get("name", "?")],
        {"enemy": enemy.id, "card": card.get("id", ""), "name": card.get("name", "?"), "morale": enemy.morale(), "dm": battle.has_dm()})
    CardRunner.play_enemy_card(battle, enemy, card)

static func _flip(battle: Battle, enemy: EnemyState, deck: EnemyDeck) -> Dictionary:
    var card: Dictionary = deck.flip(battle.rng)
    if deck.reshuffled_on_last_flip:
        battle.emit("reshuffle", "The %s deck is reshuffled." % enemy.enemy_type, {"type": enemy.enemy_type})
    if not card.is_empty():
        battle.emit("enemy_flip", "%s flips %s." % [enemy.name, card.get("name", "?")], {"enemy": enemy.id, "card": card.get("id", ""), "name": card.get("name", "?")})
    return card

static func _is_phase(card: Dictionary) -> bool:
    return String(card.get("tag", "")) == "phase"

## A ◆ card takes effect once per enemy per battle; a repeat flip counts as unflipped.
static func _apply_phase(battle: Battle, enemy: EnemyState, card: Dictionary) -> void:
    var card_id: String = String(card.get("id", ""))
    if enemy.used_phase.has(card_id):
        battle.emit("phase_repeat", "%s has already used %s; it counts as unflipped." % [enemy.name, card.get("name", "?")], {"enemy": enemy.id, "card": card_id})
        return
    enemy.used_phase[card_id] = true
    battle.emit("phase", "%s: %s takes effect for the rest of the battle." % [enemy.name, card.get("name", "?")], {"enemy": enemy.id, "card": card_id})
    CardRunner.resolve_enemy_card(battle, enemy, card)
