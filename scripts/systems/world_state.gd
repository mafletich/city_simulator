extends Node

## Глобальное состояние симуляции (автозагружаемый синглтон "World").
## Хранит всех персонажей, все здания и игровое время; продвигает циклы.

const MINUTES_PER_TICK: int = 10
## Ежедневные (не будни-only) заведения теперь всегда укомплектованы ПАРАМИ
## 2/2-сотрудников на позицию (см. BuildingSchedules), чтобы гарантированно
## не оставаться без персонала по выходным — это примерно удваивает спрос
## на рабочую силу у баров/клубов/магазина/больницы, так что жителей города
## тоже пришлось увеличить, иначе вакансии просто некому было бы закрыть.
const CHARACTER_COUNT: int = 40

const DAY_NAMES: Array[String] = [
	"Понедельник", "Вторник", "Среда", "Четверг",
	"Пятница", "Суббота", "Воскресенье",
]

const REST_FLAVORS: Array[String] = [
	"Смотрит телевизор", "Читает книгу", "Слушает музыку", "Просто отдыхает",
]
const OFFICE_ACTIVITIES: Array[String] = [
	"Пишет отчёт", "На совещании", "Отвечает на письма", "Звонит клиенту",
]
const DOCTOR_ACTIVITIES: Array[String] = [
	"Ведёт приём", "Заполняет карты пациентов", "На обходе",
]

var characters: Array[CharacterData] = []
var buildings: Array[BuildingData] = []

var current_day: int = 0
var current_hour: int = 8
var current_minute: int = 0
## Абсолютный счётчик дней с начала симуляции (для 2/2-графиков — они не
## привязаны к дню недели, иначе паттерн не мог бы "плавать" по неделям).
var total_days_elapsed: int = 0

var decision_system: DecisionSystem
var weights: DecisionWeights

func _ready() -> void:
	randomize()
	decision_system = DecisionSystem.new()
	weights = DecisionWeights.new()
	generate_city()

## --- Генерация мира ---------------------------------------------------

func generate_city() -> void:
	buildings.clear()
	characters.clear()
	current_day = 0
	current_hour = 8
	current_minute = 0
	total_days_elapsed = 0
	var next_id := 0

	var residential: Array[BuildingData] = []
	for i in range(10):
		var b := _create_building(next_id, "Жилой дом №%d" % (i + 1), Enums.BuildingType.RESIDENTIAL, 4)
		next_id += 1
		buildings.append(b)
		residential.append(b)

	var office1 := _create_building(next_id, "Офис №1", Enums.BuildingType.OFFICE, 6); next_id += 1
	var office2 := _create_building(next_id, "Офис №2", Enums.BuildingType.OFFICE, 6); next_id += 1
	var hospital := _create_building(next_id, "Больница", Enums.BuildingType.HOSPITAL, 5); next_id += 1
	var bar := _create_building(next_id, "Бар \"Полночь\"", Enums.BuildingType.BAR, 10); next_id += 1
	var club := _create_building(next_id, "Клуб \"Электро\"", Enums.BuildingType.CLUB, 15); next_id += 1
	var shop := _create_building(next_id, "Магазин", Enums.BuildingType.SHOP, 8); next_id += 1

	var workplaces: Array[BuildingData] = [office1, office2, hospital, bar, club, shop]
	var all_vacancies: Array[Dictionary] = []
	for wp in workplaces:
		var preset := BuildingSchedules.pick_random_preset(wp.building_type)
		wp.open_hour = preset["open"]
		wp.close_hour = preset["close"]
		wp.schedule_label = preset["label"]
		wp.is_weekday_only = BuildingSchedules.is_weekday_only(wp.building_type)
		wp.workdays_label = "Пн–Пт" if wp.is_weekday_only else "Ежедневно"

		var vacancies := BuildingSchedules.generate_vacancies(wp)
		wp.staff_count = vacancies.size()
		all_vacancies.append_array(vacancies)
		buildings.append(wp)

	# Вакансии раскиданы случайно между персонажами; если вакансий больше, чем
	# людей в городе, лишние остаются незаполненными — такое бывает, если
	# городу не повезло со случайными часами работы (много круглосуточных).
	all_vacancies.shuffle()
	var employed_count: int = min(all_vacancies.size(), CHARACTER_COUNT)
	var job_assignments: Array = []
	for i in range(employed_count):
		job_assignments.append(all_vacancies[i])
	for i in range(CHARACTER_COUNT - employed_count):
		job_assignments.append(null)
	job_assignments.shuffle()

	for i in range(CHARACTER_COUNT):
		var c := _create_random_character(i, residential, job_assignments[i])
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

