# Data schema

All game content lives in `data/*.json`. Code interprets it; it never hard-codes card names or numbers. The human-readable `text` on every card is what gets printed on the tabletop version, and the `effects` list is what the engine executes. If they disagree, `docs/RULES.md` is the authority and the data should be fixed.

## Files

| File | Contents |
| --- | --- |
| `rules.json` | Tunable rule constants: hand rules, Provoke, morale, skill rolls, camping, rations, XP thresholds, wipe rules, DM modes, default formation |
| `heroes.json` | The four heroes: Type, hand size, starting gear, 30-card starting deck, advancement cards (levels 2–3) |
| `enemies.json` | Enemy stat lines (armor, Hit Dice, Draw, size), their shared action decks, and named encounters |
| `items.json` | White starting gear, the loot deck (gear with `copies`), and consumables |
| `module_witch_hut.json` | Module 1: Hut track, Iron Key gate, tile/room weights (placeholders), obstacles, Hut Whims |

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

## Conventions

- Board coordinates are `[row, lane]` on each side's own board: row 0 = front, lane 0 = left (from that side's point of view in the rules; pick one convention in code and document it).
- IDs are snake_case and stable. Never rename an ID once saves exist; change `name` instead.
- When a rule changes, update `docs/RULES.md`, then the data, then the tests.
