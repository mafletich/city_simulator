class_name RoomLayouts
extends RefCounted

## Какие комнаты состоят у квартиры внутри жилого дома. У каждого жителя
## своя спальня/гостиная/кухня — не общие на весь дом, а именно его личные.
static func get_apartment_room_kinds() -> Array[Enums.RoomType]:
	return [Enums.RoomType.BEDROOM, Enums.RoomType.LIVING_ROOM, Enums.RoomType.HOME_KITCHEN]

## Комнаты нежилого здания: {"kind": Enums.RoomType, "capacity": int}.
## main_capacity — вместимость главного "публичного" помещения (зал/торговый
## зал/обеденный зал и т.п.), подбирается под размер конкретного здания;
## служебные комнаты (кабинеты, кухня, склад) — фиксированного размера.
static func get_room_specs(building_type: Enums.BuildingType, main_capacity: int) -> Array[Dictionary]:
	match building_type:
		Enums.BuildingType.OFFICE:
			return [
				{"kind": Enums.RoomType.OFFICE_FLOOR, "capacity": 6},
				{"kind": Enums.RoomType.MEETING_ROOM, "capacity": 6},
				{"kind": Enums.RoomType.DIRECTOR_OFFICE, "capacity": 2},
			]
		Enums.BuildingType.HOSPITAL:
			return [
				{"kind": Enums.RoomType.DOCTOR_OFFICE, "capacity": 3},
				{"kind": Enums.RoomType.WARD, "capacity": 8},
				{"kind": Enums.RoomType.STAFF_ROOM, "capacity": 6},
				{"kind": Enums.RoomType.CHIEF_OFFICE, "capacity": 2},
			]
		Enums.BuildingType.BAR, Enums.BuildingType.CLUB:
			return [
				{"kind": Enums.RoomType.BAR_COUNTER, "capacity": 4},
				{"kind": Enums.RoomType.VENUE_HALL, "capacity": main_capacity},
				{"kind": Enums.RoomType.VENUE_OFFICE, "capacity": 2},
			]
		Enums.BuildingType.SHOP:
			return [
				{"kind": Enums.RoomType.SHOP_FLOOR, "capacity": main_capacity},
				{"kind": Enums.RoomType.STOCKROOM, "capacity": 4},
				{"kind": Enums.RoomType.SHOP_OFFICE, "capacity": 2},
			]
		Enums.BuildingType.CAFE:
			return [
				{"kind": Enums.RoomType.CAFE_KITCHEN, "capacity": 4},
				{"kind": Enums.RoomType.DINING_HALL, "capacity": main_capacity},
				{"kind": Enums.RoomType.CAFE_OFFICE, "capacity": 2},
			]
		Enums.BuildingType.PARK:
			return [
				{"kind": Enums.RoomType.PARK_PATH, "capacity": main_capacity},
				{"kind": Enums.RoomType.PARK_REST_ZONE, "capacity": main_capacity},
				{"kind": Enums.RoomType.GARDEN, "capacity": 4},
			]
	return []
