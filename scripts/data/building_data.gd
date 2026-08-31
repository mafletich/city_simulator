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

## Дни недели работы. Если true — закрыто по субботам/воскресеньям (и штат
## состоит только из 5/2-сотрудников, у которых как раз эти дни выходные —
## так что "закрыт по выходным" и "у всех работников выходной" совпадают
## по построению, а не случайно). Если false — открыто все 7 дней; тогда
## штат каждой позиции — пара 2/2-сотрудников со смещением графика ровно
## на 2 дня, что математически гарантирует: каждый день недели кто-то из
## пары работает (см. BuildingSchedules.generate_vacancies).
@export var is_weekday_only: bool = false
@export var workdays_label: String = "Ежедневно"

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

## day — 0..6 (Пн..Вс), как World.current_day. Без него дни недели не учитываются.
func is_open(hour: int, day: int = -1) -> bool:
	if staff_count <= 0:
		return true # жилые дома и т.п. — не заведения, "открыты" всегда
	if is_weekday_only and day != -1 and day >= 5:
		return false
	if open_hour == close_hour:
		return true
	if open_hour < close_hour:
		return hour >= open_hour and hour < close_hour
	return hour >= open_hour or hour < close_hour # диапазон через полночь
