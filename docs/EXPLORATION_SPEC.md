# Exploration spec: room tiles on an open map (approved 2026-10-28; no fixed board since 2026-10-28; rooms redesigned 2026-10-30)

This replaces the v0.5 exploration rules in `docs/RULES.md` §8 ("The map": Tiles, Revealing, Rooms, Hidden doors) and the tile, room-deck, Hut-track and Iron Key parts of §10. Skill rolls, traps, bandaging and camping are unchanged except where noted. The first version was balanced in the Python campaign simulator (blind draws, standard DM, 400 campaigns).

**Redesign (2026-10-30).** Room types and their four decks became named rooms and one Hut deck; Hut Whims moved from a deck drawn at Hut 3/6/9 onto the rooms themselves; the Witch's Workshop and Iron Key (and the level-3 gate) became four component rooms; the single backtracking flip became a walking check per tile; the waking Hut now throws the party out instead of adding Lair fights. Removed: the Lair, Dark, Vault and Library decks, Ambush, Strange font, the Shrine, Pantry and Hearth, the Workshop, the Iron Key, Whim decks and thresholds. `docs/OPEN_QUESTIONS.md` lists the rulings this changed or retired.

## 1. Overview

Exploring builds the Hut one room at a time. The party picks which doorway to open, draws a room tile **blind** from a bag, and places it there. **The party never chooses the room.** Their only choice is the doorway. Each tile is a single named room (Castles of Mad King Ludwig style). The first time the party enters a room in a run, its printed Hut Whim happens (if it has one) and then a Hut card is drawn. The map is cleared between runs, so every run builds a new Hut.

## 2. Components

- **No map board:** tiles are laid directly on the table and the map can grow in any direction without limit. Coordinates (digital) are `[x, y]` from the Front Door at `[0, 0]`: x east, y north; both can go negative.
- **Room tiles:** 26 in the bag, all different rooms (section 5). Two special tiles start outside the bag: the Front Door and the Inner Study.
- **Tile bag:** a cloth bag at the table; a shuffled list in the digital version (seeded RNG).
- **Hut deck (21 cards):** section 8.
- **Component tokens (4):** one each from the Library, the Kitchen, the Armory and the Baths.
- **Party marker:** the room the party is in.
- **Rations:** 8 per run (unchanged).

## 3. Setup (each run)

Lay the Front Door at `[0, 0]` (doorways N, E, W). Shuffle the 26 bag tiles into the bag. The Inner Study waits outside the bag until the party holds all four components (section 6). Shuffle the Hut deck. Hut track at 0. The party starts in the Front Door. Components held from earlier runs stay held.

## 4. Exploring (one room at a time)

1. **Pick a doorway.** Choose an open doorway of the room the party is in. If it has none left, or the party prefers another, they may **walk** to an open doorway in any other explored room, making the walking checks on the way (see below). This is the party's only choice. (Digital: always pick the doorway first, then flip. At the table it may be played more loosely: draw the tile, then lay it at whichever doorway of the party's room fits best.)
2. **Draw and flip** 1 tile from the bag.
3. **Place it** so one of its doorways meets the chosen doorway, rotating it to fit (any of 4 rotations). It must not overlap another tile. If no rotation fits there, place it at another open doorway of the same room, or else of any explored room. Its other doorways may face another tile's wall; those are simply closed. Two doorways that end up facing each other connect.
4. **Moon:** if the tile shows a moon, the Hut track rises by 1.
5. **Enter.** The party moves in and resolves the room (section 5).

An **open doorway** is a doorway of a placed tile whose neighbouring square is empty.

**Nothing fits.** If the drawn tile fits at no open doorway on the map: the Hut stirs (+1, only once per exploration); set the tile aside and draw again until one fits; then shuffle the set-aside tiles back into the bag. If nothing in the bag fits, the party **breaks through** a wall: place a set-aside tile against any wall of an explored room where it fits (no doorway needed; the Hut makes one). If even that is impossible, the Hut has closed in and the party must head home. (Simulation, on the old 7×9 board: a redraw about once in 4 runs; a break-through almost never; closed in about 1 run in 50. Without board edges these rules are a safety net that should almost never trigger.)

