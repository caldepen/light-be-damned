class_name MoveEffect
extends EffectHandler

## "move": card movement (RULES §5). A card that moves you replaces the free step.
## Hero modes: to_melee_reach, up_to, step_back, teleport_own_board (any empty square on your
## own board: Blink, Smoke Bomb, Calculated Retreat). Enemy modes are in EnemyMoves.

func op_name() -> String:
    return "move"

func is_legal(ctx: EffectContext) -> bool:
    var mode: String = String(ctx.effect.get("mode", ""))
    if ctx.actor is EnemyState:
        if mode == "vault_to_hero_middle_row":
            return not EnemyMoves.vault_cells(ctx.battle, ctx.enemy).is_empty()
        return true
    match mode:
        "to_melee_reach":
            return not Targeting.move_to_reach_candidates(ctx.battle, ctx.hero, ctx.effect).is_empty()
        "up_to":
            return Targeting.up_to_cells(ctx.battle, ctx.hero, ctx.effect).size() > 1
        "step_back":
            return _step_back_cell(ctx) != Vector2i(-1, -1)
        "teleport_own_board":
            return not ctx.battle.field.empty_cells(Field.board_cells(ctx.actor.side)).is_empty()
    push_error("move: unknown mode '%s'." % mode)
    return false

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    if ctx.actor is EnemyState:
        EnemyMoves.perform(battle, ctx.enemy, ctx.effect)
        return
    var hero: HeroState = ctx.hero
    var mode: String = String(ctx.effect.get("mode", ""))
    ctx.moved_by_card = true
    match mode:
        "to_melee_reach":
            var target: EnemyState = battle.ask(DecisionRequest.MOVE_TARGET, hero,
                Targeting.move_to_reach_candidates(battle, hero, ctx.effect), ctx.card, {"purpose": "damage"})
            ctx.planned_target = target
            if not battle.in_reach(hero, target):
                var cell: Vector2i = battle.ask(DecisionRequest.MOVE_SQUARE, hero, Targeting.nearest_cells_in_reach(battle, target, hero), ctx.card, {"purpose": "reach"})
                _move(ctx, cell)
        "up_to":
            var options: Array = Targeting.up_to_cells(battle, hero, ctx.effect)
            var with_reach: Array = options.filter(func(c: Vector2i) -> bool: return not battle.enemies_within_1_of([c]).is_empty())
            if _melee_follows(ctx) and not with_reach.is_empty():
                options = with_reach
            _move(ctx, battle.ask(DecisionRequest.MOVE_SQUARE, hero, options, ctx.card, {"purpose": "reach"}))
        "step_back":
            var back: Vector2i = _step_back_cell(ctx)
            var go: bool = battle.ask(DecisionRequest.OPTIONAL_MOVE, hero, [false, true], ctx.card, {"cell": back})
            if go:
                _move(ctx, back)
        "teleport_own_board":
            var cells: Array = battle.field.empty_cells(Field.board_cells(hero.side))
            _move(ctx, battle.ask(DecisionRequest.MOVE_SQUARE, hero, cells, ctx.card, {"purpose": "retreat"}))

func _move(ctx: EffectContext, cell: Vector2i) -> void:
    if cell == ctx.actor.cells[0]:
        return
    var cells: Array[Vector2i] = [cell]
    ctx.battle.move_figure(ctx.actor, cells, ctx.card_name)

func _melee_follows(ctx: EffectContext) -> bool:
    for i in range(ctx.index + 1, ctx.effects.size()):
        var e: Dictionary = ctx.effects[i]
        if String(e.get("op", "")) in ["damage", "damage_choice"] and String(e.get("range", "")) == "melee":
            return true
    return false

## One square straight back toward the hero's own back row, if empty; (-1, -1) if not.
func _step_back_cell(ctx: EffectContext) -> Vector2i:
    var cell: Vector2i = ctx.actor.cells[0] + Vector2i(0, 1)
    if ctx.battle.field.is_empty(cell):
        return cell
    return Vector2i(-1, -1)
