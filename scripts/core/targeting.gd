class_name Targeting
extends RefCounted

## Queries about who a hero can hit and from where (RULES §5 Movement, §6 Attacks). No state changes.

## Empty squares one straight step away: the free step before a melee attack, on either board.
static func free_step_cells(battle: Battle, hero: HeroState) -> Array[Vector2i]:
    return battle.field.straight_steps(hero.cells[0])

## Enemies the hero can melee: in reach now, or after the free step when it is allowed.
static func melee_targets(battle: Battle, hero: HeroState, allow_free_step: bool) -> Array[EnemyState]:
    var result: Array[EnemyState] = battle.enemies_within_1_of(hero.cells)
    if allow_free_step:
        for cell in free_step_cells(battle, hero):
            for e in battle.enemies_within_1_of([cell]):
                if not result.has(e):
                    result.append(e)
    return result

## Free-step squares from which `target` is in reach.
static func step_cells_reaching(battle: Battle, hero: HeroState, target: FigureState) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for cell in free_step_cells(battle, hero):
        if Field.cells_distance([cell], target.cells) <= 1:
            result.append(cell)
    return result

## Empty squares (either board) within melee reach of `target`; the mover's own square counts as empty.
static func cells_in_reach_of(battle: Battle, target: FigureState, mover: FigureState) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for cell in Field.all_cells():
        if battle.field.is_empty(cell, mover) and Field.cells_distance([cell], target.cells) <= 1:
            result.append(cell)
    return result

## The closest of `cells_in_reach_of` to the mover (counting diagonals as 1); ties are all returned.
static func nearest_cells_in_reach(battle: Battle, target: FigureState, mover: FigureState) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    var best_d: int = 1000
    for cell in cells_in_reach_of(battle, target, mover):
        var d: int = Field.distance(mover.cells[0], cell)
        if d < best_d:
            best_d = d
            best = [cell]
        elif d == best_d:
            best.append(cell)
    return best

## Enemies a "move to the nearest square in melee reach" card can go after (optionally only the weakest).
static func move_to_reach_candidates(battle: Battle, hero: HeroState, move_effect: Dictionary) -> Array[EnemyState]:
    var pool: Array[EnemyState] = battle.standing_enemies()
    if String(move_effect.get("of", "")) == "weakest_enemy":
        pool = weakest(pool)
    var result: Array[EnemyState] = []
    for e in pool:
        if battle.in_reach(hero, e) or not cells_in_reach_of(battle, e, hero).is_empty():
            result.append(e)
    return result

## Squares a "move up to N" card can end on (the current square included).
static func up_to_cells(battle: Battle, hero: HeroState, move_effect: Dictionary) -> Array[Vector2i]:
    var result: Array[Vector2i] = [hero.cells[0]]
    var allow_enemy_board: bool = bool(move_effect.get("allow_enemy_board", false))
    for cell in battle.field.cells_within_steps(hero.cells[0], int(move_effect.get("squares", 1))):
        if allow_enemy_board or Field.board_of(cell) == hero.side:
            result.append(cell)
    return result

## Enemies a melee effect could reach once the card's own movement (before it) has happened.
static func reachable_via_move(battle: Battle, hero: HeroState, move_effect: Dictionary) -> Array[EnemyState]:
    var mode: String = String(move_effect.get("mode", ""))
    if mode == "to_melee_reach":
        return move_to_reach_candidates(battle, hero, move_effect)
    if mode == "up_to":
        var result: Array[EnemyState] = []
        for cell in up_to_cells(battle, hero, move_effect):
            for e in battle.enemies_within_1_of([cell]):
                if not result.has(e):
                    result.append(e)
        return result
    return melee_targets(battle, hero, false)

static func weakest(pool: Array[EnemyState]) -> Array[EnemyState]:
    var result: Array[EnemyState] = []
    var best: int = 100000
    for e in pool:
        var p: int = e.power()
        if p < best:
            best = p
            result = [e]
        elif p == best:
            result.append(e)
    return result

static func strongest(pool: Array[EnemyState]) -> Array[EnemyState]:
    var result: Array[EnemyState] = []
    var best: int = -1
    for e in pool:
        var p: int = e.power()
        if p > best:
            best = p
            result = [e]
        elif p == best:
            result.append(e)
    return result
