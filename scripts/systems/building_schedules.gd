class_name BuildingSchedules
extends RefCounted

## Пресеты часов работы по типу здания + список должностей с их правилами
## покрытия. Один пресет часов = {"open": int, "close": int, "label": String}.
## open == close значит "круглосуточно". close < open — диапазон через полночь
## (например 20:00–04:00), это не баг, а нормальный формат ночных заведений.

## Максимальная длина одной смены для обязательных должностей — не даём
## сменам растягиваться на весь день, чтобы не сажать одного человека на
## 24-часовую смену. Для больницы короче — там реалистичнее делить на 3.
static func get_max_shift_length(type: Enums.BuildingType) -> int:
	if type == Enums.BuildingType.HOSPITAL:
		return 8
	return 14

## Какие дни недели работает заведение этого типа. Офисы — только будни (и
## поэтому их обязательные вакансии обходятся одним 5/2-сотрудником: у него
## и так выходные именно в эти дни). Всё остальное — каждый день, поэтому
## обязательные вакансии там устроены парами (см. generate_vacancies),
## иначе по выходным будет пусто.
static func is_weekday_only(type: Enums.BuildingType) -> bool:
	return type == Enums.BuildingType.OFFICE

## Список должностей для типа здания:
## {"position": Enums.Profession, "required": bool, "count_per_shift": int}.
## required=true — должность обязана быть покрыта КАЖДЫЙ час работы здания
## (генерируется по полной схеме со сменами/парами, см. generate_vacancies).
## required=false — "необязательная" должность (директор/менеджер/садовник):
## один человек, стандартный дневной график 5/2, могут быть часы/дни, когда
## его нет на месте — это осознанно, не баг.
static func get_position_rules(type: Enums.BuildingType) -> Array[Dictionary]:
	match type:
		Enums.BuildingType.OFFICE:
			return [
				{"position": Enums.Profession.OFFICE_WORKER, "required": true, "count_per_shift": 2},
				{"position": Enums.Profession.OFFICE_DIRECTOR, "required": false, "count_per_shift": 1},
			]
		Enums.BuildingType.HOSPITAL:
			return [
				{"position": Enums.Profession.DOCTOR, "required": true, "count_per_shift": 1},
				{"position": Enums.Profession.CHIEF_DOCTOR, "required": false, "count_per_shift": 1},
			]
		Enums.BuildingType.BAR, Enums.BuildingType.CLUB:
			return [
				{"position": Enums.Profession.BARTENDER, "required": true, "count_per_shift": 1},
				{"position": Enums.Profession.BAR_MANAGER, "required": false, "count_per_shift": 1},
			]
		Enums.BuildingType.SHOP:
			return [
				{"position": Enums.Profession.SHOPKEEPER, "required": true, "count_per_shift": 1},
				{"position": Enums.Profession.SHOP_MANAGER, "required": false, "count_per_shift": 1},
			]
		Enums.BuildingType.CAFE:
			return [
				{"position": Enums.Profession.COOK, "required": true, "count_per_shift": 1},
				{"position": Enums.Profession.WAITER, "required": true, "count_per_shift": 1},
				{"position": Enums.Profession.CAFE_MANAGER, "required": false, "count_per_shift": 1},
			]
		Enums.BuildingType.PARK:
			# Парк — общественное пространство: садовник не обязателен для
			# того, чтобы люди могли туда прийти отдохнуть/погулять.
			return [
				{"position": Enums.Profession.GARDENER, "required": false, "count_per_shift": 1},
			]
	return []

## Возвращает случайно выбираемый пул пресетов часов работы для типа здания.
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
		Enums.BuildingType.CAFE:
			return _generate([6, 7, 8, 9], [8, 9, 10, 11, 12, 13, 14], false)
		Enums.BuildingType.PARK:
			return _generate([6, 7, 8], [12, 13, 14, 15, 16], false)
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

## Полный список вакансий здания (по всем должностям), каждая уже с готовым
## графиком и должностью:
## {"building", "start", "end", "schedule_type", "schedule_offset", "position"}.
static func generate_vacancies(building: BuildingData) -> Array[Dictionary]:
	var vacancies: Array[Dictionary] = []
	for rule in get_position_rules(building.building_type):
		if rule["required"]:
			vacancies.append_array(_generate_required_vacancies(building, rule))
		else:
			vacancies.append_array(_generate_optional_vacancies(building, rule))
	return vacancies

## Обязательная должность: часы работы здания режутся на смены, полностью
## покрывающие весь период без пропусков.
##
## Будни-заведение (офис): одна вакансия на позицию в смене, график 5/2 — у
## такого сотрудника выходные ровно Сб/Вс, когда здание и так закрыто.
##
## Ежедневное заведение: ДВЕ вакансии на позицию в смене, обе 2/2, со
## смещением графика ровно на 2 дня друг от друга. Это не рандомная
## эвристика: при периоде цикла 4 дня (2 рабочих/2 выходных) смещение на 2
## гарантированно зеркалит рабочие и выходные дни — когда один из пары
## отдыхает, у второго как раз рабочий день, и наоборот, для любого дня.
static func _generate_required_vacancies(building: BuildingData, rule: Dictionary) -> Array[Dictionary]:
	var max_shift_length := get_max_shift_length(building.building_type)
	var workers_per_shift: int = rule["count_per_shift"]
	var position: Enums.Profession = rule["position"]

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
			if building.is_weekday_only:
				vacancies.append({
					"building": building, "start": cursor, "end": shift_end,
					"schedule_type": Enums.ScheduleType.FIVE_TWO, "schedule_offset": 0,
					"position": position,
				})
			else:
				var base_offset := randi() % 4
				vacancies.append({
					"building": building, "start": cursor, "end": shift_end,
					"schedule_type": Enums.ScheduleType.TWO_TWO, "schedule_offset": base_offset,
					"position": position,
				})
				vacancies.append({
					"building": building, "start": cursor, "end": shift_end,
					"schedule_type": Enums.ScheduleType.TWO_TWO, "schedule_offset": (base_offset + 2) % 4,
					"position": position,
				})
		cursor = shift_end
	return vacancies

## Необязательная должность (директор/менеджер/садовник): фиксированный
## дневной график 5/2, независимо от часов самого здания — руководитель не
## обязан быть на месте всё то время, что работает заведение. Никакой пары
## и гарантии покрытия — отсутствие "начальника" вечером/в выходные не баг.
static func _generate_optional_vacancies(building: BuildingData, rule: Dictionary) -> Array[Dictionary]:
	var count: int = rule["count_per_shift"]
	var position: Enums.Profession = rule["position"]
	var vacancies: Array[Dictionary] = []
	for i in range(count):
		vacancies.append({
			"building": building, "start": 9, "end": 17,
			"schedule_type": Enums.ScheduleType.FIVE_TWO, "schedule_offset": 0,
			"position": position,
		})
	return vacancies
