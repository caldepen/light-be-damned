class_name PartyState
extends RefCounted

## The four heroes between battles (RULES §8): hands, decks, discards, Exhausted cards, Wounds and
## armor damage carry from room to room; only the campfire resets them. Damage outside battle is
## not an attack: armor first, then Wounds (discard a non-Wound card for each). A hero whose hand
## holds only Wounds is Down until bandaged, healed by the Shrine or reset at a campfire (ruling #54).

var heroes: Array[HeroState] = []
var rules: Dictionary = {}
var _next_uid: int = 0

## The party in White gear with shuffled decks and fresh hands, from loaded data.
static func create(data: Dictionary, rng: SeededRng) -> PartyState:
    var party := PartyState.new()
    party.rules = data["rules"]
    for key in party.rules["hero_order"]:
        var def: Dictionary = data["heroes"][key]
        var hero := HeroState.new()
        hero.id = String(key)
        hero.hero_id = String(key)
        hero.name = String(def.get("name", key))
        hero.hero_type = String(def.get("type", ""))
        hero.hand_size = int(def.get("hand_size", 5))
        hero.armor_slots = BattleSetup.armor_from_gear(def.get("starting_gear", {}), data["items"])
        for card_def in def.get("deck", []):
            for i in range(int(card_def.get("qty", 1))):
                hero.deck.append(Card.new(party.new_uid(), card_def))
        rng.shuffle(hero.deck)
        party.draw(hero, hero.hand_size)
        for card in hero.deck + hero.hand:
            for e in card.effects:
                if String(e.get("op", "")) == "signature_choice" and hero.signature_option.is_empty():
                    hero.signature_option = e.get("options", [{}])[0]
        party.heroes.append(hero)
    return party

func new_uid() -> int:
    _next_uid += 1
    return _next_uid

func last_uid() -> int:
    return _next_uid

## After a battle: carry on numbering from the battle's last uid.
func continue_uids(after: int) -> void:
    _next_uid = maxi(_next_uid, after)

func hero(hero_id: String) -> HeroState:
    for h in heroes:
        if h.hero_id == hero_id:
            return h
    return null

func standing() -> Array[HeroState]:
    var result: Array[HeroState] = []
    for h in heroes:
        if h.standing:
            result.append(h)
    return result

## Heroes who can make a skill roll: standing, with a card in their deck.
func can_roll() -> Array[HeroState]:
    var result: Array[HeroState] = []
    for h in heroes:
        if h.standing and not h.deck.is_empty():
            result.append(h)
    return result

func all_down() -> bool:
    return standing().is_empty()

## Heroes who fight the next battle: standing, with cards in their deck. The rest sit out: Down
## heroes, and heroes whose deck ran out, until the party camps (RULES §5 Empty deck, §8).
func fighters() -> Array[HeroState]:
    return can_roll()

## Battle effects end with each battle (RULES §8 Battles in a run): squares, Guard, Bleed, Stun,
## statuses, pending bonuses and draws, toad turns. Hands, piles, Wounds, armor and Down stay.
func clear_battle_state(hero_in: HeroState) -> void:
    hero_in.cells = []
    hero_in.guard_tokens = 0
    hero_in.guard_expires_round = -1
    hero_in.bleeds.clear()
    hero_in.stunned = false
    hero_in.statuses.clear()
    hero_in.buffs.clear()
    hero_in.owed_draws = 0
    hero_in.toad_turns = 0

## Average deck size of the standing heroes (the AI's "keep going" measure, ruling #57).
func average_deck() -> float:
    var up: Array[HeroState] = standing()
    if up.is_empty():
        return 0.0
    var total: int = 0
    for h in up:
        total += h.deck.size()
    return float(total) / up.size()

func draw(hero_in: HeroState, count: int) -> int:
    var drawn: int = 0
    for i in range(count):
        if hero_in.deck.is_empty():
            break
        hero_in.hand.append(hero_in.deck.pop_back())
        drawn += 1
    return drawn

## The top card of the deck, spent as in a skill roll: discarded, or Exhausted if ▲ or ★.
func flip(hero_in: HeroState) -> Card:
    if hero_in.deck.is_empty():
        return null
    var card: Card = hero_in.deck.pop_back()
    if card.exhausts():
        hero_in.exhausted.append(card)
    else:
        hero_in.discard.append(card)
    return card

## Damage outside battle: armor first, then each point is a Wound; `discard_choice` picks the
## non-Wound card to discard (func(hero, cards) -> Card). Returns Wounds taken.
func damage(hero_in: HeroState, amount: int, discard_choice: Callable) -> int:
    if hero_in.down or amount <= 0:
        return 0
    var to_armor: int = mini(amount, hero_in.unmarked_armor())
    hero_in.armor_damage += to_armor
    var wounds: int = 0
    for i in range(amount - to_armor):
        if hero_in.down:
            break
        var options: Array[Card] = hero_in.non_wound_cards()
        if not options.is_empty():
            var gone: Card = discard_choice.call(hero_in, options)
            hero_in.hand.erase(gone)
            hero_in.discard.append(gone)
        hero_in.hand.append(Card.make_wound(new_uid()))
        wounds += 1
        if hero_in.is_spent():
            hero_in.down = true
    return wounds

## Remove up to `amount` Wounds, drawing a replacement for each while below hand size. A Down hero
## whose hand is no longer only Wounds gets up.
func heal_wounds(hero_in: HeroState, amount: int) -> int:
    var healed: int = 0
    for i in range(amount):
        var wound: Card = null
        for c in hero_in.hand:
            if c.is_wound:
                wound = c
                break
        if wound == null:
            break
        hero_in.hand.erase(wound)
        healed += 1
        if hero_in.hand.size() < hero_in.hand_size:
            draw(hero_in, 1)
    if hero_in.down and not hero_in.is_spent():
        hero_in.down = false
    return healed

func repair_armor(hero_in: HeroState, amount: int) -> int:
    var repaired: int = mini(amount, hero_in.armor_damage)
    hero_in.armor_damage -= repaired
    return repaired

## The campfire (RULES §8 Camping): Wounds and armor damage cleared, discards, Exhausted cards and
## the hand shuffled back into the deck, a fresh hand, Down heroes up, battle leftovers gone.
func campfire_reset(hero_in: HeroState, rng: SeededRng) -> void:
    var cards: Array[Card] = []
    for pile in [hero_in.deck, hero_in.hand, hero_in.discard, hero_in.exhausted]:
        for c in pile:
            if not c.is_wound:
                cards.append(c)
    hero_in.deck = cards
    hero_in.hand = []
    hero_in.discard = []
    hero_in.exhausted = []
    rng.shuffle(hero_in.deck)
    draw(hero_in, hero_in.hand_size)
    hero_in.armor_damage = 0
    hero_in.down = false
    clear_battle_state(hero_in)

## Party armor slots still intact, and in all (the "armor gone means leave" meter).
func armor_left() -> int:
    var n: int = 0
    for h in heroes:
        n += h.unmarked_armor()
    return n
