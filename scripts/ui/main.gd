extends Control

@onready var time_label: Label = $VBox/TopBar/TimeLabel
@onready var next_tick_button: Button = $VBox/TopBar/NextTickButton
@onready var weights_button: Button = $VBox/TopBar/WeightsButton
@onready var weights_panel: PanelContainer = $WeightsPanel
@onready var buildings_list: ItemList = $VBox/Split/BuildingsPanel/BuildingsList
@onready var building_name_label: Label = $VBox/Split/DetailsPanel/BuildingNameLabel
@onready var characters_list: ItemList = $VBox/Split/DetailsPanel/CharactersList
@onready var character_details_label: Label = $VBox/Split/DetailsPanel/CharacterDetailsLabel

var selected_building_id: int = -1
var characters_in_selected_building: Array[CharacterData] = []

func _ready() -> void:
	next_tick_button.pressed.connect(_on_next_tick_pressed)
	weights_button.pressed.connect(_on_weights_button_pressed)
	buildings_list.item_selected.connect(_on_building_selected)
	characters_list.item_selected.connect(_on_character_selected)

	_refresh_buildings_list()
	_update_time_label()

func _on_next_tick_pressed() -> void:
	World.advance_tick()
	_update_time_label()
	_refresh_buildings_list()
	if selected_building_id != -1:
		var b := World.get_building(selected_building_id)
		if b != null:
			building_name_label.text = _building_header_text(b)
		_refresh_characters_list()
		character_details_label.text = ""

func _on_weights_button_pressed() -> void:
	weights_panel.visible = not weights_panel.visible

func _update_time_label() -> void:
	time_label.text = World.get_current_time_string()

func _refresh_buildings_list() -> void:
	var previous_selection := selected_building_id
	buildings_list.clear()
	for i in range(World.buildings.size()):
		var b: BuildingData = World.buildings[i]
		var occupant_count := b.get_occupants().size()
		var status := ""
		if b.staff_count > 0:
			status = " — Открыто" if b.is_open(World.current_hour) else " — Закрыто"
		buildings_list.add_item("%s (%d чел.)%s" % [b.building_name, occupant_count, status])
		if b.id == previous_selection:
			buildings_list.select(i)

func _on_building_selected(index: int) -> void:
	var b: BuildingData = World.buildings[index]
	selected_building_id = b.id
	building_name_label.text = _building_header_text(b)
	character_details_label.text = ""
	_refresh_characters_list()

func _building_header_text(b: BuildingData) -> String:
	if b.staff_count <= 0:
		return b.building_name
	var status := "Открыто" if b.is_open(World.current_hour) else "Закрыто"
	return "%s\n%s — %s (сотрудников: %d)" % [b.building_name, b.schedule_label, status, b.staff_count]

func _refresh_characters_list() -> void:
	characters_list.clear()
	characters_in_selected_building = World.get_characters_in_building(selected_building_id)
	for c in characters_in_selected_building:
		characters_list.add_item("%s — %s" % [c.full_name(), _action_summary(c)])

func _on_character_selected(index: int) -> void:
	var c: CharacterData = characters_in_selected_building[index]
	character_details_label.text = _format_character_details(c)

func _action_summary(c: CharacterData) -> String:
	var text := _action_text(c.current_action)
	if c.current_activity_detail != "":
		text += " (%s)" % c.current_activity_detail
	return text

func _format_character_details(c: CharacterData) -> String:
	var home_building := World.get_building(c.home_building_id)
	var work_building := World.get_building(c.work_building_id)

	var lines: Array[String] = [
		"Имя: %s" % c.full_name(),
		"Пол: %s" % ("М" if c.gender == Enums.Gender.MALE else "Ж"),
		"Возраст: %d" % c.age,
		"Профессия: %s" % _profession_text(c.profession),
		"Отпечаток пальца: %s" % c.fingerprint,
		"",
		"Дом: %s" % (home_building.building_name if home_building != null else "—"),
		"Место работы: %s" % (work_building.building_name if work_building != null else "—"),
		"Часы работы: %s" % _work_hours_text(c),
		"Часы сна: %02d:00–%02d:00" % [c.sleep_start_hour, c.sleep_end_hour],
		"График: %s" % _schedule_text(c),
		"",
		"Действие: %s" % _action_summary(c),
		"",
		"Энергия: %d" % int(c.energy),
		"Голод: %d" % int(c.hunger),
		"Общение: %d" % int(c.social),
		"Веселье: %d" % int(c.fun),
		"Стресс: %d" % int(c.stress),
	]
	return "\n".join(lines)

func _work_hours_text(c: CharacterData) -> String:
	if c.profession == Enums.Profession.UNEMPLOYED:
		return "не работает"
	return "%02d:00–%02d:00" % [c.work_start_hour, c.work_end_hour]

func _schedule_text(c: CharacterData) -> String:
	if c.profession == Enums.Profession.UNEMPLOYED:
		return "—"
	if c.schedule_type == Enums.ScheduleType.FIVE_TWO:
		return "5/2 (выходные Сб/Вс)"
	return "2/2 (плавающие выходные)"

func _action_text(action: Enums.ActionType) -> String:
	match action:
		Enums.ActionType.SLEEP:
			return "Спит"
		Enums.ActionType.WORK:
			return "Работает"
		Enums.ActionType.EAT:
			return "Ест"
		Enums.ActionType.SOCIALIZE:
			return "Общается"
		Enums.ActionType.REST:
			return "Отдыхает"
		Enums.ActionType.WANDER:
			return "Гуляет"
	return "?"

func _profession_text(p: Enums.Profession) -> String:
	match p:
		Enums.Profession.UNEMPLOYED:
			return "Безработный"
		Enums.Profession.OFFICE_WORKER:
			return "Офисный работник"
		Enums.Profession.DOCTOR:
			return "Врач"
		Enums.Profession.BARTENDER:
			return "Бармен"
		Enums.Profession.SHOPKEEPER:
			return "Продавец"
	return "?"
