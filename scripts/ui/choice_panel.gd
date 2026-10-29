class_name ChoicePanel
extends VBoxContainer

## The prompt for the pending request: Play / Flip / Pass on a hero's turn, a button per option
## for every other request (the board and hand offer the same options by clicking), and the
## turn summary with Continue after an enemy turn.

signal option_chosen(index: int)
signal play_pressed
signal continue_pressed

var _prompt := Label.new()
var _options := HFlowContainer.new()
var _buttons := HBoxContainer.new()
var _play := Button.new()
var _flip := Button.new()
var _pass := Button.new()
var _continue := Button.new()
var _summary := RichTextLabel.new()
var _flip_index: int = -1
var _pass_index: int = -1

func _init() -> void:
    _prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _prompt.add_theme_font_size_override("font_size", 16)
    add_child(_prompt)
    add_child(_options)
    _play.text = "Play"
    _flip.text = "Flip"
    _pass.text = "Pass"
    _continue.text = "Continue"
    for b in [_play, _flip, _pass, _continue]:
        (b as Button).custom_minimum_size = Vector2(90, 34)
        _buttons.add_child(b)
    add_child(_buttons)
    _summary.fit_content = true
    _summary.scroll_active = false
    _summary.custom_minimum_size = Vector2(0, 0)
    add_child(_summary)
    _play.pressed.connect(func() -> void: play_pressed.emit())
    _flip.pressed.connect(func() -> void: option_chosen.emit(_flip_index))
    _pass.pressed.connect(func() -> void: option_chosen.emit(_pass_index))
    _continue.pressed.connect(func() -> void: continue_pressed.emit())

func show_decision(request: DecisionRequest, selected: Card) -> void:
    _clear()
    _prompt.text = UiText.prompt(request)
    if request.kind == DecisionRequest.TURN:
        _play.visible = true
        _flip.visible = true
        _pass.visible = true
        _play.disabled = selected == null
        if selected != null:
            _prompt.text += "\nSelected: %s. %s" % [selected.name, String(selected.def.get("text", ""))]
        for i in range(request.options.size()):
            var option: TurnOption = request.options[i]
            if option.kind == TurnOption.FLIP:
                _flip_index = i
            elif option.kind == TurnOption.PASS:
                _pass_index = i
        _flip.disabled = _flip_index < 0
        _pass.disabled = _pass_index < 0
        return
    for i in range(request.options.size()):
        var b := Button.new()
        b.text = UiText.option_label(request, request.options[i])
        var index: int = i
        b.pressed.connect(func() -> void: option_chosen.emit(index))
        _options.add_child(b)

func show_continue(summary: String) -> void:
    _clear()
    _prompt.text = "Press Continue (or turn on auto-continue)."
    _continue.visible = true
    _summary.text = summary

func show_message(text: String) -> void:
    _clear()
    _prompt.text = text

## After answering: nothing is clickable until the next pause.
func set_busy() -> void:
    for b in [_play, _flip, _pass, _continue]:
        (b as Button).disabled = true
    for child in _options.get_children():
        (child as Button).disabled = true

func _clear() -> void:
    for child in _options.get_children():
        child.queue_free()
    for b in [_play, _flip, _pass, _continue]:
        (b as Button).visible = false
        (b as Button).disabled = false
    _flip_index = -1
    _pass_index = -1
    _summary.text = ""
