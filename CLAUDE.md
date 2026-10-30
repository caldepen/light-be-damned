# Card RPG — digital prototype (Godot 4)

This is the digital version of a tabletop card RPG. It exists first to playtest and balance the rules, and later to ship alongside the physical game. The tabletop rules are the source of truth: **`docs/RULES.md`** (v0.5, exploration revised for room tiles from `docs/EXPLORATION_SPEC.md`). All content (cards, enemies, items, rule numbers) lives in **`data/*.json`**, described in **`docs/DATA_SCHEMA.md`**.

## The game in one paragraph

A party of four heroes (Fighter, Cleric, Thief, Wizard) explores a shifting dungeon over several runs. Every hero is a 30-card deck; there are no dice. In battle each hero plays a card from hand or flips the top of their deck. Damage fills armor slots, then puts useless Wound cards into the hand; a hand of only Wounds means Down. Enemies have Hit Dice instead of hands and play cards from a shared deck per enemy type, choosing by morale. A shared Provoke track decides who enemies attack. Exploring builds the Hut one room tile at a time on an open, unbounded map: the party picks a doorway and draws the room blind from a bag. Skill rolls flip a deck card and read its 1–6 skill value. The deck is the clock: fighting and exploring both run it down until the party camps.

## Architecture rules (please follow these)

1. **Rules engine separate from presentation.** Everything in `scripts/core/` is plain GDScript (`RefCounted` / `Resource`, no `Node`, no scene references) and can run headless. UI scenes only read state and send player choices; they never change game state directly.
2. **Data-driven.** Card, enemy and item behaviour comes from the `effects` arrays in `data/*.json`, executed by a small set of effect handlers (one per `op`). Never hard-code a card by name in game logic. Tunable numbers come from `data/rules.json`.
3. **Deterministic and seeded.** All shuffles and random choices go through one seeded RNG object owned by the game state, so any battle can be replayed from a seed. The one exception is cosmetic: map decorations (`features`) use a second stream derived from the run seed, so a replay draws the same map and art data can never change play.
4. **Event log.** The engine emits a structured event for everything that happens (card played, damage, Wound added, Provoke moved, enemy flips). The UI animates from events; tests and the headless runner read them.
5. **Decisions are an interface.** Every choice a hero makes (which card, which target, which square) goes through a decision provider. Implement a human provider (UI) and an AI provider (heuristics) behind the same interface, so the same battle can be played by a person or simulated.
6. **Static typing** in GDScript (`var x: int`, typed arrays, `class_name`), small files, one class per file.

## Suggested layout

```
res://
  data/            # JSON content (do not hand-edit numbers in code)
  docs/            # RULES.md, DATA_SCHEMA.md
  scripts/core/    # rules engine: game_state, battle, deck, hero_state, enemy_state, effects/, enemy_ai, provoke, rng
  scripts/data/    # JSON loading + validation (fail loudly on unknown ops or bad references)
  scripts/ai/      # hero AI decision provider (for simulation and auto-play)
  scripts/ui/      # presentation only
  scenes/
  tests/           # GUT unit tests
  tools/           # headless runners: battle simulation, balance reports
```

## Commands

Godot 4.7.2 with GUT 9.7.0 (`addons/gut`). Use the console exe for headless runs; the editor is `Godot_v4.7.2-stable_win64.exe` in the same folder. Run from the project root (PowerShell):

