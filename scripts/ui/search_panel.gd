extends VBoxContainer

signal navigation_requested(result: Dictionary)
signal query_changed(query: String)
signal remote_connection_requested(entity_id: String)

const SearchIndex = preload("res://scripts/core/search_index.gd")
const PAGE_SIZE = 8

var state: Object
var search_field: LineEdit
var count_label: Label
var results_box: VBoxContainer
var page_label: Label
var previous_button: Button
var next_button: Button
var debounce: Timer
var results: Array = []
var page: int = 0
var current_query: String = ""
var built: bool = false

func setup(game_state: Object = null) -> void:
	state = game_state if game_state != null else get_node_or_null("/root/GameState")
	if not built:
		_build()
	if state != null and state.has_signal("cards_changed") and not state.is_connected("cards_changed", _data_changed):
		state.connect("cards_changed", _data_changed)
	if state != null and state.has_signal("entities_changed") and not state.is_connected("entities_changed", _data_changed):
		state.connect("entities_changed", _data_changed)
	refresh_language()

func open(query: String = "") -> void:
	if not built:
		setup()
	current_query = query
	search_field.text = query
	page = 0
	_run_search()
	search_field.grab_focus.call_deferred()
	search_field.caret_column = query.length()

func _text(fi: String, en: String) -> String:
	return fi if str(SearchIndex.property_value(state, "language", "fi")) == "fi" else en

