class_name RoomEffectRegistry
extends RefCounted

## One handler per exploration op (DATA_SCHEMA "Exploration effect ops"). The data loader checks
## every op in room cards, room types and Hut Whims against this, so unknown ops fail loudly.

var _handlers: Dictionary = {}

func _init() -> void:
    for h in [
        FightRoomEffect.new(),
        DrawRoomCardEffect.new(),
        TrapRoomEffect.new(),
        LockRoomEffect.new(),
        SkillCheckRoomEffect.new(),
        LootRoomEffect.new(),
        GainRationRoomEffect.new(),
        PartyDamageRoomEffect.new(),
        PartyRepairRoomEffect.new(),
        PartyHealRoomEffect.new(),
        TakeKeyRoomEffect.new(),
        BossRoomEffect.new(),
        HutTrackRoomEffect.new(),
        OptionalRoomEffect.new(),
        RotateTileRoomEffect.new(),
        CloseDoorwayRoomEffect.new(),
        LockInRoomEffect.new(),
        SwapTilesRoomEffect.new(),
        CollapseRoomEffect.new(),
        KeyholeRoomEffect.new(),
        DoorsSlamRoomEffect.new(),
        CrookedCorridorRoomEffect.new(),
    ]:
        _handlers[(h as RoomEffect).op_name()] = h

func has(op: String) -> bool:
    return _handlers.has(op)

func handler(op: String) -> RoomEffect:
    return _handlers.get(op, null)

func ops() -> Array:
    return _handlers.keys()
