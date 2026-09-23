extends VBoxContainer
## Bilingual person profile with stable, reorderable question/answer records.

signal saved
signal cancelled
signal deleted

var entity_id = ""
var editing_language = "fi"
var fields: Dictionary = {}
var qa_rows: Array = []
var qa_container: VBoxContainer
var qa_scroll: ScrollContainer
var status_label: Label
var count_label: Label
var add_button: Button
var save_button: Button
var delete_button: Button
var delete_dialog: ConfirmationDialog
var age_picker: OptionButton
var team_picker: OptionButton
var initial_team_id: String = ""
var _next_row_key = 0
var _finished = false


func setup(id: String) -> void:
	entity_id = id
	editing_language = GameState.language
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var profile = GameState.get_person_profile(id, editing_language)
	if profile.is_empty():
		var unavailable = Label.new()
		unavailable.text = _t("Henkilöä ei löytynyt.", "Person not found.")
		add_child(unavailable)
		return
	var instruction = Label.new()
	instruction.text = _t("Muokkaat suomenkielistä henkilökuvausta ja vastauksia. Englanninkieliset tekstit säilyvät.", "You are editing the English profile and answers. Finnish text is preserved.")
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.modulate = Color("b0c8ce")
	instruction.add_theme_font_size_override("font_size", 15)
	add_child(instruction)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	add_child(grid)
	_make_field(grid, "name", _t("Nimi", "Name"), str(profile.get("name", "")))
	_make_field(grid, "title", _t("Tehtävänimike", "Job title"), str(profile.get("title", "")))
	_make_field(grid, "team_role", _t("Tiimirooli", "Team role"), str(profile.get("team_role", "")))
	_make_field(grid, "expertise", _t("Osaamisalueet", "Expertise"), str(profile.get("expertise", "")), true)
	_make_age_and_team(grid, profile)
	var questions_heading = HBoxContainer.new()
	questions_heading.add_theme_constant_override("separation", 14)
	add_child(questions_heading)
	var title = Label.new()
	title.text = _t("Kysymykset ja vastaukset", "Questions and answers")
	title.add_theme_font_size_override("font_size", 21)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	questions_heading.add_child(title)
	count_label = Label.new()
	count_label.modulate = Color("98bdc0")
	questions_heading.add_child(count_label)
	add_button = Button.new()
	add_button.text = _t("+ Lisää kysymys", "+ Add question")
	add_button.custom_minimum_size = Vector2(185, 40)
	add_button.set_meta("focus_id", "person_add_question")
	add_button.pressed.connect(_add_blank_question)
	questions_heading.add_child(add_button)
	qa_scroll = ScrollContainer.new()
	qa_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	qa_scroll.follow_focus = true
	qa_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	qa_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qa_scroll.custom_minimum_size.y = 160
	add_child(qa_scroll)
	qa_container = VBoxContainer.new()
	qa_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qa_container.add_theme_constant_override("separation", 14)
	qa_scroll.add_child(qa_container)
	for pair in profile.get("qa", []):
		add_question(str(pair.get("question", "")), str(pair.get("answer", "")), str(pair.get("id", "")))
	_make_footer()
	_refresh_rows()
	call_deferred("_focus_name")


func _make_field(parent: Node, key: String, title: String, value: String, multiline: bool = false) -> void:
	var row = VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)
	var label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var control: Control
	if multiline:
		var text = TextEdit.new()
		text.text = value
		text.custom_minimum_size.y = 66
		text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		control = text
	else:
		var text = LineEdit.new()
		text.text = value
		text.custom_minimum_size.y = 42
		text.max_length = 180 if key == "name" else 500
		control = text
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.set_meta("focus_id", "person_field:" + key)
	row.add_child(control)
	fields[key] = control

