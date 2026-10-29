# Exploration spec: room tiles on an open map (approved 2026-10-28; no fixed board since 2026-10-28)

This replaces the v0.5 exploration rules in `docs/RULES.md` §8 ("The map": Tiles, Revealing, Rooms, Hidden doors) and the tile, room-deck, Hut-track and Iron Key parts of §10. Skill rolls, teamwork, traps, bandaging and camping are unchanged except where noted. It was balanced in the Python campaign simulator (blind draws, standard DM, 400 campaigns).

## 1. Overview

Exploring builds the Hut one room at a time. The party picks which doorway to open, draws a room tile **blind** from a bag, and places it there. **The party never chooses the room.** Their only choice is the doorway. Each tile is a single room (Castles of Mad King Ludwig style). The tile shows its room type once flipped; entering draws from that type's small room deck. The map is cleared between runs, so every run builds a new Hut.

## 2. Components

- **No map board:** tiles are laid directly on the table and the map can grow in any direction without limit. Coordinates (digital) are `[x, y]` from the Front Door at `[0, 0]`: x east, y north; both can go negative.
- **Room tiles:** 26 in the bag (section 7). Three special tiles start outside the bag: Front Door, Witch's Workshop, Inner Study.
- **Tile bag:** a cloth bag at the table; a shuffled list in the digital version (seeded RNG).
- **Room decks (36 cards):** Lair (8), Dark (12), Vault (8), Library (8). Section 8.
- **Rooms with no deck:** Shrine, Pantry, Empty chamber, Hearth and corridors carry their rule on the tile.
- **Party marker:** the room the party is in.
- **Rations:** 8 per run (unchanged).

## 3. Setup (each run)

Lay the Front Door at `[0, 0]` (doorways N, E, W). Shuffle the 26 bag tiles into the bag. Workshop and Inner Study wait outside the bag (section 6). Hut track at 0. The party starts in the Front Door.

## 4. Exploring (one room at a time)

1. **Pick a doorway.** Choose an open doorway of the room the party is in. If it has none left, or the party prefers another, they may first **backtrack** to an unopened doorway in any explored room (see below). This is the party's only choice. (Digital: always pick the doorway first, then flip. At the table it may be played more loosely: draw the tile, then lay it at whichever doorway of the party's room fits best.)
2. **Draw and flip** 1 tile from the bag.
3. **Place it** so one of its doorways meets the chosen doorway, rotating it to fit (any of 4 rotations). It must not overlap another tile. If no rotation fits there, place it at another open doorway of the same room, or else of any explored room. Its other doorways may face another tile's wall; those are simply closed. Two doorways that end up facing each other connect.
4. **Moon:** if the tile shows a moon, the Hut track rises by 1.
5. **Enter.** The party moves in and resolves the room (section 5).

An **open doorway** is a doorway of a placed tile whose neighbouring square is empty.

**Nothing fits.** If the drawn tile fits at no open doorway on the map: the Hut stirs (+1, only once per exploration); set the tile aside and draw again until one fits; then shuffle the set-aside tiles back into the bag. If nothing in the bag fits, the party **breaks through** a wall: place a set-aside tile against any wall of an explored room where it fits (no doorway needed; the Hut makes one). If even that is impossible, the Hut has closed in and the party must head home. (Simulation, on the old 7×9 board: a redraw about once in 4 runs; a break-through almost never; closed in about 1 run in 50. Without board edges these rules are a safety net that should almost never trigger.)

**Backtracking.** Walking back through explored rooms to open a doorway in a different room costs time. The hero with the most cards in their deck flips the top card; it is spent as in a skill roll (Exhausted if ▲ or ★). On a skill value of 1 or 2, wandering monsters spill out: fight 3 goblins (`wandering` encounter) before exploring. **This fight gives no loot and no XP**, though bandaging afterwards works as usual. Backtracking is meant to be a small cost the party can choose to pay, never something worth doing for its own sake. Walking through explored rooms is otherwise free and triggers nothing.