**Walking through the Hut.** Walking through explored rooms, to a campsite or to an unopened doorway in another room, costs time. For each tile the party enters on the way, the leading hero (the Fighter, else the first of Thief, Cleric, Wizard who can flip) flips the top card of their deck; it is spent as in a skill roll (Exhausted if ▲ or ★). On a skill value of 1, wandering monsters attack: fight 3 goblins (`wandering` encounter) in that room, then carry on. **These fights give no loot and no XP**, though bandaging afterwards works as usual.

**Leaving.** Walking back to the Front Door to leave is free, with no walking checks, except when the Hut has woken and thrown the party out (section 7).

**Hidden doors** (v0.5) are dropped for now; they will come back as a skill roll.

**DM mode at the table:** the DM holds 3 tiles and plays one onto the chosen doorway. The digital version has no DM tile hand yet (later milestone, with the human DM decision provider).

## 5. Rooms

| Kind | Bag tiles | On the first entry each run |
| --- | --- | --- |
| Room with a Whim | 12 | Resolve the printed Whim (section 7), then draw a Hut card |
| Room without a Whim | 4 | Draw a Hut card: Amphibian and Reptile Terrarium, Bone Closet, Potion Store, Well Room |
| Component room | 4 | A set battle while the party lacks the component (section 6) |
| Bedchamber | 3 | Nothing; a campsite (normal wandering check when camping) |
| Corridor | 3 | Nothing happens. No moon; not a campsite |

The rooms with a Whim: Cauldron Room (Bubbling Cauldron), Mirror Hall (Hall of Mirrors), Crypt (Bones Stir), Spinning Room (Shifting Walls), Root Cellar (Collapse), Storeroom (Locked In), Gallery (Vanishing Door), Great Hall (Doors Slam), Crow Loft (Crooked Corridor), Candle Nook (The Black Cat), Laundry (Keyhole), Garden (Gingerbread Garden). Each name sits on one of the old shapes with the same moons (section 9): Great Hall, Mirror Hall and the Armory on the 2×2s, the Storeroom, Bone Closet and Kitchen on the dead-end squares, the Bedchambers on the old campsite shapes.

**Re-entering** an explored room never resolves it again.

**Camping** works as in v0.5 but only in a campsite the party has explored this run (a Bedchamber or the Kitchen): 1 ration per hero, Hut track +1, the campfire resets every hero, then the wandering-monster check (skill 1–3). Walking to the campsite makes the walking checks.

## 6. Special tiles and components

- **Front Door:** 1×1, doorways N, E, W, at `[0, 0]`. Leaving the Hut means walking back here.
- **Inner Study:** 2×2, one iron door (cell `[0,0]`, side S). Shuffled into the bag as soon as the party holds all four components, even mid-run. It ignores doorway matching: placed at the chosen doorway if it fits, else against any wall of an explored room where it fits; the Hut makes a door. It always fits. Entering starts the boss battle.

**Component rooms.** Each is a set battle on the first visit while the party lacks that component (normal loot and XP, then the component):

| Room | Guardians | Encounter | Also |
| --- | --- | --- | --- |
| Library | 5 skeletons, "the dusty dead" | `skeleton_band` | |
| Kitchen | 5 goblins, "the cooks" | `standard` | Always a campsite; 1 ration on the first visit each run |
| Armory | An ogre and 4 goblins | `tough` | |
| Baths | 3 skeletons and 2 goblins | `baths_guardians` | Afterwards, once per run, every hero removes 2 Wounds and repairs 1 armor |

Once the party holds a component, its room plays as a room without a Whim (a Hut card); the Kitchen stays a campsite and the Baths keep their healing. Components are kept if the party escapes and lost if it wipes on the run they were found. For Milestone 4, "components held at start" is a run setting.

## 7. Hut track and Hut Whims

The Hut track (0–10) rises by 1 for: each moon tile placed, each failed skill roll, each campfire, each "nothing fits" stir; and as The Black Cat and Bubbling Cauldron say. **At 10 the Hut wakes and evicts the party:** no more exploring; the party must walk to the Front Door, making the walking check for every tile on the way (this time leaving is not free). There are no Whim thresholds.

**Hut Whims (12),** printed on their rooms:

