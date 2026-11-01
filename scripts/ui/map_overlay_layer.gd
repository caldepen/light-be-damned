class_name MapOverlayLayer
extends Node2D

## The overlay layer's drawing: wall tokens, the party marker, and the options of the pending
## choice (doorways, placement previews, campsites), each with a clickable shape. MapView builds
## the option shapes from the request; option_at() finds the one under a world point.

const DOORWAY_RADIUS := 0.24   # of a square
const WALL_WIDTH := 7.0

## Each option: {"index": int, "kind": "point"|"cells", "point": Vector2, "cells": Array[Vector2i],
## "doors": Array[Dictionary], "label": String}.
var options: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var party_rect := Rect2()
var hovered: int = -1
var palette: Dictionary = {}

func show_overlay(option_list: Array[Dictionary], wall_list: Array[Dictionary], party: Rect2, colors: Dictionary) -> void:
    options = option_list
    walls = wall_list
    party_rect = party
    palette = colors
    queue_redraw()

## The option index under `world` (a world point), or -1. Doorway markers win over tile previews.
func option_at(world: Vector2) -> int:
    for o in options:
        if o["kind"] == "point" and world.distance_to(o["point"]) <= MapView.SQUARE * DOORWAY_RADIUS:
            return int(o["index"])
    for o in options:
        if o["kind"] == "cells":
            for c in o["cells"]:
                if TileView.square_rect(c).has_point(world):
                    return int(o["index"])
    return -1

## The world point of a doorway marker: the middle of the edge, nudged outwards.
static func doorway_point(cell: Vector2i, side: String) -> Vector2:
    var r: Rect2 = TileView.square_rect(cell)
    var c: Vector2 = r.get_center()
    var half: float = MapView.SQUARE * 0.5
    match side:
        "N":
            return c + Vector2(0, -half)
        "S":
            return c + Vector2(0, half)
        "E":
            return c + Vector2(half, 0)
    return c + Vector2(-half, 0)

func _draw() -> void:
    var ink: Color = palette.get("ink", Color.BLACK)
    var highlight: Color = palette.get("highlight", Color(1, 0.8, 0.2))
    var doorway: Color = palette.get("doorway", Color(0.3, 0.6, 0.3))
    var font: Font = ThemeDB.fallback_font
    for w in walls:
        var p: Vector2 = doorway_point(w["cell"], w["side"])
        var along: Vector2 = Vector2(1, 0) if w["side"] in ["N", "S"] else Vector2(0, 1)
        draw_line(p - along * MapView.SQUARE * 0.22, p + along * MapView.SQUARE * 0.22, ink, WALL_WIDTH)
    for o in options:
        var hot: bool = int(o["index"]) == hovered
        if o["kind"] == "cells":
            for c in o["cells"]:
                var r: Rect2 = TileView.square_rect(c).grow(-3)
                draw_rect(r, Color(highlight, 0.28 if hot else 0.14))
                draw_rect(r, highlight, false, 3.0 if hot else 2.0)
            for d in o.get("doors", []):
                draw_circle(doorway_point(d["cell"], d["side"]), 4.0, highlight)
        else:
            var radius: float = MapView.SQUARE * DOORWAY_RADIUS
            draw_circle(o["point"], radius, Color(doorway, 0.85 if hot else 0.6))
            draw_arc(o["point"], radius, 0, TAU, 24, highlight, 3.0 if hot else 2.0)
        if not String(o.get("label", "")).is_empty():
            var at: Vector2 = o["point"] if o["kind"] == "point" else TileView.square_rect(o["cells"][0]).get_center()
            draw_string(font, at + Vector2(-20, 5), String(o["label"]), HORIZONTAL_ALIGNMENT_CENTER, 40, 13, ink)
    if party_rect.size != Vector2.ZERO:
        var centre: Vector2 = party_rect.end - Vector2(18, 18)  # the room's corner, clear of its name
        draw_circle(centre, 13.0, Color(0.8, 0.2, 0.2))
        draw_arc(centre, 13.0, 0, TAU, 24, ink, 2.0)
        draw_string(font, centre + Vector2(-10, 5), "P", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color.WHITE)
