class_name Enums

enum Gender {
	MALE,
	FEMALE,
}

## Конкретная должность персонажа — не просто "сфера", а точный титул,
## который виден в характеристиках (CharacterData.profession).
enum Profession {
	UNEMPLOYED,
	OFFICE_WORKER,
	OFFICE_DIRECTOR,
	DOCTOR,
	CHIEF_DOCTOR,
	BARTENDER,
	BAR_MANAGER,
	SHOPKEEPER,
	SHOP_MANAGER,
	COOK,
	WAITER,
	CAFE_MANAGER,
	GARDENER,
}

enum BuildingType {
	RESIDENTIAL,
	OFFICE,
	HOSPITAL,
	BAR,
	CLUB,
	SHOP,
	CAFE,
	PARK,
}

enum ActionType {
	SLEEP,
	WORK,
	EAT,
	SOCIALIZE,
	REST,
	WANDER,
	SHOP,
}

enum ScheduleType {
	FIVE_TWO,
	TWO_TWO,
}

## Конкретное помещение внутри здания. Занятия привязаны именно к этим
## комнатам (см. ActivityCatalog) — так гарантируется, что, например,
## "смотрит телевизор" не всплывёт нигде, кроме гостиной.
enum RoomType {
	# Жилой дом — комнаты внутри квартиры конкретного жителя.
	BEDROOM,
	LIVING_ROOM,
	HOME_KITCHEN,
	# Офис
	OFFICE_FLOOR,
	MEETING_ROOM,
	DIRECTOR_OFFICE,
	# Больница
	DOCTOR_OFFICE,
	WARD,
	STAFF_ROOM,
	CHIEF_OFFICE,
	# Бар / Клуб
	BAR_COUNTER,
	VENUE_HALL,
	VENUE_OFFICE,
	# Магазин
	SHOP_FLOOR,
	STOCKROOM,
	SHOP_OFFICE,
	# Кафе
	CAFE_KITCHEN,
	DINING_HALL,
	CAFE_OFFICE,
	# Парк
	PARK_PATH,
	PARK_REST_ZONE,
	GARDEN,
}

static func room_type_text(kind: RoomType) -> String:
	match kind:
		RoomType.BEDROOM:
			return "Спальня"
		RoomType.LIVING_ROOM:
			return "Гостиная"
		RoomType.HOME_KITCHEN:
			return "Кухня"
		RoomType.OFFICE_FLOOR:
			return "Рабочий зал"
		RoomType.MEETING_ROOM:
			return "Переговорная"
		RoomType.DIRECTOR_OFFICE:
			return "Кабинет директора"
		RoomType.DOCTOR_OFFICE:
			return "Кабинет врача"
		RoomType.WARD:
			return "Палата"
		RoomType.STAFF_ROOM:
			return "Ординаторская"
		RoomType.CHIEF_OFFICE:
			return "Кабинет главного врача"
		RoomType.BAR_COUNTER:
			return "Барная стойка"
		RoomType.VENUE_HALL:
			return "Зал"
		RoomType.VENUE_OFFICE:
			return "Кабинет администратора"
		RoomType.SHOP_FLOOR:
			return "Торговый зал"
		RoomType.STOCKROOM:
			return "Склад"
		RoomType.SHOP_OFFICE:
			return "Кабинет управляющего"
		RoomType.CAFE_KITCHEN:
			return "Кухня"
		RoomType.DINING_HALL:
			return "Обеденный зал"
		RoomType.CAFE_OFFICE:
			return "Кабинет менеджера"
		RoomType.PARK_PATH:
			return "Аллея"
		RoomType.PARK_REST_ZONE:
			return "Зона отдыха"
		RoomType.GARDEN:
			return "Клумбы"
	return "?"

## Текстовые подписи вынесены сюда (а не дублируются в UI и в журнале
## событий), чтобы они у обоих гарантированно совпадали.
static func action_text(action: ActionType) -> String:
	match action:
		ActionType.SLEEP:
			return "Спит"
		ActionType.WORK:
			return "Работает"
		ActionType.EAT:
			return "Ест"
		ActionType.SOCIALIZE:
			return "Общается"
		ActionType.REST:
			return "Отдыхает"
		ActionType.WANDER:
			return "Гуляет"
		ActionType.SHOP:
			return "За покупками"
	return "?"

static func profession_text(p: Profession) -> String:
	match p:
		Profession.UNEMPLOYED:
			return "Безработный"
		Profession.OFFICE_WORKER:
			return "Офисный работник"
		Profession.OFFICE_DIRECTOR:
			return "Директор"
		Profession.DOCTOR:
			return "Врач"
		Profession.CHIEF_DOCTOR:
			return "Главный врач"
		Profession.BARTENDER:
			return "Бармен"
		Profession.BAR_MANAGER:
			return "Администратор"
		Profession.SHOPKEEPER:
			return "Продавец"
		Profession.SHOP_MANAGER:
			return "Управляющий магазином"
		Profession.COOK:
			return "Повар"
		Profession.WAITER:
			return "Официант"
		Profession.CAFE_MANAGER:
			return "Менеджер кафе"
		Profession.GARDENER:
			return "Садовник"
	return "?"
