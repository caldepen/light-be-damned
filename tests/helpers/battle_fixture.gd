class_name BattleFixture
extends RefCounted

## Builds small hand-made battles for tests: chosen heroes, hands, decks, enemies and squares.
## Board positions are [row, lane] on each side's own board (row 0 = front), as in the rules.

static var _data: Dictionary = {}

static func data() -> Dictionary:
    if _data.is_empty():
        _data = DataLoader.new().load_all()
    return _data

static func battle(provider: DecisionProvider = null, seed_in: int = 1) -> Battle:
    var p: DecisionProvider = provider if provider != null else ScriptedProvider.new()
    var b := Battle.new(data()["rules"], data()["enemies"], seed_in, p)
    b.round_number = 1
    return b

## Add a hero. `hand` and `deck` are card ids ("wound" for a Wound); `deck` is listed top first.
## null keeps the shuffled starting deck and hand. Heroes added earlier start higher on the Provoke track.
static func hero(b: Battle, key: String, row: int, lane: int, hand: Variant = null, deck: Variant = null) -> HeroState:
    var h: HeroState = BattleSetup.make_hero(b, key, data()["heroes"][key], data()["items"])
    if hand != null:
        h.hand = cards(b, key, hand)
    if deck != null:
        var top_first: Array[Card] = cards(b, key, deck)
        top_first.reverse()
        h.deck = top_first
    b.heroes.append(h)
    var cells: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_HEROES, row, lane)]
    b.field.place(h, cells)
    b.provoke.setup(b.heroes, 20)
    return h

## Add an enemy with its top-left (front-most, left-most) square at [row, lane] of the enemy board.
static func enemy(b: Battle, enemy_type: String, row: int, lane: int) -> EnemyState:
    var e: EnemyState = BattleSetup.make_enemy(b, enemy_type)
    var cells: Array[Vector2i] = []
    for dr in range(e.size.y):
        for dl in range(e.size.x):
            cells.append(Field.cell_for(FigureState.SIDE_ENEMIES, row + dr, lane + dl))
    b.enemies.append(e)
    b.field.place(e, cells)
    return e

static func cards(b: Battle, hero_key: String, ids: Array) -> Array[Card]:
    var result: Array[Card] = []
    for card_id in ids:
        if card_id == Card.WOUND_ID:
            result.append(Card.make_wound(b.new_uid()))
        else:
            result.append(Card.new(b.new_uid(), card_def(hero_key, card_id)))
    return result

static func card_def(hero_key: String, card_id: String) -> Dictionary:
    var hero_def: Dictionary = data()["heroes"][hero_key]
    for c in hero_def.get("deck", []) + hero_def.get("advancement", []):
        if c["id"] == card_id:
            return c
    push_error("No card '%s' for hero '%s'." % [card_id, hero_key])
    return {}

static func enemy_card(enemy_type: String, card_id: String) -> Dictionary:
    for c in data()["enemies"][enemy_type]["deck"]:
        if c["id"] == card_id:
            return c
    push_error("No card '%s' for enemy '%s'." % [card_id, enemy_type])
    return {}

## Replace an enemy type's deck with these cards, top first, and empty its discards.
static func stack_enemy_deck(b: Battle, enemy_type: String, ids_top_first: Array) -> void:
    var deck: EnemyDeck = b.deck_for(enemy_type)
    deck.draw_pile.clear()
    deck.discard_pile.clear()
    for i in range(ids_top_first.size() - 1, -1, -1):
        deck.draw_pile.append(enemy_card(enemy_type, ids_top_first[i]))

## Play a card from the hero's hand as a whole turn (owed draws, play, put away, refill).
static func play(b: Battle, h: HeroState, card_id: String) -> void:
    (b.decisions as ScriptedProvider).then(DecisionRequest.TURN, card_id)
    HeroTurn.take(b, h)

static func card_in(pile: Array[Card], card_id: String) -> bool:
    for c in pile:
        if c.id == card_id:
            return true
    return false

static func event_types(b: Battle) -> Array[String]:
    var result: Array[String] = []
    for entry in b.log.entries:
        result.append(entry["type"])
    return result
