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
