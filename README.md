# Card RPG — Godot starter kit

1. Create a new Godot 4 project (or open an empty folder) and copy everything in this kit into the project root.
2. Install the **GUT** add-on (Godot Unit Test) from the Godot Asset Library, for the tests.
3. In VS Code, install the **godot-tools** extension and point Godot's external editor at VS Code (Editor Settings → Text Editor → External).
4. Open the project folder in VS Code, start Claude, and paste the prompt from `KICKOFF_PROMPT.md`.

## What's in here

| Path | What it is |
| --- | --- |
| `CLAUDE.md` | Project brief Claude reads automatically: architecture rules, layout, milestones, balance references |
| `KICKOFF_PROMPT.md` | The first prompt to paste (Milestone 1: headless battle engine + tests) |
| `docs/RULES.md` | The tabletop rules, v0.5 (source of truth) |
| `docs/DATA_SCHEMA.md` | How the JSON data and effect ops work |
| `data/rules.json` | Tunable rule numbers |
| `data/heroes.json` | Four heroes, 30-card decks with skill values, advancement cards |
| `data/enemies.json` | Goblin, ogre, skeleton, witch: stats, action decks, encounters |
| `data/items.json` | White gear, loot deck, consumables |
| `data/module_witch_hut.json` | Module 1: room tiles, room types, room decks, Hut track, Hut Whims |
| `reference/` | The Python simulator used for balancing (prototype code, for reference only) |

Run `python3 reference/hut.py` style experiments only if you want to compare numbers; the Godot project doesn't depend on it.
