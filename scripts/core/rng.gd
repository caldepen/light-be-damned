class_name SeededRng
extends RefCounted

## The one source of randomness for a battle. Every shuffle and random pick goes
## through here, so a battle replays exactly from its seed.

var seed_value: int = 1
var _rng: RandomNumberGenerator

func _init(seed_in: int = 1) -> void:
    seed_value = seed_in
    _rng = RandomNumberGenerator.new()
    _rng.seed = seed_in

func reset(seed_in: int = -1) -> void:
    if seed_in >= 0:
        seed_value = seed_in
    _rng.seed = seed_value

func next_float() -> float:
    return _rng.randf()

## A random int in [0, max_value). Returns 0 when max_value <= 0.
func next_index(max_value: int) -> int:
    if max_value <= 0:
        return 0
    return _rng.randi_range(0, max_value - 1)

func int_range(min_value: int, max_value: int) -> int:
    return _rng.randi_range(min_value, max_value)

## Fisher-Yates shuffle using this RNG (Array.shuffle() would use the global RNG).
func shuffle(array: Array) -> void:
    for i in range(array.size() - 1, 0, -1):
        var j: int = _rng.randi_range(0, i)
        var tmp: Variant = array[i]
        array[i] = array[j]
        array[j] = tmp

func pick(array: Array) -> Variant:
    if array.is_empty():
        return null
    return array[next_index(array.size())]
