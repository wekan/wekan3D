extends VBoxContainer
## Complete schema-driven card editor. Complex WeKan values retain their structure.

signal saved
signal cancelled

const TAB_ORDER = ["main", "planning", "people", "checklists", "comments", "attachments", "advanced"]
const TAB_TITLES = {
	"main": ["Perustiedot", "Main"], "planning": ["Suunnittelu", "Planning"],
	"people": ["Ihmiset", "People"], "checklists": ["Tarkistuslistat", "Checklists"],
	"comments": ["Kommentit", "Comments"], "attachments": ["Liitteet", "Attachments"],
	"advanced": ["Lisätiedot", "Advanced"]
}
const RELATED_FIELDS = [
	{"key": "checklists", "tab": "checklists", "fi": "Tarkistuslistat", "en": "Checklists", "example": "[{\"_id\":\"checklist-1\",\"title\":\"Review\",\"sort\":0}]"},
	{"key": "checklistItems", "tab": "checklists", "fi": "Tarkistuslistojen kohdat", "en": "Checklist items", "example": "[{\"_id\":\"item-1\",\"checklistId\":\"checklist-1\",\"title\":\"Test changes\",\"isFinished\":false,\"sort\":0}]"},
	{"key": "cardComments", "tab": "comments", "fi": "Kommentit", "en": "Comments", "example": "[{\"_id\":\"comment-1\",\"text\":\"Ready for review\",\"userId\":\"author-1\"}]"},
	{"key": "cardCommentReactions", "tab": "comments", "fi": "Kommenttien reaktiot", "en": "Comment reactions", "example": "[]"},
	{"key": "attachments", "tab": "attachments", "fi": "Liitteiden tiedot", "en": "Attachment records", "example": "[]"},
	{"key": "activities", "tab": "advanced", "fi": "Tapahtumahistoria", "en": "Activity records", "example": "[]"},
]

var card_id = ""
var editing_language = "fi"
var field_controls: Dictionary = {}
var field_definitions: Dictionary = {}
var related_controls: Dictionary = {}
var tabs: TabContainer
var status_label: Label
var save_button: Button
var filter_input: LineEdit
var _pages: Dictionary = {}
var _rows: Dictionary = {}
var _initial_values: Dictionary = {}
var _initial_document: Dictionary = {}
var _initial_related: Dictionary = {}
var _schema
var _finished = false


func setup(id: String) -> void:
	card_id = id
	editing_language = GameState.language
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_schema = load("res://scripts/core/card_schema.gd")
	if _schema == null or not GameState.cards.has(card_id):
		var unavailable = Label.new()
		unavailable.text = _t("Kortin tietoja ei voitu avata.", "Could not open this card.")
		add_child(unavailable)
		return
	_initial_document = GameState.get_card_details(card_id, editing_language).duplicate(true)
	_initial_related = _initial_document.get("related", GameState.cards[card_id].get("related", {})).duplicate(true)
	_make_header()
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size.y = 250
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	add_child(tabs)
	for key in TAB_ORDER:
		var scroll = ScrollContainer.new()
		scroll.name = key
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		tabs.add_child(scroll)
		tabs.set_tab_title(tabs.get_tab_count() - 1, _pair(TAB_TITLES[key]))
		var margin = MarginContainer.new()
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_left", 18)
		margin.add_theme_constant_override("margin_right", 18)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_bottom", 18)
		scroll.add_child(margin)
		var page = VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 18)
		margin.add_child(page)
		_pages[key] = page
	var descriptors = _schema.fields().duplicate()
	descriptors.sort_custom(_field_order)
	for descriptor in descriptors:
		_make_field(descriptor)
	for relation in RELATED_FIELDS:
		_make_related(relation)
	_make_footer()
	if field_controls.has("title"):
		call_deferred("_focus_first")


