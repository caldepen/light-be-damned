class_name LayoutMenu
extends MenuButton

## The "Layout" menu in the top bar: preset (Tall, Wide, My layout), save my layout, battlefield
## orientation and Provoke strip edge, hand dock position, hand auto-open, phase-layout mode and an
## exploring-layout preview (until exploration exists). Areas are docked from here, never dragged
## loose. Emits `chosen(action, value)`; TableScreen applies it (and owns the Reset layout button).

signal chosen(action: String, value: String)

const ACTION_PRESET := "preset"
const ACTION_SAVE_CUSTOM := "save_custom"
const ACTION_ORIENTATION := "orientation"
const ACTION_EDGE := "provoke_edge"
const ACTION_DOCK := "hand_dock"
const ACTION_AUTO_OPEN := "hand_auto_open"
const ACTION_PHASE_MODE := "phase_mode"
const ACTION_PREVIEW := "preview_exploring"

const ITEMS: Array = [
    ["Preset"],
    [ACTION_PRESET, LayoutSettings.PRESET_TALL, "Tall"],
    [ACTION_PRESET, LayoutSettings.PRESET_WIDE, "Wide"],
    [ACTION_PRESET, LayoutSettings.PRESET_CUSTOM, "My layout"],
    [ACTION_SAVE_CUSTOM, "", "Save current as my layout"],
    ["Battlefield"],
    [ACTION_ORIENTATION, BoardOrientation.TALL, "Tall: DM board above the player board"],
    [ACTION_ORIENTATION, BoardOrientation.WIDE, "Wide: player board left, DM board right"],
    [ACTION_EDGE, BattlefieldView.EDGE_TOP, "Wide: Provoke strip along the top"],
    [ACTION_EDGE, BattlefieldView.EDGE_BOTTOM, "Wide: Provoke strip along the bottom"],
    ["Hand"],
    [ACTION_DOCK, LayoutSettings.DOCK_BOTTOM_FULL, "Dock at the bottom, full width"],
    [ACTION_DOCK, LayoutSettings.DOCK_BOTTOM_BOARDS, "Dock at the bottom, under the boards"],
    [ACTION_DOCK, LayoutSettings.DOCK_LEFT, "Dock on the left side"],
    [ACTION_DOCK, LayoutSettings.DOCK_RIGHT, "Dock on the right side"],
    [ACTION_AUTO_OPEN, "", "Open a collapsed hand when a card must be chosen"],
    ["Exploring and battle"],
    [ACTION_PHASE_MODE, LayoutSettings.MODE_AUTOMATIC, "Automatic: boards for battle, map for exploring"],
    [ACTION_PHASE_MODE, LayoutSettings.MODE_BOTH, "Always show both"],
    [ACTION_PHASE_MODE, LayoutSettings.MODE_MANUAL, "Manual: no automatic changes"],
    [ACTION_PREVIEW, "", "Preview the exploring layout (until exploration exists)"],
]

func _init() -> void:
    text = "Layout"
    flat = false
    var popup: PopupMenu = get_popup()
    popup.hide_on_checkable_item_selection = false
    for entry in ITEMS:
        if entry.size() == 0:
            popup.add_separator()
        elif entry.size() == 1:
            popup.add_separator(String(entry[0]))
        else:
            var id: int = popup.item_count
            match String(entry[0]):
                ACTION_SAVE_CUSTOM:
                    popup.add_item(String(entry[2]), id)
                ACTION_AUTO_OPEN, ACTION_PREVIEW:
                    popup.add_check_item(String(entry[2]), id)
                _:
                    popup.add_radio_check_item(String(entry[2]), id)
            popup.set_item_metadata(popup.get_item_index(id), [entry[0], entry[1]])
    popup.id_pressed.connect(_on_id_pressed)

## Tick the items that match the current settings.
func refresh(settings: LayoutSettings, previewing_exploring: bool) -> void:
    var popup: PopupMenu = get_popup()
    var current: Dictionary = {
        ACTION_PRESET: settings.preset, ACTION_ORIENTATION: settings.orientation,
        ACTION_EDGE: settings.provoke_edge, ACTION_DOCK: settings.hand_dock,
        ACTION_PHASE_MODE: settings.phase_mode,
    }
    for i in range(popup.item_count):
        var meta: Variant = popup.get_item_metadata(i)
        if not meta is Array:
            continue
        var action: String = String(meta[0])
        if current.has(action):
            popup.set_item_checked(i, String(current[action]) == String(meta[1]))
        elif action == ACTION_AUTO_OPEN:
            popup.set_item_checked(i, settings.hand_auto_open)
        elif action == ACTION_PREVIEW:
            popup.set_item_checked(i, previewing_exploring)
        if action == ACTION_EDGE:
            popup.set_item_disabled(i, settings.orientation != BoardOrientation.WIDE)
        elif action == ACTION_PRESET and String(meta[1]) == LayoutSettings.PRESET_CUSTOM:
            popup.set_item_disabled(i, settings.custom.is_empty())

func _on_id_pressed(id: int) -> void:
    var popup: PopupMenu = get_popup()
    var meta: Variant = popup.get_item_metadata(popup.get_item_index(id))
    if meta is Array:
        chosen.emit(String(meta[0]), String(meta[1]))
