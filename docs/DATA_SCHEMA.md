# Data schema

All game content lives in `data/*.json`. Code interprets it; it never hard-codes card names or numbers. The human-readable `text` on every card is what gets printed on the tabletop version, and the `effects` list is what the engine executes. If they disagree, `docs/RULES.md` is the authority and the data should be fixed.

## Files

| File | Contents |
| --- | --- |
| `rules.json` | Tunable rule constants: hand rules, Provoke, morale, skill rolls, camping, rations, XP thresholds, wipe rules, DM modes, default formation |
| `heroes.json` | The four heroes: Type, hand size, starting gear, 30-card starting deck, advancement cards (levels 2–3) |
| `enemies.json` | Enemy stat lines (armor, Hit Dice, Draw, size), their shared action decks, and named encounters |
| `items.json` | White starting gear, the loot deck (gear with `copies`), and consumables |
| `module_witch_hut.json` | Module 1: named room tiles (bag and specials) with their Whims, room types, the components, the Hut deck, the Hut track |

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
| `attack` | `melee` X (RULES §7 Targeting priority: the top-Provoke hero if in reach after the free step toward them; else `throw` Y at them from where the enemy stands, no step; melee only: the step, then the highest-Provoke hero in reach, or the turn ends), or `ranged` X with `target` (top_provoke / lowest_provoke). Optional `melee_bonus_per_ally` |
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
{ "id": "crow_loft", "name": "Crow Loft", "type": "room", "qty": 1, "moon_qty": 1,
  "cells": [[0,0],[0,1]],
  "doors": [{"cell": [0,0], "side": "S"}, {"cell": [0,1], "side": "N"}, {"cell": [0,1], "side": "E"}],
  "whim": {"id": "crooked_corridor", "name": "Crooked Corridor", "text": "...", "effects": [{"op": "crooked_corridor"}]} }
```

- **Coordinates.** There is no fixed board: the map grows in any direction without limit. Map squares are `[x, y]` from the Front Door at `[0, 0]`: x east, y north (N is +y, E is +x); both can be negative. Tile-local cells use the same axes, with the tile's anchor cell at `[0, 0]`; other cells may be negative (`corridor_t` has `[-1, 0]`).
- **Doorways.** `{"cell", "side"}`: an opening on that side (N, E, S, W) of one of the tile's own cells. It must be on the tile's outer edge: the square it faces is not one of the tile's cells. A cell may have several doorways.
- **Rotation.** A placed tile has a rotation r from 0 to 3: r quarter turns **clockwise** about the anchor, applied to every cell (`(x, y) → (y, −x)` per turn) and every doorway side (N → E → S → W). The engine then shifts the tile so it lands where it is placed. `TileGeometry` implements this.
- `type`: a key of `room_types` (`room`, `component`, `bedchamber`, `corridor`).
- `qty`: copies in the tile bag. `moon_qty`: how many of those copies show a moon (0 to `qty`). Every named room has `qty` 1; the two-square Bedchamber has 2.
- Bag totals are checked on load against `bag_size` (26) and `bag_moons` (11).
- `whim` (optional): the Hut Whim printed on the room, `{"id", "name", "text", "effects"}`. It resolves the first time the party enters the room in a run, before the room's own effects. Whim ids are unique, and there must be `whim_count` (12) of them.
- `effects` (optional): the room's own effects, resolved on the first entry after its Whim and before its room type's effects (the component rooms).
- `campsite` (optional): the party may camp here once it is explored, whatever its type (the Kitchen).
- **Special tiles** start outside the bag. They use `moon` (true/false) instead of `qty`/`moon_qty`, and may have:
  - `fixed_at`: the map square of the anchor (Front Door, `[0, 0]`).
  - `ignores_doorway_matching`: placed at the chosen doorway if it fits there, else against any wall of an explored room where it fits; the Hut makes the door (Inner Study).
  - `enters_bag`: `{"all_components": true}` shuffles it into the bag as soon as the party holds every component in `components`.
- `map.entrance_tile` names the tile the party starts in.

## Room types (module file `room_types`)

Keyed by tile `type`. Fields: `name`, `text` (printed rule), and any of:

- `effects`: resolved on the first entry each run, after the tile's Whim and the tile's own effects (`room`: draw a Hut card; `inner_study`: the boss).
- `campsite`: the party may camp in tiles of this type once explored (Bedchambers). `wandering_check: false` would skip the campfire's wandering-monster flip (no room does now).
- `exit`: the way out (Front Door).
- `features`: decorations for tiles of this type (see Map features).

## Components (module file `components`)

```json
{ "id": "kitchen", "name": "Kitchen component", "room": "kitchen" }
```

The four things the Inner Study needs. `room` names the tile whose `component` effect gives it; every component must have exactly one such room.

## Map features (decorations)

Purely cosmetic hand-drawn details on placed tiles (bones, cobwebs, bookshelves). They never affect play. Art comes in Milestone 7; until then the ids are drawn as placeholders.

```json
"room": { "name": "Room", "effects": [{"op": "draw_hut_card"}],
          "features": {"slots_per_cell": 1, "chance": 0.5,
                       "pool": [{"id": "cobweb", "weight": 1}, {"id": "rubble", "weight": 1}]} }
