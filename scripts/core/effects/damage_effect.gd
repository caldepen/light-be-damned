class_name DamageEffect
extends EffectHandler

## "damage": a hero attack (RULES §6). Areas: single, adjacent, row, area2x2, chain, split.
## Melee needs reach, allowing the free step unless the card moves the hero itself (RULES §5).

func op_name() -> String:
    return "damage"

func is_legal(ctx: EffectContext) -> bool:
    match ctx.area():
        "single":
            return not single_targets(ctx).is_empty()
        "adjacent":
            return not adjacent_positions(ctx).is_empty()
        "row":
            if String(ctx.effect.get("row", "")) == "enemy_front":
                return ctx.battle.enemy_front_row_y() >= 0
            return not row_options(ctx).is_empty()
        "area2x2":
            return not area_options(ctx).is_empty()
    return not ctx.battle.standing_enemies().is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var hits: Array[FigureState] = []
    match ctx.area():
        "single":
            var target: EnemyState = battle.ask(DecisionRequest.TARGET, ctx.hero, single_targets(ctx), ctx.card, _details(ctx))
            if target == null:
                return
            step_into_reach_if_needed(ctx, target)
            _hit(ctx, target, hits)
        "adjacent":
            var position: Vector2i = battle.ask(DecisionRequest.MELEE_POSITION, ctx.hero, adjacent_positions(ctx), ctx.card, _details(ctx))
            if position != ctx.hero.cells[0]:
                var step: Array[Vector2i] = [position]
                battle.move_figure(ctx.hero, step, "free step")
            for e in battle.enemies_within_1_of(ctx.hero.cells):
                _hit(ctx, e, hits)
        "row":
            var y: int = battle.enemy_front_row_y()
            if String(ctx.effect.get("row", "")) != "enemy_front":
                y = battle.ask(DecisionRequest.ROW, ctx.hero, row_options(ctx), ctx.card, _details(ctx))
            for e in battle.enemies_in_cells(Battle.row_cells(y)):
                _hit(ctx, e, hits)
        "area2x2":
            var corner: Vector2i = battle.ask(DecisionRequest.AREA, ctx.hero, area_options(ctx), ctx.card, _details(ctx))
            for e in battle.enemies_in_cells(Field.block_cells(corner)):
                _hit(ctx, e, hits)
        "chain":
            var max_targets: int = int(ctx.effect.get("targets", 1))
            var options: Array = battle.standing_enemies()
            while hits.size() < max_targets and not options.is_empty():
                var next: EnemyState = battle.ask(DecisionRequest.TARGET, ctx.hero, options, ctx.card, _details(ctx))
                var last_cells: Array[Vector2i] = next.cells.duplicate()
                _hit(ctx, next, hits)
                options = []
                for e in battle.enemies_within_1_of(last_cells):
                    if not hits.has(e):
                        options.append(e)
        "split":
            _resolve_split(ctx, hits)
    ctx.set_targets(hits)
    if not hits.is_empty():
        ctx.earned_provoke = true

## Single-target candidates: any enemy for Ranged; for melee, who is in reach (see RULES §5).
func single_targets(ctx: EffectContext) -> Array:
    var battle: Battle = ctx.battle
    var hero: HeroState = ctx.hero
    var pool: Array[EnemyState] = []
    var earlier_move: Dictionary = ctx.earlier_move()
    if not ctx.is_melee():
        pool = battle.standing_enemies()
    elif ctx.planned_target != null:
        if ctx.planned_target.standing and (ctx.dry_run or battle.in_reach(hero, ctx.planned_target)):
            pool.append(ctx.planned_target as EnemyState)
    elif ctx.dry_run and not earlier_move.is_empty():
        pool = Targeting.reachable_via_move(battle, hero, earlier_move)
    elif ctx.moved_by_card or not earlier_move.is_empty():
        pool = battle.enemies_within_1_of(hero.cells)
    else:
        pool = Targeting.melee_targets(battle, hero, true)
    if String(ctx.effect.get("target", "")) == "weakest_enemy":
        var weakest: Array[EnemyState] = Targeting.weakest(battle.standing_enemies())
        var kept: Array[EnemyState] = []
        for e in pool:
            if weakest.has(e):
                kept.append(e)
        pool = kept
    if ctx.is_melee() and hero.statuses.has("berserk"):
        pool = Targeting.strongest(pool)
    return pool

