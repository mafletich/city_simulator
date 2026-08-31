extends PanelContainer

## Автогенерируемая панель ползунков для DecisionWeights: не нужно руками
## добавлять/связывать новый Slider в сцене при каждом новом весе — она
## сама строит список из DecisionWeights.get_definitions().

@onready var rows_container: VBoxContainer = $Scroll/RowsContainer

func _ready() -> void:
	visible = false
	_build_rows()

func _build_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "Настройка весов ИИ"
	title.add_theme_font_size_override("font_size", 18)
	rows_container.add_child(title)
	rows_container.add_child(HSeparator.new())

	for definition in DecisionWeights.get_definitions():
		rows_container.add_child(_build_row(definition))

func _build_row(definition: Dictionary) -> Control:
	var row := VBoxContainer.new()

	var header := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = definition["label"]
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)

	var current_value: float = World.weights.get(definition["property"])
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.text = "%.2f" % current_value
	header.add_child(value_label)
	row.add_child(header)

	var slider := HSlider.new()
	slider.min_value = definition["min"]
	slider.max_value = definition["max"]
	slider.step = definition["step"]
	slider.value = current_value
	var property_name: String = definition["property"]
	slider.value_changed.connect(func(v: float) -> void:
		World.weights.set(property_name, v)
		value_label.text = "%.2f" % v
	)
	row.add_child(slider)
	row.add_child(HSeparator.new())

	return row