func _create_random_character(id: int, residential: Array[BuildingData], vacancy) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.gender = Enums.Gender.MALE if randi() % 2 == 0 else Enums.Gender.FEMALE
	c.first_name = NameGenerator.random_first_name(c.gender)
	c.last_name = NameGenerator.random_last_name(c.gender)
	c.age = randi_range(19, 65)
	c.fingerprint = NameGenerator.random_fingerprint()

	if vacancy == null:
		c.profession = Enums.Profession.UNEMPLOYED
		c.work_building_id = -1
		c.work_room_id = -1
		c.work_start_hour = -1
		c.work_end_hour = -1
	else:
		var workplace: BuildingData = vacancy["building"]
		c.profession = _profession_for_building_type(workplace.building_type)
		c.work_building_id = workplace.id
		c.work_room_id = 0
		# Часы смены идут прямо из вакансии (см. BuildingSchedules) — так все
		# вакансии здания вместе покрывают весь его рабочий день без дыр.
		c.work_start_hour = vacancy["start"]
		c.work_end_hour = vacancy["end"]
		# График идёт прямо из вакансии, не рандомом — для ежедневных заведений
		# это гарантированно "спаренный" 2/2, покрывающий все 7 дней без дыр.
		c.schedule_type = vacancy["schedule_type"]
		c.schedule_offset = vacancy["schedule_offset"]

	_assign_sleep_hours(c)

	c.trait_workaholic = randf_range(0.5, 1.5)
	c.trait_social = randf_range(0.5, 1.5)
	c.trait_loner = randf_range(0.0, 1.0)

	# Стартуем утром с хорошим запасом сил, а не полуживыми/полусытыми.
	c.energy = randf_range(70.0, 100.0)
	c.hunger = randf_range(0.0, 30.0)
	c.social = randf_range(30.0, 100.0)
	c.fun = randf_range(30.0, 100.0)
	c.stress = randf_range(0.0, 30.0)

	var home: BuildingData = residential[randi() % residential.size()]
	var apartment: RoomData = home.rooms[randi() % home.rooms.size()]
	c.home_building_id = home.id
	c.home_room_id = apartment.id

	return c

func _profession_for_building_type(type: Enums.BuildingType) -> Enums.Profession:
	match type:
		Enums.BuildingType.OFFICE:
			return Enums.Profession.OFFICE_WORKER
		Enums.BuildingType.HOSPITAL:
			return Enums.Profession.DOCTOR
		Enums.BuildingType.BAR, Enums.BuildingType.CLUB:
			return Enums.Profession.BARTENDER
		Enums.BuildingType.SHOP:
			return Enums.Profession.SHOPKEEPER
	return Enums.Profession.UNEMPLOYED

## Часы сна считаются от времени пробуждения: работающие встают за час до
## смены и спят 8 часов назад от этого момента; безработные встают когда хотят.
func _assign_sleep_hours(c: CharacterData) -> void:
	var wake_hour: int
	if c.profession == Enums.Profession.UNEMPLOYED:
		wake_hour = randi_range(7, 10)
	else:
		wake_hour = (c.work_start_hour - 1 + 24) % 24
	c.sleep_end_hour = wake_hour
	c.sleep_start_hour = (wake_hour - 8 + 24) % 24

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
			total_days_elapsed += 1

	for c in characters:
		_update_needs(c)

	for c in characters:
		var decision := decision_system.decide_action(c, self)
		_apply_decision(c, decision)

	_resolve_work_activities()

func _update_needs(c: CharacterData) -> void:
	var energy_loss := weights.energy_decay_rate
	if c.current_action == Enums.ActionType.WORK:
		energy_loss += weights.work_extra_fatigue
	c.energy = clamp(c.energy - energy_loss, 0.0, 100.0)
	c.hunger = clamp(c.hunger + weights.hunger_growth_rate, 0.0, 100.0)
	c.social = clamp(c.social - weights.social_decay_rate, 0.0, 100.0)
	c.fun = clamp(c.fun - weights.fun_decay_rate, 0.0, 100.0)
	c.stress = clamp(c.stress + weights.stress_growth_rate, 0.0, 100.0)