func _make_age_and_team(parent: Node, profile: Dictionary) -> void:
	var entity: Dictionary = GameState.entities.get(entity_id, {})
	var age_row = VBoxContainer.new()
	age_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(age_row)
	var age_label = Label.new()
	age_label.text = _t("Ikäryhmä", "Age group")
	age_row.add_child(age_label)
	age_picker = OptionButton.new()
	age_picker.custom_minimum_size.y = 42
	age_picker.set_meta("focus_id", "person_age_group")
	age_picker.add_item(_t("Nuori", "Young"))
	age_picker.add_item(_t("Keski-ikäinen", "Middle-aged"))
	age_picker.add_item(_t("Iäkäs", "Older"))
	var age_groups: Array = ["young", "middle", "old"]
	age_picker.select(maxi(0, age_groups.find(str(profile.get("age_group", entity.get("age_group", "middle"))))))
	age_row.add_child(age_picker)
	var team_row = VBoxContainer.new()
	team_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(team_row)
	var team_label = Label.new()
	team_label.text = _t("Tiimi ja työtila", "Team and workspace")
	team_row.add_child(team_label)
	team_picker = OptionButton.new()
	team_picker.custom_minimum_size.y = 42
	team_picker.clip_text = true
	team_picker.set_meta("focus_id", "person_team")
	team_row.add_child(team_picker)
	initial_team_id = str(profile.get("team_id", entity.get("team_id", "")))
	team_picker.add_item(_t("Säilytä nykyinen tiimi", "Keep current team"))
	team_picker.set_item_metadata(0, initial_team_id)
	var teams = GameState.get("teams")
	if not teams is Dictionary: return
	var ids: Array = teams.keys()
	ids.sort()
	for team_id in ids:
		var team: Dictionary = teams[team_id]
		if team.get("deleted", false): continue
		var room_id: String = str(team.get("room_id", ""))
		if GameState.has_method("is_spatial_active") and str(team_id) != initial_team_id and not bool(GameState.call("is_spatial_active", "room", room_id)): continue
		var name_value = team.get("name", "")
		var team_name: String = str(name_value.get(editing_language, name_value.get("en", ""))) if name_value is Dictionary else str(name_value)
		team_picker.add_item(team_name + " · " + GameState.room_name(room_id))
		team_picker.set_item_metadata(team_picker.item_count - 1, str(team_id))
		if str(team_id) == initial_team_id: team_picker.select(team_picker.item_count - 1)


