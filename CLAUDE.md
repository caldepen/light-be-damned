# Card RPG — digital prototype (Godot 4)

This is the digital version of a tabletop card RPG. It exists first to playtest and balance the rules, and later to ship alongside the physical game. The tabletop rules are the source of truth: **`docs/RULES.md`** (v0.5). All content (cards, enemies, items, rule numbers) lives in **`data/*.json`**, described in **`docs/DATA_SCHEMA.md`**.

## The game in one paragraph

A party of four heroes (Fighter, Cleric, Thief, Wizard) explores a shifting dungeon over several runs. Every hero is a 30-card deck; there are no dice. In battle each hero plays a card from hand or flips the top of their deck. Damage fills armor slots, then puts useless Wound cards into the hand; a hand of only Wounds means Down. Enemies have Hit Dice instead of hands and play cards from a shared deck per enemy type, choosing by morale. A shared Provoke track decides who enemies attack. Exploring uses skill rolls: flip a deck card and read its 1–6 skill value. The deck is the clock: fighting and exploring both run it down until the party camps.

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
```

Battle scene for playtesting (`scenes/battle.tscn`, the main scene): press F5 in the editor, or run the editor exe without `--headless`:

```powershell
& "C:\Program Files\Godot4_7_2\Godot_v4.7.2-stable_win64.exe" --path .
```

The scene runs the engine on a worker thread (`scripts/ui/battle_session.gd`) that pauses for each human decision (`HumanDecisionProvider`) and after enemy turns; the scene reads state only while it is paused.

`--dm` also works on single battles. A batch of 500 for every encounter takes about 40 seconds.

A script error during a headless run can leave Godot running instead of exiting; stop it if a run hangs.

## Working agreements

- **When a rule is ambiguous, stop and ask** rather than inventing one. Note the question in `docs/OPEN_QUESTIONS.md`.
- When a rule changes: update `docs/RULES.md` first, then `data/`, then tests, then code.
- Every rule implemented gets a GUT test with a fixed seed.
- Keep a headless entry point (`tools/run_battle.gd`, see Commands below) that plays a seeded battle with AI heroes and prints the event log.
- Placeholder art only (coloured rectangles, text labels) until the rules feel right.
- The project is a git repository (branch `main`). Commit everything when a milestone is complete, with the message "Milestone N complete", so there is always a working version to go back to.

## Balance baseline (Godot engine batch runner)

The Godot engine is the balance baseline; re-run the batch after rule or data changes and compare. Recorded 2026-10-26, rules v0.5 with Provoke per point (ruling #38) and the party choosing hero turn order (ruling #39; the AI picks the hero with the best-scoring play) and lost turns taking no place in the alternation for both sides (#42), `run_battle.gd --batch` (500 seeds per encounter, seeds 1-500), SimpleAiProvider heroes, level 1 party in White gear, default formation (Thief, Fighter, Cleric in front; Wizard back centre). DM modes use the greedy policy (highest-damage playable card). Standard DM is the intended default for play.

Down = battles where any hero went Down. Wounds (from damage), armor damage left and cards Exhausted are party totals per battle, averaged. No battle hit the 30-round cap.

| Encounter | DM | Party wins | Down | Rounds | Wounds | Armor left | Exhausted |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 5 goblins (`standard`) | automated | 100% | 5.6% | 3.77 | 2.96 | 5.63 | 3.48 |
| | standard | 100% | 23.4% | 3.85 | 5.31 | 6.49 | 3.46 |
| | ruthless | 99.2% | 50.0% | 4.00 | 7.99 | 7.26 | 3.43 |
| Ogre + 4 goblins (`tough`) | automated | 99.0% | 37.6% | 4.82 | 8.22 | 8.48 | 4.23 |
| | standard | 93.2% | 59.8% | 4.96 | 11.05 | 9.31 | 4.10 |
| | ruthless | 80.8% | 76.8% | 5.06 | 13.97 | 9.92 | 4.02 |
| 5 skeletons (`skeleton_band`) | automated | 100% | 0% | 2.97 | 0.78 | 4.50 | 2.58 |
| | standard | 100% | 3.0% | 2.94 | 1.59 | 5.54 | 2.58 |
| | ruthless | 100% | 9.2% | 2.90 | 2.94 | 6.49 | 2.59 |
| `wandering` | automated | 100% | 0% | 2.35 | 0.30 | 2.59 | 2.21 |
| | standard | 100% | 0% | 2.35 | 0.50 | 3.25 | 2.20 |
| | ruthless | 100% | 0% | 2.37 | 0.91 | 3.91 | 2.20 |
| `bones_stir` | automated | 100% | 0% | 1.81 | 0.02 | 2.07 | 1.49 |
| | standard | 100% | 0% | 1.72 | 0.08 | 2.73 | 1.45 |
| | ruthless | 100% | 0% | 1.67 | 0.20 | 3.33 | 1.41 |

The `witch` encounter is left out: her Bone Storm extra turn is built (ruling #45) but Bone Ward isn't, and the batch uses the level 1 party rather than a level 3 party with items. The old Python simulator in `reference/` is prototype quality and no longer the baseline; it is still useful for porting AI heuristics.

## Current status (2026-10-27)

**Done**
- Milestone 1: battle engine for rules v0.5, with rulings #1-45 recorded in `docs/RULES.md` and none open; 154 GUT tests.
- Milestone 2: battle scene with board, hand and Provoke track, click to play for every decision type, the party choosing hero order, the event log, and toggles for AI heroes and auto-continue.
- Most of Milestone 3: `SimpleAiProvider` heroes and the batch runner with three DM modes (baseline above).

**Next**
- Finish Milestone 3: stronger hero AI (heuristics can be ported from `reference/`) and fuller balance reports.
- Then Milestone 4: exploration.

**Known quirks and follow-ups**
- Witch: Bone Ward isn't built. Since her extra turn landed she beats a level 1 party 82% / 94% / 99% of the time (automated / standard / ruthless DM). Re-check her against a level 3 party with items once Milestone 5 exists, then add her to the baseline.
- Campaign balance: the baseline is per battle. Once runs and camping exist (Milestones 4-5), re-check balance over whole runs under the standard DM, the intended default for play.
- The battle scene redraws when the engine pauses instead of animating from events, and it has no automated tests (checked by screenshots).

## Milestones

1. Battle engine, headless, with tests (no UI).
2. Minimal battle UI: boards, hands, Provoke track, click to play.
3. Hero AI + headless balance runner (thousands of seeded battles, summary stats).
4. Exploration: tiles, rooms, skill rolls, Hut track, camping.
5. Loot, equipment, levels, runs, town, wipes.
6. The witch boss and the full Witch's Hut module.
7. Later: export card data to printable sheets for the tabletop version.
