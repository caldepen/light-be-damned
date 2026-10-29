# Data schema

All game content lives in `data/*.json`. Code interprets it; it never hard-codes card names or numbers. The human-readable `text` on every card is what gets printed on the tabletop version, and the `effects` list is what the engine executes. If they disagree, `docs/RULES.md` is the authority and the data should be fixed.

## Files

| File | Contents |
| --- | --- |
| `rules.json` | Tunable rule constants: hand rules, Provoke, morale, skill rolls, camping, rations, XP thresholds, wipe rules, DM modes, default formation |
| `heroes.json` | The four heroes: Type, hand size, starting gear, 30-card starting deck, advancement cards (levels 2–3) |
| `enemies.json` | Enemy stat lines (armor, Hit Dice, Draw, size), their shared action decks, and named encounters |
| `items.json` | White starting gear, the loot deck (gear with `copies`), and consumables |
| `module_witch_hut.json` | Module 1: map board, room tiles (bag and specials), room types, the four room decks, Hut track, Hut Whims |

## Hero card

```json
{ "id": "cleave", "name": "Cleave", "qty": 3, "skill": 4,
  "tier": "basic", "level": 1, "exhaust": false,
  "text": "Adjacent: 1 damage + Bleed 2; Provoke +2",
  "effects": [ {"op": "damage", "amount": 1, "range": "melee", "area": "adjacent"},
               {"op": "bleed", "rounds": 2, "area": "same"},
               {"op": "provoke", "amount": 2} ] }
```

- `tier`: `basic`, `top` (▲), `signature` (★), `recovery` (↺) or `advancement`.
- `skill`: 1–6, used only for exploration skill rolls. Each starting deck has five cards of each value.
- `exhaust`: when played (or flipped for a skill roll), the card is set aside until a campfire instead of being discarded. Top-tier and signature cards always Exhaust.
- Effects run in list order. `"area": "same"` means "the same target(s) as the previous effect".
- Provoke: the engine adds Provoke automatically for a card with a damage, heal or repair effect played on a legal target: `rules.json` `provoke.per_point_landed_or_healed` per damage point that lands (armor, Hd, Wound) and per Wound removed or armor point repaired, at least `minimum_per_card_that_damages_or_heals`. The card's own `provoke` and `provoke_halve` ops then resolve last, wherever they sit in the list.
- A card may only be played from hand if at least one of its effects has a legal target or use; the engine offers only those cards to the decision provider.

## Hero effect ops

| op | Fields | Meaning |
| --- | --- | --- |
| `damage` | `amount`, `range` (melee/ranged; omitted for enemy-front-row cards, which need no reach), `area` (single/adjacent/row/area2x2/chain/split), optional `targets`, `bolts`, `row`, `target` (e.g. weakest_enemy), `radiant`, `undead_multiplier`, `element` | Deal damage. `split`: divide `bolts` (or one hit each) among up to `targets` enemies. `chain`: first target, then each next within 1 square of the last |
| `damage_choice` | `options` [{amount, targets}] | Player chooses one option (Twin Daggers) |
| `bleed` | `rounds`, `area`/`range` | Target takes 1 damage at the end of each round for `rounds` rounds |
| `stun` | `area`, optional `row`, `only` (undead) | Target skips its next turn |
| `guard` | `amount`, `target` (self/ally/hero_any/all_heroes) | Add Guard tokens (see Guard rules) |
| `provoke` | `amount` (may be negative) | Move the hero's Provoke token |
| `provoke_halve` | `rounding` | Halve the hero's Provoke |
| `heal_wound` | `amount`, `target` (hero_adjacent/hero_any/all_heroes/heroes_within_1) | Remove Wounds; each removed Wound is replaced by a draw |
| `cleanse` | `amount`, `target`, `kinds` [wound, armor] | Remove any mix of Wounds and armor damage |
| `repair_armor` | `amount` (number or "all"), `target`, optional `between_battles_amount` | Remove armor/shield damage |
| `transfer_wounds` | `amount`, `from`, `to` | Move Wounds from an ally's hand to yours (Lay on Hands) |
| `consecrate` | `enemy_damage`, `undead_multiplier`, `hero_cleanse`, `boards` | 2×2 area on either board or straddling both front rows (two front squares in the same two neighbouring lanes on each board) |
| `draw` | `amount`, `target` | Draw cards (can exceed hand size) |
| `move` | `mode`, optional `squares`, `allow_enemy_board`, `of`, `optional` | Modes: to_melee_reach, step_back, teleport_own_board (any empty square on your own board), up_to |
| `status` | `name`, `duration`/`duration_rounds`, extra fields | Ongoing effects: berserk, thorns, ignore_next_attack, lightning_orb |
| `buff_next` | `amount`, `target` (self/ally), `applies_to` (attack/damage_or_guard), `scope` (battle) | Next qualifying card gets +amount, to every target of that card |
| `weaken_next_attack` | `amount` | Target's next attack deals less |
| `peek` | `count`, `reorder` | Look at the top cards of an enemy type's deck |
| `recover` | `amount`, `to` (deck/hand), `target` | Pull non-Exhausted cards (never itself) back from a discard pile |
| `signature_choice` | `options` [card-like objects] | Wizard signature: choose one option at each campfire |

