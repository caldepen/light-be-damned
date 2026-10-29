extends GutTest

## Milestone 4.1b: table areas collapse to a strip and expand again; a collapsed panel can peek
## open (the hand when a card must be chosen) without changing its saved state.

func _panel() -> CollapsiblePanel:
    var p: CollapsiblePanel = UiScenes.collapsible_panel("hand", "Hand", CollapsiblePanel.STRIP_ROW)
    p.add_content(Label.new())
    add_child_autofree(p)
    return p

func test_collapse_and_expand():
    var p := _panel()
    watch_signals(p)
    assert_true(p.is_open())
    p.set_collapsed(true)
    assert_false(p.is_open())
    assert_false(p.content.is_visible_in_tree(), "content hidden, only the strip shows")
    assert_signal_emitted_with_parameters(p, "collapse_toggled", [true])
    assert_signal_emitted_with_parameters(p, "open_changed", [false])
    p.set_collapsed(false)
    assert_true(p.content.is_visible_in_tree())

func test_peek_opens_without_changing_the_saved_state():
    var p := _panel()
    p.set_collapsed(true)
    watch_signals(p)
    p.set_peek(true)
    assert_true(p.is_open())
    assert_true(p.collapsed, "still collapsed in the settings")
    assert_true(p.is_auto_peek(), "opened by the table, not the mouse")
    assert_signal_not_emitted(p, "collapse_toggled")
    p.set_peek(false)
    assert_false(p.is_open())

func test_peek_does_nothing_on_an_open_panel():
    var p := _panel()
    p.set_peek(true)
    assert_false(p.peeking)

func test_the_hand_wants_attention_only_for_card_choices():
    var hero := HeroState.new()
    var card := Card.new(1, {"id": "test", "name": "Test"})
    hero.hand.append(card)
    var turn := DecisionRequest.new(DecisionRequest.TURN, hero, [TurnOption.new(TurnOption.PLAY, card)])
    assert_true(HandView.wants_card(turn), "a turn with a card to play")
    var flip_only := DecisionRequest.new(DecisionRequest.TURN, hero, [TurnOption.new(TurnOption.FLIP)])
    assert_false(HandView.wants_card(flip_only), "nothing playable")
    var discard := DecisionRequest.new(DecisionRequest.WOUND_DISCARD, hero, [card])
    assert_true(HandView.wants_card(discard), "a choice among hand cards")
    var target := DecisionRequest.new(DecisionRequest.MOVE_SQUARE, hero, [Vector2i(0, 3)])
    assert_false(HandView.wants_card(target), "a square to choose")
    assert_false(HandView.wants_card(null))