func add_question(question: String = "", answer: String = "", stable_id: String = "") -> Dictionary:
	if qa_rows.size() >= 200:
		return {}
	_next_row_key += 1
	var row: Dictionary = {"id": stable_id, "key": _next_row_key}
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color("193644")
	style.border_color = Color("305361")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	qa_container.add_child(panel)
	row["panel"] = panel
	var body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	var heading = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	body.add_child(heading)
	var number = Label.new()
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	number.add_theme_font_size_override("font_size", 17)
	number.modulate = Color("b4e0d1")
	heading.add_child(number)
	row["heading"] = number
	var up = Button.new()
	up.text = "↑"
	up.custom_minimum_size = Vector2(40, 32)
	up.tooltip_text = _t("Siirrä kysymys ylöspäin", "Move question up")
	up.pressed.connect(_move_question.bind(_next_row_key, -1))
	heading.add_child(up)
	row["up"] = up
	var down = Button.new()
	down.text = "↓"
	down.custom_minimum_size = Vector2(40, 32)
	down.tooltip_text = _t("Siirrä kysymys alaspäin", "Move question down")
	down.pressed.connect(_move_question.bind(_next_row_key, 1))
	heading.add_child(down)
	row["down"] = down
	var remove = Button.new()
	remove.text = _t("Poista pari", "Remove pair")
	remove.custom_minimum_size = Vector2(125, 32)
	remove.tooltip_text = _t("Poistaa tämän kysymys–vastausparin molemmilla kielillä tallennettaessa.", "Saving removes this question and answer in both languages.")
	remove.pressed.connect(_remove_question.bind(_next_row_key))
	heading.add_child(remove)
	row["remove"] = remove
	var question_label = Label.new()
	question_label.text = _t("Kysymys", "Question")
	question_label.add_theme_font_size_override("font_size", 14)
	body.add_child(question_label)
	var question_control = TextEdit.new()
	question_control.text = question
	question_control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	question_control.custom_minimum_size.y = 61
	question_control.placeholder_text = _t("Mitä pelaaja voi kysyä tältä henkilöltä?", "What can the player ask this person?")
	question_control.set_meta("focus_id", "person_question:%d" % _next_row_key)
	body.add_child(question_control)
	row["question"] = question_control
	var answer_label = Label.new()
	answer_label.text = _t("Vastaus", "Answer")
	answer_label.add_theme_font_size_override("font_size", 14)
	body.add_child(answer_label)
	var answer_control = TextEdit.new()
	answer_control.text = answer
	answer_control.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	answer_control.custom_minimum_size.y = 94
	answer_control.placeholder_text = _t("Kirjoita henkilön vastaus pelaajalle.", "Write this person's answer to the player.")
	answer_control.set_meta("focus_id", "person_answer:%d" % _next_row_key)
	body.add_child(answer_control)
	row["answer"] = answer_control
	if not stable_id.is_empty() and question.is_empty() and answer.is_empty():
		var missing = Label.new()
		missing.text = _t("Tälle parille ei vielä ole suomenkielistä käännöstä.", "This pair does not have an English translation yet.")
		missing.modulate = Color("edcb8b")
		missing.add_theme_font_size_override("font_size", 12)
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(missing)
		row["missing_translation"] = missing
		question_control.text_changed.connect(_refresh_translation_hint.bind(_next_row_key))
		answer_control.text_changed.connect(_refresh_translation_hint.bind(_next_row_key))
	qa_rows.append(row)
	_refresh_rows()
	return row


func _refresh_translation_hint(key: int) -> void:
	var index = _row_index(key)
	if index >= 0 and qa_rows[index].has("missing_translation"):
		var row = qa_rows[index]
		row.missing_translation.visible = str(row.question.text).is_empty() and str(row.answer.text).is_empty()


func _add_blank_question() -> void:
	var row = add_question()
	if not row.is_empty():
		call_deferred("_focus_question", int(row.key))


func _focus_question(key: int) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var index = _row_index(key)
	if is_inside_tree() and index >= 0:
		qa_rows[index].question.grab_focus()
		qa_scroll.ensure_control_visible(qa_rows[index].panel)


func _focus_name() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if is_inside_tree() and fields.has("name"):
		fields.name.grab_focus()


func _remove_question(key: int) -> void:
	var index = _row_index(key)
	if index < 0:
		return
	var row = qa_rows[index]
	qa_container.remove_child(row.panel)
	row.panel.queue_free()
	qa_rows.remove_at(index)
	_refresh_rows()


func _move_question(key: int, direction: int) -> void:
	var index = _row_index(key)
	var destination = index + direction
	if index < 0 or destination < 0 or destination >= qa_rows.size():
		return
	var row = qa_rows[index]
	qa_rows.remove_at(index)
	qa_rows.insert(destination, row)
	qa_container.move_child(row.panel, destination)
	_refresh_rows()


func _row_index(key: int) -> int:
	for index in range(qa_rows.size()):
		if int(qa_rows[index].key) == key:
			return index
	return -1


func _refresh_rows() -> void:
	for index in range(qa_rows.size()):
		var row = qa_rows[index]
		row.heading.text = _t("Kysymys %d", "Question %d") % (index + 1)
		row.up.disabled = index == 0
		row.down.disabled = index == qa_rows.size() - 1
	if count_label != null:
		count_label.text = _t("%d paria", "%d pairs") % qa_rows.size()
	if add_button != null:
		add_button.disabled = qa_rows.size() >= 200


