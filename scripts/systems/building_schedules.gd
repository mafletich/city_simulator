class_name BuildingSchedules
extends RefCounted

## Пресеты часов работы по типу здания + параметры смен для генерации
## вакансий. Один пресет = {"open": int, "close": int, "label": String}.
## open == close значит "круглосуточно". close < open — диапазон через полночь
## (например 20:00–04:00), это не баг, а нормальный формат ночных заведений.

## Сколько часов максимум длится одна смена и сколько человек нужно на смену
## для этого типа здания — определяет, сколько вакансий сгенерируется, чтобы
## суммарно покрыть все часы работы без "дыр".
static func get_shift_params(type: Enums.BuildingType) -> Dictionary:
	match type:
		Enums.BuildingType.OFFICE:
			return {"max_shift_length": 9, "workers_per_shift": 2}
		Enums.BuildingType.HOSPITAL:
			return {"max_shift_length": 8, "workers_per_shift": 1}
		Enums.BuildingType.BAR:
			return {"max_shift_length": 6, "workers_per_shift": 1}
		Enums.BuildingType.CLUB:
			return {"max_shift_length": 6, "workers_per_shift": 1}
		Enums.BuildingType.SHOP:
			return {"max_shift_length": 7, "workers_per_shift": 2}
	return {"max_shift_length": 8, "workers_per_shift": 1}

## Возвращает случайно выбираемый пул пресетов для типа здания.
static func get_presets(type: Enums.BuildingType) -> Array[Dictionary]:
	match type:
		Enums.BuildingType.HOSPITAL:
			# Больница у нас всегда круглосуточная — "закрытая на ночь больница"
			# в симуляторе жизни города выглядит неправдоподобно, так что для
			# этого типа пул пресетов намеренно состоит из одного варианта.
			return [{"open": 0, "close": 0, "label": "Круглосуточно"}]
		Enums.BuildingType.OFFICE:
			return _generate([6, 7, 8, 9, 10, 11], [6, 7, 8, 9, 10], false)
		Enums.BuildingType.SHOP:
			return _generate([6, 7, 8, 9, 10], [8, 9, 10, 11, 12, 13, 14], true)
		Enums.BuildingType.BAR:
			return _generate([15, 16, 17, 18, 19, 20], [5, 6, 7, 8, 9], true)
		Enums.BuildingType.CLUB:
			return _generate([18, 19, 20, 21, 22], [4, 5, 6, 7, 8], true)
	return [{"open": 0, "close": 0, "label": "Круглосуточно"}]

static func _generate(opens: Array, durations: Array, include_24_7: bool) -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	for open_h in opens:
		for duration in durations:
			var close_h: int = (open_h + duration) % 24
			presets.append({
				"open": open_h,
				"close": close_h,
				"label": "%02d:00–%02d:00" % [open_h, close_h],
			})
	if include_24_7:
		presets.append({"open": 0, "close": 0, "label": "Круглосуточно"})
	return presets

static func pick_random_preset(type: Enums.BuildingType) -> Dictionary:
	var presets := get_presets(type)
	return presets[randi() % presets.size()]

## Длительность окна работы в часах (24, если круглосуточно).
static func duration_hours(open_h: int, close_h: int) -> int:
	if open_h == close_h:
		return 24
	if open_h < close_h:
		return close_h - open_h
	return 24 - open_h + close_h

## Режет часы работы здания на смены, полностью покрывающие весь период без
## пропусков, и возвращает список вакансий {"building", "start", "end"} —
## по одной записи на каждое рабочее место в каждой смене.
static func generate_vacancies(building: BuildingData) -> Array[Dictionary]:
	var params := get_shift_params(building.building_type)
	var max_shift_length: int = params["max_shift_length"]
	var workers_per_shift: int = params["workers_per_shift"]

	var total_hours := duration_hours(building.open_hour, building.close_hour)
	var num_shifts: int = max(1, int(ceil(float(total_hours) / max_shift_length)))
	var base_length: int = total_hours / num_shifts
	var remainder: int = total_hours % num_shifts

	var vacancies: Array[Dictionary] = []
	var cursor: int = building.open_hour
	for i in range(num_shifts):
		var length: int = base_length + (1 if i < remainder else 0)
		var shift_end: int = (cursor + length) % 24
		for w in range(workers_per_shift):
			vacancies.append({"building": building, "start": cursor, "end": shift_end})
		cursor = shift_end
	return vacancies
