# Reference simulator (Python)

Prototype code used to balance rules v0.5 in design conversations. It is **not** part of the Godot project and is not clean code: `sim.py` holds the battle rules and hero AI heuristics, and `hut.py` adds Hit Dice enemies, the witch and skeletons, exploration, loot, levels and runs. Defaults in `hut.py` match rules v0.5.

    python3 hut.py 100

Useful for: porting the hero AI heuristics (`sim.choose`), and checking that the Godot engine produces similar balance numbers.
Known simplifications: some item effects are approximated (Staff of Embers and Bow of the Hunter boost all attacks; Shadowfang, Boots and Healer's Satchel are not modelled), and room/tile weights are assumptions.
