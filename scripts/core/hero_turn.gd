class_name HeroTurn
extends RefCounted

## A hero's turn (RULES §4): draw cards owed, then play a card with a legal effect, flip the top
## of the deck, or pass. A played card is replaced by drawing back up to hand size; a flip draws nothing.

static func take(battle: Battle, hero: HeroState) -> void:
    battle.check_spent(hero)
    if hero.down or loses_turn(battle, hero):
        return
    if hero.owed_draws > 0:
        var owed: int = hero.owed_draws
        hero.owed_draws = 0
        battle.draw_cards(hero, owed, "owed")
    var options: Array = turn_options(battle, hero)
    var choice: TurnOption = battle.ask(DecisionRequest.TURN, hero, options)
    battle.acting_hero = hero
    match choice.kind:
        TurnOption.PLAY:
            hero.hand.erase(choice.card)
            battle.emit("card_played", "%s plays %s." % [hero.name, choice.card.name], {"hero": hero.id, "card": choice.card.id})
            CardRunner.resolve_hero_card(battle, hero, choice.card)
            battle.put_away(hero, choice.card)
            if hero.standing:
                battle.draw_up_to_hand_size(hero)
        TurnOption.FLIP:
            var card: Card = hero.deck.pop_back()
            if CardRunner.is_card_legal(battle, hero, card):
                battle.emit("card_flipped", "%s flips %s and plays it." % [hero.name, card.name], {"hero": hero.id, "card": card.id, "played": true})
                CardRunner.resolve_hero_card(battle, hero, card)
            else:
                battle.emit("card_flipped", "%s flips %s: no legal effect." % [hero.name, card.name], {"hero": hero.id, "card": card.id, "played": false})
            battle.put_away(hero, card)
        TurnOption.PASS:
            battle.emit("pass", "%s passes." % hero.name, {"hero": hero.id})
    # The one Down check for this turn's card: after it resolved and the hand was refilled.
    battle.acting_hero = null
    battle.check_spent(hero)

## A toad or a Stunned hero loses this turn. One lost turn uses up the Stun and one toad turn
## together (RULES §5 Lost turns, Stun and toad together).
static func loses_turn(battle: Battle, hero: HeroState) -> bool:
    var reasons: PackedStringArray = []
    if hero.toad_turns > 0:
        hero.toad_turns -= 1
        reasons.append("a toad")
    if hero.stunned:
        hero.stunned = false
        reasons.append("Stunned")
    if reasons.is_empty():
        return false
    battle.emit("skip_turn", "%s is %s and loses the turn." % [hero.name, " and ".join(reasons)],
        {"hero": hero.id, "reason": "toad" if reasons[0] == "a toad" else "stun", "stun_used": reasons.has("Stunned")})
    return true

## Every legal play from hand, then flip (if the deck has cards), then pass (RULES §5).
static func turn_options(battle: Battle, hero: HeroState) -> Array:
    var options: Array = []
    for card in CardRunner.legal_hand_cards(battle, hero):
        options.append(TurnOption.new(TurnOption.PLAY, card))
    if not hero.deck.is_empty():
        options.append(TurnOption.new(TurnOption.FLIP))
    options.append(TurnOption.new(TurnOption.PASS))
    return options
