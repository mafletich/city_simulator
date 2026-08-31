class_name DecisionSystem
extends RefCounted

## В рабочие часы персонаж ВСЕГДА на работе, в часы сна — ВСЕГДА спит дома:
## это больше не конкурирующие "веса", а жёсткое правило (см. decide_action).
## Вне этих двух окон включается Utility AI: для каждого из оставшихся
## действий (поесть/пообщаться/отдохнуть/погулять/сходить в магазин) считаем
## "полезность" (score) и выбираем действие с максимальным score. Каждый
## вариант несёт с собой не только здание, но и конкретную комнату в нём —
## именно комната потом определяет, какой текст занятия допустим (см.
## ActivityCatalog и World._apply_decision).

func decide_action(c: CharacterData, world) -> Dictionary:
	if _is_work_time(c, world):
		return _fixed_action(Enums.ActionType.WORK, c.work_building_id, c.work_room_id)

	if _is_sleep_time(c, world):
		return _fixed_action(Enums.ActionType.SLEEP, c.home_building_id, _home_room_id(c, world, Enums.RoomType.BEDROOM))

	var w: DecisionWeights = world.weights

	# Инерция: "неохота бросать то, чем уже занят" — но не тогда, когда
	# персонаж работает/спит (это уже отсечено выше) или реально хочет есть
	# (голод не должен блокироваться привычкой сидеть в парке).
	if _should_apply_inertia(c, w):
		var stay_activity_chance := _decaying_chance(
			c.activity_streak, w.activity_stay_start_chance, w.activity_stay_min_chance, w.activity_stay_decay
		)
		if randf() < stay_activity_chance:
			var stay_location_chance := _decaying_chance(
				c.location_streak, w.location_stay_start_chance, w.location_stay_min_chance, w.location_stay_decay
			)
			if randf() < stay_location_chance:
				# Самый сильный вариант инерции: буквально ничего не меняет.
				return _fixed_action(c.current_action, c.current_building_id, c.current_room_id)
			# Готов заниматься тем же самым, но не обязательно здесь же —
			# пересчитываем как обычно, просто для того же типа действия.
			return _score_for_action(c.current_action, c, world, w)

	var candidates: Array[Dictionary] = [
		_score_eat(c, world, w),
		_score_socialize(c, world, w),
		_score_rest(c, world, w),
		_score_wander(c, world, w),
		_score_shop(c, world, w),
	]
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

func _fixed_action(action: Enums.ActionType, building_id: int, room_id: int) -> Dictionary:
	return {"action": action, "score": 9999.0, "building_id": building_id, "room_id": room_id}

## Комната указанного типа в СВОЕЙ квартире персонажа (спальня/гостиная/
## кухня) — запасной вариант, если вдруг квартиры/дома не нашлось, -1
## (тогда цель не сдвинется с текущего места, ничего не сломается).
func _home_room_id(c: CharacterData, world, kind: Enums.RoomType) -> int:
	var home: BuildingData = world.get_building(c.home_building_id)
	if home == null:
		return -1
	var room := home.get_apartment_room(c.home_apartment_index, kind)
	return room.id if room != null else -1

## Инерция применима только к "свободным" занятиям — не к работе/сну (те уже
## решены выше жёстко) и не к самому приёму пищи (есть не "залипает" сам по
## себе). Если голод уже выше порога — включаем обычную конкуренцию весов,
## чтобы явное "хочу есть" могло пробить привычку сидеть в парке.
func _should_apply_inertia(c: CharacterData, w: DecisionWeights) -> bool:
	if c.current_action == Enums.ActionType.WORK or c.current_action == Enums.ActionType.SLEEP:
		return false
	if c.current_action == Enums.ActionType.EAT:
		return false
	if c.hunger >= w.inertia_hunger_override:
		return false
	return true

## Вероятность "остаться" убывает с числом циклов подряд, которые персонаж
## уже этим занят: экспоненциальное затухание от start к min с коэффициентом
## decay за цикл. streak=1 (только что начал) -> ровно start; дальше плавно
## снижается, но никогда не падает ниже min — иногда лень пересчитывать жизнь
## заново даже после часа одного и того же занятия, и это реалистично.
func _decaying_chance(streak: int, start: float, min_chance: float, decay: float) -> float:
	if streak <= 0:
		return start
	return min_chance + (start - min_chance) * pow(decay, streak - 1)

