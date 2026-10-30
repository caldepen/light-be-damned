class_name RoomEffect
extends RefCounted

## Base class for exploration effect handlers: one per `op` in room cards, room types and Hut
## Whims (DATA_SCHEMA "Exploration effect ops"). Never named after a card.

func op_name() -> String:
    return ""

func resolve(_ctx: RoomContext, _effect: Dictionary) -> void:
    pass
