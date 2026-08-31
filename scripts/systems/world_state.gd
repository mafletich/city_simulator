extends Node

## Глобальное состояние симуляции (автозагружаемый синглтон "World").
## Хранит всех персонажей, все здания и игровое время; продвигает циклы.

const MINUTES_PER_TICK: int = 10
const CHARACTER_COUNT: int = 20

const DAY_NAMES: Array[String] = [
	"Понедельник", "Вторник", "Среда", "Четверг",
	"Пятница", "Суббота", "Воскресенье",
]

var characters: Array[CharacterData] = []
var buildings: Array[BuildingData] = []

var current_day: int = 0
var current_hour: int = 8
var current_minute: int = 0

var decision_system: DecisionSystem

func _ready() -> void:
	decision_system = DecisionSystem.new()
	generate_city()

## --- Генерация мира ---------------------------------------------------

func generate_city() -> void:
	buildings.clear()
	characters.clear()
	var next_id := 0

	var residential: Array[BuildingData] = []
	for i in range(6):
		var b := _create_building(next_id, "Жилой дом №%d" % (i + 1), Enums.BuildingType.RESIDENTIAL, 4)
		next_id += 1
		buildings.append(b)
		residential.append(b)

	var offices: Array[BuildingData] = []
	for i in range(2):
		var b := _create_building(next_id, "Офис №%d" % (i + 1), Enums.BuildingType.OFFICE, 6)
		next_id += 1
		buildings.append(b)
		offices.append(b)

	var hospital := _create_building(next_id, "Больница", Enums.BuildingType.HOSPITAL, 5)
	next_id += 1
	buildings.append(hospital)

	var bar := _create_building(next_id, "Бар \"Полночь\"", Enums.BuildingType.BAR, 10)
	next_id += 1
	buildings.append(bar)

	var club := _create_building(next_id, "Клуб \"Электро\"", Enums.BuildingType.CLUB, 15)
	next_id += 1
	buildings.append(club)

	var shop := _create_building(next_id, "Магазин", Enums.BuildingType.SHOP, 8)
	next_id += 1
	buildings.append(shop)

	for i in range(CHARACTER_COUNT):
		var c := _create_random_character(i, residential, offices, hospital, bar, shop)
		characters.append(c)

	_place_all_characters_at_home()

func _create_building(id: int, building_name: String, type: Enums.BuildingType, size: int) -> BuildingData:
	var b := BuildingData.new()
	b.id = id
	b.building_name = building_name
	b.building_type = type

	var rooms: Array[RoomData] = []
	if type == Enums.BuildingType.RESIDENTIAL:
		for i in range(size):
			var r := RoomData.new()
			r.id = i
			r.room_type = "apartment"
			r.capacity = 2
			rooms.append(r)
	else:
		var r := RoomData.new()
		r.id = 0
		r.room_type = "hall"
		r.capacity = size
		rooms.append(r)
	b.rooms = rooms
	return b

func _create_random_character(
	id: int,
	residential: Array[BuildingData],
	offices: Array[BuildingData],
	hospital: BuildingData,
	bar: BuildingData,
	shop: BuildingData
) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.gender = Enums.Gender.MALE if randi() % 2 == 0 else Enums.Gender.FEMALE
	c.first_name = NameGenerator.random_first_name(c.gender)
	c.last_name = NameGenerator.random_last_name(c.gender)
	c.age = randi_range(19, 65)
	c.fingerprint = NameGenerator.random_fingerprint()

	var roll := randi() % 6
	match roll:
		0:
			c.profession = Enums.Profession.UNEMPLOYED
		1, 2:
			c.profession = Enums.Profession.OFFICE_WORKER
			var office: BuildingData = offices[randi() % offices.size()]
			c.work_building_id = office.id
			c.work_room_id = 0
		3:
			c.profession = Enums.Profession.DOCTOR
			c.work_building_id = hospital.id
			c.work_room_id = 0
		4:
			c.profession = Enums.Profession.BARTENDER
			c.work_building_id = bar.id
			c.work_room_id = 0
		5:
			c.profession = Enums.Profession.SHOPKEEPER
			c.work_building_id = shop.id
			c.work_room_id = 0

	if c.profession == Enums.Profession.UNEMPLOYED:
		c.work_start_hour = -1
		c.work_end_hour = -1
	else:
		var starts: Array[int] = [7, 8, 9]
		var durations: Array[int] = [7, 8, 9]
		c.work_start_hour = starts[randi() % starts.size()]
		c.work_end_hour = (c.work_start_hour + durations[randi() % durations.size()]) % 24

	c.sleep_hour = randi_range(21, 24) % 24
	c.trait_workaholic = randf_range(0.5, 1.5)
	c.trait_social = randf_range(0.5, 1.5)
	c.trait_loner = randf_range(0.0, 1.0)

	c.energy = randf_range(50.0, 100.0)
	c.hunger = randf_range(0.0, 50.0)
	c.social = randf_range(30.0, 100.0)
	c.fun = randf_range(30.0, 100.0)
	c.stress = randf_range(0.0, 40.0)

	var home: BuildingData = residential[randi() % residential.size()]
	var apartment: RoomData = home.rooms[randi() % home.rooms.size()]
	c.home_building_id = home.id
	c.home_room_id = apartment.id

	return c

