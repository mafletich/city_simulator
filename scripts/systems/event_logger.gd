class_name EventLogger
extends RefCounted

## Ведёт отдельный текстовый файл-журнал на каждого персонажа: где он был и
## что делал в каждый цикл, плюс кто ещё был рядом (в том же здании) и что
## делали они. Файлы лежат в user:// (реальная папка на диске пользователя,
## не внутри проекта) — их можно открыть любым текстовым редактором прямо во
## время игры, они дописываются по ходу симуляции.

const LOG_DIR := "user://logs"

## Удаляет все прошлые журналы и создаёт пустую папку — вызывается при
## генерации нового города, чтобы не путать журналы разных городов/сессий.
func clear_logs() -> void:
	if not DirAccess.dir_exists_absolute(LOG_DIR):
		DirAccess.make_dir_recursive_absolute(LOG_DIR)
		return
	for file_name in DirAccess.get_files_at(LOG_DIR):
		DirAccess.remove_absolute("%s/%s" % [LOG_DIR, file_name])

static func get_log_dir_absolute() -> String:
	return ProjectSettings.globalize_path(LOG_DIR)

## Дописывает по одной записи в журнал каждого персонажа за прошедший цикл.
## Вызывается из World.advance_tick() ПОСЛЕ того, как решения приняты и
## рабочие под-активности разрешены — чтобы в журнал попало окончательное
## состояние этого цикла, а не промежуточное.
func log_tick(characters: Array[CharacterData], world) -> void:
	var by_building: Dictionary = {}
	for c in characters:
		if not by_building.has(c.current_building_id):
			by_building[c.current_building_id] = []
		by_building[c.current_building_id].append(c)

	var time_str: String = world.get_current_time_string()
	for c in characters:
		var co_present: Array = by_building.get(c.current_building_id, [])
		_append_entry(c, co_present, world, time_str)

func _append_entry(c: CharacterData, co_present: Array, world, time_str: String) -> void:
	var file := _open_for_append(c)
	if file == null:
		return

	var building: BuildingData = world.get_building(c.current_building_id)
	var location := _location_label(building, c.current_room_id)

	file.store_line("[%s] Место: %s" % [time_str, location])
	file.store_line("  " + _format_person_line(c, "Я"))

	var others: Array = []
	for other in co_present:
		if other.id != c.id:
			others.append(other)

	if others.is_empty():
		file.store_line("  Рядом никого нет.")
	else:
		file.store_line("  Рядом (%d):" % others.size())
		for other in others:
			file.store_line("    - " + _format_person_line(other, ""))
	file.store_line("")
	file.close()

func _format_person_line(c: CharacterData, prefix: String) -> String:
	var action_str := Enums.action_text(c.current_action)
	if c.current_activity_detail != "":
		action_str += " (%s)" % c.current_activity_detail
	var name_part := "%s: " % prefix if prefix != "" else ""
	return "%s%s — %s | Энергия %d, Голод %d, Общение %d, Веселье %d, Стресс %d" % [
		name_part, c.full_name(), action_str,
		int(c.energy), int(c.hunger), int(c.social), int(c.fun), int(c.stress),
	]

func _location_label(building: BuildingData, room_id: int) -> String:
	if building == null:
		return "неизвестно"
	if building.building_type == Enums.BuildingType.RESIDENTIAL:
		return "%s, квартира %d" % [building.building_name, room_id + 1]
	return building.building_name

func _file_name_for(c: CharacterData) -> String:
	return "%s_%s.log" % [c.first_name, c.last_name]

## Открывает файл персонажа в режиме дозаписи (в конец), создавая его вместе
## с "шапкой" при первом обращении. Godot не имеет отдельного режима
## "append" — стандартный способ дозаписи: открыть READ_WRITE и перевести
## курсор в конец файла перед записью.
func _open_for_append(c: CharacterData) -> FileAccess:
	var path := "%s/%s" % [LOG_DIR, _file_name_for(c)]
	if not FileAccess.file_exists(path):
		var new_file := FileAccess.open(path, FileAccess.WRITE)
		if new_file == null:
			return null
		new_file.store_line("=== Журнал событий: %s ===" % c.full_name())
		new_file.store_line("Пол: %s | Возраст: %d | Должность: %s | Отпечаток пальца: %s" % [
			"мужской" if c.gender == Enums.Gender.MALE else "женский",
			c.age, Enums.profession_text(c.profession), c.fingerprint,
		])
		new_file.store_line(_separator())
		new_file.store_line("")
		new_file.close()

	var file := FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return null
	file.seek_end()
	return file

func _separator() -> String:
	var s := ""
	for i in range(70):
		s += "-"
	return s