```

- **Room type** `features`: `slots_per_cell` (decoration slots on each cell of a tile of this type, default 1), `chance` (0–1, how likely each slot gets a decoration, default 1) and `pool` (`{"id", "weight"}` entries to pick from).
- **Tile** `features` (optional): `slots` (`[{"cell": [x, y], "count": n}]` on the tile's own cells, replacing the type's `slots_per_cell` for that tile) and `pool` (extra entries added to the type's pool: the Crypt's bones, the Library's bookshelves).
- **Picking.** When a tile is placed, the engine walks its slots in data order (cells, then count), rolls `chance` for each, and makes a weighted pick from the pool. The result is stored on the placed tile in map coordinates and logged with the `tile_placed` event.
- **A separate seeded stream.** Picks use the run's cosmetic RNG, derived from the run seed, not the gameplay RNG. A replay draws the same map, and changing feature data never changes how a seeded run plays.

## The Hut deck (module file `hut_deck`)

```json
{ "id": "locked_chest", "name": "Locked chest", "qty": 1, "text": "Agility 5, one retry: draw 3 loot and gain 1 XP",
  "effects": [ {"op": "lock", "type": "agility", "target": 5, "retries": 1,
                "success": [ {"op": "loot", "count": 3} ]} ] }
```

`hut_deck` lists the cards (with `qty`); `hut_deck_size` (21) is checked on load. A card with no effects does nothing (Quiet room).

XP for beating a Hard or harder obstacle (target ≥ `rules.json` `skill_rolls.difficulty.hard`) is given by the engine, so it is not written into `success` lists.

## Exploration effect ops

Used in Hut cards, Whims, tiles' `effects` and room types' `effects`. Each op has one handler (`scripts/core/explore/room_effects/`); the data loader rejects ops without one.

| op | Fields | Meaning |
| --- | --- | --- |
| `fight` | `encounter`, optional `rewards` (default true) | Fight a named encounter. `rewards: false` for wandering monsters (no loot, no XP) |
| `draw_hut_card` | | Draw a card from the Hut deck and resolve it |
| `component` | `component`, `encounter`, `guardians` (their name), `otherwise` | While the party lacks `component`: fight `encounter` (normal loot and XP), then take the component. Once it holds it: resolve `otherwise` (a Hut card) |
| `trap` | `target`, `damage`, `salvage_loot` | A hidden trap: optional Wits spot, then avoid or Agility disarm (salvage), or it springs on the leader, who may dodge (Agility). All rolls at `target` |
| `lock` | `type`, `target`, `retries` (number, or `"unlimited"`), `success` | An obstacle the party may attempt (a locked chest); each failure Hut +1; `success` effects on beating it |
| `loot` | `count` | Draw loot cards (Milestone 4 logs the count only) |
| `gain_ration` | `amount` | Rations +amount |
| `party_repair_armor` | `amount` | Each hero repairs armor damage |
| `party_heal_wounds` | `amount` | Each hero removes Wounds, drawing replacements; a Down hero whose hand is no longer all Wounds gets up |
| `boss` | `encounter` | The boss battle (Milestone 4 ends the run as "boss reached") |
| `hut_track` | `amount` | Raise the Hut track |
| `optional` | `prompt`, `effects` | The party may accept (resolve `effects`) or refuse (The Black Cat) |
| `rotate_tile` | | Shifting Walls |
| `close_doorway` | | Vanishing Door: a random open doorway gets a wall token |
| `lock_in` | `type`, `target`, `hut_if_nobody_rolls` | Locked In: bash the door with a `type` roll at `target`, at once, retried until it gives way (each failure Hut +1). If nobody can roll, it gives way and the Hut track rises by `hut_if_nobody_rolls` (default 1, ruling #72) |
| `swap_tiles` | | Hall of Mirrors |
| `collapse` | | Collapse: remove a dead-end room |
| `keyhole` | | The next exploration draws the tile before the doorway is chosen |
| `doors_slam` | | Every open doorway of the party's room but one (random) closes |
| `crooked_corridor` | | The next tile goes as far from the Front Door (by path, in squares) as it can |

## Exploration rules (`rules.json`)

- `camping`: `rations_per_hero`, `hut_track`, `wandering_on_skill_at_most` (the campfire flip: monsters on this skill value or lower), `wandering_encounter`.
- `walking`: `wandering_on_skill_at_most` (the flip for each tile walked into: monsters on this value or lower), `encounter`.
- `leader_order`: the hero leading the party: an unspotted trap springs on the first standing hero in this order; the walking check is flipped by the first who can flip.
- `skill_rolls`: off-Type penalty, minimum, teamwork threshold, difficulty targets, `failure_hut_track`, `xp_for_hard_or_better`.
- `run`: `rations`, `xp_for_walking_out`.
- `formations`: named formations `{hero_id: [row, lane]}` the party chooses from when a run starts (`RunRequest.FORMATION`). `default` must equal `default_formation`; `back_row` puts three heroes in the back row and the Fighter in the middle. Each hero needs their own square.
- Module `hut_track`: `start`, `max`, `evicts_at` (the Hut wakes and throws the party out).

## Conventions

- Battle board coordinates are `[row, lane]` on each side's own board: row 0 = front, lane 0 = the players' left on both boards (ruling #1).
- Map coordinates are `[x, y]` from the Front Door at `[0, 0]`, y north, unbounded (see Room tiles).
- IDs are snake_case and stable. Never rename an ID once saves exist; change `name` instead.
- When a rule changes, update `docs/RULES.md`, then the data, then the tests.
