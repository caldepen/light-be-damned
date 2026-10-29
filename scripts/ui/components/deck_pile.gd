class_name DeckPile
extends Control

## A pile of face-down cards (a deck, a discard pile, Exhausted cards) with its label and count.
## The pile looks taller the more cards it holds. Tooltip text can list the cards.
## Colours come from the Theme (type DeckPile). Reusable scene: scenes/components/deck_pile.tscn.

const MAX_LAYERS := 5

var label: String = ""
var count: int = 0

func _init() -> void:
    custom_minimum_size = Vector2(64, 58)
    mouse_filter = Control.MOUSE_FILTER_PASS

func show_pile(pile_label: String, pile_count: int, tooltip: String = "") -> void:
    label = pile_label
    count = pile_count
    tooltip_text = tooltip
    queue_redraw()

func _draw() -> void:
    var font: Font = get_theme_default_font()
    var card := Rect2(Vector2(8, 4), Vector2(size.x - 22, size.y - 24))
    if count == 0:
        draw_rect(card, get_theme_color("empty", "DeckPile"))
        draw_rect(card, get_theme_color("card_edge", "DeckPile").darkened(0.3), false, 1.0)
    else:
        var layers: int = clampi(ceili(count / 6.0), 1, MAX_LAYERS)
        for i in range(layers - 1, -1, -1):
            var r := Rect2(card.position + Vector2(i * 2, -i * 2 + MAX_LAYERS), card.size)
            draw_rect(r, get_theme_color("card_back", "DeckPile"))
            draw_rect(r, get_theme_color("card_edge", "DeckPile"), false, 1.0)
        draw_string(font, card.position + Vector2(0, card.size.y * 0.5 + 8), str(count), HORIZONTAL_ALIGNMENT_CENTER,
            card.size.x, 18, get_theme_color("card_edge", "DeckPile"))
    draw_string(font, Vector2(0, size.y - 4), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, get_theme_color("font_color", "Label"))