func _focus_first() -> void:
	if not is_inside_tree():
		return
	# Let ScrollContainer calculate its content height before following focus.
	await get_tree().process_frame
	if is_inside_tree() and field_controls.has("title") and is_instance_valid(field_controls["title"]):
		tabs.current_tab = 0
		field_controls["title"].grab_focus()
		tabs.get_child(0).scroll_vertical = 0


func _make_header() -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	var note = Label.new()
	note.text = _t("Muokkaa kortin kaikkia tietoja. Tekstit: suomi. Muut tiedot ovat yhteisiä.", "Edit all card details. Text language: English. Other values are shared.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_theme_font_size_override("font_size", 15)
	note.modulate = Color("b4ccd0")
	row.add_child(note)
	filter_input = LineEdit.new()
	filter_input.custom_minimum_size = Vector2(260, 40)
	filter_input.placeholder_text = _t("Etsi kenttää…", "Find a field…")
	filter_input.clear_button_enabled = true
	filter_input.text_changed.connect(_filter_fields)
	filter_input.set_meta("focus_id", "card_editor_filter")
	row.add_child(filter_input)


func _make_field(descriptor: Dictionary) -> void:
	var key = str(descriptor.get("key", descriptor.get("path", "")))
	if key.is_empty():
		return
	field_definitions[key] = descriptor
	var group = _tab_for(descriptor)
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_pages[group].add_child(row)
	_rows[key] = {"node": row, "tab": group, "search": (key + " " + _localized(descriptor.get("label", key)) + " " + _localized(descriptor.get("help", ""))).to_lower()}
	var heading = HBoxContainer.new()
	row.add_child(heading)
	var label = Label.new()
	label.text = _localized(descriptor.get("label", key))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	heading.add_child(label)
	var hint = Label.new()
	var read_only = bool(descriptor.get("readonly", false))
	var localized = bool(descriptor.get("localized", false))
	hint.text = _t("Vain luku", "Read only") if read_only else ("FI" if editing_language == "fi" else "EN") if localized else ""
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color("8ebaae")
	heading.add_child(hint)
	var help = _localized(descriptor.get("help", ""))
	if not help.is_empty():
		var help_label = Label.new()
		help_label.text = help
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.modulate = Color("9bb7bf")
		help_label.add_theme_font_size_override("font_size", 13)
		row.add_child(help_label)
	var type = str(descriptor.get("type", "string")).to_lower()
	var value = _initial_document.get(key, _default_value(descriptor))
	if key == "_id" and (value == null or str(value).is_empty()):
		value = card_id
	var control: Control
	var allowed_values = descriptor.get("allowed_values", [])
	if not allowed_values.is_empty() and type not in ["array", "object", "mixed", "any"]:
		var choice = OptionButton.new()
		choice.custom_minimum_size.y = 43
		choice.disabled = read_only
		var allowed_labels = descriptor.get("allowed_labels", {}).get(editing_language, [])
		var selected_index = 0
		for index in range(allowed_values.size()):
			choice.add_item(str(allowed_labels[index]) if index < allowed_labels.size() else str(allowed_values[index]))
			choice.set_item_metadata(index, allowed_values[index])
			if allowed_values[index] == value:
				selected_index = index
		choice.select(selected_index)
		control = choice
	elif type == "boolean":
		var toggle = CheckButton.new()
		toggle.text = _t("Kyllä / käytössä", "Yes / enabled")
		toggle.button_pressed = bool(value) if value != null else false
		toggle.disabled = read_only
		control = toggle
	elif type in ["array", "object", "mixed", "any"]:
		var json = _json_editor(value if value != null else ([] if type == "array" else {}), read_only, 155)
		control = json
		var json_help = Label.new()
		json_help.text = _json_help(descriptor)
		json_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		json_help.add_theme_font_size_override("font_size", 12)
		json_help.modulate = Color("8ebaae")
		row.add_child(json_help)
	elif key == "description" or type == "text":
		var text = TextEdit.new()
		text.text = "" if value == null else str(value)
		text.editable = not read_only
		text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		text.custom_minimum_size.y = 185
		control = text
	else:
		var text = LineEdit.new()
		text.text = "" if value == null else str(value)
		text.editable = not read_only
		text.custom_minimum_size.y = 43
		if type == "date":
			text.placeholder_text = _t("VVVV-KK-PP tai VVVV-KK-PPTHH:MM:SSZ", "YYYY-MM-DD or YYYY-MM-DDTHH:MM:SSZ")
		elif type == "number":
			text.placeholder_text = _t("Luku, desimaalierotin piste", "Number, use a dot for decimals")
		control = text
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.set_meta("focus_id", "card_field:" + key)
	if read_only:
		control.modulate = Color("a1afb5")
	row.add_child(control)
	field_controls[key] = control
	_initial_values[key] = _read_control(key).get("value")


func _make_related(relation: Dictionary) -> void:
	var key = str(relation.key)
	var row = VBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_pages[relation.tab].add_child(row)
	_rows["related." + key] = {"node": row, "tab": relation.tab, "search": (key + " " + relation.fi + " " + relation.en).to_lower()}
	var label = Label.new()
	label.text = _localized(relation)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var instruction = Label.new()
	instruction.text = _t("JSON-taulukko. Kukin tietue on oma objekti; tunnisteet yhdistävät tietueet tähän korttiin.", "JSON array. Each record is an object; IDs connect records to this card.")
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.modulate = Color("a7c4ca")
	instruction.add_theme_font_size_override("font_size", 13)
	row.add_child(instruction)
	var editor = _json_editor(_initial_related.get(key, []), false, 205)
	editor.set_meta("focus_id", "card_related:" + key)
	row.add_child(editor)
	related_controls[key] = editor
	var example = Label.new()
	example.text = _t("Esimerkki: ", "Example: ") + str(relation.example)
	example.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	example.modulate = Color("89b5a9")
	example.add_theme_font_size_override("font_size", 12)
	row.add_child(example)
	# Expose every related model's available fields as a compact reference.
	var related_schema = _schema.schema(key)
	var references = _related_reference(related_schema)
	if not references.is_empty():
		var reference = RichTextLabel.new()
		reference.fit_content = true
		reference.scroll_active = false
		reference.selection_enabled = true
		reference.text = _t("Mallin kentät: ", "Model fields: ") + references
		reference.add_theme_font_size_override("normal_font_size", 12)
		reference.modulate = Color("91aeb8")
		row.add_child(reference)


func _related_reference(schema: Dictionary) -> String:
	var values = schema.get("fields", [])
	var names = PackedStringArray()
	if values is Array:
		for value in values:
			if value is Dictionary:
				names.append(str(value.get("key", value.get("path", ""))))
	elif values is Dictionary:
		for key in values:
			names.append(str(key))
	return ", ".join(names)


func _json_editor(value, read_only: bool, height: int) -> TextEdit:
	var editor = TextEdit.new()
	editor.text = JSON.stringify(value, "  ")
	editor.custom_minimum_size.y = height
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.editable = not read_only
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	editor.add_theme_font_override("font", font)
	editor.add_theme_font_size_override("font_size", 14)
	return editor


func _make_footer() -> void:
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.modulate = Color("ffad9c")
	status_label.visible = false
	add_child(status_label)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	add_child(actions)
	save_button = Button.new()
	save_button.text = _t("Tallenna kortti", "Save card")
	save_button.custom_minimum_size = Vector2(180, 46)
	save_button.set_meta("focus_id", "card_editor_save")
	save_button.pressed.connect(_save)
	actions.add_child(save_button)
	var cancel = Button.new()
	cancel.text = _t("Peruuta", "Cancel")
	cancel.custom_minimum_size = Vector2(140, 46)
	cancel.set_meta("focus_id", "card_editor_cancel")
	cancel.pressed.connect(func(): cancelled.emit())
	actions.add_child(cancel)
	var note = Label.new()
	note.text = _t("Esc: takaisin  •  Järjestelmäkentät päivittyvät automaattisesti", "Esc: back  •  System fields update automatically")
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("9ab4bd")
	note.add_theme_font_size_override("font_size", 12)
	actions.add_child(note)


func _tab_for(descriptor: Dictionary) -> String:
	match str(descriptor.get("group", "advanced")):
		"basic", "appearance": return "main"
		"workflow", "dates", "location", "dependencies": return "planning"
		"people": return "people"
		_: return "advanced"


func _field_order(left: Dictionary, right: Dictionary) -> bool:
	var rank = {"title": 0, "description": 1, "priority": 2, "startAt": 3, "dueAt": 4, "endAt": 5, "members": 6, "assignees": 7, "customFields": 8}
	var left_rank = int(rank.get(left.get("key", ""), 90 if left.get("readonly", false) else 40))
	var right_rank = int(rank.get(right.get("key", ""), 90 if right.get("readonly", false) else 40))
	return left_rank < right_rank


func _default_value(descriptor: Dictionary):
	if bool(descriptor.get("has_default", false)):
		return descriptor.get("default")
	match str(descriptor.get("type", "string")):
		"array": return []
		"object": return {}
		"boolean": return false
		"number": return null
		_: return ""


func _json_help(descriptor: Dictionary) -> String:
	var type = str(descriptor.get("type", "object"))
	var hint = _t("JSON-taulukko: [ … ].", "JSON array: [ … ].") if type == "array" else _t("JSON-objekti: { … }.", "JSON object: { … }.")
	var children = descriptor.get("children", [])
	var items = descriptor.get("items", {})
	if items is Dictionary and children.is_empty():
		children = items.get("children", [])
	var child_names = PackedStringArray()
	if children is Array:
		for child in children:
			if child is Dictionary:
				child_names.append(str(child.get("key", child.get("path", ""))))
	elif children is Dictionary:
		for key in children:
			child_names.append(str(key))
	if not child_names.is_empty():
		hint += _t(" Kentät: ", " Fields: ") + ", ".join(child_names)
	return hint


func _read_control(key: String) -> Dictionary:
	var descriptor = field_definitions[key]
	var control = field_controls[key]
	var type = str(descriptor.get("type", "string"))
	if control is OptionButton:
		return {"value": control.get_item_metadata(control.selected)}
	if type == "boolean":
		return {"value": control.button_pressed}
	var raw = str(control.text)
	if type in ["array", "object", "mixed", "any"]:
		return _parse_json(raw, type)
	if type == "number":
		if raw.strip_edges().is_empty() and bool(descriptor.get("optional", false)):
			return {"value": null}
		if not raw.is_valid_float():
			return {"error": _t("Anna kelvollinen luku.", "Enter a valid number.")}
		return {"value": float(raw)}
	if type == "date":
		if raw.strip_edges().is_empty():
			return {"value": null}
		if not _valid_date(raw.strip_edges()):
			return {"error": _t("Käytä kelvollista ISO-päivämäärää, esimerkiksi 2026-09-08 tai 2026-09-08T14:30:00Z.", "Use a valid ISO date, such as 2026-09-08 or 2026-09-08T14:30:00Z.")}
		return {"value": raw.strip_edges()}
	return {"value": raw}


func _parse_json(raw: String, expected: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(raw) != OK:
		return {"error": _t("Virheellinen JSON rivillä %d: %s", "Invalid JSON on line %d: %s") % [json.get_error_line() + 1, json.get_error_message()]}
	if expected == "array" and not json.data is Array:
		return {"error": _t("Arvon on oltava JSON-taulukko [ … ].", "Value must be a JSON array [ … ].")}
	if expected == "object" and not json.data is Dictionary:
		return {"error": _t("Arvon on oltava JSON-objekti { … }.", "Value must be a JSON object { … }.")}
	return {"value": json.data}


func _valid_date(value: String) -> bool:
	var expression = RegEx.new()
	expression.compile("^(\\d{4})-(\\d{2})-(\\d{2})(?:T(\\d{2}):(\\d{2})(?::(\\d{2})(?:\\.\\d{1,6})?)?(?:Z|[+-]\\d{2}:\\d{2})?)?$")
	var matched = expression.search(value)
	if matched == null:
		return false
	var year = int(matched.get_string(1))
	var month = int(matched.get_string(2))
	var day = int(matched.get_string(3))
	if month < 1 or month > 12 or day < 1:
		return false
	var days = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day <= days[month - 1] and int(matched.get_string(4)) < 24 and int(matched.get_string(5)) < 60 and int(matched.get_string(6)) < 60


func collect_changes() -> Dictionary:
	var changes: Dictionary = {}
	for key in field_controls:
		if bool(field_definitions[key].get("readonly", false)):
			continue
		var result = _read_control(key)
		if result.has("error"):
			return {"error": str(result.error), "field": key}
		if result.value != _initial_values.get(key):
			changes[key] = result.value
	var related: Dictionary = {}
	var related_changed = false
	for key in related_controls:
		var result = _parse_json(related_controls[key].text, "array")
		if result.has("error"):
			return {"error": str(result.error), "field": "related." + key}
		for record in result.value:
			if not record is Dictionary:
				return {"error": _t("Jokaisen tietueen on oltava JSON-objekti.", "Every record must be a JSON object."), "field": "related." + key}
		if result.value != _initial_related.get(key, []):
			related[key] = result.value
			related_changed = true
	if related_changed:
		changes["related"] = related
	return {"values": changes}


func _save() -> void:
	if _finished:
		return
	var result = collect_changes()
	if result.has("error"):
		_show_error(result.error, result.get("field", ""))
		return
	if not GameState.edit_card_details(card_id, result["values"], editing_language):
		_show_error(GameState.last_error)
		return
	_finished = true
	saved.emit()


func _show_error(message: String, field: String = "") -> void:
	status_label.text = (field + ": " if not field.is_empty() else "") + message
	status_label.visible = true
	if _rows.has(field):
		filter_input.text = ""
		_filter_fields("")
		tabs.current_tab = TAB_ORDER.find(_rows[field].tab)
		var control = related_controls.get(field.trim_prefix("related.")) if field.begins_with("related.") else field_controls.get(field)
		if control != null:
			control.grab_focus()


func _filter_fields(query: String) -> void:
	var needle = query.strip_edges().to_lower()
	var first_tab = -1
	for key in _rows:
		var row = _rows[key]
		row.node.visible = needle.is_empty() or str(row.search).contains(needle)
		if row.node.visible and first_tab < 0:
			first_tab = TAB_ORDER.find(row.tab)
	if not needle.is_empty() and first_tab >= 0:
		tabs.current_tab = first_tab


func set_field_value(key: String, value) -> void:
	## Public helper also used by the regression test and controller integration.
	if key.begins_with("related."):
		var related_key = key.trim_prefix("related.")
		if related_controls.has(related_key):
			related_controls[related_key].text = JSON.stringify(value, "  ")
		return
	if not field_controls.has(key) or bool(field_definitions[key].get("readonly", false)):
		return
	var type = str(field_definitions[key].get("type", "string"))
	if field_controls[key] is OptionButton:
		var choice = field_controls[key]
		for index in range(choice.item_count):
			if choice.get_item_metadata(index) == value:
				choice.select(index)
	elif type == "boolean":
		field_controls[key].button_pressed = bool(value)
	elif type in ["array", "object", "mixed", "any"]:
		field_controls[key].text = JSON.stringify(value, "  ")
	else:
		field_controls[key].text = "" if value == null else str(value)


func _localized(value) -> String:
	if value is Dictionary:
		return str(value.get(editing_language, value.get("en", value.get("fi", ""))))
	return str(value)


func _pair(values: Array) -> String:
	return str(values[0 if editing_language == "fi" else 1])


func _t(fi: String, en: String) -> String:
	return fi if editing_language == "fi" else en
