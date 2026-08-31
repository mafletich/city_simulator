class_name DecisionWeights
extends Resource

## Все "магические числа" системы принятия решений и обновления потребностей
## собраны здесь, чтобы их можно было крутить ползунками прямо в игре
## (см. scripts/ui/weights_panel.gd), не трогая код.
##
## Работа и сон в свои расписанные часы больше не "весы", а жёсткое правило
## (см. DecisionSystem.decide_action) — поэтому здесь только веса для того,
## что происходит вне рабочего/спального окна, плюс скорость потребностей.

## --- Скорость изменения потребностей (за один цикл = 10 игровых минут) ---
@export var energy_decay_rate: float = 0.5
@export var work_extra_fatigue: float = 0.3
@export var hunger_growth_rate: float = 0.6
@export var social_decay_rate: float = 0.5
@export var fun_decay_rate: float = 0.4
@export var stress_growth_rate: float = 0.2

## --- Насколько сильно действие восстанавливает/тратит потребности ---
@export var sleep_energy_regen: float = 3.0
@export var eat_hunger_relief: float = 30.0
@export var socialize_social_gain: float = 15.0
@export var socialize_fun_gain: float = 10.0
@export var rest_fun_gain: float = 5.0
@export var rest_stress_relief: float = 2.0
@export var wander_fun_gain: float = 8.0
@export var work_stress_gain: float = 2.0

## --- "Ест, не покидая работу" ---
@export var work_lunch_hunger_threshold: float = 60.0
@export var work_lunch_relief: float = 15.0

## --- Базовые веса конкурирующих желаний (вне рабочего/спального окна) ---
@export var eat_weight: float = 0.9
@export var socialize_weight: float = 0.8
@export var rest_weight: float = 0.5
@export var wander_weight: float = 0.4
@export var inertia_bonus: float = 8.0

## --- Профессиональное поведение ---
@export var bartender_serve_chance: float = 0.95

## Список описаний для автогенерации UI-панели с ползунками.
static func get_definitions() -> Array[Dictionary]:
	return [
		{"label": "Расход энергии / цикл", "property": "energy_decay_rate", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Доп. усталость от работы / цикл", "property": "work_extra_fatigue", "min": 0.0, "max": 1.0, "step": 0.05},
		{"label": "Рост голода / цикл", "property": "hunger_growth_rate", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Спад потребности в общении / цикл", "property": "social_decay_rate", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Спад веселья / цикл", "property": "fun_decay_rate", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Рост стресса / цикл", "property": "stress_growth_rate", "min": 0.0, "max": 1.0, "step": 0.05},
		{"label": "Восстановление энергии сном", "property": "sleep_energy_regen", "min": 0.5, "max": 10.0, "step": 0.5},
		{"label": "Снижение голода едой", "property": "eat_hunger_relief", "min": 5.0, "max": 60.0, "step": 1.0},
		{"label": "Порог голода для обеда на работе", "property": "work_lunch_hunger_threshold", "min": 20.0, "max": 90.0, "step": 5.0},
		{"label": "Снижение голода обедом на работе", "property": "work_lunch_relief", "min": 5.0, "max": 40.0, "step": 1.0},
		{"label": "Вес желания поесть", "property": "eat_weight", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Вес желания общаться", "property": "socialize_weight", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Вес желания отдыхать", "property": "rest_weight", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Вес желания гулять", "property": "wander_weight", "min": 0.1, "max": 2.0, "step": 0.05},
		{"label": "Инерция текущего действия", "property": "inertia_bonus", "min": 0.0, "max": 50.0, "step": 1.0},
		{"label": "Шанс бармена обслужить клиента", "property": "bartender_serve_chance", "min": 0.0, "max": 1.0, "step": 0.05},
	]
