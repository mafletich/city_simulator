class_name CharacterData
extends Resource

## Постоянные характеристики персонажа.
@export var id: int = -1
@export var first_name: String = ""
@export var last_name: String = ""
@export var gender: Enums.Gender = Enums.Gender.MALE
@export var age: int = 30
@export var profession: Enums.Profession = Enums.Profession.UNEMPLOYED
@export var fingerprint: String = ""

@export var home_building_id: int = -1
@export var home_room_id: int = -1
@export var work_building_id: int = -1
@export var work_room_id: int = -1

## Примерное расписание. -1 у work_start_hour значит "не работает".
@export var work_start_hour: int = -1
@export var work_end_hour: int = -1
@export var schedule_type: Enums.ScheduleType = Enums.ScheduleType.FIVE_TWO
## Для TWO_TWO — сдвиг фазы 2/2-цикла (0..3), чтобы не все были синхронны.
@export var schedule_offset: int = 0

## Часы сна как диапазон (может "переходить" через полночь: start > end).
@export var sleep_start_hour: int = 23
@export var sleep_end_hour: int = 7

## Черты характера — множители/бонусы для весов в системе принятия решений.
@export var trait_workaholic: float = 1.0
@export var trait_social: float = 1.0
@export var trait_loner: float = 0.0

## Динамические потребности, 0..100.
var energy: float = 80.0
var hunger: float = 20.0
var social: float = 60.0
var fun: float = 60.0
var stress: float = 10.0

## Текущее состояние.
var current_action: Enums.ActionType = Enums.ActionType.REST
## Уточнение текущего действия ("Готовит коктейль для Марии", "Читает книгу" итд).
var current_activity_detail: String = ""
var current_building_id: int = -1
var current_room_id: int = -1

func full_name() -> String:
	return "%s %s" % [first_name, last_name]