func _apply_decision(c: CharacterData, decision: Dictionary) -> void:
	var action: Enums.ActionType = decision["action"]
	var target_building_id: int = decision["building_id"]
	var target_room_id: int = decision["room_id"]

	if target_building_id != c.current_building_id or target_room_id != c.current_room_id:
		_move_character(c, target_building_id, target_room_id)

	c.current_action = action

	match action:
		Enums.ActionType.SLEEP:
			c.current_activity_detail = ""
			c.energy = clamp(c.energy + weights.sleep_energy_regen, 0.0, 100.0)
		Enums.ActionType.EAT:
			c.current_activity_detail = ""
			c.hunger = clamp(c.hunger - weights.eat_hunger_relief, 0.0, 100.0)
		Enums.ActionType.SOCIALIZE:
			c.current_activity_detail = ""
			c.social = clamp(c.social + weights.socialize_social_gain, 0.0, 100.0)
			c.fun = clamp(c.fun + weights.socialize_fun_gain, 0.0, 100.0)
		Enums.ActionType.WORK:
			# current_activity_detail для WORK назначается ниже, в
			# _resolve_work_activities — там виден весь коллектив здания разом.
			c.stress = clamp(c.stress + weights.work_stress_gain, 0.0, 100.0)
		Enums.ActionType.REST:
			c.current_activity_detail = REST_FLAVORS[randi() % REST_FLAVORS.size()]
			c.fun = clamp(c.fun + weights.rest_fun_gain, 0.0, 100.0)
			c.stress = clamp(c.stress - weights.rest_stress_relief, 0.0, 100.0)
		Enums.ActionType.WANDER:
			c.current_activity_detail = ""
			c.fun = clamp(c.fun + weights.wander_fun_gain, 0.0, 100.0)

## Второй проход: конкретизируем, ЧЕМ именно занят каждый работающий персонаж,
## с учётом того, кто ещё есть в этом же здании (клиенты, другие работники).
func _resolve_work_activities() -> void:
	var workers_by_building: Dictionary = {}
	for c in characters:
		if c.current_action == Enums.ActionType.WORK:
			if not workers_by_building.has(c.current_building_id):
				workers_by_building[c.current_building_id] = []
			workers_by_building[c.current_building_id].append(c)

	for building_id in workers_by_building.keys():
		var building := get_building(building_id)
		if building == null:
			continue
		var all_workers: Array = workers_by_building[building_id]

		# "Едят, не покидая работу" — если сильно проголодался, перекусывает
		# на месте вместо своей обычной рабочей под-активности этот цикл.
		var workers: Array = []
		for wk in all_workers:
			if wk.hunger > weights.work_lunch_hunger_threshold:
				wk.current_activity_detail = "Обедает на рабочем месте"
				wk.hunger = clamp(wk.hunger - weights.work_lunch_relief, 0.0, 100.0)
			else:
				workers.append(wk)

		match building.building_type:
			Enums.BuildingType.BAR, Enums.BuildingType.CLUB:
				_resolve_bartender_activities(building, workers)
			Enums.BuildingType.SHOP:
				_resolve_shopkeeper_activities(building, workers)
			Enums.BuildingType.HOSPITAL:
				for doctor in workers:
					doctor.current_activity_detail = DOCTOR_ACTIVITIES[randi() % DOCTOR_ACTIVITIES.size()]
			Enums.BuildingType.OFFICE:
				for worker in workers:
					worker.current_activity_detail = OFFICE_ACTIVITIES[randi() % OFFICE_ACTIVITIES.size()]
			_:
				for w in workers:
					w.current_activity_detail = "Работает"

func _get_clients_in_building(building_id: int, wanted_action: Enums.ActionType) -> Array:
	var result: Array = []
	for c in characters:
		if c.current_building_id == building_id and c.current_action == wanted_action:
			result.append(c)
	return result

## Клиентов, ищущих обслуживания, распределяем 1-в-1 между барменами этого
## тика, чтобы двое барменов не "готовили коктейль" одному и тому же гостю.
func _resolve_bartender_activities(building: BuildingData, workers: Array) -> void:
	var clients := _get_clients_in_building(building.id, Enums.ActionType.SOCIALIZE)
	var served_client_ids: Array[int] = []
	for bartender in workers:
		var available: Array = []
		for cl in clients:
			if not served_client_ids.has(cl.id):
				available.append(cl)
		if available.size() > 0 and randf() < weights.bartender_serve_chance:
			var client: CharacterData = available[randi() % available.size()]
			served_client_ids.append(client.id)
			bartender.current_activity_detail = "Готовит коктейль для %s" % client.first_name
		else:
			bartender.current_activity_detail = "Протирает барную стойку"

func _resolve_shopkeeper_activities(building: BuildingData, workers: Array) -> void:
	var clients := _get_clients_in_building(building.id, Enums.ActionType.WANDER)
	for shopkeeper in workers:
		if clients.size() > 0 and randf() < 0.8:
			shopkeeper.current_activity_detail = "Обслуживает покупателя"
		else:
			shopkeeper.current_activity_detail = "Раскладывает товар на полках"

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
	return "День %d — %s, %02d:%02d" % [total_days_elapsed + 1, DAY_NAMES[current_day], current_hour, current_minute]
