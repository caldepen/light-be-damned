# Card RPG — digital prototype (Godot 4)

This is the digital version of a tabletop card RPG. It exists first to playtest and balance the rules, and later to ship alongside the physical game. The tabletop rules are the source of truth: **`docs/RULES.md`** (v0.5, exploration revised for room tiles from `docs/EXPLORATION_SPEC.md`). All content (cards, enemies, items, rule numbers) lives in **`data/*.json`**, described in **`docs/DATA_SCHEMA.md`**.

## The game in one paragraph

A party of four heroes (Fighter, Cleric, Thief, Wizard) explores a shifting dungeon over several runs. Every hero is a 30-card deck; there are no dice. In battle each hero plays a card from hand or flips the top of their deck. Damage fills armor slots, then puts useless Wound cards into the hand; a hand of only Wounds means Down. Enemies have Hit Dice instead of hands and play cards from a shared deck per enemy type, choosing by morale. A shared Provoke track decides who enemies attack. Exploring builds the Hut one room tile at a time on an open, unbounded map: the party picks a doorway and draws the room blind from a bag. Skill rolls flip a deck card and read its 1–6 skill value. The deck is the clock: fighting and exploring both run it down until the party camps.

## Architecture rules (please follow these)

1. **Rules engine separate from presentation.** Everything in `scripts/core/` is plain GDScript (`RefCounted` / `Resource`, no `Node`, no scene references) and can run headless. UI scenes only read state and send player choices; they never change game state directly.
2. **Data-driven.** Card, enemy and item behaviour comes from the `effects` arrays in `data/*.json`, executed by a small set of effect handlers (one per `op`). Never hard-code a card by name in game logic. Tunable numbers come from `data/rules.json`.
3. **Deterministic and seeded.** All shuffles and random choices go through one seeded RNG object owned by the game state, so any battle can be replayed from a seed.
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
```

Battle scene for playtesting (`scenes/battle.tscn`, the main scene): press F5 in the editor, or run the editor exe without `--headless`:

```powershell
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64.exe" --path .
```

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

The Godot engine is the balance baseline; re-run the batch after rule or data changes and compare. Recorded 2026-10-28, rules v0.5 with rulings #1-45, `run_battle.gd --batch` (500 seeds per encounter, seeds 1-500), `TacticalAiProvider` heroes (Milestone 3 AI, see `scripts/ai/`), level 1 party in White gear, default formation (Thief, Fighter, Cleric in front; Wizard back centre). DM modes use the greedy policy (highest-damage playable card). Standard DM is the intended default for play.

The previous baseline (2026-10-26, `SimpleAiProvider`, still available as `--ai simple`) is in git history. The tactical AI is stronger in every cell, most on `tough`: wins 99.0 / 93.2 / 80.8% became 100 / 97.4 / 87.4% (automated / standard / ruthless), and Downs 37.6 / 59.8 / 76.8% became 13.0 / 33.2 / 65.4%.

Down = battles where any hero went Down. Wounds (from damage), armor damage left and cards Exhausted are party totals per battle, averaged. No battle hit the 30-round cap.

| Encounter | DM | Party wins | Down | Rounds | Wounds | Armor left | Exhausted |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5 goblins (`standard`) | automated | 100% | 1.2% | 3.59 | 2.91 | 5.96 | 3.07 |
| | standard | 100% | 10.2% | 3.67 | 4.92 | 7.03 | 3.21 |
| | ruthless | 99.6% | 32.0% | 3.89 | 7.54 | 7.97 | 3.35 |
| Ogre + 4 goblins (`tough`) | automated | 100% | 13.0% | 4.44 | 6.42 | 8.47 | 3.87 |
| | standard | 97.4% | 33.2% | 4.76 | 9.89 | 9.41 | 4.05 |
| | ruthless | 87.4% | 65.4% | 5.08 | 13.78 | 10.10 | 4.06 |
| 5 skeletons (`skeleton_band`) | automated | 100% | 0.2% | 2.78 | 0.77 | 4.49 | 2.26 |
| | standard | 100% | 0.6% | 2.78 | 1.40 | 5.80 | 2.28 |
| | ruthless | 100% | 3.4% | 2.84 | 2.60 | 6.98 | 2.42 |
| `wandering` | automated | 100% | 0% | 2.19 | 0.32 | 2.73 | 1.89 |
| | standard | 100% | 0% | 2.18 | 0.55 | 3.41 | 1.91 |
| | ruthless | 100% | 0.4% | 2.21 | 0.94 | 4.14 | 1.93 |
| `bones_stir` | automated | 100% | 0% | 1.71 | 0.01 | 2.07 | 1.34 |
| | standard | 100% | 0% | 1.66 | 0.09 | 2.76 | 1.29 |
| | ruthless | 100% | 0% | 1.64 | 0.19 | 3.58 | 1.28 |

The `witch` encounter is left out: her Bone Storm extra turn is built (ruling #45) but Bone Ward isn't, and the batch uses the level 1 party rather than a level 3 party with items. The old Python simulator in `reference/` is prototype quality and no longer the baseline; it is still useful for porting AI heuristics.

## Current status (2026-10-28)

**Done** (Milestones 1-3 complete, 2026-10-28)
- Milestone 1: headless battle engine for rules v0.5 (rulings #1-45 in `docs/RULES.md`, none open), data-driven effects, seeded RNG, event log, GUT tests.
- Milestone 2: battle scene (`scenes/battle.tscn`) with board, hands, Provoke track, click to play for every decision, the party choosing hero order, event log, AI-heroes and auto-continue toggles.
- Milestone 3: `TacticalAiProvider` hero AI (threat model, Provoke-aware scoring, one-turn look-ahead for hero order; `--ai simple` keeps the old heuristics) and the batch balance runner with automated / standard / ruthless DM modes and `--detail` reports; 163 GUT tests; baseline above.

**In progress: Milestone 4, exploration** (spec `docs/EXPLORATION_SPEC.md`, rulings #46-65)
- Step 0 done: RULES.md §8 and §10 rewritten for room tiles; `module_witch_hut.json` holds the tiles, specials, room types, four room decks, Hut track and 12 Whims, validated on load (26 bag tiles, 11 moons, doorways on tile edges); DATA_SCHEMA.md documents them.
- Steps: 4.1 table layout (placeholder visuals, reusable scenes, one Theme) → 4.2 map and tile engine → 4.3 rooms, rolls, traps, camping, backtracking, Whims → 4.4 the run loop → 4.5 run decisions and exploration AI → 4.6 map UI → 4.7 run batch report. Commit each step as "M4.x: ...".
- Exploration code lives in `scripts/core/explore/` (`TileGeometry` so far). Rotation: r quarter turns clockwise about the anchor, y up. The map has no fixed board (changed 2026-10-28): the Front Door is at [0,0] and coordinates can go negative; nothing fits / break-through / closed in stay as a rarely used safety net. Map UI (4.6): zoom to fit the whole map while keeping the party's room in view, optional drag pan and wheel zoom, a centre-on-party button, zoom toward the chosen doorway when placing; the 4.1 map panel hosts a SubViewport with a Camera2D for this.

**Known follow-ups**
- Standard DM is the intended default. Re-check campaign balance (wipes, runs to beat the witch) under standard DM once exploration and runs exist; the baseline above is per battle.
- The witch stays out of the baseline until Bone Ward is built and the batch can use a level 3 party with items. For reference she currently beats a level 1 party 80% / 92% / 99% of the time (automated / standard / ruthless DM).
- Digital UI: show the party's total armor prominently and warn when most of it is damaged ("armor gone means leave").
- As designed, not a bug: the goblin Shortbow targets the *lowest*-Provoke hero (its card overrides §6), and ties at 0 go to the bottom of the start stack, so early on it usually hits the Wizard.
- The tactical AI doesn't foresee where a card moves its hero (Backstab, Charge and Twin Daggers step into enemy reach) and treats a kill as not changing who the enemies hit. These are candidates if the AI needs to get stronger still.
- The battle scene redraws when the engine pauses instead of animating from events, and it has no automated tests (checked by screenshots).

## Milestones

1. Battle engine, headless, with tests ✔
2. Minimal battle UI ✔
3. Hero AI, batch balance runner, DM modes ✔
4. **Exploration:** table layout, the open map and room tiles, rooms and room decks, skill rolls and traps, Hut track and Whims, camping and rations, backtracking, a full run from the Front Door until the party leaves or wipes, exploration AI and a run batch report. Loot, levels and the boss are stubbed.
5. **Loot, equipment, levels, runs, town and wipes:** real loot draws and items, XP and levels, the Workshop's level gate, wipes, a campaign batch runner (many runs per campaign), then re-check campaign balance under standard DM against the spec's simulation numbers.
6. **The witch and the full Witch's Hut module:** Bone Ward, the boss fight in the Inner Study, escaping after the win, Whim polish, and a witch baseline with a level 3 party with items.
7. **Art pass:** retro ink on graph paper. Swap the reusable scenes and the shared Theme; design card frames that the print version will share.
8. **Tabletop export:** printable cards, tiles and boards from the data.
- Later: human DM decision provider (including the DM's 3-tile hand), advancement cards for levels 4–5, hybrid classes, more modules.
