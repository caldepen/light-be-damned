class_name ProvokeTrack
extends RefCounted

## The shared Provoke track (RULES §6). Each space holds a stack of tokens; a token moving
## onto a space goes on top, and the top token counts as highest. A token that gains at the
## cap goes on top of the cap stack; a token that loses at 0 stays where it is.

var track_max: int = 20
var _values: Dictionary = {}   # HeroState -> int
var _arrival: Dictionary = {}  # HeroState -> int; higher = nearer the top of its stack
var _clock: int = 0

## `top_to_bottom`: the starting stack on 0, top first.
func setup(top_to_bottom: Array[HeroState], max_value: int) -> void:
    track_max = max_value
    _values.clear()
    _arrival.clear()
    _clock = 0
    for i in range(top_to_bottom.size() - 1, -1, -1):
        _clock += 1
        _values[top_to_bottom[i]] = 0
        _arrival[top_to_bottom[i]] = _clock

func value_of(hero: HeroState) -> int:
    return int(_values.get(hero, 0))

## Move a token by `delta`. Returns the change actually made.
func move(hero: HeroState, delta: int) -> int:
    var old: int = value_of(hero)
    var new_value: int = clampi(old + delta, 0, track_max)
    if new_value == old and not (delta > 0 and old == track_max):
        return 0
    _values[hero] = new_value
    _clock += 1
    _arrival[hero] = _clock
    return new_value - old

func set_value(hero: HeroState, value: int) -> int:
    return move(hero, value - value_of(hero))

## True if `a` is above `b` on the track.
func is_above(a: HeroState, b: HeroState) -> bool:
    var va: int = value_of(a)
    var vb: int = value_of(b)
    if va != vb:
        return va > vb
    return int(_arrival.get(a, 0)) > int(_arrival.get(b, 0))

## Candidates sorted top first.
func ordered(candidates: Array[HeroState]) -> Array[HeroState]:
    var result: Array[HeroState] = candidates.duplicate()
    result.sort_custom(func(a: HeroState, b: HeroState) -> bool: return is_above(a, b))
    return result

func top(candidates: Array[HeroState]) -> HeroState:
    if candidates.is_empty():
        return null
    return ordered(candidates)[0]

func bottom(candidates: Array[HeroState]) -> HeroState:
    if candidates.is_empty():
        return null
    var o: Array[HeroState] = ordered(candidates)
    return o[o.size() - 1]
