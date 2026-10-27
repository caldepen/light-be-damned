class_name EnemyMoves
extends RefCounted

## Where enemies move: the free step toward the top-Provoke hero (RULES §6, Who enemies attack)
## and the movement modes on enemy cards. Enemies follow fixed rules; no decision provider.
## preview() is used both to check whether a move-then-melee card is playable and to perform it.

## The free step: one straight step toward the top-Provoke hero, if not already in reach of them
## and the step gets closer. Returns the new cells, or [] for no step.
static func free_step(battle: Battle, enemy: EnemyState) -> Array[Vector2i]:
    var top: HeroState = battle.top_hero()
    if top == null or battle.in_reach(enemy, top):
        return []
    return step_toward(battle, enemy, top)

## One straight step (whole body) that strictly reduces the distance to `goal`; [] if none.
## Ties prefer forward, then back, then left, then right (Field.STRAIGHT_DIRECTIONS order).
static func step_toward(battle: Battle, enemy: EnemyState, goal: FigureState) -> Array[Vector2i]:
    var best: Array[Vector2i] = []
    var best_d: int = Field.cells_distance(enemy.cells, goal.cells)
    for d in Field.STRAIGHT_DIRECTIONS:
        var moved: Array[Vector2i] = Field.shifted(enemy.cells, d)
        if not battle.field.are_empty(moved, enemy):
            continue
        var dist: int = Field.cells_distance(moved, goal.cells)
        if dist < best_d:
            best_d = dist
            best = moved
    return best

## Where a card's move effect would put the enemy (its current cells if it can't move).
static func preview(battle: Battle, enemy: EnemyState, move_effect: Dictionary) -> Array[Vector2i]:
    var top: HeroState = battle.top_hero()
    var mode: String = String(move_effect.get("mode", ""))
    var options: Array = []
    match mode:
        "step_toward_top_provoke":
            if top != null and not battle.in_reach(enemy, top):
                var step: Array[Vector2i] = step_toward(battle, enemy, top)
                if not step.is_empty():
                    return step
            return enemy.cells
        "shift_lane":
            for d in [Vector2i(-1, 0), Vector2i(1, 0)]:
                var moved: Array[Vector2i] = Field.shifted(enemy.cells, d)
                if battle.field.are_empty(moved, enemy):
                    options.append(moved)
        "along_own_front_row":
            if enemy.cells.size() == 1:
                for cell in Battle.row_cells(Field.ENEMY_FRONT_Y):
                    if battle.field.is_empty(cell, enemy):
                        var one: Array[Vector2i] = [cell]
                        options.append(one)
        "vault_to_hero_middle_row":
            for cell in vault_cells(battle, enemy):
                var one: Array[Vector2i] = [cell]
                options.append(one)
    if options.is_empty():
        return enemy.cells
    var best: Array[Vector2i] = options[0]
    for o in options:
        if _score(battle, o, top) > _score(battle, best, top):
            best = o
    return best

## Vault: an empty hero middle-row square directly behind a standing front-row hero (RULES §7).
static func vault_cells(battle: Battle, enemy: EnemyState) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if enemy.cells.size() != 1:
        return result
    for lane in range(Field.LANES):
        var front: FigureState = battle.field.figure_at(Vector2i(lane, Field.HERO_FRONT_Y))
        var behind := Vector2i(lane, Field.HERO_FRONT_Y + 1)
        if front is HeroState and battle.field.is_empty(behind):
            result.append(behind)
    return result

static func perform(battle: Battle, enemy: EnemyState, move_effect: Dictionary) -> void:
    var cells: Array[Vector2i] = preview(battle, enemy, move_effect)
    if cells != enemy.cells:
        battle.move_figure(enemy, cells, String(move_effect.get("mode", "move")))

## Prefer squares in reach of the top hero, then in reach of any hero, then closer to the top hero.
static func _score(battle: Battle, cells: Array[Vector2i], top: HeroState) -> int:
    var s: int = 0
    if top != null:
        if Field.cells_distance(cells, top.cells) <= 1:
            s += 100
        s -= Field.cells_distance(cells, top.cells)
    if not battle.heroes_within_1_of(cells).is_empty():
        s += 50
    return s
