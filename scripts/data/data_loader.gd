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
const DECK_SIZE := 30
const ENEMY_TAGS: Array[String] = ["", "phase", "top"]
const HERO_TIERS: Array[String] = ["basic", "top", "signature", "recovery", "advancement"]

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
    return errors.is_empty()

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
