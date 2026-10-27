class_name ConsecrateEffect
extends EffectHandler

## "consecrate": a 2x2 area on either board or straddling both front rows (any 2x2 block of the grid).
## Enemies in it take `enemy_damage` radiant damage (times `undead_multiplier` vs undead);
## heroes in it remove `hero_cleanse` Wounds or armor damage.

func op_name() -> String:
    return "consecrate"

func is_legal(ctx: EffectContext) -> bool:
    return not area_options(ctx).is_empty()

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var corner: Vector2i = battle.ask(DecisionRequest.AREA, ctx.hero, area_options(ctx), ctx.card, {"purpose": "consecrate"})
    var cells: Array[Vector2i] = Field.block_cells(corner)
    var hits: Array[FigureState] = []
    for e in battle.enemies_in_cells(cells):
        var amount: int = int(ctx.effect.get("enemy_damage", 0)) + ctx.damage_bonus
        if e.undead:
            amount *= int(ctx.effect.get("undead_multiplier", 1))
        battle.damage(e, maxi(0, amount), ctx.actor, true)
        hits.append(e)
    for h in _hurt_heroes(battle, cells):
        CleanseEffect.apply(ctx, h, int(ctx.effect.get("hero_cleanse", 1)))
        hits.append(h)
    ctx.set_targets(hits)
    if not hits.is_empty():
        ctx.earned_provoke = true

func area_options(ctx: EffectContext) -> Array:
    var options: Array = []
    for corner in Field.block_corners():
        var cells: Array[Vector2i] = Field.block_cells(corner)
        if not ctx.battle.enemies_in_cells(cells).is_empty() or not _hurt_heroes(ctx.battle, cells).is_empty():
            options.append(corner)
    return options

func _hurt_heroes(battle: Battle, cells: Array[Vector2i]) -> Array[HeroState]:
    var result: Array[HeroState] = []
    for h in battle.heroes_in_cells(cells):
        if h.wound_count() > 0 or h.armor_damage > 0:
            result.append(h)
    return result