## Where an Adjacent attack can be made from: here, or after the free step, if any enemy is in reach.
func adjacent_positions(ctx: EffectContext) -> Array:
    var battle: Battle = ctx.battle
    var hero: HeroState = ctx.hero
    var positions: Array = []
    if not battle.enemies_within_1_of(hero.cells).is_empty():
        positions.append(hero.cells[0])
    if not ctx.moved_by_card and ctx.earlier_move().is_empty():
        for cell in Targeting.free_step_cells(battle, hero):
            if not battle.enemies_within_1_of([cell]).is_empty():
                positions.append(cell)
    return positions

func row_options(ctx: EffectContext) -> Array:
    var options: Array = []
    for y in range(Field.HEIGHT):
        if not ctx.battle.enemies_in_cells(Battle.row_cells(y)).is_empty():
            options.append(y)
    return options

func area_options(ctx: EffectContext) -> Array:
    var options: Array = []
    for corner in Field.block_corners():
        if not ctx.battle.enemies_in_cells(Field.block_cells(corner)).is_empty():
            options.append(corner)
    return options

## Melee without card movement: take the free step if the target is not yet in reach.
func step_into_reach_if_needed(ctx: EffectContext, target: FigureState) -> void:
    if not ctx.is_melee() or ctx.moved_by_card or not ctx.earlier_move().is_empty():
        return
    if ctx.battle.in_reach(ctx.hero, target):
        return
    var cell: Vector2i = ctx.battle.ask(DecisionRequest.FREE_STEP, ctx.hero, Targeting.step_cells_reaching(ctx.battle, ctx.hero, target), ctx.card, _details(ctx))
    var step: Array[Vector2i] = [cell]
    ctx.battle.move_figure(ctx.hero, step, "free step")

## Split: `bolts` hits divided among up to `targets` enemies, or one hit on each of up to `targets` enemies.
func _resolve_split(ctx: EffectContext, hits: Array[FigureState]) -> void:
    var battle: Battle = ctx.battle
    var max_targets: int = int(ctx.effect.get("targets", 1))
    var bolts: int = int(ctx.effect.get("bolts", 0))
    if bolts > 0:
        for b in range(bolts):
            var options: Array = []
            for e in battle.standing_enemies():
                if hits.size() < max_targets or hits.has(e):
                    options.append(e)
            if options.is_empty():
                break
            _hit(ctx, battle.ask(DecisionRequest.TARGET, ctx.hero, options, ctx.card, _details(ctx)), hits)
    else:
        for i in range(max_targets):
            var options: Array = []
            for e in battle.standing_enemies():
                if not hits.has(e):
                    options.append(e)
            if options.is_empty():
                break
            _hit(ctx, battle.ask(DecisionRequest.TARGET, ctx.hero, options, ctx.card, _details(ctx)), hits)

## One damage instance: printed amount plus bonuses, then any multiplier against undead (RULES §6, §10).
func _hit(ctx: EffectContext, target: EnemyState, hits: Array[FigureState]) -> void:
    var amount: int = hit_amount(ctx, target)
    ctx.battle.damage(target, amount, ctx.actor, true)
    if not hits.has(target):
        hits.append(target)

static func hit_amount(ctx: EffectContext, target: EnemyState) -> int:
    var amount: int = ctx.amount() + ctx.damage_bonus
    if target.undead:
        amount *= int(ctx.effect.get("undead_multiplier", 1))
    return maxi(0, amount)

func _details(ctx: EffectContext) -> Dictionary:
    return {"purpose": "damage", "amount": ctx.amount() + ctx.damage_bonus, "effect": ctx.effect}