## Enemy card

```json
{ "id": "spear", "name": "Spear", "qty": 3, "text": "Melee 2 · Throw 1",
  "ai_value": 2, "effects": [ {"op": "attack", "melee": 2, "throw": 1} ] }
```

- `tag`: `phase` (◆: takes effect for the rest of the battle, then the enemy plays another flipped card) or `top` (▲: once per battle per enemy).
- `ai_value`: how much damage the card does, for morale. Bold and Desperate enemies play the highest, Timid the lowest. Strings like "2 per hero in reach" mean "compute at play time".

## Enemy effect ops

| op | Meaning |
| --- | --- |
| `attack` | `melee` X (needs reach after the free step), `throw` Y (ranged fallback at the top-Provoke hero), or `ranged` X with `target` (top_provoke / lowest_provoke). Optional `melee_bonus_per_ally` |
| `attack_area` | `amount` to every hero in `area` (heroes_within_1, area2x2_most_heroes) |
| `splash` | Extra damage to one hero next to the target |
| `stun`, `bleed`, `guard` | As for heroes |
| `discard_random` | Target discards `count` random playable cards (never Wounds), replaced at the start of their next turn; never knocks a hero Down |
| `discard` | Heroes in `area` each discard `count` non-Wound cards of their choice; `cannot_down`: never knocks a hero Down (Roar) |
| `move` | Modes: along_own_front_row, shift_lane, step_toward_top_provoke, vault_to_hero_middle_row |
| `summon` / `summon_if_last` | Place `count` enemies of `type` on empty squares (front row first) |
| `throw_ally` | Ogre throws a goblin into the heroes' back row; `fallback` if none |
| `flee_if` | Leave the battle (no loot) if the condition holds, else run `otherwise` |
| `heal_hd` / `repair_self_armor` | Clear marked Hit Dice / armor |
| `provoke_all_heroes` | Move every hero's Provoke token |
| `polymorph` | Target skips its next `turns` turns |
| `status` | rage (+1 damage for the battle), extra_turn_each_round (an extra turn just before the end of each round; several figures take theirs in the order they gained the status) |

## Item effect ops

`armor_slots`, `shield_slots`, `hand_size`, `skill_bonus` (type or "all"), `damage_bonus` (range), `card_modifier` (changes a named card), `battle_start` (wraps an effect applied at the start of each battle), `once_per_battle` (wraps an effect; turn the item sideways when used), `on_campfire`, `heal_bonus`, `return_to_hand`, `heal_wound` and `rations` for consumables. Cursed items carry a `curse` object with its own `effects`.

## Room tiles (module file `tiles`, `special_tiles`)

```json
{ "id": "lair_long_hall", "name": "Long hall", "type": "lair", "qty": 3, "moon_qty": 1,
  "cells": [[0,0],[0,1]],
  "doors": [{"cell": [0,0], "side": "S"}, {"cell": [0,1], "side": "N"}, {"cell": [0,1], "side": "E"}] }
```

- **Coordinates.** Map squares are `[x, y]`: x is the column from the left (0 to `map.width` − 1), y the row up from the **bottom** edge (0 to `map.height` − 1). So N is +y, E is +x. Tile-local cells use the same axes, with the tile's anchor cell at `[0, 0]`; other cells may be negative (`corridor_t` has `[-1, 0]`).
- **Doorways.** `{"cell", "side"}`: an opening on that side (N, E, S, W) of one of the tile's own cells. It must be on the tile's outer edge: the square it faces is not one of the tile's cells. A cell may have several doorways.
- **Rotation.** A placed tile has a rotation r from 0 to 3: r quarter turns **clockwise** about the anchor, applied to every cell (`(x, y) → (y, −x)` per turn) and every doorway side (N → E → S → W). The engine then shifts the tile so it lands where it is placed. `TileGeometry` implements this.
- `type`: a key of `room_types`.
- `qty`: copies in the tile bag. `moon_qty`: how many of those copies show a moon (0 to `qty`).
- Bag totals are checked on load against `bag_size` (26) and `bag_moons` (11).
- **Special tiles** start outside the bag. They use `moon` (true/false) instead of `qty`/`moon_qty`, and may have:
  - `fixed_at`: the map square of the anchor (Front Door, `[3, 0]`).
  - `ignores_doorway_matching`: placed against any wall of an explored room where it fits; the Hut makes the door (Workshop, Inner Study).
  - `enters_bag`: `{"at_hut": N}` shuffles it into the bag when the Hut track reaches N; optional `min_party_level` and `unless_party_has_key`.
