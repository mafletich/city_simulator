extends Control

@onready var time_label: Label = $VBox/TopBarPanel/TopBarMargin/TopBar/TimeLabel
@onready var next_tick_button: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/NextTickButton
@onready var weights_button: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/WeightsButton
@onready var logs_button: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/LogsButton
@onready var weights_panel: PanelContainer = $WeightsPanel

@onready var buildings_list: ItemList = $VBox/ContentArea/BuildingsPanel/BuildingsMargin/BuildingsVBox/BuildingsList
@onready var characters_header: Label = $VBox/ContentArea/CharactersPanel/CharactersMargin/CharactersVBox/CharactersHeader
@onready var characters_list: ItemList = $VBox/ContentArea/CharactersPanel/CharactersMargin/CharactersVBox/CharactersList

const DETAILS_ROOT := "VBox/ContentArea/DetailsPanel/DetailsMargin/DetailsScroll/"
@onready var placeholder_label: Label = get_node(DETAILS_ROOT + "PlaceholderLabel")
@onready var details_content: VBoxContainer = get_node(DETAILS_ROOT + "ContentVBox")
@onready var name_label: Label = get_node(DETAILS_ROOT + "ContentVBox/NameLabel")
@onready var subtitle_label: Label = get_node(DETAILS_ROOT + "ContentVBox/SubtitleLabel")
@onready var gender_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/GenderValue")
@onready var age_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/AgeValue")
@onready var profession_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/ProfessionValue")
@onready var home_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/HomeValue")
@onready var work_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/WorkValue")
@onready var work_hours_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/WorkHoursValue")
@onready var sleep_hours_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/SleepHoursValue")
@onready var schedule_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/ScheduleValue")
@onready var fingerprint_value: Label = get_node(DETAILS_ROOT + "ContentVBox/FactsGrid/FingerprintValue")
@onready var action_label: Label = get_node(DETAILS_ROOT + "ContentVBox/ActionLabel")

@onready var energy_bar: ProgressBar = get_node(DETAILS_ROOT + "ContentVBox/EnergyRow/Bar")
@onready var energy_value_label: Label = get_node(DETAILS_ROOT + "ContentVBox/EnergyRow/ValueLabel")
@onready var hunger_bar: ProgressBar = get_node(DETAILS_ROOT + "ContentVBox/HungerRow/Bar")
@onready var hunger_value_label: Label = get_node(DETAILS_ROOT + "ContentVBox/HungerRow/ValueLabel")
@onready var social_bar: ProgressBar = get_node(DETAILS_ROOT + "ContentVBox/SocialRow/Bar")
@onready var social_value_label: Label = get_node(DETAILS_ROOT + "ContentVBox/SocialRow/ValueLabel")
@onready var fun_bar: ProgressBar = get_node(DETAILS_ROOT + "ContentVBox/FunRow/Bar")
@onready var fun_value_label: Label = get_node(DETAILS_ROOT + "ContentVBox/FunRow/ValueLabel")
@onready var stress_bar: ProgressBar = get_node(DETAILS_ROOT + "ContentVBox/StressRow/Bar")
@onready var stress_value_label: Label = get_node(DETAILS_ROOT + "ContentVBox/StressRow/ValueLabel")

var selected_building_id: int = -1
var selected_character_id: int = -1
var characters_in_selected_building: Array[CharacterData] = []

func _ready() -> void:
	next_tick_button.pressed.connect(_on_next_tick_pressed)
	weights_button.pressed.connect(_on_weights_button_pressed)
	logs_button.pressed.connect(_on_logs_button_pressed)
	buildings_list.item_selected.connect(_on_building_selected)
	characters_list.item_selected.connect(_on_character_selected)

	_refresh_buildings_list()
	_update_time_label()
	print("Журналы персонажей: ", EventLogger.get_log_dir_absolute())

func _on_logs_button_pressed() -> void:
	OS.shell_open(EventLogger.get_log_dir_absolute())

