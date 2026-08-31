class_name ActivityCatalog
extends RefCounted

## Каждая запись — {"flavor": String, "room": Enums.RoomType}. Фраза и
## комната выбираются ВСЕГДА одной записью, никогда порознь — так
## структурно невозможна ситуация "смотрит телевизор в парке": у "смотрит
## телевизор" в принципе нет записи ни с какой комнатой, кроме гостиной.

static func rest_options(at_home: bool) -> Array[Dictionary]:
	if at_home:
		return [
			{"flavor": "Смотрит телевизор", "room": Enums.RoomType.LIVING_ROOM},
			{"flavor": "Читает книгу", "room": Enums.RoomType.LIVING_ROOM},
			{"flavor": "Слушает музыку", "room": Enums.RoomType.LIVING_ROOM},
			{"flavor": "Играет в настольную игру", "room": Enums.RoomType.LIVING_ROOM},
			{"flavor": "Просто отдыхает на диване", "room": Enums.RoomType.LIVING_ROOM},
		]
	return [
		{"flavor": "Сидит на скамейке", "room": Enums.RoomType.PARK_REST_ZONE},
		{"flavor": "Кормит голубей", "room": Enums.RoomType.PARK_REST_ZONE},
		{"flavor": "Наблюдает за людьми", "room": Enums.RoomType.PARK_REST_ZONE},
		{"flavor": "Дремлет на скамейке", "room": Enums.RoomType.PARK_REST_ZONE},
		{"flavor": "Читает книгу на свежем воздухе", "room": Enums.RoomType.PARK_REST_ZONE},
	]

static func wander_options() -> Array[Dictionary]:
	return [
		{"flavor": "Гуляет по аллее", "room": Enums.RoomType.PARK_PATH},
		{"flavor": "Фотографирует природу", "room": Enums.RoomType.PARK_PATH},
		{"flavor": "Дышит свежим воздухом", "room": Enums.RoomType.PARK_PATH},
		{"flavor": "Прогуливается не спеша", "room": Enums.RoomType.PARK_PATH},
	]

static func eat_home_options() -> Array[Dictionary]:
	return [
		{"flavor": "Готовит перекус", "room": Enums.RoomType.HOME_KITCHEN},
		{"flavor": "Ужинает на кухне", "room": Enums.RoomType.HOME_KITCHEN},
		{"flavor": "Ест на кухне", "room": Enums.RoomType.HOME_KITCHEN},
	]

static func eat_cafe_options() -> Array[Dictionary]:
	return [
		{"flavor": "Ест поданное блюдо", "room": Enums.RoomType.DINING_HALL},
		{"flavor": "Наслаждается обедом", "room": Enums.RoomType.DINING_HALL},
		{"flavor": "Пьёт кофе за столиком", "room": Enums.RoomType.DINING_HALL},
	]

static func socialize_options() -> Array[Dictionary]:
	return [
		{"flavor": "Общается за стойкой", "room": Enums.RoomType.VENUE_HALL},
		{"flavor": "Танцует", "room": Enums.RoomType.VENUE_HALL},
		{"flavor": "Общается с друзьями", "room": Enums.RoomType.VENUE_HALL},
		{"flavor": "Смеётся над шуткой", "room": Enums.RoomType.VENUE_HALL},
	]

static func shop_options() -> Array[Dictionary]:
	return [
		{"flavor": "Выбирает товары", "room": Enums.RoomType.SHOP_FLOOR},
		{"flavor": "Стоит в очереди на кассу", "room": Enums.RoomType.SHOP_FLOOR},
		{"flavor": "Изучает витрину", "room": Enums.RoomType.SHOP_FLOOR},
	]

## --- Рабочие занятия по должностям --------------------------------------
## Бармен, официант и продавец сюда не входят — у них своя логика,
## завязанная на конкретных клиентов (см. World._resolve_bartender_activities
## и соседние функции), а не случайный выбор из списка.
static func work_options(profession: Enums.Profession) -> Array[Dictionary]:
	match profession:
		Enums.Profession.OFFICE_WORKER:
			return [
				{"flavor": "Пишет отчёт", "room": Enums.RoomType.OFFICE_FLOOR},
				{"flavor": "Отвечает на письма", "room": Enums.RoomType.OFFICE_FLOOR},
				{"flavor": "Звонит клиенту", "room": Enums.RoomType.OFFICE_FLOOR},
				{"flavor": "На совещании", "room": Enums.RoomType.MEETING_ROOM},
			]
		Enums.Profession.OFFICE_DIRECTOR:
			return [
				{"flavor": "Подписывает документы", "room": Enums.RoomType.DIRECTOR_OFFICE},
				{"flavor": "Изучает отчёты", "room": Enums.RoomType.DIRECTOR_OFFICE},
				{"flavor": "На звонке с партнёрами", "room": Enums.RoomType.DIRECTOR_OFFICE},
				{"flavor": "Проводит совещание", "room": Enums.RoomType.MEETING_ROOM},
			]
		Enums.Profession.DOCTOR:
			return [
				{"flavor": "Ведёт приём", "room": Enums.RoomType.DOCTOR_OFFICE},
				{"flavor": "На обходе", "room": Enums.RoomType.WARD},
				{"flavor": "Заполняет карты пациентов", "room": Enums.RoomType.STAFF_ROOM},
			]
		Enums.Profession.CHIEF_DOCTOR:
			return [
				{"flavor": "Изучает отчёты", "room": Enums.RoomType.CHIEF_OFFICE},
				{"flavor": "Проверяет работу отделения", "room": Enums.RoomType.WARD},
				{"flavor": "Совещание с персоналом", "room": Enums.RoomType.STAFF_ROOM},
			]
		Enums.Profession.BAR_MANAGER:
			return [
				{"flavor": "Проверяет кассу", "room": Enums.RoomType.VENUE_OFFICE},
				{"flavor": "Работает с отчётами", "room": Enums.RoomType.VENUE_OFFICE},
				{"flavor": "Следит за залом", "room": Enums.RoomType.VENUE_HALL},
			]
		Enums.Profession.SHOP_MANAGER:
			return [
				{"flavor": "Проверяет отчёты", "room": Enums.RoomType.SHOP_OFFICE},
				{"flavor": "Работает с документами", "room": Enums.RoomType.SHOP_OFFICE},
				{"flavor": "Следит за залом", "room": Enums.RoomType.SHOP_FLOOR},
			]
		Enums.Profession.CAFE_MANAGER:
			return [
				{"flavor": "Проверяет отчёты", "room": Enums.RoomType.CAFE_OFFICE},
				{"flavor": "Общается с поставщиками", "room": Enums.RoomType.CAFE_OFFICE},
				{"flavor": "Следит за залом", "room": Enums.RoomType.DINING_HALL},
			]
		Enums.Profession.COOK:
			return [
				{"flavor": "Готовит блюдо", "room": Enums.RoomType.CAFE_KITCHEN},
				{"flavor": "Моет посуду", "room": Enums.RoomType.CAFE_KITCHEN},
				{"flavor": "Проверяет запасы на кухне", "room": Enums.RoomType.CAFE_KITCHEN},
			]
		Enums.Profession.GARDENER:
			return [
				{"flavor": "Подстригает кусты", "room": Enums.RoomType.GARDEN},
				{"flavor": "Поливает клумбы", "room": Enums.RoomType.GARDEN},
				{"flavor": "Сажает цветы", "room": Enums.RoomType.GARDEN},
				{"flavor": "Убирает территорию", "room": Enums.RoomType.GARDEN},
			]
	return [{"flavor": "Работает", "room": Enums.RoomType.OFFICE_FLOOR}]