- `map.entrance_tile` names the tile the party starts in.

## Room types (module file `room_types`)

Keyed by tile `type`. Fields: `name`, `text` (printed rule), and any of:

- `deck`: entering draws a card from this room deck and resolves it.
- `effects`: resolved on entering (rooms without a deck: Shrine, Pantry, Workshop, Inner Study).
- `campsite`: the party may camp here once it is explored. `wandering_check: false` skips the campfire's wandering-monster flip (Hearth).
- `requires_key`: the door stays shut without the Iron Key (Inner Study). `exit`: the way out (Front Door).

`hut_track.wake_skips_types` lists the types that draw no extra Lair card once the Hut wakes (corridors, Lairs, the Front Door).

## Room cards and Hut Whims (module file `room_decks`, `hut_whims`)

```json
{ "id": "locked_chest", "name": "Locked chest", "qty": 3, "text": "Agility 5, one retry: draw 3 loot and gain 1 XP",
  "effects": [ {"op": "lock", "type": "agility", "target": 5, "retries": 1,
                "success": [ {"op": "loot", "count": 3} ]} ] }
```

`room_decks` maps a deck name to its cards (with `qty`); `room_deck_sizes` gives each deck's expected size, checked on load. Hut Whims have `id`, `name`, `text` and `effects`, and there must be 12.

XP for beating a Hard or harder obstacle (target ≥ `rules.json` `skill_rolls.difficulty.hard`) is given by the engine, so it is not written into `success` lists.

## Exploration effect ops

| op | Fields | Meaning |
| --- | --- | --- |
| `fight` | `encounter`, optional `rewards` (default true) | Fight a named encounter. `rewards: false` for wandering monsters (no loot, no XP) |
| `draw_room_card` | `deck` | Draw a card from a room deck and resolve it (Workshop guardians) |
| `trap` | `target`, `damage`, `salvage_loot` | A hidden trap: optional Wits spot, then avoid or Agility disarm (salvage), or it springs on the leader, who may dodge (Agility). All rolls at `target` |
| `lock` | `type`, `target`, `retries` (number, or `"unlimited"`), `success` | An obstacle the party may attempt; each failure Hut +1; `success` effects on beating it |
| `skill_check` | `type`, `target`, optional `optional` (default false), `success`, `failure` | One roll. `optional: true` means the party may decline and come back later (Shrine, Strange font) |
| `loot` | `count` | Draw loot cards (Milestone 4 logs the count only) |
| `gain_ration` | `amount` | Rations +amount |
| `party_damage` | `amount` | Each standing hero takes damage (not an attack): armor first, then Wounds |
| `party_repair_armor` | `amount` | Each hero repairs armor damage |
| `party_heal_wounds` | `amount` | Each hero removes Wounds, drawing replacements; a Down hero whose hand is no longer all Wounds gets up |
| `take_key` | | The party takes the Iron Key |
| `boss` | `encounter` | The boss battle (Milestone 4 ends the run as "boss reached") |
| `hut_track` | `amount` | Raise the Hut track |
| `optional` | `prompt`, `effects` | The party may accept (resolve `effects`) or refuse (The Black Cat) |
| `rotate_tile` | | Shifting Walls |
| `close_doorway` | | Vanishing Door: a random open doorway gets a wall token |
| `lock_in` | `types`, `target` | Locked In: the party's room seals until one of `types` beats `target`; roll at once, retry until success |
| `swap_tiles` | | Hall of Mirrors |
| `collapse` | | Collapse: remove a dead-end room |
| `keyhole` | | The next exploration draws the tile before the doorway is chosen |
| `doors_slam` | | Every open doorway of the party's room but one (random) closes |
| `crooked_corridor` | | The next tile goes as far from the Front Door (by path, in squares) as it can |

## Exploration rules (`rules.json`)

- `camping`: `rations_per_hero`, `hut_track`, `wandering_on_skill_at_most` (the campfire flip: monsters on this skill value or lower), `wandering_encounter`.
- `backtracking`: `wandering_on_skill_at_most`, `encounter`.
- `traps.leader_order`: an unspotted trap springs on the first standing hero in this order.
- `skill_rolls`: off-Type penalty, minimum, teamwork threshold, difficulty targets, `failure_hut_track`, `xp_for_hard_or_better`.

## Conventions

- Battle board coordinates are `[row, lane]` on each side's own board: row 0 = front, lane 0 = the players' left on both boards (ruling #1).
- Map board coordinates are `[x, y]` with y up from the bottom edge (see Room tiles).
- IDs are snake_case and stable. Never rename an ID once saves exist; change `name` instead.
- When a rule changes, update `docs/RULES.md`, then the data, then the tests.
