extends Node

## Глобальное состояние симуляции (автозагружаемый синглтон "World").
## Хранит всех персонажей, все здания и игровое время; продвигает циклы.

const MINUTES_PER_TICK: int = 10
## Число жителей подобрано под ~10-20% безработицы при текущем наборе
## зданий/должностей ниже — если поменяешь состав города, скорее всего
## придётся подстроить и это число (см. отчёт о прогонах в PR/чате).
const CHARACTER_COUNT: int = 50
## У каждой квартиры в жилом доме — 4 комнаты? Нет: см. RoomLayouts, у каждой
## квартиры своя спальня/гостиная/кухня (3 комнаты). Это число — сколько
## квартир в одном жилом доме.
const APARTMENTS_PER_BUILDING: int = 4
const MAX_FRIENDS: int = 5

const DAY_NAMES: Array[String] = [
	"Понедельник", "Вторник", "Среда", "Четверг",
	"Пятница", "Суббота", "Воскресенье",
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
var event_logger: EventLogger

func _ready() -> void:
	randomize()
	decision_system = DecisionSystem.new()
	weights = DecisionWeights.new()
	event_logger = EventLogger.new()
	generate_city()

## --- Генерация мира ---------------------------------------------------

func generate_city() -> void:
	event_logger.clear_logs()
	buildings.clear()
	characters.clear()
	current_day = 0
	current_hour = 8
	current_minute = 0
	total_days_elapsed = 0
	var next_id := 0

	var residential: Array[BuildingData] = []
	for i in range(14):
		var b := _create_residential_building(next_id, "Жилой дом №%d" % (i + 1), APARTMENTS_PER_BUILDING)
		next_id += 1
		buildings.append(b)
		residential.append(b)

	var workplace_specs: Array[Dictionary] = [
		{"name": "Офис №1", "type": Enums.BuildingType.OFFICE, "size": 6},
		{"name": "Офис №2", "type": Enums.BuildingType.OFFICE, "size": 6},
		{"name": "Больница", "type": Enums.BuildingType.HOSPITAL, "size": 5},
		{"name": "Бар \"Полночь\"", "type": Enums.BuildingType.BAR, "size": 10},
		{"name": "Бар \"Закат\"", "type": Enums.BuildingType.BAR, "size": 8},
		{"name": "Клуб \"Электро\"", "type": Enums.BuildingType.CLUB, "size": 15},
		{"name": "Клуб \"Резонанс\"", "type": Enums.BuildingType.CLUB, "size": 12},
		{"name": "Магазин №1", "type": Enums.BuildingType.SHOP, "size": 8},
		{"name": "Магазин №2", "type": Enums.BuildingType.SHOP, "size": 6},
		{"name": "Кафе \"Уют\"", "type": Enums.BuildingType.CAFE, "size": 8},
		{"name": "Кафе \"Аромат\"", "type": Enums.BuildingType.CAFE, "size": 6},
		{"name": "Парк \"Центральный\"", "type": Enums.BuildingType.PARK, "size": 30},
		{"name": "Парк \"Речной\"", "type": Enums.BuildingType.PARK, "size": 20},
	]

	var all_vacancies: Array[Dictionary] = []
	for spec in workplace_specs:
		var wp := _create_workplace_building(next_id, spec["name"], spec["type"], spec["size"])
		next_id += 1

		var preset := BuildingSchedules.pick_random_preset(wp.building_type)
		wp.open_hour = preset["open"]
		wp.close_hour = preset["close"]
		wp.schedule_label = preset["label"]
		wp.is_weekday_only = BuildingSchedules.is_weekday_only(wp.building_type)
		wp.workdays_label = "Пн–Пт" if wp.is_weekday_only else "Ежедневно"
		wp.always_open_to_public = wp.building_type == Enums.BuildingType.PARK

		var position_rules := BuildingSchedules.get_position_rules(wp.building_type)
		wp.has_required_staffing = position_rules.any(func(r): return r["required"])

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

	# Общий на весь город реестр "уже занятых" полных имён — гарантирует
	# отсутствие полных тёзок (совпадения и имени, и фамилии одновременно).
	var used_full_names: Dictionary = {}
	for i in range(CHARACTER_COUNT):
		var c := _create_random_character(i, residential, job_assignments[i], used_full_names)
		characters.append(c)

	_assign_friendships()
	_place_all_characters_at_home()

func _create_residential_building(id: int, building_name: String, apartment_count: int) -> BuildingData:
	var b := BuildingData.new()
	b.id = id
	b.building_name = building_name
	b.building_type = Enums.BuildingType.RESIDENTIAL

	var rooms: Array[RoomData] = []
	var room_id := 0
	for apt in range(apartment_count):
		for kind in RoomLayouts.get_apartment_room_kinds():
			var r := RoomData.new()
			r.id = room_id
			room_id += 1
			r.kind = kind
			r.capacity = 2
			r.apartment_index = apt
			rooms.append(r)
	b.rooms = rooms
	return b

func _create_workplace_building(id: int, building_name: String, type: Enums.BuildingType, main_capacity: int) -> BuildingData:
	var b := BuildingData.new()
	b.id = id
	b.building_name = building_name
	b.building_type = type

	var rooms: Array[RoomData] = []
	var room_id := 0
	for spec in RoomLayouts.get_room_specs(type, main_capacity):
		var r := RoomData.new()
		r.id = room_id
		room_id += 1
		r.kind = spec["kind"]
		r.capacity = spec["capacity"]
		rooms.append(r)
	b.rooms = rooms
	return b

func _create_random_character(id: int, residential: Array[BuildingData], vacancy, used_full_names: Dictionary) -> CharacterData:
	var c := CharacterData.new()
	c.id = id
	c.gender = Enums.Gender.MALE if randi() % 2 == 0 else Enums.Gender.FEMALE
	var name := NameGenerator.generate_unique_full_name(c.gender, used_full_names)
	c.first_name = name["first_name"]
	c.last_name = name["last_name"]
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
		# Должность идёт прямо из вакансии, не выводится из типа здания —
		# у одного здания (например кафе) несколько разных должностей сразу.
		c.profession = vacancy["position"]
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
	c.home_building_id = home.id
	c.home_apartment_index = randi() % APARTMENTS_PER_BUILDING

	return c

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

## Каждому — от 0 до MAX_FRIENDS друзей. Дружба взаимна по построению: она
## добавляется на обе стороны одновременно, никогда только на одну. Сосед
## (тот же дом) или коллега (то же место работы) выбирается с повышенной
## вероятностью, но не обязательно — если такого нет рядом или не повезло,
## берём случайного жителя города.
func _assign_friendships() -> void:
	for c in characters:
		var target := randi_range(0, MAX_FRIENDS)
		var attempts := 0
		while c.friend_ids.size() < target and attempts < 30:
			attempts += 1
			var candidate := _pick_friend_candidate(c)
			if candidate == null or candidate.id == c.id:
				continue
			if c.friend_ids.has(candidate.id):
				continue
			if c.friend_ids.size() >= MAX_FRIENDS or candidate.friend_ids.size() >= MAX_FRIENDS:
				continue
			c.friend_ids.append(candidate.id)
			candidate.friend_ids.append(c.id)

func _pick_friend_candidate(c: CharacterData) -> CharacterData:
	if randf() < 0.6:
		var pool: Array[CharacterData] = []
		for other in characters:
			if other.id == c.id:
				continue
			if other.home_building_id == c.home_building_id:
				pool.append(other)
			elif c.work_building_id != -1 and other.work_building_id == c.work_building_id:
				pool.append(other)
		if not pool.is_empty():
			return pool[randi() % pool.size()]
	return characters[randi() % characters.size()]

func _place_all_characters_at_home() -> void:
	for c in characters:
		var home := get_building(c.home_building_id)
		var bedroom := home.get_apartment_room(c.home_apartment_index, Enums.RoomType.BEDROOM) if home != null else null
		_move_character(c, c.home_building_id, bedroom.id if bedroom != null else -1)
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
	event_logger.log_tick(characters, self)

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

	# Считаем "стрик" ДО того, как перезапишем текущее состояние — иначе
	# сравнивать было бы уже не с чем. Стрик начинается с 1 в тот самый
	# цикл, когда действие/место выбрано (см. DecisionSystem._decaying_chance).
	c.activity_streak = (c.activity_streak + 1) if action == c.current_action else 1
	c.location_streak = (c.location_streak + 1) if target_building_id == c.current_building_id else 1

	if target_building_id != c.current_building_id or target_room_id != c.current_room_id:
		_move_character(c, target_building_id, target_room_id)

	c.current_action = action
	var target_building := get_building(target_building_id)
	var target_room := target_building.get_room(target_room_id) if target_building != null else null
	var room_kind: Enums.RoomType = target_room.kind if target_room != null else Enums.RoomType.LIVING_ROOM

	match action:
		Enums.ActionType.SLEEP:
			c.current_activity_detail = ""
			c.energy = clamp(c.energy + weights.sleep_energy_regen, 0.0, 100.0)
		Enums.ActionType.EAT:
			var at_home := room_kind == Enums.RoomType.HOME_KITCHEN
			var options := ActivityCatalog.eat_home_options() if at_home else ActivityCatalog.eat_cafe_options()
			c.current_activity_detail = options[randi() % options.size()]["flavor"]
			if at_home:
				c.hunger = clamp(c.hunger - weights.eat_hunger_relief, 0.0, 100.0)
			else:
				c.hunger = clamp(c.hunger - weights.cafe_hunger_relief, 0.0, 100.0)
		Enums.ActionType.SOCIALIZE:
			if room_kind == Enums.RoomType.VENUE_HALL:
				var options := ActivityCatalog.socialize_options()
				c.current_activity_detail = options[randi() % options.size()]["flavor"]
			else:
				c.current_activity_detail = "Созванивается с друзьями"
			c.social = clamp(c.social + weights.socialize_social_gain, 0.0, 100.0)
			c.fun = clamp(c.fun + weights.socialize_fun_gain, 0.0, 100.0)
		Enums.ActionType.WORK:
			# current_activity_detail для WORK назначается ниже, в
			# _resolve_work_activities — там виден весь коллектив здания разом.
			c.stress = clamp(c.stress + weights.work_stress_gain, 0.0, 100.0)
		Enums.ActionType.REST:
			var at_home := room_kind == Enums.RoomType.LIVING_ROOM
			var options := ActivityCatalog.rest_options(at_home)
			c.current_activity_detail = options[randi() % options.size()]["flavor"]
			c.fun = clamp(c.fun + weights.rest_fun_gain, 0.0, 100.0)
			c.stress = clamp(c.stress - weights.rest_stress_relief, 0.0, 100.0)
		Enums.ActionType.WANDER:
			if room_kind == Enums.RoomType.PARK_PATH:
				var options := ActivityCatalog.wander_options()
				c.current_activity_detail = options[randi() % options.size()]["flavor"]
			else:
				c.current_activity_detail = ""
			c.fun = clamp(c.fun + weights.wander_fun_gain, 0.0, 100.0)
		Enums.ActionType.SHOP:
			if room_kind == Enums.RoomType.SHOP_FLOOR:
				var options := ActivityCatalog.shop_options()
				c.current_activity_detail = options[randi() % options.size()]["flavor"]
			else:
				c.current_activity_detail = ""
			c.fun = clamp(c.fun + weights.shop_fun_gain, 0.0, 100.0)

## Второй проход: конкретизируем, ЧЕМ именно занят каждый работающий персонаж
## И В КАКОЙ ИМЕННО КОМНАТЕ — с учётом того, кто ещё есть в этом же здании
## (клиенты, другие работники). Группируем по ДОЛЖНОСТИ, а не по типу
## здания — у одного здания (кафе) бывает сразу несколько разных должностей.
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

		var by_position: Dictionary = {}
		for wk in workers:
			if not by_position.has(wk.profession):
				by_position[wk.profession] = []
			by_position[wk.profession].append(wk)

		for position in by_position.keys():
			var pos_workers: Array = by_position[position]
			match position:
				Enums.Profession.BARTENDER:
					_resolve_bartender_activities(building, pos_workers)
				Enums.Profession.WAITER:
					_resolve_waiter_activities(building, pos_workers)
				Enums.Profession.SHOPKEEPER:
					_resolve_shopkeeper_activities(building, pos_workers)
				_:
					_resolve_catalog_activities(building, pos_workers, position)

## Профессии без завязки на конкретных клиентов — берём готовую пару
## "фраза+комната" из ActivityCatalog и физически переставляем работника
## в эту комнату (не только текст меняется, но и реальное местоположение).
func _resolve_catalog_activities(building: BuildingData, workers: Array, profession: Enums.Profession) -> void:
	var options := ActivityCatalog.work_options(profession)
	for w in workers:
		var choice: Dictionary = options[randi() % options.size()]
		_move_worker(w, building, building.get_room_by_kind(choice["room"]))
		w.current_activity_detail = choice["flavor"]

func _move_worker(c: CharacterData, building: BuildingData, room: RoomData) -> void:
	if room == null:
		return
	if c.current_building_id != building.id or c.current_room_id != room.id:
		_move_character(c, building.id, room.id)

func _get_clients_in_building(building_id: int, wanted_action: Enums.ActionType) -> Array:
	var result: Array = []
	for c in characters:
		if c.current_building_id == building_id and c.current_action == wanted_action:
			result.append(c)
	return result

## Клиентов, ищущих обслуживания, распределяем 1-в-1 между сотрудниками этого
## тика, чтобы двое барменов/официантов не обслуживали одного и того же гостя.
func _resolve_bartender_activities(building: BuildingData, workers: Array) -> void:
	var room := building.get_room_by_kind(Enums.RoomType.BAR_COUNTER)
	var clients := _get_clients_in_building(building.id, Enums.ActionType.SOCIALIZE)
	var served_client_ids: Array[int] = []
	for bartender in workers:
		_move_worker(bartender, building, room)
		var available: Array = []
		for cl in clients:
			if not served_client_ids.has(cl.id):
				available.append(cl)
		if available.size() > 0 and randf() < weights.staff_serve_chance:
			var client: CharacterData = available[randi() % available.size()]
			served_client_ids.append(client.id)
			bartender.current_activity_detail = "Готовит коктейль для %s" % client.first_name
		else:
			bartender.current_activity_detail = "Протирает барную стойку"

func _resolve_waiter_activities(building: BuildingData, workers: Array) -> void:
	var room := building.get_room_by_kind(Enums.RoomType.DINING_HALL)
	var clients := _get_clients_in_building(building.id, Enums.ActionType.EAT)
	var served_client_ids: Array[int] = []
	for waiter in workers:
		_move_worker(waiter, building, room)
		var available: Array = []
		for cl in clients:
			if not served_client_ids.has(cl.id):
				available.append(cl)
		if available.size() > 0 and randf() < weights.staff_serve_chance:
			var client: CharacterData = available[randi() % available.size()]
			served_client_ids.append(client.id)
			waiter.current_activity_detail = "Обслуживает столик %s" % client.first_name
		else:
			waiter.current_activity_detail = "Убирает со стола"

func _resolve_shopkeeper_activities(building: BuildingData, workers: Array) -> void:
	var floor_room := building.get_room_by_kind(Enums.RoomType.SHOP_FLOOR)
	var stock_room := building.get_room_by_kind(Enums.RoomType.STOCKROOM)
	var clients := _get_clients_in_building(building.id, Enums.ActionType.SHOP)
	for shopkeeper in workers:
		if clients.size() > 0 and randf() < 0.8:
			_move_worker(shopkeeper, building, floor_room)
			shopkeeper.current_activity_detail = "Обслуживает покупателя"
		else:
			_move_worker(shopkeeper, building, stock_room)
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

func get_buildings_by_type(type: Enums.BuildingType) -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for b in buildings:
		if b.building_type == type:
			result.append(b)
	return result

func get_character(id: int) -> CharacterData:
	for c in characters:
		if c.id == id:
			return c
	return null

func get_characters_in_building(building_id: int) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for c in characters:
		if c.current_building_id == building_id:
			result.append(c)
	return result

func get_current_time_string() -> String:
	return "День %d — %s, %02d:%02d" % [total_days_elapsed + 1, DAY_NAMES[current_day], current_hour, current_minute]
