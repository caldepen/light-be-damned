class_name DamageResolver
extends RefCounted

## Damage in the order of RULES §6: Iron Skin can cancel an attack; Guard tokens absorb first;
## then armor and shield slots fill; then each point is a Wound (heroes) or a marked Hit Die (enemies).
## Thorns reflects the points that got past Guard back at an attacking enemy.

## Returns the points that got past Guard. `source` may be null (Bleed).
static func apply(battle: Battle, target: FigureState, amount: int, source: FigureState, is_attack: bool) -> int:
    if target == null or target.down or amount <= 0:
        return 0
    var source_id: String = source.id if source != null else ""
    if is_attack and target.statuses.has("ignore_next_attack"):
        target.statuses.erase("ignore_next_attack")
        battle.emit("attack_ignored", "%s ignores the attack (Iron Skin)." % target.name, {"target": target.id, "source": source_id})
        return 0
    var absorbed: int = mini(target.guard_tokens, amount)
    target.guard_tokens -= absorbed
    var passed: int = amount - absorbed
    var to_armor: int = mini(passed, target.unmarked_armor())
    var rest: int = passed - to_armor
    if target is EnemyState:
        rest = mini(rest, (target as EnemyState).unmarked_hd())
    var kind: String = "Wounds" if target.is_hero() else "Hd"
    battle.emit("damage", "%s takes %d%s: guard %d, armor %d, %s %d." % [
            target.name, amount, " from " + source.name if source != null else "", absorbed, to_armor, kind, rest],
        {"target": target.id, "source": source_id, "amount": amount, "guard": absorbed, "armor": to_armor,
            "rest": rest, "is_attack": is_attack})
    target.armor_damage += to_armor
    var landed: int = to_armor
    if target is HeroState:
        for i in range(rest):
            if target.down:
                break
            battle.add_wound(target)
            landed += 1
    else:
        var enemy: EnemyState = target
        enemy.marked_hd += rest
        landed += rest
        if enemy.marked_hd >= enemy.hit_dice:
            battle.knock_down(enemy)
    # Only attacks count for Provoke; Thorns and Bleed are not attacks (RULES §6 Provoke).
    if is_attack:
        battle.count_points(source, landed)
    if is_attack and passed > 0 and target.statuses.has("thorns") and source is EnemyState and source.standing:
        battle.emit("thorns", "Thorns reflects %d to %s." % [passed, source.name], {"target": source.id, "source": target.id, "amount": passed})
        apply(battle, source, passed, target, false)
    return passed