func _make_footer() -> void:
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.modulate = Color("ffb29d")
	status_label.visible = false
	add_child(status_label)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	save_button = Button.new()
	save_button.text = _t("Tallenna henkilö", "Save person")
	save_button.custom_minimum_size = Vector2(190, 46)
	save_button.set_meta("focus_id", "person_editor_save")
	save_button.pressed.connect(_save)
	row.add_child(save_button)
	var cancel = Button.new()
	cancel.text = _t("Peruuta", "Cancel")
	cancel.custom_minimum_size = Vector2(140, 46)
	cancel.set_meta("focus_id", "person_editor_cancel")
	cancel.pressed.connect(func(): cancelled.emit())
	row.add_child(cancel)
	var space = Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	delete_button = Button.new()
	delete_button.text = _t("Poista henkilö…", "Delete person…")
	delete_button.custom_minimum_size = Vector2(175, 46)
	delete_button.modulate = Color("efb4a6")
	delete_button.set_meta("focus_id", "person_editor_delete")
	delete_button.pressed.connect(_request_delete)
	row.add_child(delete_button)
	delete_dialog = ConfirmationDialog.new()
	delete_dialog.title = _t("Poista henkilö", "Delete person")
	delete_dialog.ok_button_text = _t("Poista henkilö", "Delete person")
	delete_dialog.cancel_button_text = _t("Peruuta", "Cancel")
	delete_dialog.confirmed.connect(_delete_confirmed)
	add_child(delete_dialog)


func collect_values() -> Dictionary:
	var values: Dictionary = {}
	for key in fields:
		values[key] = str(fields[key].text).strip_edges()
	if values.name.is_empty():
		return {"error": _t("Kirjoita henkilön nimi.", "Enter the person's name."), "field": "name"}
	var pairs: Array = []
	for index in range(qa_rows.size()):
		var row = qa_rows[index]
		var question = str(row.question.text).strip_edges()
		var answer = str(row.answer.text).strip_edges()
		var untranslated = not str(row.id).is_empty() and question.is_empty() and answer.is_empty()
		if (question.is_empty() or answer.is_empty()) and not untranslated:
			return {"error": _t("Täytä sekä kysymys että vastaus kohdassa %d.", "Enter both the question and answer for pair %d.") % (index + 1), "row_key": row.key}
		var pair = {"question": question, "answer": answer}
		if not str(row.id).is_empty():
			pair["id"] = str(row.id)
		pairs.append(pair)
	values["qa"] = pairs
	var age_groups: Array = ["young", "middle", "old"]
	values["age_group"] = str(age_groups[age_picker.selected])
	if team_picker.selected >= 0:
		var selected_team_id: String = str(team_picker.get_item_metadata(team_picker.selected))
		if not selected_team_id.is_empty() and selected_team_id != initial_team_id: values["team_id"] = selected_team_id
	return {"values": values}


func _save() -> void:
	if _finished:
		return
	var result = collect_values()
	if result.has("error"):
		_show_error(str(result.error))
		if result.has("field"):
			fields[result.field].grab_focus()
		elif result.has("row_key"):
			_focus_question(int(result.row_key))
		return
	if not GameState.edit_person_profile(entity_id, result["values"], editing_language):
		_show_error(GameState.last_error)
		return
	_finished = true
	saved.emit()


func _request_delete() -> void:
	if _finished:
		return
	var display_name = str(fields.name.text).strip_edges()
	delete_dialog.dialog_text = _t("Poistetaanko %s? Henkilö poistuu toimistosta ja henkilöluettelosta.", "Delete %s? This person will leave the office and the people directory.") % display_name
	delete_dialog.popup_centered(Vector2i(530, 175))


func _delete_confirmed() -> void:
	if _finished:
		return
	if not GameState.delete_person(entity_id):
		_show_error(GameState.last_error)
		return
	_finished = true
	deleted.emit()


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.visible = true


func _t(fi: String, en: String) -> String:
	return fi if editing_language == "fi" else en
