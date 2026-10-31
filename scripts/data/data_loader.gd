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
## Fields of exploration effects that hold nested effect lists.
const EXPLORE_NESTED_FIELDS: Array[String] = ["success", "failure", "effects", "otherwise"]
const DECK_SIZE := 30
const ENEMY_TAGS: Array[String] = ["", "phase", "top"]
const HERO_TIERS: Array[String] = ["basic", "top", "signature", "recovery", "advancement"]
const HERO_TYPES: Array[String] = ["strength", "agility", "wits", "spirit"]

var errors: PackedStringArray = []
var _registry: EffectRegistry = EffectRegistry.new()
## Ops in room cards, room types and Hut Whims each need a handler (DATA_SCHEMA "Exploration effect ops").
var _room_effects: RoomEffectRegistry = RoomEffectRegistry.new()

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
    var formations: Dictionary = rules.get("formations", {})
    if not formations.has("default") or formations.get("default") != rules.get("default_formation", {}):
        _fail("rules.formations needs a 'default' equal to rules.default_formation.")
    for formation_name in formations:
        var used: Dictionary = {}
        for key in rules.get("hero_order", []):
            var pos: Array = formations[formation_name].get(key, [])
            if pos.size() != 2 or int(pos[0]) < 0 or int(pos[0]) > 2 or int(pos[1]) < 0 or int(pos[1]) > 2 or used.has(str(pos)):
                _fail("rules.formations.%s puts '%s' on %s: every hero needs their own square on the board." % [formation_name, key, str(pos)])
            used[str(pos)] = true
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
    for key in rules.get("leader_order", []):
        if not heroes.has(key):
            _fail("rules.leader_order names '%s', which is not in heroes.json." % key)
    for section in ["camping", "walking"]:
        var encounter_name: String = String(rules.get(section, {}).get("wandering_encounter" if section == "camping" else "encounter", ""))
        if not encounters.has(encounter_name):
            _fail("rules.%s names unknown encounter '%s'." % [section, encounter_name])
    _validate_module(data.get("module_witch_hut", {}), encounters)
    return errors.is_empty()

