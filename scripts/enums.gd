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
