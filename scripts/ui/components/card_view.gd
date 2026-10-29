class_name CardView
extends Button

## One hero card face (name, skill, effect text). States: normal, selected, wound, dimmed (not
## playable now). Styled by the Theme type CardView. Reusable scene: scenes/components/card_view.tscn.

const STATE_NORMAL := "normal"
const STATE_SELECTED := "selected"
const STATE_WOUND := "wound"
const STATE_DIMMED := "dimmed"

var card_uid: int = -1
var _face := Label.new()
var _state: String = STATE_NORMAL

func _init() -> void:
    theme_type_variation = &"CardView"
    clip_contents = true
    _face.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _face.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    _face.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _face.add_theme_font_size_override("font_size", 13)
    add_child(_face)
    _face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 7)

func show_card(card: Card, state: String) -> void:
    card_uid = card.uid
    _face.text = UiText.card_face(card)
    _state = state
    _apply_state()

func _notification(what: int) -> void:
    if what == NOTIFICATION_THEME_CHANGED:
        _apply_state()

func _apply_state() -> void:
    var ink: Color = get_theme_color("font_color", "CardView")
    _face.add_theme_color_override("font_color", get_theme_color("dimmed", "CardView") if _state == STATE_DIMMED else ink)
    match _state:
        STATE_WOUND:
            self_modulate = get_theme_color("wound", "CardView")
        STATE_SELECTED:
            self_modulate = get_theme_color("selected", "CardView")
        _:
            self_modulate = Color.WHITE
