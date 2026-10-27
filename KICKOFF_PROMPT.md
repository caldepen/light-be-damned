# Kickoff prompt for Claude in VS Code

Copy everything below the line into Claude in VS Code, with the Godot project folder open.

---

I'm building a digital prototype of my tabletop card RPG in **Godot 4** (GDScript). Please start by reading `CLAUDE.md`, `docs/RULES.md` and `docs/DATA_SCHEMA.md`, and skim the files in `data/`.

**Goal for this session: Milestone 1, a headless battle engine with tests. No UI yet.**

Before writing code, give me:
1. A short plan: the classes you'll create in `scripts/core/`, how effects are dispatched from the JSON `op` field, and how decisions (card, target, square) are requested from a decision provider.
2. A list of any rules in `docs/RULES.md` that are ambiguous for implementation. Ask me about them instead of guessing.

Wait for my go-ahead on the plan, then build:

- **Data loading and validation** (`scripts/data/`): load all `data/*.json`; fail with a clear error on unknown ops, missing IDs, decks that aren't 30 cards, or skill values that aren't five of each 1–6.
- **Battle state**: two 3×3 boards, figure placement (heroes from `rules.json` default formation; enemies fill front row first), 2×2 enemies, turn order (alternate one figure at a time starting with a hero; front row first, then left to right; the side with figures left finishes the round).
- **Hero turns**: play from hand or flip from deck; draw-to-replace; no draws while at or above hand size; Exhaust; empty deck rule; cards owed from Disarm/Hex drawn at turn start.
- **Movement**: one free straight step before a melee attack; straight moves only (no diagonals) unless a card says otherwise; melee reach of 1 including diagonals; ranged reaches anything.
- **Provoke track**: +1 per card that deals damage, heals or repairs; card-named Provoke; ties go to the token that arrived last.
- **Damage**: Guard tokens (one Guard card per hero, stacking, discarded at the end of the next round), then armor slots, then Wound cards into the hand (the player discards a card of their choice); all Wounds = Down.
- **Enemies**: Hit Dice, shared decks per type with reshuffle, Draw count, morale (Bold / Timid / Desperate), phase (◆) and top-tier (▲) cards, Go Fish, Melee/Throw goblin cards, free step toward the top-Provoke hero.
- **Effect handlers** for every op used by the four starting decks and the goblin, ogre and skeleton decks. The witch can wait for a later milestone.
- **End of round**: Bleed, Stun, Guard expiry.
- **Event log** for everything that happens.
- **A simple AI decision provider** so a battle can run with no human: e.g. heal the most-wounded hero, keep the fighter on top of the Provoke track, otherwise pick the card dealing the most damage, preferring kills.
- **GUT tests** with fixed seeds for each rule above.
- **A headless runner** (`tools/run_battle.gd`) that plays one seeded battle (four level 1 heroes vs 5 goblins, and vs an ogre + 4 goblins) and prints the event log and the result.

Keep `scripts/core/` free of Node and scene dependencies. Show me the test results and a sample battle log at the end.
