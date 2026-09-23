extends VBoxContainer

signal save_requested(values: Array)
signal cancel_requested

var fields: Array = []

func setup(initial_values: Array, language: String) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	var instruction = Label.new()
	instruction.text = "Muutos tallennetaan vain suomenkieliseen tekstiin." if language == "fi" else "This change is saved only in the English text."
	instruction.add_theme_font_size_override("font_size", 16)
	instruction.modulate = Color("a8c7cc")
	add_child(instruction)
	for index in range(initial_values.size()):
		var row = VBoxContainer.new()
		add_child(row)
		var label = Label.new()
		label.text = ("Rivi " if language == "fi" else "Line ") + str(index + 1) if initial_values.size() > 1 else ("Nimi" if language == "fi" else "Name")
		row.add_child(label)
		var field = LineEdit.new()
		field.text = str(initial_values[index])
		field.custom_minimum_size.y = 52
		field.max_length = 180 if initial_values.size() > 1 else 100
		field.set_meta("focus_id", "edit_field:" + str(index))
		field.text_submitted.connect(func(_text): _save())
		row.add_child(field)
		fields.append(field)
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(spacer)
	var actions = HBoxContainer.new()
	add_child(actions)
	var save = Button.new()
	save.text = "Tallenna" if language == "fi" else "Save"
	save.custom_minimum_size = Vector2(160, 46)
	save.set_meta("focus_id", "editor_save")
	save.pressed.connect(_save)
	actions.add_child(save)
	var cancel = Button.new()
	cancel.text = "Peruuta" if language == "fi" else "Cancel"
	cancel.custom_minimum_size = Vector2(140, 46)
	cancel.pressed.connect(func(): cancel_requested.emit())
	actions.add_child(cancel)
	_focus_first.call_deferred()

func _focus_first() -> void:
	if not is_inside_tree() or fields.is_empty(): return
	if is_instance_valid(fields[0]) and fields[0].is_inside_tree(): fields[0].grab_focus()

func _save() -> void:
	var values: Array = []
	for field in fields:
		if field.text.strip_edges().is_empty():
			field.grab_focus()
			return
		values.append(field.text.strip_edges())
	if values.is_empty() or str(values[0]).is_empty():
		if not fields.is_empty(): fields[0].grab_focus()
		return
	save_requested.emit(values)