```powershell
# Refresh the class cache after adding or renaming a class_name
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --import

# Run all GUT tests
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Play the seeded sample battles (standard and tough, seed 1) and print the event log
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd

# One encounter from enemies.json "encounters" with a chosen seed (quote '--' in PowerShell)
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd '--' tough 42

# Balance batch: 500 seeded battles per encounter (all encounters), summary table only
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd '--' --batch

# Batch options: --battles N, --seed S (first seed), encounter names, --dm automated|standard|ruthless
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd '--' --batch --battles 2000 --dm ruthless standard tough

# Per-hero and per-enemy-type tables under each encounter (Down %, damage taken and dealt, share of
# party damage taken, healing, play/flip/pass mix, most-played cards; enemy kills and damage)
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd '--' --batch --detail --dm standard tough

# Hero AI: --ai tactical (default) or --ai simple (the old heuristics, for comparison); works on single battles too
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_battle.gd '--' --batch --ai simple

# Map engine (no rooms resolved yet): build the Hut from the whole bag for a seed, print the log and an ASCII map
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_map.gd '--' 7

# How often 'nothing fits', break-through and closed in fire over many seeds
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_map.gd '--' --batch 1000

# One whole run (HutRun.play: SimpleRunAi outside battle, TacticalAiProvider heroes, real battles) with its
# full log and map, or a batch summary. Options: --dm automated|standard|ruthless (default standard),
# --level N (party level for the Workshop gate; default 1, so no key and no boss), --stub (battles called won)
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_map.gd '--' --rooms 7
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script tools/run_map.gd '--' --rooms --batch 300 --level 3
```

The playtest table (`scenes/table.tscn`, the main scene; single battles until exploration lands): press F5 in the editor, or run the editor exe without `--headless`:

```powershell
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64.exe" --path .
```

