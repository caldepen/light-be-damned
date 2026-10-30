class_name PatchUp
extends RefCounted

## Patch up after a won battle (RULES §8 After a won battle, step 2; open question #75): one card at a
## time, any standing hero may play a card from hand for its healing, repair and recovery effects,
## drawing back up to hand size, until the party stops. Only those effects happen (plus a draw on the
## same card, Greater Heal); damage, Guard and Provoke never do. The heroes stand in the party's
## formation on an empty battle board, so "adjacent" and areas work as in battle, and the cards run
## through the battle's own effect handlers with `between_battles` set (Fix Armor removes all).
## Choices go to the battle decision provider (DecisionRequest.PATCH_UP, then the usual targets).

const OPS: Array[String] = ["heal_wound", "repair_armor", "cleanse", "recover", "transfer_wounds", "consecrate"]
## Effects that go along with a patch-up effect on the same card.
const FOLLOW_UPS: Array[String] = ["draw"]

## Returns how many cards were played. `listener` gets every event (HutRun forwards them to its log).
static func play(run: HutRun, seed_in: int, listener: Callable) -> int:
    var heroes: Array[HeroState] = run.party.standing()
    if heroes.is_empty():
        return 0
    var battle := Battle.new(run.rules, run.data["enemies"], seed_in, run.battle_decisions)
    battle.between_battles = true
    battle.continue_uids(run.party.last_uid())
    battle.log.listeners.append(listener)
    for h in run.party.heroes:
        run.party.clear_battle_state(h)
    BattleSetup.add_heroes(battle, heroes, run.formation)
    var played: int = 0
    while true:
        var options: Array = [{}]
        for h in battle.standing_heroes():
            for card in h.hand:
                if is_playable(battle, h, card):
                    options.append({"hero": h, "card": card})
        if options.size() == 1:
            break
        var choice: Dictionary = battle.ask(DecisionRequest.PATCH_UP, null, options)
        if choice.is_empty():
            break
        resolve(battle, choice["hero"], choice["card"])
        played += 1
    for h in run.party.heroes:
        run.party.clear_battle_state(h)
    run.party.continue_uids(battle.last_uid())
    return played

## The effects a card has when played to patch up; empty if it has none of OPS.
static func effects_for(hero: HeroState, card: Card) -> Array:
    var effects: Array = CardRunner.effects_of(hero, card)
    if card.is_wound or not CardRunner.has_op(effects, OPS):
        return []
    var result: Array = []
    for e in effects:
        var op: String = String(e.get("op", ""))
        if OPS.has(op) or FOLLOW_UPS.has(op):
            result.append(e)
    return result

## Playable when one of its patch-up effects has a legal use (a wounded hero in reach, armor damage,
## a discard pile to recover from).
static func is_playable(battle: Battle, hero: HeroState, card: Card) -> bool:
    var effects: Array = effects_for(hero, card)
    var ctx := EffectContext.new(battle, hero, card.def, effects, card)
    ctx.dry_run = true
    for i in range(effects.size()):
        ctx.effect = effects[i]
        ctx.index = i
        if OPS.has(String(ctx.effect.get("op", ""))) and battle.effects.handler(String(ctx.effect["op"])).is_legal(ctx):
            return true
    return false

## Play `card` from the hero's hand: its patch-up effects, then discard or Exhaust it and draw back
## up to hand size. Wounds taken from an ally (Lay on Hands) can still put the hero Down.
static func resolve(battle: Battle, hero: HeroState, card: Card) -> void:
    var effects: Array = effects_for(hero, card)
    hero.hand.erase(card)
    battle.emit("patch_up", "%s plays %s to patch up." % [hero.name, card.name], {"hero": hero.id, "card": card.id})
    battle.acting_hero = hero
    CardRunner.run_effects(EffectContext.new(battle, hero, card.def, effects, card), effects)
    battle.acting_hero = null
    battle.put_away(hero, card)
    battle.draw_up_to_hand_size(hero)
    battle.check_spent(hero)
