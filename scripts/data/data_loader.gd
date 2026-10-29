class_name DataLoader
extends RefCounted

## Loads data/*.json and validates it. Any problem is reported with push_error and listed in
## `errors`, and load_all() then returns {} so nothing runs on bad data (fail loudly).
## Hero and enemy ops are checked against the EffectRegistry, so every op in the data has a handler.

## Item ops are run by the equipment system (a later milestone), not by effect handlers.
const ITEM_OPS: Array[String] = [
    "armor_slots", "shield_slots", "hand_size", "skill_bonus", "damage_bonus", "card_modifier",
    "battle_start", "once_per_battle", "on_campfire", "heal_bonus", "return_to_hand", "heal_wound",
    "rations", "guard", "buff_next", "move", "add_wound", "hut_track",
]
## Effect fields that hold nested effect lists.
const NESTED_FIELDS: Array[String] = ["otherwise", "fallback", "effects", "effect"]
## Ops in room cards, room types and Hut Whims (DATA_SCHEMA "Exploration effect ops").
const EXPLORE_OPS: Array[String] = [
    "fight", "draw_room_card", "trap", "lock", "skill_check", "loot", "gain_ration", "party_damage",
    "party_repair_armor", "party_heal_wounds", "take_key", "boss", "hut_track", "optional",
    "rotate_tile", "close_doorway", "lock_in", "swap_tiles", "collapse", "keyhole", "doors_slam",
    "crooked_corridor",
]
## Fields of exploration effects that hold nested effect lists.
const EXPLORE_NESTED_FIELDS: Array[String] = ["success", "failure", "effects"]
const DECK_SIZE := 30
const ENEMY_TAGS: Array[String] = ["", "phase", "top"]
const HERO_TIERS: Array[String] = ["basic", "top", "signature", "recovery", "advancement"]
const HERO_TYPES: Array[String] = ["strength", "agility", "wits", "spirit"]

var errors: PackedStringArray = []
var _registry: EffectRegistry = EffectRegistry.new()

func load_all() -> Dictionary:
    errors.clear()
    var enemies_file: Dictionary = _read_json("res://data/enemies.json")
    var data: Dictionary = {
        "rules": _read_json("res://data/rules.json"),
        "heroes": _read_json("res://data/heroes.json").get("heroes", {}),
        "enemies": enemies_file.get("enemies", {}),
        "encounters": enemies_file.get("encounters", {}),
        "items": _read_json("res://data/items.json"),
        "module_witch_hut": _read_json("res://data/module_witch_hut.json"),
    }
    if errors.is_empty():
        validate(data)
    if not errors.is_empty():
        for message in errors:
            push_error("Data error: " + message)
        return {}
    return data

## Checks everything and appends to `errors`. Returns true if the data is valid.
func validate(data: Dictionary) -> bool:
    var rules: Dictionary = data.get("rules", {})
    var heroes: Dictionary = data.get("heroes", {})
    var enemies: Dictionary = data.get("enemies", {})
    var items: Dictionary = data.get("items", {})
    if rules.is_empty():
        _fail("rules.json is empty.")
    for key in rules.get("hero_order", []):
        if not heroes.has(key):
            _fail("rules.hero_order names '%s', which is not in heroes.json." % key)
        if not rules.get("default_formation", {}).has(key):
            _fail("rules.default_formation has no square for '%s'." % key)
    for hero_id in heroes:
        _validate_hero(String(hero_id), heroes[hero_id], items)
    for enemy_type in enemies:
        _validate_enemy(String(enemy_type), enemies[enemy_type], enemies)
    var encounters: Dictionary = data.get("encounters", {})
    for encounter_name in encounters:
        for group in encounters[encounter_name]:
            if not enemies.has(String(group.get("type", ""))):
                _fail("Encounter '%s' uses unknown enemy type '%s'." % [encounter_name, group.get("type", "")])
    for list_name in ["white", "loot", "consumables"]:
        for item in items.get(list_name, []):
            _validate_effects(item.get("effects", []), "item '%s'" % item.get("id", "?"), ITEM_OPS)
    for key in rules.get("traps", {}).get("leader_order", []):
        if not heroes.has(key):
            _fail("rules.traps.leader_order names '%s', which is not in heroes.json." % key)
    for section in ["camping", "backtracking"]:
        var encounter_name: String = String(rules.get(section, {}).get("wandering_encounter" if section == "camping" else "encounter", ""))
        if not encounters.has(encounter_name):
            _fail("rules.%s names unknown encounter '%s'." % [section, encounter_name])
    _validate_module(data.get("module_witch_hut", {}), encounters)
    return errors.is_empty()

