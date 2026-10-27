extends GutTest

## CLAUDE.md rule 3: all randomness goes through one seeded RNG, so a battle replays from its seed.

func test_same_seed_gives_same_shuffle():
    var x: Array = range(30)
    var y: Array = range(30)
    SeededRng.new(7).shuffle(x)
    SeededRng.new(7).shuffle(y)
    assert_eq(x, y)
    assert_ne(x, range(30), "Shuffle should change the order")

func test_shuffle_ignores_the_global_rng():
    var x: Array = range(30)
    SeededRng.new(7).shuffle(x)
    seed(12345)
    randi()
    var y: Array = range(30)
    SeededRng.new(7).shuffle(y)
    assert_eq(x, y)

func test_different_seeds_give_different_shuffles():
    var x: Array = range(30)
    var y: Array = range(30)
    SeededRng.new(1).shuffle(x)
    SeededRng.new(2).shuffle(y)
    assert_ne(x, y)

func test_a_whole_battle_replays_from_its_seed():
    var data: Dictionary = BattleFixture.data()
    var a := BattleSetup.create(data, data["encounters"]["tough"], 42, SimpleAiProvider.new())
    var b := BattleSetup.create(data, data["encounters"]["tough"], 42, SimpleAiProvider.new())
    var c := BattleSetup.create(data, data["encounters"]["tough"], 43, SimpleAiProvider.new())
    a.run()
    b.run()
    c.run()
    assert_eq(a.log.to_text(), b.log.to_text())
    assert_ne(a.log.to_text(), c.log.to_text())