Screenshots of the table at chosen window sizes (needs a window, so the editor exe without `--headless`; writes `<prefix>_<size>_start.png` and `_mid.png`; options `--preset tall|wide`, `--phase exploring`, `--dock bottom_full|bottom_boards|left|right`; uses its own layout file, not the player's):

```powershell
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64.exe" --path . --script tools/screenshot_table.gd '--' C:/temp/shot --preset wide 1600x940 1280x720
```

The table's layout (dividers, collapsed panels, hand dock, battlefield orientation, preset, phase mode) is saved to `user://layout.cfg` (`LayoutSettings`) and restored on launch; delete it or press Reset layout to start over.

The scene runs the engine on a worker thread (`scripts/ui/battle_session.gd`) that pauses for each human decision (`HumanDecisionProvider`) and after enemy turns; the scene reads state only while it is paused.

`--dm` also works on single battles. A batch of 500 for every encounter takes about 3.5 minutes with the tactical AI (about 40 seconds with `--ai simple`); pass encounter names to run fewer.

GUT leaves a test file that fails to parse out of its totals instead of failing, so check that the test count went up after adding tests.

A script error during a headless run can leave Godot running instead of exiting; stop it if a run hangs.

## Working agreements

- **When a rule is ambiguous, stop and ask** rather than inventing one. Note the question in `docs/OPEN_QUESTIONS.md`.
- When a rule changes: update `docs/RULES.md` first, then `data/`, then tests, then code.
- Every rule implemented gets a GUT test with a fixed seed.
- Keep a headless entry point (`tools/run_battle.gd`, see Commands below) that plays a seeded battle with AI heroes and prints the event log.
- Placeholder art only (coloured rectangles, text labels) until the rules feel right.
- Git: `main` on https://github.com/caldepen/light-be-damned. Commit and push at the end of each milestone ("Milestone N complete") and whenever the user asks; never force-push or rewrite history. The old gargoyle roguelite lives on the `gargoyle-roguelite` branch and `gargoyle-final` tag. Pushing from the agent shell needs `$env:GCM_INTERACTIVE = 'always'; $env:GIT_TERMINAL_PROMPT = '1'` so Git Credential Manager can sign in.

## Balance baseline (Godot engine batch runner)

The Godot engine is the balance baseline; re-run the batch after rule or data changes and compare. Recorded 2026-10-29, after the free-step + targeting rules (rulings #66-70: the free step is melee only, enemies decide before moving and go for the top-Provoke hero, a melee card that can reach nobody is worth 0 and Goes Fish), rules v0.5 with rulings #1-70, `run_battle.gd --batch` (500 seeds per encounter, seeds 1-500), `TacticalAiProvider` heroes (Milestone 3 AI, see `scripts/ai/`), level 1 party in White gear, default formation (Thief, Fighter, Cleric in front; Wizard back centre). DM modes use the greedy policy (highest-damage playable card). Standard DM is the intended default for play.

The previous baselines are in git history: 2026-10-28 (rulings #1-45, tactical AI) and 2026-10-26 (`SimpleAiProvider`, still available as `--ai simple`). The free-step + targeting rules made `tough` easier (Downs 13.0 / 33.2 / 65.4% became 11.0 / 24.0 / 47.8%, automated / standard / ruthless; ruthless wins 87.4% became 91.4%) and 5 goblins a little harder (about 0.7-1 more Wounds per battle): the ogre must chase the top hero instead of hitting whoever is next to it, and goblins throw at the top hero rather than stabbing a hero in reach. The exploration simulation numbers in `EXPLORATION_SPEC.md` §10 predate these rules; campaign balance is re-checked in Milestone 5.

Down = battles where any hero went Down. Wounds (from damage), armor damage left and cards Exhausted are party totals per battle, averaged. No battle hit the 30-round cap.

| Encounter | DM | Party wins | Down | Rounds | Wounds | Armor left | Exhausted |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5 goblins (`standard`) | automated | 100% | 1.6% | 3.70 | 3.59 | 6.07 | 3.24 |
| | standard | 100% | 12.4% | 3.80 | 5.87 | 7.00 | 3.37 |
| | ruthless | 99.4% | 34.2% | 4.06 | 8.50 | 7.66 | 3.55 |
| Ogre + 4 goblins (`tough`) | automated | 99.8% | 11.0% | 4.76 | 6.31 | 8.03 | 4.19 |
| | standard | 98.4% | 24.0% | 4.88 | 8.74 | 8.89 | 4.25 |
| | ruthless | 91.4% | 47.8% | 5.11 | 11.71 | 9.61 | 4.27 |
| 5 skeletons (`skeleton_band`) | automated | 100% | 0% | 2.80 | 0.73 | 4.52 | 2.27 |
| | standard | 100% | 0.8% | 2.77 | 1.36 | 5.84 | 2.24 |
| | ruthless | 100% | 3.0% | 2.77 | 2.53 | 6.92 | 2.37 |
| `wandering` | automated | 100% | 0% | 2.25 | 0.54 | 2.84 | 2.00 |
| | standard | 100% | 0% | 2.25 | 0.63 | 3.62 | 1.96 |
| | ruthless | 100% | 0.4% | 2.27 | 1.27 | 4.39 | 2.02 |
| `bones_stir` | automated | 100% | 0% | 1.71 | 0.01 | 2.07 | 1.34 |
| | standard | 100% | 0% | 1.66 | 0.08 | 2.76 | 1.29 |
| | ruthless | 100% | 0% | 1.64 | 0.18 | 3.59 | 1.28 |

The `witch` encounter is left out: her Bone Storm extra turn is built (ruling #45) but Bone Ward isn't, and the batch uses the level 1 party rather than a level 3 party with items. The old Python simulator in `reference/` is prototype quality and no longer the baseline; it is still useful for porting AI heuristics.

## Current status (2026-10-30)

- 2026-10-29, movement and targeting (rulings #66-70 in `docs/RULES.md` §3, §5-§7): the free step is melee only (no step before a throw or ranged attack, either board); enemies flip first and decide before moving (top-Provoke hero in reach after the step, else throw at them, else melee only: step, then the best hero in reach); cards beat rules; a large enemy in a row or area takes the effect once; a melee card that can reach nobody is worth 0 (Go Fish, then step). `CardRunner.melee_plan` / `play_enemy_card`, `EnemyMoves.melee_cells`; the hero AI's `ThreatModel` predicts the same targets. 229 GUT tests; baseline re-recorded.

**Done** (Milestones 1-3 complete, 2026-10-28)
- Milestone 1: headless battle engine for rules v0.5 (rulings #1-45 in `docs/RULES.md`, none open), data-driven effects, seeded RNG, event log, GUT tests.
- Milestone 2: battle scene (`scenes/battle.tscn`) with board, hands, Provoke track, click to play for every decision, the party choosing hero order, event log, AI-heroes and auto-continue toggles.
- Milestone 3: `TacticalAiProvider` hero AI (threat model, Provoke-aware scoring, one-turn look-ahead for hero order; `--ai simple` keeps the old heuristics) and the batch balance runner with automated / standard / ruthless DM modes and `--detail` reports; 163 GUT tests; baseline above.

**In progress: Milestone 4, exploration** (spec `docs/EXPLORATION_SPEC.md`, rulings #46-65)
- Step 0 done: RULES.md §8 and §10 rewritten for room tiles; `module_witch_hut.json` holds the tiles, specials, room types, four room decks, Hut track and 12 Whims, validated on load (26 bag tiles, 11 moons, doorways on tile edges); DATA_SCHEMA.md documents them.
- Steps: 4.1 table layout (placeholder visuals, reusable scenes, one Theme) → 4.1b flexible layout → 4.2 map and tile engine → 4.3 rooms, rolls, traps, camping, backtracking, Whims → 4.4 the run loop → 4.5 run decisions and exploration AI → 4.6 map UI → 4.7 run batch report. Commit each step as "M4.x: ...".
- Party formation: 4.4 done (`HutRun.formation`, `set_formation` validates; every run battle and patch-up uses it). Still planned for 4.5: choosing it is a run decision (decision provider, with an AI choice) and the batch runner gets a formation option. Then run the all-back-row formation test (as far back as four heroes fit) and report it against the default formation.
- 4.1 done: `scenes/table.tscn` (`TableScreen`) follows the wireframe: top bar; left the Hut track / rations / party armor meter (warns past half damaged) over the map; centre the DM board, the Provoke strip, the player board (front rows facing); right the decks, discards and Exhausted piles and the collapsible event log; bottom the prompt and the hand. Built from `scenes/components/` (panel frame, board square, figure token, card, deck pile, tile) via `UiScenes`, styled by one Theme `ui/theme.tres` (custom-drawn pieces read their colours from it), `canvas_items` stretch. The map is `MapView`: a SubViewport with a Camera2D and five layers; `ink_in()` is the placement hook; dimmed during battle.
- 4.1b done (presentation only): draggable dividers (`TableSplit`) between the map, the battle area, the decks column and the hand dock; the map, battle boards, decks column, log and hand collapse to thin strips (`CollapsiblePanel`); a collapsed hand opens on hover and when a hero must choose a card (setting). The Layout menu (`LayoutMenu`) picks the preset (Tall, Wide, My layout), the battlefield orientation (`BoardOrientation`: tall = DM board above the player board, the Provoke strip under the player board at its width; wide = player board left, DM right; only the grid's direction changes, tooltips name lanes), the Provoke strip edge when wide, the hand dock (bottom full width, bottom under the boards, left, right) and the phase mode (Automatic: the boards collapse to a party-summary strip while exploring and expand with an animation for battle, the map shrinks and dims; Always show both; Manual). Exploring and battle keep separate divider sizes and collapsed panels. `TableScreen.set_phase()` is the hook exploration will call; until then the menu has an exploring-layout preview. The map never rotates. Saved to `user://layout.cfg`; Reset layout keeps a saved "My layout".
- 4.2 done: the headless map and tile engine in `scripts/core/explore/`. `HutExplorer` owns one run's `HutMap`, `TileBag` (seeded) and Hut track. `explore(doorway)` draws blind and places the tile:
  - At the chosen doorway (any rotation, no overlap; symmetric rotations offered once), else another open doorway of the same room, else of any explored room.
  - Goal tiles go at the doorway ignoring matching, else against any wall of an explored room; the Hut makes the door.
  - Nothing fits: the Hut stirs once and tiles are set aside and returned; then break-through with the first set-aside tile; then closed in; an empty bag ends exploring.
  - Moons raise the Hut track; the Workshop and Inner Study enter the bag at Hut 2 and 4.
  - `MapFeatures` picks decorations from the cosmetic stream.
  - Events go to an `EventLog` (`tile_drawn`, `tile_placed`, `hut_track`, `special_enters_bag`, `break_through`, `closed_in`, ...).
  - Several legal placements go through `chooser` (first option until 4.5).
  - `HutMap` also answers open doorways (wall tokens included), connections and reachability.
  - Map changes for the Whims (start of 4.3): `rotate_tile` (in place, same squares), `swap_tiles` (same footprint by sliding, orientation kept), `remove_tile` (dead ends) and `close_doorway` (wall token on an open doorway). Each returns "" or the reason it refused (party's room, Front Door, special tile, unexplored, cutting the party off from the Front Door) and logs `map_change_refused`; `rotation_options` / `swap_options` / `collapse_options` / `open_doorway_options` list the legal ones.
  - `HutExplorer.to_dict()` / `from_dict()` save the whole exploration state as JSON-safe data (map, bag order, Hut track, party, both RNG positions as strings).
  - `tools/run_map.gd` builds seeded maps.
- 4.3 done: `HutRun` (`scripts/core/explore/hut_run.gd`) is one run outside battle.
  - It owns the `HutExplorer`, `PartyState` (heroes carried between fights: damage armor-then-Wounds, Down outside battle, healing, campfire reset), `RoomDecks`, the Whim deck, rations, XP and a loot count.
  - `enter_room` resolves a room once: the waking Hut's Lair card first, then the room card or the room's own effects. Optional rooms (Shrine, Strange font) wait for the party to come back; the Inner Study stays shut without the key.
  - Room, card and Whim behaviour comes from the module's `effects` through one handler per op in `scripts/core/explore/room_effects/` (`RoomEffectRegistry`; the data loader rejects ops without a handler).
  - `SkillRoll`: off-Type −2, cards spent or Exhausted, teamwork, failure Hut +1, Hard gives XP. Traps, locks and retries, the Iron Key, the boss stub ("boss reached").
  - Whims at Hut 3/6/9 (no repeats; map Whims pick at random among legal options), the Hut waking at 10, Keyhole (`peek`) and Crooked Corridor (`farthest_options`).
  - `camp`, `backtrack_check` and `explore_step` (doorway choice, backtrack check, place, enter).
  - Party choices go through `RunDecisionProvider` (`RunRequest` kinds); `SimpleRunAi` (`scripts/ai/`) plays them until 4.5.
  - Battles go through `fight_runner` (real battles since 4.4, see below).
- 4.4 done: the run loop.
  - `RunFight` (default `fight_runner`): the party's own `HeroState`s fight, carrying hands, decks, discards, Exhausted cards, Wounds and armor damage in and out; Down heroes and empty decks sit out (nobody left = wipe); battle-only state is cleared before and after (`PartyState.clear_battle_state`); fresh enemy decks; seeds from the run's RNG (`next_seed`); card uids continue the party's numbering; battle events are forwarded into the run log. Loss = wipe; round cap = enemies withdraw (no loot, XP or bandage, #76).
  - After a win: bandage 2 Wounds each (Down heroes get up), then `PatchUp`: the battle decision provider plays healing / repair / recover cards one at a time (`DecisionRequest.PATCH_UP`) on an empty board with the heroes in formation, through the normal effect handlers with `Battle.between_battles` (Fix Armor removes all) (#75). Then loot (2 with a Draw 2 monster) and 1 XP unless the fight was a wandering one.
  - Formation: `HutRun.formation` / `set_formation` (validated), used by every run battle and patch up.
  - `HutRun.play()`: each step `RunRequest.ACTION` among explore / camp (`RunRequest.CAMPSITE`) / study (key + reachable Inner Study → boss) / leave (+2 XP); results left / wipe / boss reached / stalled (step cap). `SimpleRunAi` rests when worn down (camp, else leave) and gives up on a lock after 3 failures or at Hut 8.
  - Map fixes found by the batch (#77): backtracking and placement fallbacks only use rooms the party can walk to (a Whim can turn a dead end away from the map); the Hut never opens a wall-token edge.
  - Locked In with nobody able to roll breaks on its own, Hut +1 (#72 as decided); #71-74 recorded in RULES.md.
  - `run_map.gd --rooms` plays whole runs (options `--dm`, `--level`, `--stub`). 300 runs, standard DM, simple run AI: level 1: left 86.3%, wipe 13.7%, 5.2 fights, 0.9 camps, 8.7 rooms; level 3 (Workshop open): left 75.3%, boss reached 8.0%, wipe 16.7%, key 26%. About 1 s per run. 316 GUT tests; the battle baseline is unchanged.
  - Open questions #71-74 (decided 2026-10-30). Over 1000 seeds the safety nets never fired; the whole bag gives maps of about 12 × 15 squares. Whims, the Hut waking, rooms and the party walking come in 4.3/4.4. Rotation: r quarter turns clockwise about the anchor, y up. The map has no fixed board (changed 2026-10-28): the Front Door is at [0,0] and coordinates can go negative; nothing fits / break-through / closed in stay as a rarely used safety net. Map UI (4.6): zoom to fit the whole map while keeping the party's room in view, optional drag pan and wheel zoom, a centre-on-party button, zoom toward the chosen doorway when placing; the 4.1 map panel hosts a SubViewport with a Camera2D for this. Art direction: an inked map on graph paper. The map view has separate layers, bottom to top: paper/grid, tiles, features, annotations (reserved, empty, UI only), overlay (doorway highlights, party marker, previews). Tile placement goes through an "ink in" hook (a short fade until Milestone 7). Decorations come from optional `features` on room types and tiles (DATA_SCHEMA "Map features"); placeholders until Milestone 7.

**Known follow-ups**
- Standard DM is the intended default. Re-check campaign balance (wipes, runs to beat the witch) under standard DM once exploration and runs exist; the baseline above is per battle.
- The witch stays out of the baseline until Bone Ward is built and the batch can use a level 3 party with items. For reference she currently beats a level 1 party 80% / 91% / 99% of the time (automated / standard / ruthless DM).
- Digital UI: show the party's total armor prominently and warn when most of it is damaged ("armor gone means leave").
- As designed, not a bug: the goblin Shortbow targets the *lowest*-Provoke hero (its card overrides §6), and ties at 0 go to the bottom of the start stack, so early on it usually hits the Wizard.
- The tactical AI doesn't foresee where a card moves its hero (Backstab, Charge and Twin Daggers step into enemy reach) and treats a kill as not changing who the enemies hit. These are candidates if the AI needs to get stronger still.
- The table scene redraws when the engine pauses instead of animating from events. Apart from the map view's layers, the board orientation mapping, layout settings and collapsible panels (`test_map_view`, `test_board_orientation`, `test_layout_settings`, `test_collapsible_panel`) it has no automated tests; check it with `tools/screenshot_table.gd` (see Commands). Hover-to-open on the hand is only checked by hand.

## Milestones

1. Battle engine, headless, with tests ✔
2. Minimal battle UI ✔
3. Hero AI, batch balance runner, DM modes ✔
4. **Exploration:** table layout, the open map and room tiles, rooms and room decks, skill rolls and traps, Hut track and Whims, camping and rations, backtracking, a full run from the Front Door until the party leaves or wipes, exploration AI and a run batch report. Loot, levels and the boss are stubbed.
5. **Loot, equipment, levels, runs, town and wipes:** real loot draws and items, XP and levels, the Workshop's level gate, wipes, a campaign batch runner (many runs per campaign), then re-check campaign balance under standard DM against the spec's simulation numbers.
6. **The witch and the full Witch's Hut module:** Bone Ward, the boss fight in the Inner Study, escaping after the win, Whim polish, and a witch baseline with a level 3 party with items.
7. **Art pass:** retro ink on graph paper. Swap the reusable scenes and the shared Theme; design card frames that the print version will share. The map becomes an inked map on graph paper: an animated ink-in when a tile is placed (replacing the placeholder fade in the ink-in hook), hand-drawn features, a wobbly line style and paper texture.
8. **Tabletop export:** printable cards, tiles and boards from the data.
- Later: human DM decision provider (including the DM's 3-tile hand), advancement cards for levels 4–5, hybrid classes, more modules, player map notes (drawn on the map's annotations layer; presentation only, never in `scripts/core/`).