**Leaving.** The party can walk back to the Front Door at any time (no backtracking check) to end the run.

**Hidden doors** (v0.5) are dropped for now.

**DM mode at the table:** the DM holds 3 tiles and plays one onto the chosen doorway. The digital version has no DM tile hand yet (later milestone, with the human DM decision provider).

## 5. Room types

| Type | Bag tiles | On entering |
| --- | --- | --- |
| Lair | 9 | Draw a Lair card and fight it |
| Dark room (?) | 5 | Draw a Dark card: a trap, an event, or an ambush |
| Vault | 2 | Dead end. Draw a Vault card |
| Library | 2 | Draw a Library card: a lock or puzzle |
| Shrine | 1 | Once per run, a Spirit 4 roll. Success: every hero removes 2 Wounds (drawing replacements) and repairs 1 armor damage. Failure: Hut track +1 |
| Pantry | 1 | Gain 1 ration. A campsite |
| Empty chamber | 2 | A campsite |
| Hearth | 1 | A campsite with no wandering-monster check |
| Corridor | 3 | Nothing happens. No moon; not a campsite |

**Re-entering** an explored room never resolves it again.

**Camping** works as in v0.5 but only in a campsite room the party has explored this run (Empty chamber, Pantry or Hearth): 1 ration per hero, Hut track +1, then the wandering-monster check (none at the Hearth). The campfire fully resets every hero.

## 6. Special tiles

- **Front Door:** 1×1, doorways N, E, W, at `[0, 0]`. Leaving the Hut means walking back here.
- **Witch's Workshop:** 1×1, one doorway (S), moon. Shuffled into the bag when the Hut track reaches 2, **only if the party is level 3 or higher and doesn't have the Iron Key**. Entering: take the Iron Key, then fight its guardians (draw a Lair card). Key rules otherwise unchanged (no slot; kept once the party escapes; lost if the party wipes on the run it was found). This replaces "the key is among the top three Treasure cards".
- **Inner Study:** 2×2, one iron door (cell `[0,0]`, side S). Shuffled into the bag when the Hut track reaches 4. Without the key it is still placed, but its door stays shut. With the key, entering starts the boss battle.
- **Both goal tiles ignore doorway matching:** place them against any wall of an explored room where they fit; the Hut makes a door. They always fit.

## 7. Hut track and Hut Whims

The Hut track (0–10) rises by 1 for: each moon tile placed, each failed skill roll, each campfire, each "nothing fits" stir. At 3, 6 and 9: draw a Hut Whim. At 2: Workshop enters the bag (if eligible). At 4: Inner Study enters the bag. At 10 the Hut wakes: every room entered from then on (except corridors) also draws a Lair card and that fight happens first.

**Hut Whims (12):**

