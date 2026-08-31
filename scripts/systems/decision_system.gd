class_name DecisionSystem
extends RefCounted

## Utility AI: для каждого персонажа считаем "полезность" (score) каждого
## возможного действия и выбираем действие с максимальным score.
## "Расписание" (рабочие часы / часы сна) — не отдельный механизм,
## а просто очень большой бонус/штраф внутри той же системы весов — так он
## почти всегда побеждает, но теоретически может быть перебит крайней нуждой
## (например, дичайшим голодом), что и даёт "скорее всего", а не "всегда".

func decide_action(c: CharacterData, world) -> Dictionary:
	var w: DecisionWeights = world.weights
	var work_time := _is_work_time(c, world)
	var sleep_time := _is_sleep_time(c, world)

	var candidates: Array[Dictionary] = [
		_score_sleep(c, world, w, sleep_time, work_time),
		_score_work(c, world, w, work_time),
		_score_eat(c, world, w, work_time),
		_score_socialize(c, world, w, work_time),
		_score_rest(c, world, w, work_time),
		_score_wander(c, world, w, work_time),
	]

	# Небольшой бонус к текущему действию, чтобы персонажи не "дёргались"
	# между разными действиями каждый цикл без веской причины.
	for candidate in candidates:
		if candidate["action"] == c.current_action:
			candidate["score"] += w.inertia_bonus

	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

func _score_sleep(c: CharacterData, world, w: DecisionWeights, sleep_time: bool, work_time: bool) -> Dictionary:
	# Намеренно небольшой множитель у голой усталости: график сна должен
	# решать почти всё сам, а не "накопилась усталость — лёг спать в 17:00".
	var score := (100.0 - c.energy) * 0.6
	if sleep_time:
		score += w.schedule_sleep_bonus
	elif work_time:
		score -= w.off_schedule_penalty
	else:
		# Не рабочее и не сонное время (вечер после работы, выходной днём) —
		# спать ещё рано, только очень низкая энергия сможет это перебить.
		score -= w.off_schedule_penalty * 0.5
	if c.energy > 90.0:
		score -= 200.0
	return {
		"action": Enums.ActionType.SLEEP,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_work(c: CharacterData, world, w: DecisionWeights, work_time: bool) -> Dictionary:
	var score := -1000.0
	if work_time:
		score = w.work_base_score * c.trait_workaholic
		score += w.schedule_work_bonus
		score -= c.stress * 0.3
	return {
		"action": Enums.ActionType.WORK,
		"score": score,
		"building_id": c.work_building_id,
		"room_id": c.work_room_id,
	}

func _score_eat(c: CharacterData, world, w: DecisionWeights, work_time: bool) -> Dictionary:
	var score := c.hunger * w.eat_weight
	if c.hunger > 70.0:
		score += 25.0
	if work_time:
		score -= w.off_schedule_penalty * 0.5 # перекусить на рабочем месте всё же можно
	return {
		"action": Enums.ActionType.EAT,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_socialize(c: CharacterData, world, w: DecisionWeights, work_time: bool) -> Dictionary:
	var score := (100.0 - c.social) * c.trait_social * w.socialize_weight
	score -= c.trait_loner * 30.0
	var hour: int = world.current_hour
	if hour >= 18 or hour < 2:
		score += 15.0
	else:
		score -= 20.0
	if work_time:
		score -= w.off_schedule_penalty

	var venue: BuildingData = _pick_social_venue(world)
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

func _score_rest(c: CharacterData, world, w: DecisionWeights, work_time: bool) -> Dictionary:
	var score := (100.0 - c.fun) * w.rest_weight + c.stress * 0.3
	if work_time:
		score -= w.off_schedule_penalty
	return {
		"action": Enums.ActionType.REST,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_wander(c: CharacterData, world, w: DecisionWeights, work_time: bool) -> Dictionary:
	var score := (100.0 - c.fun) * w.wander_weight
	var hour: int = world.current_hour
	if work_time:
		score -= w.off_schedule_penalty
	if hour < 7 or hour > 23:
		score -= 40.0

	var shop: BuildingData = world.get_building_by_type(Enums.BuildingType.SHOP)
	var building_id := c.home_building_id
	var room_id := c.home_room_id
	if shop != null:
		building_id = shop.id
		room_id = shop.rooms[0].id if shop.rooms.size() > 0 else 0

	return {
		"action": Enums.ActionType.WANDER,
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

func _pick_social_venue(world) -> BuildingData:
	var options: Array[BuildingData] = []
	var bar: BuildingData = world.get_building_by_type(Enums.BuildingType.BAR)
	var club: BuildingData = world.get_building_by_type(Enums.BuildingType.CLUB)
	if bar != null:
		options.append(bar)
	if club != null:
		options.append(club)
	if options.is_empty():
		return null
	return options[randi() % options.size()]
