class_name RoomData
extends Resource

## Конкретное помещение внутри здания (см. Enums.RoomType) — занятия
## привязаны именно к комнатам, а не к зданию в целом.

@export var id: int = -1
@export var kind: Enums.RoomType = Enums.RoomType.LIVING_ROOM
@export var capacity: int = 4
## Только для комнат внутри жилых домов: индекс квартиры-владельца (у каждой
## квартиры своя спальня/гостиная/кухня). -1 — комната ни к какой квартире не
## привязана (все нежилые здания).
@export var apartment_index: int = -1
@export var occupant_ids: Array[int] = []