## The module: tiles (bag size, moons, doorway geometry), room types, room decks and Hut Whims.
func _validate_module(module: Dictionary, encounters: Dictionary) -> void:
    if module.is_empty():
        _fail("module_witch_hut.json is empty.")
        return
    var room_types: Dictionary = module.get("room_types", {})
    var decks: Dictionary = module.get("room_decks", {})
    var map: Dictionary = module.get("map", {})
    var bag_tiles: int = 0
    var bag_moons: int = 0
    var tile_ids: Dictionary = {}
    for tile in module.get("tiles", []):
        _validate_tile(tile, room_types, tile_ids)
        bag_tiles += int(tile.get("qty", 1))
        bag_moons += int(tile.get("moon_qty", 0))
        if int(tile.get("moon_qty", 0)) < 0 or int(tile.get("moon_qty", 0)) > int(tile.get("qty", 1)):
            _fail("Tile '%s' has moon_qty %d for qty %d." % [tile.get("id", "?"), int(tile.get("moon_qty", 0)), int(tile.get("qty", 1))])
    if bag_tiles != int(module.get("bag_size", -1)):
        _fail("The tile bag has %d tiles; bag_size says %d." % [bag_tiles, int(module.get("bag_size", -1))])
    if bag_moons != int(module.get("bag_moons", -1)):
        _fail("The tile bag has %d moons; bag_moons says %d." % [bag_moons, int(module.get("bag_moons", -1))])
    for tile in module.get("special_tiles", []):
        _validate_tile(tile, room_types, tile_ids)
        if tile.has("fixed_at") and (typeof(tile["fixed_at"]) != TYPE_ARRAY or tile["fixed_at"].size() != 2):
            _fail("Special tile '%s' has a bad fixed_at %s." % [tile.get("id", "?"), str(tile["fixed_at"])])
    if not tile_ids.has(String(map.get("entrance_tile", ""))):
        _fail("map.entrance_tile '%s' is not a tile." % map.get("entrance_tile", ""))
    for type_name in room_types:
        var room: Dictionary = room_types[type_name]
        if room.has("deck") and not decks.has(String(room["deck"])):
            _fail("Room type '%s' uses unknown room deck '%s'." % [type_name, room["deck"]])
        _validate_explore_effects(room.get("effects", []), "room type '%s'" % type_name, decks, encounters)
        if room.has("features"):
            _validate_features(room["features"], "Room type '%s'" % type_name, {})
    var sizes: Dictionary = module.get("room_deck_sizes", {})
    for deck_name in decks:
        var total: int = sum_deck_quantity(decks[deck_name])
        if total != int(sizes.get(deck_name, -1)):
            _fail("Room deck '%s' has %d cards; room_deck_sizes says %d." % [deck_name, total, int(sizes.get(deck_name, -1))])
        for card in decks[deck_name]:
            _validate_explore_effects(card.get("effects", []), "room card '%s'" % card.get("id", "?"), decks, encounters)
    var whims: Array = module.get("hut_whims", [])
    if whims.size() != 12:
        _fail("There are %d Hut Whims; expected 12." % whims.size())
    for whim in whims:
        _validate_explore_effects(whim.get("effects", []), "Hut Whim '%s'" % whim.get("id", "?"), decks, encounters)
    var hut: Dictionary = module.get("hut_track", {})
    if not decks.has(String(hut.get("wake_extra_deck", ""))):
        _fail("hut_track.wake_extra_deck '%s' is not a room deck." % hut.get("wake_extra_deck", ""))

## A tile has a known type, cells with no duplicates, and doorways on its own cells' outer edges.
func _validate_tile(tile: Dictionary, room_types: Dictionary, tile_ids: Dictionary) -> void:
    var tile_id: String = String(tile.get("id", ""))
    var context: String = "Tile '%s'" % tile_id
    if tile_id.is_empty():
        _fail("A tile has no id.")
    elif tile_ids.has(tile_id):
        _fail("Two tiles have id '%s'." % tile_id)
    tile_ids[tile_id] = true
    if not room_types.has(String(tile.get("type", ""))):
        _fail("%s has unknown room type '%s'." % [context, tile.get("type", "")])
    var cells: Array[Vector2i] = TileGeometry.cells_from_data(tile.get("cells", []))
    if cells.is_empty():
        _fail("%s has no cells." % context)
    var seen: Dictionary = {}
    for c in cells:
        if seen.has(c):
            _fail("%s lists cell %s twice." % [context, str(c)])
        seen[c] = true
    var doors: Array = tile.get("doors", [])
    if doors.is_empty():
        _fail("%s has no doorways." % context)
    var door_keys: Dictionary = {}
    for door in doors:
        var raw: Array = door.get("cell", [])
        var side: String = String(door.get("side", ""))
        if raw.size() != 2 or not TileGeometry.is_side(side):
            _fail("%s has a bad doorway %s." % [context, str(door)])
            continue
        var cell := Vector2i(int(raw[0]), int(raw[1]))
        if not seen.has(cell):
            _fail("%s has a doorway on %s, which is not one of its cells." % [context, str(cell)])
        elif seen.has(TileGeometry.facing_cell(cell, side)):
            _fail("%s has a doorway on %s side %s, which is not on the tile's edge." % [context, str(cell), side])
        var key: String = "%s%s" % [str(cell), side]
        if door_keys.has(key):
            _fail("%s lists the doorway %s %s twice." % [context, str(cell), side])
        door_keys[key] = true
    if tile.has("features"):
        _validate_features(tile["features"], context, seen)