func _on_next_tick_pressed() -> void:
	World.advance_tick()
	_update_time_label()
	_refresh_buildings_list()
	if selected_building_id != -1:
		characters_header.text = _building_header_text(World.get_building(selected_building_id))
		_refresh_characters_list()
	_refresh_selected_character_details()

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
			status = " · Открыто" if b.is_open(World.current_hour, World.current_day) else " · Закрыто"
		buildings_list.add_item("%s (%d чел.)%s" % [b.building_name, occupant_count, status])
		if b.id == previous_selection:
			buildings_list.select(i)

func _on_building_selected(index: int) -> void:
	var b: BuildingData = World.buildings[index]
	selected_building_id = b.id
	characters_header.text = _building_header_text(b)
	_refresh_characters_list()

func _building_header_text(b: BuildingData) -> String:
	if b == null:
		return "Выберите здание слева"
	if b.staff_count <= 0:
		return b.building_name
	var status := "Открыто" if b.is_open(World.current_hour, World.current_day) else "Закрыто"
	return "%s\n%s, %s — %s (сотрудников: %d)" % [b.building_name, b.workdays_label, b.schedule_label, status, b.staff_count]

func _refresh_characters_list() -> void:
	var previous_selection := selected_character_id
	characters_list.clear()
	characters_in_selected_building = World.get_characters_in_building(selected_building_id)
	for i in range(characters_in_selected_building.size()):
		var c := characters_in_selected_building[i]
		characters_list.add_item("%s — %s" % [c.full_name(), _action_summary(c)])
		if c.id == previous_selection:
			characters_list.select(i)

func _on_character_selected(index: int) -> void:
	var c: CharacterData = characters_in_selected_building[index]
	selected_character_id = c.id
	_show_character_details(c)

func _refresh_selected_character_details() -> void:
	if selected_character_id == -1:
		return
	for c in characters_in_selected_building:
		if c.id == selected_character_id:
			_show_character_details(c)
			return
	# Персонаж, за которым мы наблюдали, покинул это здание — карточка остаётся
	# на экране (последнее известное состояние), просто больше не обновляется.

func _action_summary(c: CharacterData) -> String:
	var text := Enums.action_text(c.current_action)
	if c.current_activity_detail != "":
		text += " (%s)" % c.current_activity_detail
	return text

func _show_character_details(c: CharacterData) -> void:
	placeholder_label.visible = false
	details_content.visible = true

	var home_building := World.get_building(c.home_building_id)
	var work_building := World.get_building(c.work_building_id)

	name_label.text = c.full_name()
	subtitle_label.text = "%s · %d лет · %s" % [
		Enums.profession_text(c.profession), c.age,
		"мужчина" if c.gender == Enums.Gender.MALE else "женщина",
	]

	gender_value.text = "М" if c.gender == Enums.Gender.MALE else "Ж"
	age_value.text = str(c.age)
	profession_value.text = Enums.profession_text(c.profession)
	home_value.text = home_building.building_name if home_building != null else "—"
	work_value.text = work_building.building_name if work_building != null else "—"
	work_hours_value.text = _work_hours_text(c)
	sleep_hours_value.text = "%02d:00–%02d:00" % [c.sleep_start_hour, c.sleep_end_hour]
	schedule_value.text = _schedule_text(c)
	fingerprint_value.text = c.fingerprint

	action_label.text = "Действие: %s" % _action_summary(c)

	_set_need(energy_bar, energy_value_label, c.energy)
	_set_need(hunger_bar, hunger_value_label, c.hunger)
	_set_need(social_bar, social_value_label, c.social)
	_set_need(fun_bar, fun_value_label, c.fun)
	_set_need(stress_bar, stress_value_label, c.stress)

func _set_need(bar: ProgressBar, label: Label, value: float) -> void:
	bar.value = value
	label.text = str(int(value))

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