| Whim | Room | Effect |
| --- | --- | --- |
| Shifting Walls | Spinning Room | Rotate an explored tile the party isn't in, in place. Doorways may open or close. If it would cut the party off from the Front Door, it doesn't turn |
| Vanishing Door | Gallery | Close one open doorway on the map with a wall token |
| Locked In | Storeroom | Bash the door: Strength 4, retried until it gives way, each failure Hut +1. Nobody can roll: the door gives way, Hut +1 |
| Hall of Mirrors | Mirror Hall | Swap two explored tiles of the same size and shape, doorways and all (not the party's room, not the Front Door) |
| Collapse | Root Cellar | Remove a dead-end room the party isn't in (not a special tile); it leaves the game for this run |
| Keyhole | Laundry | For the next exploration, draw and look at the tile before choosing the doorway |
| Doors Slam | Great Hall | Every open doorway of the party's room closes except one, chosen at random |
| Crooked Corridor | Crow Loft | The next tile must be placed as far (in squares, by path) from the Front Door as it can go |
| The Black Cat | Candle Nook | Optional: tell the cat a secret for Hut track +1 and 1 loot card |
| Bubbling Cauldron | Cauldron Room | Drink if you dare: each hero repairs 1 armor; Hut track +1 (no roll) |
| Gingerbread Garden | Garden | Gain a ration |
| Bones Stir | Crypt | 3 skeletons attack (`bones_stir` encounter); no loot, no XP |

## 8. The Hut deck

21 cards, shuffled each run; it reshuffles its discards when empty.

- Monsters ×9: Goblin band ×5 (`standard`), Skeleton band ×2 (`skeleton_band`), Ogre and goblins ×2 (`tough`). Normal loot and XP.
- Traps ×4: Pit (target 4, 2 damage), Poison needle (target 4, 2 damage), Falling ceiling ×2 (Hard, target 5, 3 damage). Traps work as in v0.5: hidden; a Wits roll at the target spots one; a spotted trap can be avoided or disarmed with an Agility roll for 1 loot card; an unspotted trap springs on the hero leading the party, who may make an Agility roll to dodge.
- Chest ×3: draw 2 loot.
- Locked chest ×1: Agility 5, one retry, each failure Hut +1; success draws 3 loot and gives 1 XP.
- Abandoned pack ×2: draw 1 loot.
- Quiet room ×2: nothing happens.

**Skill checks** are only for locked chests, traps (spot, disarm, dodge), bashing doors (Locked In) and, later, hidden doors.

## 9. Tile data

Tile-local coordinates use the same axes as the map (x east, y north), with the tile's anchor cell at `[0, 0]`. Rotations are applied at placement. The exact cells, doorways, moons, Whims and component rules of every tile are in `data/module_witch_hut.json` (schema in `docs/DATA_SCHEMA.md`). The shapes and moons are the 2026-10-28 ones; only the names and what happens inside changed:

| Old shape (2026-10-28) | Count, moons | Rooms now |
| --- | --- | --- |
| Great hall (2×2) | 3, 2 | Great Hall (moon), Mirror Hall (moon), Armory |
| Long hall (2 squares, 3 doorways) | 3, 1 | Spinning Room, Crow Loft (moon), Laundry |
| Den (1 square, 2 doorways at a corner) | 3, 2 | Candle Nook (moon), Potion Store (moon), Well Room |
| Small dark room (1 square, 3 doorways) | 3, 2 | Crypt (moon), Cauldron Room (moon), Root Cellar |
| Long dark room (2 squares, 3 doorways) | 2, 1 | Amphibian and Reptile Terrarium (moon), Garden |
| Vault (dead end) | 2, 1 | Storeroom, Bone Closet (moon) |
| Pantry (dead end) | 1, 0 | Kitchen |
| Long library | 1, 1 | Library (moon) |
| Wide library | 1, 0 | Gallery |
| Shrine (1 square, 2 doorways opposite) | 1, 1 | Baths (moon) |
| Empty chamber (2 squares) | 2, 0 | Bedchamber ×2 |
| Hearth (1 square, 2 doorways opposite) | 1, 0 | Bedchamber |
| Corridors | 3, 0 | Straight, T and bent corridor |

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