func _score_for_action(action: Enums.ActionType, c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	match action:
		Enums.ActionType.EAT:
			return _score_eat(c, world, w)
		Enums.ActionType.SOCIALIZE:
			return _score_socialize(c, world, w)
		Enums.ActionType.REST:
			return _score_rest(c, world, w)
		Enums.ActionType.WANDER:
			return _score_wander(c, world, w)
		Enums.ActionType.SHOP:
			return _score_shop(c, world, w)
	return _score_rest(c, world, w) # не должно случаться, безопасный запасной вариант

func _score_eat(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := c.hunger * w.eat_weight
	if c.hunger > 70.0:
		score += 25.0
	if c.hunger < w.eat_min_hunger_threshold:
		# Без этого EAT никогда не обнуляется до конца (голод чуть растёт
		# каждый цикл), а другие желания при насыщении падают ровно до 0 —
		# и крошечный положительный счёт "поесть" начинает побеждать чаще,
		# чем должен, из-за чего персонаж будто перекусывает каждый цикл.
		score -= 1000.0

	var venue := _pick_open_building(world, [Enums.BuildingType.CAFE])
	var building_id := c.home_building_id
	var room_id := _home_room_id(c, world, Enums.RoomType.HOME_KITCHEN)
	if venue != null:
		var room := venue.get_room_by_kind(Enums.RoomType.DINING_HALL)
		if room != null:
			building_id = venue.id
			room_id = room.id

	return {
		"action": Enums.ActionType.EAT,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

func _score_socialize(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := (100.0 - c.social) * c.trait_social * w.socialize_weight
	score -= c.trait_loner * 30.0
	var hour: int = world.current_hour
	if hour >= 18 or hour < 2:
		score += 15.0
	else:
		score -= 20.0

	var venue := _pick_open_building(world, [Enums.BuildingType.BAR, Enums.BuildingType.CLUB])
	var building_id := c.home_building_id
	var room_id := _home_room_id(c, world, Enums.RoomType.LIVING_ROOM)
	if venue != null:
		var room := venue.get_room_by_kind(Enums.RoomType.VENUE_HALL)
		if room != null:
			building_id = venue.id
			room_id = room.id

	return {
		"action": Enums.ActionType.SOCIALIZE,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

func _score_rest(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := (100.0 - c.fun) * w.rest_weight + c.stress * 0.3

	var building_id := c.home_building_id
	var room_id := _home_room_id(c, world, Enums.RoomType.LIVING_ROOM)
	if randf() < w.park_rest_chance:
		var park := _pick_open_building(world, [Enums.BuildingType.PARK])
		if park != null:
			var room := park.get_room_by_kind(Enums.RoomType.PARK_REST_ZONE)
			if room != null:
				building_id = park.id
				room_id = room.id

	return {
		"action": Enums.ActionType.REST,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

func _score_wander(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := (100.0 - c.fun) * w.wander_weight
	var hour: int = world.current_hour
	if hour < 7 or hour > 23:
		score -= 40.0

	var park := _pick_open_building(world, [Enums.BuildingType.PARK])
	var building_id := c.home_building_id
	var room_id := _home_room_id(c, world, Enums.RoomType.LIVING_ROOM)
	if park != null:
		var room := park.get_room_by_kind(Enums.RoomType.PARK_PATH)
		if room != null:
			building_id = park.id
			room_id = room.id

	return {
		"action": Enums.ActionType.WANDER,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

func _score_shop(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := (100.0 - c.fun) * w.shop_weight
	var hour: int = world.current_hour
	if hour < 8 or hour > 21:
		score -= 30.0

	var venue := _pick_open_building(world, [Enums.BuildingType.SHOP])
	var building_id := c.home_building_id
	var room_id := _home_room_id(c, world, Enums.RoomType.LIVING_ROOM)
	if venue != null:
		var room := venue.get_room_by_kind(Enums.RoomType.SHOP_FLOOR)
		if room != null:
			building_id = venue.id
			room_id = room.id
	else:
		score -= 1000.0 # "сходить в магазин, оставшись дома" смысла не имеет

	return {
		"action": Enums.ActionType.SHOP,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

## --- Расписание ---------------------------------------------------------

func _is_work_time(c: CharacterData, world) -> bool:
	if c.profession == Enums.Profession.UNEMPLOYED or c.work_start_hour == -1:
		return false
	if not _is_work_day(c, world):
		return false
	return _hour_in_range(world.current_hour, c.work_start_hour, c.work_end_hour)

func _is_work_day(c: CharacterData, world) -> bool:
	if c.schedule_type == Enums.ScheduleType.FIVE_TWO:
		return world.current_day < 5 # 0..4 = Пн..Пт, 5..6 = Сб/Вс выходные
	# 2/2: два дня подряд рабочие, два выходных, по абсолютному дню симуляции
	# (не по дню недели — иначе паттерн не сможет "плавать" по неделям).
	var total_days: int = world.total_days_elapsed
	var cycle_pos: int = (total_days + c.schedule_offset) % 4
	return cycle_pos < 2

func _is_sleep_time(c: CharacterData, world) -> bool:
	return _hour_in_range(world.current_hour, c.sleep_start_hour, c.sleep_end_hour)

func _hour_in_range(hour: int, start: int, end: int) -> bool:
	if start == -1 or end == -1:
		return false
	if start <= end:
		return hour >= start and hour < end
	return hour >= start or hour < end # диапазон переходит через полночь

## Случайное открытое сейчас здание среди нескольких типов (например бар ИЛИ
## клуб) — в городе может быть несколько зданий одного типа одновременно.
func _pick_open_building(world, types: Array) -> BuildingData:
	var hour: int = world.current_hour
	var day: int = world.current_day
	var options: Array[BuildingData] = []
	for b in world.buildings:
		if types.has(b.building_type) and b.is_open(hour, day):
			options.append(b)
	if options.is_empty():
		return null
	return options[randi() % options.size()]
