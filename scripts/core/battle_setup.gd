class_name BattleSetup
extends RefCounted

## Builds a Battle from loaded data (DataLoader.load_all): the party in its default formation with
## White gear, and an encounter placed front row first, large enemies first (RULES §2, §5 Placement).

## `encounter`: [{"type": String, "count": int}, ...], e.g. data["encounters"]["standard"].
static func create(data: Dictionary, encounter: Array, seed_in: int, provider: DecisionProvider) -> Battle:
    var battle := Battle.new(data["rules"], data["enemies"], seed_in, provider)
    add_party(battle, data)
    var groups: Array = encounter.duplicate()
    groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var sa: Vector2i = size_of(battle.enemy_defs[a["type"]])
        var sb: Vector2i = size_of(battle.enemy_defs[b["type"]])
        return sa.x * sa.y > sb.x * sb.y)
    for group in groups:
        for i in range(int(group.get("count", 1))):
            add_enemy(battle, String(group["type"]))
    return battle

static func add_party(battle: Battle, data: Dictionary) -> void:
    var formation: Dictionary = battle.rules.get("default_formation", {})
    for key in battle.rules["hero_order"]:
        var hero: HeroState = make_hero(battle, String(key), data["heroes"][key], data["items"])
        var pos: Array = formation[key]
        var cells: Array[Vector2i] = [Field.cell_for(FigureState.SIDE_HEROES, int(pos[0]), int(pos[1]))]
        battle.heroes.append(hero)
        battle.field.place(hero, cells)
    battle.provoke.setup(battle.heroes, int(battle.rules.get("provoke", {}).get("track_max", 20)))

static func make_hero(battle: Battle, key: String, def: Dictionary, items: Dictionary) -> HeroState:
    var hero := HeroState.new()
    hero.id = key
    hero.hero_id = key
    hero.name = String(def.get("name", key))
    hero.hero_type = String(def.get("type", ""))
    hero.hand_size = int(def.get("hand_size", 5))
    hero.armor_slots = armor_from_gear(def.get("starting_gear", {}), items)
    for card_def in def.get("deck", []):
        for i in range(int(card_def.get("qty", 1))):
            hero.deck.append(Card.new(battle.new_uid(), card_def))
    battle.rng.shuffle(hero.deck)
    for i in range(hero.hand_size):
        if not hero.deck.is_empty():
            hero.hand.append(hero.deck.pop_back())
    for card in hero.deck + hero.hand:
        for e in card.effects:
            if String(e.get("op", "")) == "signature_choice" and hero.signature_option.is_empty():
                hero.signature_option = battle.ask(DecisionRequest.SIGNATURE_OPTION, hero, e.get("options", []), card)
    return hero

## Armor and shield slots from equipped item effects (RULES §6 table).
static func armor_from_gear(gear: Dictionary, items: Dictionary) -> int:
    var slots: int = 0
    for slot in gear:
        var item: Dictionary = find_item(items, String(gear[slot]))
        for e in item.get("effects", []):
            if String(e.get("op", "")) in ["armor_slots", "shield_slots"]:
                slots += int(e.get("amount", 0))
    return slots

static func find_item(items: Dictionary, item_id: String) -> Dictionary:
    for list_name in ["white", "loot"]:
        for item in items.get(list_name, []):
            if String(item.get("id", "")) == item_id:
                return item
    return {}

static func add_enemy(battle: Battle, enemy_type: String) -> EnemyState:
    var enemy: EnemyState = make_enemy(battle, enemy_type)
    var cells: Array[Vector2i] = []
    if String(enemy.def.get("start_square", "")) == "enemy_back_centre":
        var back_centre: Vector2i = Field.cell_for(FigureState.SIDE_ENEMIES, 2, 1)
        if battle.field.is_empty(back_centre):
            cells = [back_centre]
    if cells.is_empty():
        cells = first_free_cells(battle, enemy.size)
    if cells.is_empty():
        push_error("No room on the enemy board for %s." % enemy.name)
        return null
    battle.enemies.append(enemy)
    battle.field.place(enemy, cells)
    return enemy

static func make_enemy(battle: Battle, enemy_type: String) -> EnemyState:
    var def: Dictionary = battle.enemy_defs[enemy_type]
    var enemy := EnemyState.new()
    enemy.enemy_type = enemy_type
    enemy.def = def
    enemy.name = battle.make_enemy_name(enemy_type)
    enemy.id = enemy.name.to_snake_case()
    enemy.armor_slots = int(def.get("armor", 0))
    enemy.hit_dice = int(def.get("hd", 1))
    enemy.draw_count = int(def.get("draw", 1))
    enemy.undead = bool(def.get("undead", false))
    enemy.size = size_of(def)
    battle.deck_for(enemy_type)
    return enemy

## Data "size" is [rows, lanes]; returned as Vector2i(lanes, rows) to match grid cells.
static func size_of(def: Dictionary) -> Vector2i:
    var raw: Array = def.get("size", [1, 1])
    return Vector2i(int(raw[1]), int(raw[0]))

## The first empty block of `size` on the enemy board: front row first, then left to right.
static func first_free_cells(battle: Battle, size: Vector2i) -> Array[Vector2i]:
    for row in range(3 - size.y + 1):
        for lane in range(Field.LANES - size.x + 1):
            var cells: Array[Vector2i] = []
            for dr in range(size.y):
                for dl in range(size.x):
                    cells.append(Field.cell_for(FigureState.SIDE_ENEMIES, row + dr, lane + dl))
            if battle.field.are_empty(cells):
                return cells
    return []