## The module: tiles (bag size, moons, doorway geometry, Whims, own effects), room types, the
## components, the Hut deck and the Hut track.
func _validate_module(module: Dictionary, encounters: Dictionary) -> void:
    if module.is_empty():
        _fail("module_witch_hut.json is empty.")
        return
    var room_types: Dictionary = module.get("room_types", {})
    var components: Dictionary = {}
    for c in module.get("components", []):
        components[String(c.get("id", ""))] = c
    var map: Dictionary = module.get("map", {})
    var bag_tiles: int = 0
    var bag_moons: int = 0
    var tile_ids: Dictionary = {}
    var whim_ids: Dictionary = {}
    var component_rooms: Dictionary = {}  # component id -> tile ids that give it
    for tile in module.get("tiles", []):
        _validate_tile(tile, room_types, tile_ids)
        bag_tiles += int(tile.get("qty", 1))
        bag_moons += int(tile.get("moon_qty", 0))
        if int(tile.get("moon_qty", 0)) < 0 or int(tile.get("moon_qty", 0)) > int(tile.get("qty", 1)):
            _fail("Tile '%s' has moon_qty %d for qty %d." % [tile.get("id", "?"), int(tile.get("moon_qty", 0)), int(tile.get("qty", 1))])
        var context: String = "tile '%s'" % tile.get("id", "?")
        if tile.has("whim"):
            var whim: Dictionary = tile["whim"]
            var whim_id: String = String(whim.get("id", ""))
            if whim_id.is_empty() or whim_ids.has(whim_id):
                _fail("Tile '%s' has a Whim with a missing or repeated id '%s'." % [tile.get("id", "?"), whim_id])
            whim_ids[whim_id] = true
            _validate_explore_effects(whim.get("effects", []), "Hut Whim '%s'" % whim_id, components, encounters)
        _validate_explore_effects(tile.get("effects", []), context, components, encounters)
        for e in tile.get("effects", []):
            if String(e.get("op", "")) == "component":
                var cid: String = String(e.get("component", ""))
                var rooms: Array = component_rooms.get(cid, [])
                rooms.append(String(tile.get("id", "")))
                component_rooms[cid] = rooms
    if bag_tiles != int(module.get("bag_size", -1)):
        _fail("The tile bag has %d tiles; bag_size says %d." % [bag_tiles, int(module.get("bag_size", -1))])
    if bag_moons != int(module.get("bag_moons", -1)):
        _fail("The tile bag has %d moons; bag_moons says %d." % [bag_moons, int(module.get("bag_moons", -1))])
    if whim_ids.size() != int(module.get("whim_count", -1)):
        _fail("The tiles carry %d Hut Whims; whim_count says %d." % [whim_ids.size(), int(module.get("whim_count", -1))])
    for cid in components:
        var room_id: String = String(components[cid].get("room", ""))
        if component_rooms.get(cid, []) != [room_id]:
            _fail("Component '%s' should be given by exactly one room, '%s'; found %s." % [cid, room_id, str(component_rooms.get(cid, []))])
    for tile in module.get("special_tiles", []):
        _validate_tile(tile, room_types, tile_ids)
        if tile.has("fixed_at") and (typeof(tile["fixed_at"]) != TYPE_ARRAY or tile["fixed_at"].size() != 2):
            _fail("Special tile '%s' has a bad fixed_at %s." % [tile.get("id", "?"), str(tile["fixed_at"])])
        if tile.has("enters_bag") and tile["enters_bag"] != {"all_components": true}:
            _fail("Special tile '%s' has an unknown enters_bag rule %s." % [tile.get("id", "?"), str(tile["enters_bag"])])
    if not tile_ids.has(String(map.get("entrance_tile", ""))):
        _fail("map.entrance_tile '%s' is not a tile." % map.get("entrance_tile", ""))
    for type_name in room_types:
        var room: Dictionary = room_types[type_name]
        _validate_explore_effects(room.get("effects", []), "room type '%s'" % type_name, components, encounters)
        if room.has("features"):
            _validate_features(room["features"], "Room type '%s'" % type_name, {})
    var deck: Array = module.get("hut_deck", [])
    if sum_deck_quantity(deck) != int(module.get("hut_deck_size", -1)):
        _fail("The Hut deck has %d cards; hut_deck_size says %d." % [sum_deck_quantity(deck), int(module.get("hut_deck_size", -1))])
    for card in deck:
        _validate_explore_effects(card.get("effects", []), "Hut card '%s'" % card.get("id", "?"), components, encounters)
    if int(module.get("hut_track", {}).get("evicts_at", 0)) <= 0:
        _fail("hut_track.evicts_at is missing.")

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

## Ops must be exploration ops; fights name known encounters, rolls a hero Type, component rooms a
## component of the module.
func _validate_explore_effects(effects: Array, context: String, components: Dictionary, encounters: Dictionary) -> void:
    for effect in effects:
        if typeof(effect) != TYPE_DICTIONARY:
            _fail("%s has an effect that is not an object." % context)
            continue
        var op: String = String(effect.get("op", ""))
        if not _room_effects.has(op):
            _fail("%s has unknown op '%s'." % [context, op])
        if op in ["fight", "boss", "component"] and not encounters.has(String(effect.get("encounter", ""))):
            _fail("%s fights unknown encounter '%s'." % [context, effect.get("encounter", "")])
        if op == "component" and not components.has(String(effect.get("component", ""))):
            _fail("%s gives unknown component '%s'." % [context, effect.get("component", "")])
        if op in ["lock", "lock_in"] and not HERO_TYPES.has(String(effect.get("type", ""))):
            _fail("%s rolls unknown Type '%s'." % [context, effect.get("type", "")])
        for field_name in EXPLORE_NESTED_FIELDS:
            if typeof(effect.get(field_name, null)) == TYPE_ARRAY:
                _validate_explore_effects(effect[field_name], context, components, encounters)

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
