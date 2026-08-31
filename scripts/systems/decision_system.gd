class_name DecisionSystem
extends RefCounted

## В рабочие часы персонаж ВСЕГДА на работе, в часы сна — ВСЕГДА спит дома:
## это больше не конкурирующие "веса", а жёсткое правило (см. decide_action).
## Вне этих двух окон включается Utility AI: для каждого из оставшихся
## действий (поесть/пообщаться/отдохнуть/погулять/сходить в магазин) считаем
## "полезность" (score) и выбираем действие с максимальным score.

func decide_action(c: CharacterData, world) -> Dictionary:
	if _is_work_time(c, world):
		return _fixed_action(Enums.ActionType.WORK, c.work_building_id, c.work_room_id)

	if _is_sleep_time(c, world):
		return _fixed_action(Enums.ActionType.SLEEP, c.home_building_id, c.home_room_id)

	var w: DecisionWeights = world.weights
	var candidates: Array[Dictionary] = [
		_score_eat(c, world, w),
		_score_socialize(c, world, w),
		_score_rest(c, world, w),
		_score_wander(c, world, w),
		_score_shop(c, world, w),
	]

	# Небольшой бонус к текущему действию, чтобы персонажи не "дёргались"
	# между разными действиями каждый цикл без веской причины.
	for candidate in candidates:
		if candidate["action"] == c.current_action:
			candidate["score"] += w.inertia_bonus

	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

func _fixed_action(action: Enums.ActionType, building_id: int, room_id: int) -> Dictionary:
	return {"action": action, "score": 9999.0, "building_id": building_id, "room_id": room_id}

func _score_eat(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := c.hunger * w.eat_weight
	if c.hunger > 70.0:
		score += 25.0

	var venue := _pick_open_building(world, [Enums.BuildingType.CAFE])
	var building_id := c.home_building_id
	var room_id := c.home_room_id
	if venue != null:
		building_id = venue.id
		room_id = venue.rooms[0].id if venue.rooms.size() > 0 else 0

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
	var room_id := c.home_room_id
	if venue != null:
		building_id = venue.id
		room_id = venue.rooms[0].id if venue.rooms.size() > 0 else 0

	return {
		"action": Enums.ActionType.SOCIALIZE,
		"score": score,
		"building_id": building_id,
		"room_id": room_id,
	}

func _score_rest(c: CharacterData, world, w: DecisionWeights) -> Dictionary:
	var score := (100.0 - c.fun) * w.rest_weight + c.stress * 0.3

	var building_id := c.home_building_id
	var room_id := c.home_room_id
	if randf() < w.park_rest_chance:
		var park := _pick_open_building(world, [Enums.BuildingType.PARK])
		if park != null:
			building_id = park.id
			room_id = park.rooms[0].id if park.rooms.size() > 0 else 0

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
	var room_id := c.home_room_id
	if park != null:
		building_id = park.id
		room_id = park.rooms[0].id if park.rooms.size() > 0 else 0

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
	var room_id := c.home_room_id
	if venue != null:
		building_id = venue.id
		room_id = venue.rooms[0].id if venue.rooms.size() > 0 else 0
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
