class_name ThrowAllyEffect
extends EffectHandler

## "throw_ally": the ogre throws an enemy of `type` from the enemy board into an empty square of the
## heroes' back row; it lands with `landing_damage` to the highest-Provoke hero within 1 square.
## With no such ally or square, run `fallback` (a thrown rock).

func op_name() -> String:
    return "throw_ally"

func resolve(ctx: EffectContext) -> void:
    var battle: Battle = ctx.battle
    var allies: Array[EnemyState] = []
    for e in battle.standing_enemies():
        if e != ctx.actor and e.enemy_type == String(ctx.effect.get("type", "")) and e.cells.size() == 1 and Field.board_of(e.cells[0]) == FigureState.SIDE_ENEMIES:
            allies.append(e)
    var spots: Array[Vector2i] = battle.field.empty_cells(Battle.row_cells(Field.HEIGHT - 1))
    if allies.is_empty() or spots.is_empty():
        CardRunner.run_effects(ctx, ctx.effect.get("fallback", []))
        return
    var thrown: EnemyState = allies[0]
    var top: HeroState = battle.top_hero()
    var spot: Vector2i = spots[0]
    for s in spots:
        if top != null and Field.cells_distance([s], top.cells) <= 1:
            spot = s
            break
    var landing: Array[Vector2i] = [spot]
    battle.emit("throw_ally", "%s throws %s into the heroes' back row." % [ctx.actor.name, thrown.name], {"enemy": ctx.actor.id, "thrown": thrown.id})
    battle.move_figure(thrown, landing, "thrown")
    var near: Array[HeroState] = battle.heroes_within_1_of(landing)
    if not near.is_empty():
        var target: HeroState = battle.provoke.top(near)
        battle.damage(target, maxi(0, int(ctx.effect.get("landing_damage", 1))), thrown, true)
        ctx.set_targets([target])
