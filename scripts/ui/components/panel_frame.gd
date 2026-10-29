class_name PanelFrame
extends PanelContainer

## A titled table panel (DM board, player board, decks, log). Content goes in `content`.
## Reusable scene: scenes/components/panel_frame.tscn.

var content := VBoxContainer.new()
var _title := Label.new()

func _init() -> void:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    _title.theme_type_variation = &"PanelTitle"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    box.add_child(_title)
    content.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(content)
    add_child(box)

func set_title(text: String) -> void:
    _title.text = text
    _title.visible = not text.is_empty()

## Add a child to the content area; `expand` lets it take the spare height.
func add_content(node: Control, expand: bool = false) -> void:
    if expand:
        node.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content.add_child(node)