## Decoration data (DATA_SCHEMA "Map features"): a room type's slots_per_cell, chance and pool, or a
## tile's slots (on its own cells) and extra pool. `tile_cells` is empty for room types.
func _validate_features(features: Variant, context: String, tile_cells: Dictionary) -> void:
    if typeof(features) != TYPE_DICTIONARY:
        _fail("%s has features that are not an object." % context)
        return
    if features.has("slots_per_cell") and int(features["slots_per_cell"]) < 0:
        _fail("%s has a negative features.slots_per_cell." % context)
    var chance: float = float(features.get("chance", 1.0))
    if chance < 0.0 or chance > 1.0:
        _fail("%s has features.chance %s; expected 0 to 1." % [context, str(chance)])
    for entry in features.get("pool", []):
        if typeof(entry) != TYPE_DICTIONARY or String(entry.get("id", "")).is_empty():
            _fail("%s has a feature with no id." % context)
        elif float(entry.get("weight", 1)) <= 0.0:
            _fail("%s feature '%s' needs a weight above 0." % [context, entry["id"]])
    for slot in features.get("slots", []):
        var raw: Array = slot.get("cell", [])
        var cell := Vector2i(int(raw[0]), int(raw[1])) if raw.size() == 2 else Vector2i(-999, -999)
        if tile_cells.is_empty() or not tile_cells.has(cell):
            _fail("%s has a feature slot on %s, which is not one of its cells." % [context, str(raw)])
        if int(slot.get("count", 1)) < 0:
            _fail("%s has a feature slot with a negative count." % context)

## Ops must be exploration ops; fights name known encounters, rolls a hero Type, room cards a deck.
func _validate_explore_effects(effects: Array, context: String, decks: Dictionary, encounters: Dictionary) -> void:
    for effect in effects:
        if typeof(effect) != TYPE_DICTIONARY:
            _fail("%s has an effect that is not an object." % context)
            continue
        var op: String = String(effect.get("op", ""))
        if not EXPLORE_OPS.has(op):
            _fail("%s has unknown op '%s'." % [context, op])
        if op in ["fight", "boss"] and not encounters.has(String(effect.get("encounter", ""))):
            _fail("%s fights unknown encounter '%s'." % [context, effect.get("encounter", "")])
        if op == "draw_room_card" and not decks.has(String(effect.get("deck", ""))):
            _fail("%s draws from unknown room deck '%s'." % [context, effect.get("deck", "")])
        if op in ["lock", "skill_check"] and not HERO_TYPES.has(String(effect.get("type", ""))):
            _fail("%s rolls unknown Type '%s'." % [context, effect.get("type", "")])
        if op == "lock_in":
            for t in effect.get("types", []):
                if not HERO_TYPES.has(String(t)):
                    _fail("%s rolls unknown Type '%s'." % [context, t])
        for field_name in EXPLORE_NESTED_FIELDS:
            if typeof(effect.get(field_name, null)) == TYPE_ARRAY:
                _validate_explore_effects(effect[field_name], context, decks, encounters)

