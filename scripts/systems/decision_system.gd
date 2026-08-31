class_name DecisionSystem
extends RefCounted

## Utility AI: для каждого персонажа считаем "полезность" (score) каждого
## возможного действия и выбираем действие с максимальным score.
## Каждая _score_* функция возвращает Dictionary:
## {"action": Enums.ActionType, "score": float, "building_id": int, "room_id": int}

const INERTIA_BONUS: float = 8.0

func decide_action(c: CharacterData, world) -> Dictionary:
	var candidates: Array[Dictionary] = [
		_score_sleep(c, world),
		_score_work(c, world),
		_score_eat(c, world),
		_score_socialize(c, world),
		_score_rest(c, world),
		_score_wander(c, world),
	]

	# Небольшой бонус к текущему действию, чтобы персонажи не "дёргались"
	# между разными действиями каждый цикл без веской причины.
	for candidate in candidates:
		if candidate["action"] == c.current_action:
			candidate["score"] += INERTIA_BONUS

	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

func _score_sleep(c: CharacterData, world) -> Dictionary:
	var score := (100.0 - c.energy) * 1.3
	var hour: int = world.current_hour
	if hour >= 23 or hour < 6:
		score += 35.0
	elif c.sleep_hour != -1 and hour >= c.sleep_hour:
		score += 20.0
	if c.energy > 85.0:
		score -= 200.0
	return {
		"action": Enums.ActionType.SLEEP,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_work(c: CharacterData, world) -> Dictionary:
	var score := -1000.0
	if c.profession != Enums.Profession.UNEMPLOYED and c.work_building_id != -1:
		if _is_work_time(c, world.current_hour):
			score = 60.0 * c.trait_workaholic
			score -= c.stress * 0.3
			score -= max(0.0, 40.0 - c.energy) * 0.5
	return {
		"action": Enums.ActionType.WORK,
		"score": score,
		"building_id": c.work_building_id,
		"room_id": c.work_room_id,
	}

func _score_eat(c: CharacterData, world) -> Dictionary:
	var score := c.hunger * 0.9
	if c.hunger > 70.0:
		score += 25.0
	return {
		"action": Enums.ActionType.EAT,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_socialize(c: CharacterData, world) -> Dictionary:
	var score := (100.0 - c.social) * c.trait_social * 0.8
	score -= c.trait_loner * 30.0
	var hour: int = world.current_hour
	if hour >= 18 or hour < 2:
		score += 15.0
	else:
		score -= 20.0
	if _is_work_time(c, hour):
		score -= 60.0

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

func _score_rest(c: CharacterData, world) -> Dictionary:
	var score := (100.0 - c.fun) * 0.5 + c.stress * 0.3
	if _is_work_time(c, world.current_hour):
		score -= 60.0
	return {
		"action": Enums.ActionType.REST,
		"score": score,
		"building_id": c.home_building_id,
		"room_id": c.home_room_id,
	}

func _score_wander(c: CharacterData, world) -> Dictionary:
	var score := (100.0 - c.fun) * 0.4
	var hour: int = world.current_hour
	if _is_work_time(c, hour):
		score -= 60.0
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

func _is_work_time(c: CharacterData, hour: int) -> bool:
	if c.work_start_hour == -1:
		return false
	if c.work_start_hour <= c.work_end_hour:
		return hour >= c.work_start_hour and hour < c.work_end_hour
	# Ночная смена, пересекающая полночь.
	return hour >= c.work_start_hour or hour < c.work_end_hour

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