| Whim | Effect |
| --- | --- |
| Shifting Walls | Rotate an explored tile the party isn't in, in place. Doorways may open or close. If it would cut the party off from the Front Door, it doesn't turn |
| Vanishing Door | Close one open doorway on the map with a wall token |
| Locked In | The doorways of the party's room seal until they beat a Strength or Agility 4 roll (retries allowed; each failure Hut +1) |
| Hall of Mirrors | Swap two explored tiles of the same size and shape, doorways and all (not the party's room, not the Front Door) |
| Collapse | Remove a dead-end room the party isn't in (not a special tile); it leaves the game for this run |
| Keyhole | For the next exploration, draw and look at the tile before choosing the doorway |
| Doors Slam | Every open doorway of the party's room closes except one, chosen at random |
| Crooked Corridor | The next tile must be placed as far (in squares, by path) from the Front Door as it can go |
| The Black Cat | Offers a bargain: 1 loot card for a secret |
| Bubbling Cauldron | Spirit 4 roll: success repairs 1 armor damage on each hero; failure deals 1 damage to each |
| Gingerbread Pantry | Gain a ration |
| Bones Stir | 3 skeletons attack (`bones_stir` encounter) |

## 8. Room decks

Skill rolls, teamwork, retries and "Hard or harder gives 1 XP" work as in v0.5 §8.

**Lair deck (8):** Goblin band ×4 (`standard`), Skeleton band ×2 (`skeleton_band`), Ogre and goblins ×2 (`tough`). Normal loot and XP after winning.

**Dark deck (12):**
- Pit ×2: trap, target 4, 2 damage.
- Poison needle ×2: trap, target 4, 2 damage.
- Falling ceiling ×2: trap, Hard (target 5), 3 damage.
- Abandoned pack ×2: event, draw 1 loot card.
- Strange font ×2: event, Spirit 4 roll: success repairs 1 armor damage on each hero; failure deals 1 damage to each.
- Ambush ×2: fight 3 goblins (`wandering`), normal loot and XP.

Traps work as in v0.5: they start hidden; a Wits roll at the trap's target spots it; a spotted trap can be avoided, or disarmed with an Agility roll for 1 loot card; an unspotted trap springs on the hero leading the party, who may make an Agility roll to dodge.

**Vault deck (8):** Chest ×5 (draw 2 loot). Locked chest ×3 (Agility 5; success draws 3 loot and gives 1 XP; one retry; each failure Hut +1).

**Library deck (8):** each is a lock or puzzle with a Type and target. Success draws 1 loot (Hard or harder also 1 XP); failure raises the Hut track by 1 and may be retried with another flip.
- Lockbox ×2: Agility 4. Trapped lock ×1: Agility 5.
- Rune lock ×2: Wits 4. Riddle door ×1: Wits 5.
- Barred cellar ×1: Strength 4. Seized bookcase ×1: Strength 5.

Room decks reshuffle when empty. They reset each run.

## 9. Tile data (exact doorway positions)

Tile-local coordinates use the same axes as the map (x east, y north), with the tile's anchor cell at `[0, 0]`. Rotations are applied at placement. `moon_qty` is how many of the `qty` copies show a moon.

```json
[
  {"id": "corridor_straight", "type": "corridor", "qty": 1, "moon_qty": 0, "cells": [[0,0],[0,1]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,1],"side":"N"},{"cell":[0,1],"side":"E"}]},
  {"id": "corridor_t", "type": "corridor", "qty": 1, "moon_qty": 0, "cells": [[-1,0],[0,0],[1,0]], "doors": [{"cell":[-1,0],"side":"W"},{"cell":[1,0],"side":"E"},{"cell":[0,0],"side":"N"}]},
  {"id": "corridor_bend", "type": "corridor", "qty": 1, "moon_qty": 0, "cells": [[0,0],[1,0],[1,1]], "doors": [{"cell":[0,0],"side":"W"},{"cell":[1,1],"side":"N"},{"cell":[1,0],"side":"E"}]},
  {"id": "lair_great_hall", "type": "lair", "qty": 3, "moon_qty": 2, "cells": [[0,0],[1,0],[0,1],[1,1]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[1,1],"side":"N"},{"cell":[1,0],"side":"E"}]},
  {"id": "lair_long_hall", "type": "lair", "qty": 3, "moon_qty": 1, "cells": [[0,0],[0,1]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,1],"side":"N"},{"cell":[0,1],"side":"E"}]},
  {"id": "lair_den", "type": "lair", "qty": 3, "moon_qty": 2, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,0],"side":"E"}]},
  {"id": "dark_small", "type": "dark", "qty": 3, "moon_qty": 2, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,0],"side":"E"},{"cell":[0,0],"side":"W"}]},
  {"id": "dark_long", "type": "dark", "qty": 2, "moon_qty": 1, "cells": [[0,0],[0,1]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,1],"side":"E"},{"cell":[0,1],"side":"N"}]},
  {"id": "vault", "type": "vault", "qty": 2, "moon_qty": 1, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"}]},
  {"id": "library_long", "type": "library", "qty": 1, "moon_qty": 1, "cells": [[0,0],[0,1]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,1],"side":"W"}]},
  {"id": "library_wide", "type": "library", "qty": 1, "moon_qty": 0, "cells": [[0,0],[1,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[1,0],"side":"N"}]},
  {"id": "shrine", "type": "shrine", "qty": 1, "moon_qty": 1, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,0],"side":"N"}]},
  {"id": "pantry", "type": "pantry", "qty": 1, "moon_qty": 0, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"}]},
  {"id": "empty_chamber", "type": "empty", "qty": 2, "moon_qty": 0, "cells": [[0,0],[1,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[1,0],"side":"E"},{"cell":[0,0],"side":"N"}]},
  {"id": "hearth", "type": "hearth", "qty": 1, "moon_qty": 0, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"},{"cell":[0,0],"side":"N"}]}
]
```

Specials:

```json
[
  {"id": "front_door", "type": "front_door", "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"N"},{"cell":[0,0],"side":"E"},{"cell":[0,0],"side":"W"}], "fixed_at": [0,0]},
  {"id": "witchs_workshop", "type": "workshop", "moon": true, "cells": [[0,0]], "doors": [{"cell":[0,0],"side":"S"}], "ignores_doorway_matching": true},
  {"id": "inner_study", "type": "inner_study", "moon": false, "cells": [[0,0],[1,0],[0,1],[1,1]], "doors": [{"cell":[0,0],"side":"S"}], "ignores_doorway_matching": true}
]
```

Totals: 26 bag tiles, 11 with a moon.

## 9a. Digital map view (added 2026-10-28)

The map has no fixed size, so the map panel shows it through a camera:

- By default the view zooms to fit the whole map, zooming out as it grows, and always keeps the party's room in view.
- Optional pan (drag) and zoom (mouse wheel), and a "centre on party" button that returns to the automatic view.
- When the party is placing a tile, the view zooms toward the chosen doorway so the placement targets stay large enough to click.

**Art direction: an inked map on graph paper.** Placed tiles "lock in" as if drawn there, hand-drawn details are added, and later players can write their own notes on it. The structure is built in Milestone 4 with placeholder visuals; the real art comes in Milestone 7 (art pass).

- **Layers**, bottom to top, kept separate: paper and grid; tiles (rooms); features (decorations); annotations (player notes, empty for now); overlay (doorway highlights, party marker, placement previews).
- **Ink in.** Placing a tile goes through a dedicated "ink in" hook: a short fade for now, a draw-on animation in Milestone 7.
- **Features.** Optional decoration slots per cell in the tile and room-type data, picked with a seeded stream so a replay draws the same map (DATA_SCHEMA "Map features"). No art yet.
- **Annotations** are presentation only and never part of the rules engine. The layer is reserved; player notes come later.

## 10. Simulation reference (Python campaign simulator, 400 campaigns, level 1 start)

| System and DM | Witch beaten within 12 runs | Median runs | Wipes per campaign | Wiped on run 1 | Battles per run | Tiles per run |
| --- | --- | --- | --- | --- | --- | --- |
| Room tiles, automated | 98.5% | 6 | 1.0 | 31% | 7.2 | 13.8 |
| Room tiles, standard | 81% | 7 | 2.6 | 59% | 6.5 | 12.5 |

The simulated party explores until the average deck drops below 9 cards, then camps if it can or leaves. Run-1 wipes come mostly in fight 2–3, with decks still about half full but most of the party's armor gone. A party that leaves once 7 armor slots are damaged wipes on run 1 only 17% of the time (but progresses more slowly). **Decided:** a tough first run is intended; no rule change. Teach "armor gone means leave" in the rules, and show party armor prominently in the UI with a warning when most is damaged.

## 11. Still open (don't block on these)

- DM tile hand: check that a DM placing Lairs everywhere isn't too strong (tabletop / later human DM provider).
- Map-shifting Whims (Shifting Walls, Hall of Mirrors, Collapse, Doors Slam): playtest for fun versus fiddliness.
- Tile art: doorway positions are final for now; art comes in the art-pass milestone.
