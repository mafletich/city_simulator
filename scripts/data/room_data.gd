class_name RoomData
extends Resource

## Комната внутри здания: квартира, рабочее пространство, общий зал итд.

@export var id: int = -1
@export var room_type: String = "room"
@export var capacity: int = 4
@export var occupant_ids: Array[int] = []
