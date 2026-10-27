class_name SimpleAiProvider
extends DecisionProvider

## Heuristic hero AI for simulation and auto-play: heal the most-wounded hero, keep the tank on
## top of the Provoke track, otherwise deal the most damage, preferring kills. Flip when nothing
## in hand is worth much.

const FLIP_THRESHOLD := 1.0

func decide(request: DecisionRequest, battle: Battle) -> int:
    match request.kind:
        DecisionRequest.NEXT_HERO:
            return _best_index(request.options, func(h: HeroState) -> float: return _best_play_score(battle, h))
        DecisionRequest.TURN:
            return _choose_turn(request, battle)
        DecisionRequest.TARGET, DecisionRequest.MOVE_TARGET:
            return _choose_target(request, battle)
        DecisionRequest.MELEE_POSITION:
            return _best_index(request.options, func(cell: Vector2i) -> float: return float(battle.enemies_within_1_of([cell]).size()))
        DecisionRequest.ROW:
            return _best_index(request.options, func(y: int) -> float: return float(battle.enemies_in_cells(Battle.row_cells(y)).size()))
        DecisionRequest.AREA:
            return _best_index(request.options, func(corner: Vector2i) -> float: return _area_value(battle, corner))
        DecisionRequest.DAMAGE_OPTION:
            return _best_index(request.options, func(option: Dictionary) -> float: return _option_value(battle, option))
        DecisionRequest.MOVE_SQUARE:
            if String(request.details.get("purpose", "")) == "retreat":
                return _best_index(request.options, func(cell: Vector2i) -> float: return float(cell.y))
            return 0
        DecisionRequest.OPTIONAL_MOVE:
            return request.options.find(true)
        DecisionRequest.WOUND_DISCARD, DecisionRequest.FORCED_DISCARD:
            return _best_index(request.options, func(card: Card) -> float: return -CardScorer.keep_value(card))
        DecisionRequest.CLEANSE_SPLIT:
            return 0  # options are listed most Wounds first
        DecisionRequest.RECOVER_CARD:
            return _best_index(request.options, func(card: Variant) -> float: return -1.0 if card == null else CardScorer.keep_value(card))
        DecisionRequest.PEEK_ORDER:
            return _best_index(request.options, func(order: Array) -> float: return -_ai_value(order[0]))
    return 0

func _choose_turn(request: DecisionRequest, battle: Battle) -> int:
    var best_index: int = -1
    var best_score: float = -1000.0
    var flip_index: int = -1
    var pass_index: int = -1
    for i in range(request.options.size()):
        var option: TurnOption = request.options[i]
        match option.kind:
            TurnOption.PLAY:
                var s: float = CardScorer.score(battle, request.hero, option.card)
                if s > best_score:
                    best_score = s
                    best_index = i
            TurnOption.FLIP:
                flip_index = i
            TurnOption.PASS:
                pass_index = i
    if best_index >= 0 and best_score >= FLIP_THRESHOLD:
        return best_index
    if flip_index >= 0:
        return flip_index
    if best_index >= 0 and best_score > 0.0:
        return best_index
    return pass_index

## Who acts next: the hero whose best legal card scores highest (0 with none). Options come in the
## old fixed order and _best_index keeps the first of equal scores, so ties go to that order.
func _best_play_score(battle: Battle, hero: HeroState) -> float:
    var best: float = 0.0
    for card in CardRunner.legal_hand_cards(battle, hero):
        best = maxf(best, CardScorer.score(battle, hero, card))
    return best

func _choose_target(request: DecisionRequest, battle: Battle) -> int:
    var purpose: String = String(request.details.get("purpose", ""))
    var amount: int = int(request.details.get("amount", 0))
    match purpose:
        "damage":
            return _best_index(request.options, func(f: FigureState) -> float:
                var kill: float = 100.0 if amount >= battle.toughness(f) else 0.0
                return kill - float(f.power()))
        "heal", "transfer":
            return _best_index(request.options, func(h: HeroState) -> float: return float(h.wound_count()))
        "cleanse":
            return _best_index(request.options, func(h: HeroState) -> float: return float(h.wound_count()) * 3.0 + float(h.armor_damage))
        "guard", "buff":
            var top: HeroState = battle.top_hero()
            return maxi(0, request.options.find(top))
        "bleed", "stun":
            return _best_index(request.options, func(f: FigureState) -> float: return float(f.power()))
        "recover":
            return maxi(0, request.options.find(request.hero))
    return 0

func _area_value(battle: Battle, corner: Vector2i) -> float:
    var cells: Array[Vector2i] = Field.block_cells(corner)
    var value: float = float(battle.enemies_in_cells(cells).size()) * 2.0
    for h in battle.heroes_in_cells(cells):
        if h.wound_count() > 0 or h.armor_damage > 0:
            value += 2.0
    return value

func _option_value(battle: Battle, option: Dictionary) -> float:
    var value: float = 0.0
    for t in option["targets"]:
        var f: FigureState = t
        value += float(option["amount"])
        if int(option["amount"]) >= battle.toughness(f):
            value += CardScorer.KILL_BONUS
    return value

func _ai_value(card_def: Dictionary) -> float:
    var v: Variant = card_def.get("ai_value", 0)
    return float(v) if typeof(v) != TYPE_STRING else 1.0

func _best_index(options: Array, value_of: Callable) -> int:
    var best: int = 0
    var best_value: float = -INF
    for i in range(options.size()):
        var v: float = value_of.call(options[i])
        if v > best_value:
            best_value = v
            best = i
    return best