func _validate_hero(hero_id: String, hero: Dictionary, items: Dictionary) -> void:
    var deck: Array = hero.get("deck", [])
    var total: int = sum_deck_quantity(deck)
    if total != DECK_SIZE:
        _fail("Hero '%s' deck has %d cards; expected %d." % [hero_id, total, DECK_SIZE])
    var counts: Dictionary = {}
    for card in deck:
        var skill: int = int(card.get("skill", 0))
        counts[skill] = int(counts.get(skill, 0)) + int(card.get("qty", 1))
    for value in range(1, 7):
        if int(counts.get(value, 0)) != DECK_SIZE / 6:
            _fail("Hero '%s' has %d cards with skill %d; expected %d." % [hero_id, int(counts.get(value, 0)), value, DECK_SIZE / 6])
    for skill in counts:
        if skill < 1 or skill > 6:
            _fail("Hero '%s' has cards with skill %d; skill must be 1-6." % [hero_id, skill])
    var ids: Dictionary = {}
    for card in deck + hero.get("advancement", []):
        var card_id: String = String(card.get("id", ""))
        var context: String = "hero '%s' card '%s'" % [hero_id, card_id]
        if card_id.is_empty():
            _fail("A card in hero '%s' has no id." % hero_id)
        elif ids.has(card_id):
            _fail("Hero '%s' has two cards with id '%s'." % [hero_id, card_id])
        ids[card_id] = true
        if int(card.get("qty", 1)) < 1:
            _fail("%s has qty %d; expected at least 1." % [context, int(card.get("qty", 1))])
        if not HERO_TIERS.has(String(card.get("tier", "basic"))):
            _fail("%s has unknown tier '%s'." % [context, card.get("tier", "")])
        _validate_effects(card.get("effects", []), context, [])
    for slot in hero.get("starting_gear", {}):
        var item_id: String = String(hero["starting_gear"][slot])
        if BattleSetup.find_item(items, item_id).is_empty():
            _fail("Hero '%s' starting gear '%s' is not in items.json." % [hero_id, item_id])

func _validate_enemy(enemy_type: String, def: Dictionary, enemies: Dictionary) -> void:
    var deck: Array = def.get("deck", [])
    var total: int = sum_deck_quantity(deck)
    if def.has("deck_size") and total != int(def["deck_size"]):
        _fail("Enemy '%s' deck has %d cards; deck_size says %d." % [enemy_type, total, int(def["deck_size"])])
    for card in deck:
        var context: String = "enemy '%s' card '%s'" % [enemy_type, card.get("id", "?")]
        if String(card.get("id", "")).is_empty():
            _fail("A card in enemy '%s' has no id." % enemy_type)
        if not ENEMY_TAGS.has(String(card.get("tag", ""))):
            _fail("%s has unknown tag '%s'." % [context, card.get("tag", "")])
        var value: Variant = card.get("ai_value", null)
        if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT and typeof(value) != TYPE_STRING:
            _fail("%s needs an ai_value (number, or a formula string)." % context)
        _validate_effects(card.get("effects", []), context, [])
        for e in _all_effects(card.get("effects", [])):
            if e.has("type") and String(e.get("op", "")) in ["summon", "summon_if_last", "throw_ally"] and not enemies.has(String(e["type"])):
                _fail("%s refers to unknown enemy type '%s'." % [context, e["type"]])

## Every op must be known: in the EffectRegistry, or in `extra_ops` (items). Nested lists are checked too.
func _validate_effects(effects: Array, context: String, extra_ops: Array[String]) -> void:
    for effect in effects:
        if typeof(effect) != TYPE_DICTIONARY:
            _fail("%s has an effect that is not an object." % context)
            continue
        var op: String = String(effect.get("op", ""))
        if op.is_empty():
            _fail("%s has an effect with no op." % context)
        elif not (_registry.has(op) or extra_ops.has(op)):
            _fail("%s has unknown op '%s'." % [context, op])
        for field_name in NESTED_FIELDS:
            var nested: Variant = effect.get(field_name, null)
            if typeof(nested) == TYPE_ARRAY:
                _validate_effects(nested, context, extra_ops)
            elif typeof(nested) == TYPE_DICTIONARY:
                _validate_effects([nested], context, extra_ops)
        for option in effect.get("options", []):
            if typeof(option) == TYPE_DICTIONARY and option.has("effects"):
                _validate_effects(option["effects"], context + " option '%s'" % option.get("id", "?"), extra_ops)

## Kept for tests: returns the first problem in an effect list, or "".
func validate_effects(effects: Array, context: String = "effect list") -> String:
    var before: int = errors.size()
    _validate_effects(effects, context, [])
    if errors.size() > before:
        return errors[before]
    return ""

func sum_deck_quantity(deck: Array) -> int:
    var total: int = 0
    for card in deck:
        total += int(card.get("qty", 1))
    return total

func _all_effects(effects: Array) -> Array:
    var result: Array = []
    for e in effects:
        if typeof(e) != TYPE_DICTIONARY:
            continue
        result.append(e)
        for field_name in NESTED_FIELDS:
            if typeof(e.get(field_name, null)) == TYPE_ARRAY:
                result.append_array(_all_effects(e[field_name]))
    return result

func _fail(message: String) -> void:
    errors.append(message)

func _read_json(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        _fail("Could not open %s." % path)
        return {}
    var json := JSON.new()
    var err: Error = json.parse(file.get_as_text())
    if err != OK:
        _fail("JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
        return {}
    if typeof(json.data) != TYPE_DICTIONARY:
        _fail("%s did not contain a JSON object." % path)
        return {}
    return json.data
