extends VBoxContainer
## Monday-first calendar using the actual optional dates on every board card.
signal card_selected(card_id: String)
signal closed
const Dates = preload("res://scripts/ui/board_dates.gd")
var board_id = ""
var display_year = 2026
var display_month = 1
var selected_fields: Array = Dates.SCHEDULE_FIELDS.duplicate()
var schedule: Dictionary = {}
var event_map: Dictionary = {}
var day_cells: Dictionary = {}
var month_label: Label
var title_label: Label
var field_picker: OptionButton
var grid: GridContainer
var undated_list: VBoxContainer
var undated_title: Label
var _built = false
var _fingerprint = -1
static var _last_views: Dictionary = {}

func setup(id: String) -> void:
	board_id = id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var date = Dates.today()
	display_year = date.year; display_month = date.month
	if _last_views.has(board_id):
		display_year = int(_last_views[board_id].year)
		display_month = int(_last_views[board_id].month)
		selected_fields = _last_views[board_id].fields.duplicate()
	_build()
	for index in range(field_picker.item_count):
		if field_picker.get_item_metadata(index) == selected_fields:field_picker.select(index)
	GameState.cards_changed.connect(refresh)
	GameState.language_changed.connect(_language_changed)
	refresh()

func _build() -> void:
	_built = true
	var heading = HBoxContainer.new()
	add_child(heading)
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_font_size_override("font_size",22)
	heading.add_child(title_label)
	var close = _button(_t("Takaisin taululle","Back to board"),func(): closed.emit())
	heading.add_child(close)
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation",10)
	add_child(toolbar)
	toolbar.add_child(_button("‹",func():change_month(-1)))
	month_label = Label.new()
	month_label.custom_minimum_size.x = 245
	month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_label.add_theme_font_size_override("font_size",23)
	toolbar.add_child(month_label)
	toolbar.add_child(_button("›",func():change_month(1)))
	toolbar.add_child(_button(_t("Tänään","Today"),go_today))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	field_picker = OptionButton.new()
	field_picker.custom_minimum_size = Vector2(230,38)
	field_picker.add_item(_t("Aikataulupäivät","Schedule dates"))
	field_picker.set_item_metadata(0,Dates.SCHEDULE_FIELDS.duplicate())
	field_picker.add_item(_t("Kaikki päivämäärät","All date fields"))
	field_picker.set_item_metadata(1,Dates.DATE_FIELDS.keys())
	for field in Dates.DATE_FIELDS:
		field_picker.add_item(_t(Dates.DATE_FIELDS[field].fi,Dates.DATE_FIELDS[field].en))
		field_picker.set_item_metadata(field_picker.item_count-1,[field])
	field_picker.item_selected.connect(_select_fields)
	toolbar.add_child(field_picker)
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation",22)
	add_child(legend)
	for field in Dates.SCHEDULE_FIELDS:
		var label = Label.new()
		label.text = "●  " + _t(Dates.DATE_FIELDS[field].fi,Dates.DATE_FIELDS[field].en)
		label.modulate = Color(Dates.DATE_FIELDS[field].color)
		label.add_theme_font_size_override("font_size",14)
		legend.add_child(label)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",14)
	add_child(body)
	var calendar = VBoxContainer.new()
	calendar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(calendar)
	var weekdays = GridContainer.new()
	weekdays.columns = 7
	weekdays.add_theme_constant_override("h_separation",6)
	calendar.add_child(weekdays)
	var names = ["Ma","Ti","Ke","To","Pe","La","Su"] if GameState.language == "fi" else ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
	for name_text in names:
		var label = Label.new()
		label.text = name_text
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.custom_minimum_size.x = 74
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color("a9c9ce")
		weekdays.add_child(label)
	grid = GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	calendar.add_child(grid)
	var sidebar = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 210
	body.add_child(sidebar)
	undated_title = Label.new()
	undated_title.add_theme_font_size_override("font_size",17)
	sidebar.add_child(undated_title)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sidebar.add_child(scroll)
	undated_list = VBoxContainer.new()
	undated_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undated_list.add_theme_constant_override("separation",7)
	scroll.add_child(undated_list)
	var note = Label.new()
	note.text = _t("Päivämäärät näkyvät tallennetun kalenteripäivän mukaan. Avaa kortti klikkaamalla.","Dates use their stored calendar day. Select any event to open its card.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("8facb7")
	note.add_theme_font_size_override("font_size",13)
	add_child(note)

func refresh() -> void:
	if not _built or not is_inside_tree():
		return
	schedule = Dates.snapshot(GameState,board_id)
	var fingerprint = hash([schedule,selected_fields,display_year,display_month,GameState.language,Dates.today().key])
	if fingerprint == _fingerprint:return
	_fingerprint = fingerprint
	var events = Dates.events(schedule,selected_fields)
	event_map = events.by_day
	title_label.text = "%s  ·  %d %s" % [schedule.title,schedule.total_cards,_t("korttia","cards")]
	month_label.text = Dates.month_title(display_year,display_month,GameState.language)
	_clear(grid); _clear(undated_list)
	day_cells.clear()
	for date in Dates.month_grid(display_year,display_month):
		_make_day(date)
	undated_title.text = _t("Ilman valittuja päiviä","No selected dates") + " (%d)" % events.undated.size()
	for card in events.undated:
		var button = _button(card.title,_open_card.bind(card.card_id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size = Vector2(190,40)
		button.tooltip_text = card.title + "\n" + card.lane_title + " / " + card.list_title
		undated_list.add_child(button)
	if events.undated.is_empty():
		var empty = Label.new()
		empty.text = _t("Kaikilla korteilla on päiväys.","Every card has a date.")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size.x = 190
		undated_list.add_child(empty)

func _make_day(date: Dictionary) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(74,72)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var current = date.month == display_month
	var style = StyleBoxFlat.new()
	style.bg_color = Color("213d4b") if current else Color("152d39")
	style.set_corner_radius_all(7)
	style.content_margin_left = 6; style.content_margin_right = 6
	style.content_margin_top = 4; style.content_margin_bottom = 4
	if date.key == Dates.today().key:
		style.set_border_width_all(2)
		style.border_color = Color("60c9ab")
	panel.add_theme_stylebox_override("panel",style)
	grid.add_child(panel)
	day_cells[date.key] = panel
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",3)
	panel.add_child(box)
	var heading = Label.new()
	heading.text = str(date.day)
	heading.add_theme_font_size_override("font_size",14)
	heading.modulate = Color("e3f3ec") if current else Color("819ba7")
	box.add_child(heading)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation",3)
	scroll.add_child(entries)
	for event in event_map.get(date.key,[]):
		var info: Dictionary = Dates.DATE_FIELDS[event.field]
		var button = _button("● " + event.title,_open_card.bind(event.card_id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size = Vector2(58,27)
		button.add_theme_font_size_override("font_size",12)
		button.add_theme_color_override("font_color",Color(info.color))
		button.tooltip_text = "%s\n%s · %s\n%s / %s" % [event.title,_t(info.fi,info.en),date.key,event.lane_title,event.list_title]
		button.set_meta("card_id",event.card_id)
		button.set_meta("date_field",event.field)
		entries.add_child(button)

func show_month(year: int, month: int) -> void:
	if year < 1 or year > 9999 or month < 1 or month > 12:
		return
	display_year = year; display_month = month
	_remember_view()
	refresh()

func change_month(delta: int) -> void:
	var shifted = Dates.shift_month(display_year,display_month,delta)
	show_month(shifted.x,shifted.y)

func go_today() -> void:
	var current = Dates.today()
	show_month(current.year,current.month)

func _select_fields(index: int) -> void:
	selected_fields = field_picker.get_item_metadata(index).duplicate()
	_remember_view()
	refresh()

func _language_changed() -> void:
	var selected = selected_fields.duplicate()
	_clear(self)
	_build()
	_fingerprint = -1
	selected_fields = selected
	for index in range(field_picker.item_count):
		if field_picker.get_item_metadata(index) == selected_fields:
			field_picker.select(index)
	refresh()

func _remember_view() -> void:
	_last_views[board_id] = {"year":display_year,"month":display_month,"fields":selected_fields.duplicate()}

func _open_card(id: String) -> void:
	if GameState.cards.has(id):
		card_selected.emit(id)

func _button(text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	return button

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _t(fi: String,en: String) -> String:
	return fi if GameState.language == "fi" else en