func _build() -> void:
	built = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	var search_row = HBoxContainer.new()
	add_child(search_row)
	var symbol = Label.new()
	symbol.text = "⌕"
	symbol.add_theme_font_size_override("font_size", 34)
	symbol.add_theme_color_override("font_color", Color("65d7bc"))
	search_row.add_child(symbol)
	search_field = LineEdit.new()
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.custom_minimum_size.y = 46
	search_field.clear_button_enabled = true
	search_field.add_theme_font_size_override("font_size", 19)
	search_field.add_theme_color_override("font_color", Color("edf5f6"))
	search_field.add_theme_color_override("font_placeholder_color", Color("8eacb7"))
	search_field.add_theme_color_override("caret_color", Color("65d7bc"))
	for style_name in ["normal", "focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("102733")
		style.set_corner_radius_all(8)
		style.set_border_width_all(2 if style_name == "focus" else 1)
		style.border_color = Color("65d7bc") if style_name == "focus" else Color("385965")
		style.content_margin_left = 12
		style.content_margin_right = 12
		search_field.add_theme_stylebox_override(style_name, style)
	search_field.text_changed.connect(_query_edited)
	search_field.text_submitted.connect(func(_value): debounce.stop(); _run_search())
	search_row.add_child(search_field)
	count_label = Label.new()
	count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	count_label.add_theme_color_override("font_color", Color("a2bdc7"))
	add_child(count_label)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	results_box = VBoxContainer.new()
	results_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_box.add_theme_constant_override("separation", 9)
	scroll.add_child(results_box)
	var footer = HBoxContainer.new()
	add_child(footer)
	previous_button = Button.new()
	previous_button.custom_minimum_size = Vector2(150, 40)
	previous_button.pressed.connect(func(): page = maxi(0, page - 1); _render_results())
	footer.add_child(previous_button)
	page_label = Label.new()
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(page_label)
	next_button = Button.new()
	next_button.custom_minimum_size = Vector2(150, 40)
	next_button.pressed.connect(func(): page += 1; _render_results())
	footer.add_child(next_button)
	debounce = Timer.new()
	debounce.one_shot = true
	debounce.wait_time = 0.16
	debounce.timeout.connect(_run_search)
	add_child(debounce)

func refresh_language() -> void:
	if not built or state == null:
		return
	search_field.placeholder_text = _text("Hae huoneita, kerroksia, kortteja, ihmisiä, huonekaluja…", "Search rooms, floors, cards, people, furniture…")
	previous_button.text = _text("← Edellinen", "← Previous")
	next_button.text = _text("Seuraava →", "Next →")
	_run_search()

func _query_edited(value: String) -> void:
	current_query = value
	page = 0
	query_changed.emit(value)
	debounce.start()

func _data_changed() -> void:
	if built and is_visible_in_tree():
		debounce.start()

func _run_search() -> void:
	if state == null:
		return
	current_query = search_field.text
	results = SearchIndex.search(current_query, state)
	page = mini(page, maxi(0, ceili(float(results.size()) / PAGE_SIZE) - 1))
	_render_results()

func _render_results() -> void:
	for child in results_box.get_children():
		results_box.remove_child(child)
		child.queue_free()
	var page_count = maxi(1, ceili(float(results.size()) / PAGE_SIZE))
	page = clampi(page, 0, page_count - 1)
	previous_button.disabled = page == 0
	next_button.disabled = page >= page_count - 1
	page_label.text = _text("Sivu %d / %d", "Page %d / %d") % [page + 1, page_count]
	if current_query.strip_edges().is_empty():
		count_label.text = _text("Kaikki tallennetut tekstit ovat haettavissa suomeksi ja englanniksi. Kirjoita yksi tai useampi hakusana.", "All saved text can be searched in Finnish and English. Enter one or more search words.")
		_empty_state(_text("Löydä oikea huone, tehtävä tai työkaveri", "Find the right room, task or colleague"), _text("Esimerkiksi: robotti • kerros 3 • näyttö • Aino • taskussa", "For example: robot • floor 3 • monitor • Aino • pocket"))
		return
	count_label.text = _text("%d tulosta · kaikki hakusanat täsmäävät · valitse tulos nähdäksesi sijainnin", "%d results · all search words match · select a result to see its location") % results.size()
	if results.is_empty():
		_empty_state(_text("Ei hakutuloksia", "No results found"), _text("Kokeile lyhyempää hakusanaa tai huoneen numeroa. Voit hakea myös toisella kielellä.", "Try a shorter word or a room number. You can also search in the other language."))
		return
	for index in range(page * PAGE_SIZE, mini((page + 1) * PAGE_SIZE, results.size())):
		_add_result(results[index])
	var scroll = results_box.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0

func _empty_state(title: String, detail: String) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 150
	results_box.add_child(panel)
	var margin = _margin(panel, 22)
	var box = VBoxContainer.new()
	margin.add_child(box)
	box.add_child(_label(title, 22, Color("edf5f6")))
	box.add_child(_label(detail, 16, Color("a2bdc7")))

func _add_result(result: Dictionary) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	results_box.add_child(row)
	var button = Button.new()
	button.custom_minimum_size.y = 118
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = str(result.title) + "\n" + str(result.detail) + "\n" + str(result.location)
	button.pressed.connect(func(): navigation_requested.emit(result))
	row.add_child(button)
	if result.get("kind", "") == "person":
		var remote_button = Button.new()
		remote_button.text = _text("Etäyhteys", "Remote call")
		remote_button.custom_minimum_size = Vector2(145, 46)
		remote_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		remote_button.tooltip_text = _text("Avaa henkilö tabletin näytölle", "Open this person on the tablet screen")
		remote_button.set_meta("focus_id", "remote:" + str(result.id))
		remote_button.pressed.connect(func(): remote_connection_requested.emit(str(result.id)))
		row.add_child(remote_button)
	var margin = _margin(button, 13)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var type_label = _label(_kind_label(str(result.kind)).to_upper() + "  ·  " + str(result.location), 12, Color("65d7bc"))
	type_label.custom_minimum_size.y = 20
	type_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	type_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(type_label)
	var title = _label(str(result.title), 19, Color("edf5f6"))
	title.custom_minimum_size.y = 30
	title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title)
	var detail = _label(str(result.detail), 14, Color("a2bdc7"))
	detail.custom_minimum_size.y = 32
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(detail)

func _kind_label(kind: String) -> String:
	var labels = {
		"organization": ["Organisaatio", "Organization"],
		"room": ["Huone", "Room"], "board": ["Kanban-taulu", "Kanban board"],
		"swimlane": ["Uimarata", "Swimlane"], "list": ["Lista", "List"],
		"card": ["Kortti", "Card"], "furniture": ["Huonekalu", "Furniture"],
		"person": ["Ihminen", "Person"], "record": ["Tietue", "Record"]
	}
	var pair = labels.get(kind, [kind, kind])
	return _text(pair[0], pair[1])

func _margin(parent: Node, amount: int) -> MarginContainer:
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(margin)
	return margin

func _label(text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
