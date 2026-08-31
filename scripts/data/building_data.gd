class_name BuildingData
extends Resource

@export var id: int = -1
@export var building_name: String = ""
@export var building_type: Enums.BuildingType = Enums.BuildingType.RESIDENTIAL
@export var rooms: Array[RoomData] = []
## Сколько сотрудников числится в этом здании (0 = не место работы; сумма
## всех сгенерированных вакансий, см. BuildingSchedules).
@export var staff_count: int = 0

## Часы работы. open_hour == close_hour означает "круглосуточно".
@export var open_hour: int = 0
@export var close_hour: int = 0
@export var schedule_label: String = ""

func get_room(room_id: int) -> RoomData:
	for r in rooms:
		if r.id == room_id:
			return r
	return null

func get_occupants() -> Array[int]:
	var ids: Array[int] = []
	for r in rooms:
		ids.append_array(r.occupant_ids)
	return ids

func is_open(hour: int) -> bool:
	if staff_count <= 0:
		return true # жилые дома и т.п. — не заведения, "открыты" всегда
	if open_hour == close_hour:
		return true
	if open_hour < close_hour:
		return hour >= open_hour and hour < close_hour
	return hour >= open_hour or hour < close_hour # диапазон через полночь