func _place_all_characters_at_home() -> void:
	for c in characters:
		_move_character(c, c.home_building_id, c.home_room_id)
		c.current_action = Enums.ActionType.SLEEP

## --- Продвижение времени ------------------------------------------------

func advance_tick() -> void:
	current_minute += MINUTES_PER_TICK
	if current_minute >= 60:
		current_minute = 0
		current_hour += 1
		if current_hour >= 24:
			current_hour = 0
			current_day = (current_day + 1) % 7

	for c in characters:
		_update_needs(c)

	for c in characters:
		var decision := decision_system.decide_action(c, self)
		_apply_decision(c, decision)

func _update_needs(c: CharacterData) -> void:
	c.energy = clamp(c.energy - 1.5, 0.0, 100.0)
	c.hunger = clamp(c.hunger + 1.2, 0.0, 100.0)
	c.social = clamp(c.social - 0.8, 0.0, 100.0)
	c.fun = clamp(c.fun - 0.5, 0.0, 100.0)
	c.stress = clamp(c.stress + 0.3, 0.0, 100.0)

func _apply_decision(c: CharacterData, decision: Dictionary) -> void:
	var action: Enums.ActionType = decision["action"]
	var target_building_id: int = decision["building_id"]
	var target_room_id: int = decision["room_id"]

	if target_building_id != c.current_building_id or target_room_id != c.current_room_id:
		_move_character(c, target_building_id, target_room_id)

	c.current_action = action

	match action:
		Enums.ActionType.SLEEP:
			c.energy = clamp(c.energy + 8.0, 0.0, 100.0)
		Enums.ActionType.EAT:
			c.hunger = clamp(c.hunger - 30.0, 0.0, 100.0)
		Enums.ActionType.SOCIALIZE:
			c.social = clamp(c.social + 15.0, 0.0, 100.0)
			c.fun = clamp(c.fun + 10.0, 0.0, 100.0)
		Enums.ActionType.WORK:
			c.stress = clamp(c.stress + 2.0, 0.0, 100.0)
		Enums.ActionType.REST:
			c.fun = clamp(c.fun + 5.0, 0.0, 100.0)
			c.stress = clamp(c.stress - 2.0, 0.0, 100.0)
		Enums.ActionType.WANDER:
			c.fun = clamp(c.fun + 8.0, 0.0, 100.0)

## --- Вспомогательные методы ---------------------------------------------

func _move_character(c: CharacterData, building_id: int, room_id: int) -> void:
	if c.current_building_id != -1:
		var old_building := get_building(c.current_building_id)
		if old_building != null:
			var old_room := old_building.get_room(c.current_room_id)
			if old_room != null:
				old_room.occupant_ids.erase(c.id)

	c.current_building_id = building_id
	c.current_room_id = room_id

	var new_building := get_building(building_id)
	if new_building != null:
		var new_room := new_building.get_room(room_id)
		if new_room != null and not new_room.occupant_ids.has(c.id):
			new_room.occupant_ids.append(c.id)

func get_building(id: int) -> BuildingData:
	for b in buildings:
		if b.id == id:
			return b
	return null

func get_building_by_type(type: Enums.BuildingType) -> BuildingData:
	for b in buildings:
		if b.building_type == type:
			return b
	return null

func get_characters_in_building(building_id: int) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for c in characters:
		if c.current_building_id == building_id:
			result.append(c)
	return result

func get_current_time_string() -> String:
	return "%s, %02d:%02d" % [DAY_NAMES[current_day], current_hour, current_minute]
