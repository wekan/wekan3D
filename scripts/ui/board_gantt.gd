extends VBoxContainer
## A date-faithful timeline: no invented start or finish dates.
signal card_selected(card_id: String)
signal closed
const Dates = preload("res://scripts/ui/board_dates.gd")
var board_id = ""
var schedule: Dictionary = {}
var intervals: Array = []
var _fingerprint = -1

class Timeline extends Control:
	signal selected(id: String)
	const ROW_HEIGHT = 50.0
	const AXIS_HEIGHT = 48.0
	var records: Array = []
	var first_day = 0
	var last_day = 0
	var pixels_per_day = 20.0
	var locale = "fi"
	func configure(values: Array, first: int, last: int, language: String) -> void:
		records = values; first_day = first; last_day = last; locale = language
		var span = maxi(1,last_day-first_day+1)
		var width = clampf(span*20.0,780.0,20000.0)
		pixels_per_day = width/float(span)
		custom_minimum_size = Vector2(width,AXIS_HEIGHT+records.size()*ROW_HEIGHT)
		queue_redraw()
	func _draw() -> void:
		pixels_per_day = size.x/float(maxi(1,last_day-first_day+1))
		var font = ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO,size),Color("182e3b"))
		var step = maxi(1,int(ceil(80.0/pixels_per_day)))
		for day in range(first_day,last_day+1,step):
			var x = float(day-first_day)*pixels_per_day
			var date = Dates.date_from_day(day)
			draw_line(Vector2(x,28),Vector2(x,size.y),Color("355160"))
			draw_string(font,Vector2(x+4,22),"%02d.%02d" % [date.day,date.month],HORIZONTAL_ALIGNMENT_LEFT,76,13,Color("b4ced7"))
		var today_x = (Dates.today().number-first_day+0.5)*pixels_per_day
		if today_x >= 0 and today_x < size.x:
			draw_line(Vector2(today_x,29),Vector2(today_x,size.y),Color("62d4b0"),2)
		for index in range(records.size()):
			var row: Dictionary = records[index]
			var y = AXIS_HEIGHT+index*ROW_HEIGHT
			if index%2 == 0:
				draw_rect(Rect2(0,y,size.x,ROW_HEIGHT),Color(0.2,0.37,0.42,0.22))
			var middle = y+ROW_HEIGHT*0.5
			var interval: Dictionary = row.interval
			if interval.has_bar:
				var from_x = (mini(interval.start,interval.end)-first_day+0.5)*pixels_per_day
				var to_x = (maxi(interval.start,interval.end)-first_day+0.5)*pixels_per_day
				draw_rect(Rect2(from_x,middle-7,maxf(6,to_x-from_x),14),Color("cc8585") if interval.reversed else Color("3e947f"))
			for marker in interval.markers:
				var x = (marker.number-first_day+0.5)*pixels_per_day
				var color = Color(Dates.DATE_FIELDS[marker.field].color)
				if marker.field == "dueAt":
					draw_colored_polygon(PackedVector2Array([Vector2(x,middle-9),Vector2(x+8,middle),Vector2(x,middle+9),Vector2(x-8,middle)]),color)
				else:
					draw_circle(Vector2(x,middle),5,color)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var index = int(floor((event.position.y-AXIS_HEIGHT)/ROW_HEIGHT))
			if index >= 0 and index < records.size():
				selected.emit(records[index].card_id)
				accept_event()

func setup(id: String) -> void:
	board_id = id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	GameState.cards_changed.connect(refresh)
	GameState.language_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	schedule = Dates.snapshot(GameState,board_id)
	var fingerprint = hash([schedule,GameState.language])
	if fingerprint == _fingerprint:
		return
	_fingerprint = fingerprint
	_clear(self)
	intervals = []
	var first_day = 9223372036854775807
	var last_day = -9223372036854775807
	var unscheduled: Array = []
	for card in schedule.cards:
		var interval = Dates.gantt_interval(card)
		if interval.markers.is_empty():
			unscheduled.append(card)
			continue
		var row = card.duplicate(true)
		row["interval"] = interval
		intervals.append(row)
		for marker in interval.markers:
			first_day = mini(first_day,marker.number)
			last_day = maxi(last_day,marker.number)
	var heading = HBoxContainer.new()
	add_child(heading)
	var title = Label.new()
	title.text = schedule.title + " · Gantt"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",23)
	heading.add_child(title)
	heading.add_child(_button(_t("Takaisin taululle","Back to board"),func():closed.emit()))
	var help = Label.new()
	help.text = _t("Palkki: aloitus → päättyminen; ilman päättymistä → määräaika. Timantti: määräaika. Yksittäinen päivä näkyy pisteenä.","Bar: start → end; without an end date → due date. Diamond: due date. A single date is shown as a marker.")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color("b1c9d2")
	help.add_theme_font_size_override("font_size",14)
	add_child(help)
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation",24)
	add_child(legend)
	for field in Dates.SCHEDULE_FIELDS:
		var label = Label.new()
		label.text = "◆  " if field == "dueAt" else "●  "
		label.text += _t(Dates.DATE_FIELDS[field].fi,Dates.DATE_FIELDS[field].en)
		label.modulate = Color(Dates.DATE_FIELDS[field].color)
		legend.add_child(label)
	var outer = ScrollContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.follow_focus = true
	add_child(outer)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",16)
	outer.add_child(content)
	if not intervals.is_empty():
		var range_label = Label.new()
		range_label.text = "%s – %s  ·  %d %s" % [Dates.date_from_day(first_day).key,Dates.date_from_day(last_day).key,intervals.size(),_t("päivättyä korttia","dated cards")]
		content.add_child(range_label)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation",0)
		content.add_child(row)
		var labels = VBoxContainer.new()
		labels.custom_minimum_size.x = 230
		labels.add_theme_constant_override("separation",0)
		row.add_child(labels)
		var axis = Label.new()
		axis.text = _t("Kortti","Card")
		axis.custom_minimum_size.y = Timeline.AXIS_HEIGHT
		labels.add_child(axis)
		for record in intervals:
			var button = _button(record.title,_open_card.bind(record.card_id))
			button.custom_minimum_size = Vector2(230,Timeline.ROW_HEIGHT)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var tips: Array = [record.title,record.lane_title + " / " + record.list_title]
			for marker in record.interval.markers:
				tips.append(_t(Dates.DATE_FIELDS[marker.field].fi,Dates.DATE_FIELDS[marker.field].en)+": "+marker.date)
			if record.interval.reversed:
				tips.append(_t("Päättävä päivä on ennen aloitusta.","The ending date precedes the start."))
			button.tooltip_text = "\n".join(tips)
			labels.add_child(button)
		var timeline_scroll = ScrollContainer.new()
		timeline_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		timeline_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		timeline_scroll.custom_minimum_size.y = Timeline.AXIS_HEIGHT+intervals.size()*Timeline.ROW_HEIGHT+18
		row.add_child(timeline_scroll)
		var chart = Timeline.new()
		chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chart.configure(intervals,first_day-1,last_day+1,GameState.language)
		chart.selected.connect(_open_card)
		timeline_scroll.add_child(chart)
	else:
		var empty = Label.new()
		empty.text = _t("Taulun korteilla ei ole aikataulupäiväyksiä.","The board has no scheduling dates.")
		content.add_child(empty)
	var undated_heading = Label.new()
	undated_heading.text = "%s (%d)" % [_t("Ilman aikataulupäiväyksiä","Without scheduling dates"),unscheduled.size()]
	undated_heading.add_theme_font_size_override("font_size",19)
	content.add_child(undated_heading)
	for card in unscheduled:
		var button = _button(card.title,_open_card.bind(card.card_id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.tooltip_text = card.lane_title + " / " + card.list_title
		content.add_child(button)

func _open_card(id: String) -> void:
	if GameState.cards.has(id):card_selected.emit(id)
func _button(text: String,callback: Callable) -> Button:
	var button = Button.new();button.text = text;button.custom_minimum_size.y = 38
	button.pressed.connect(callback);return button
func _clear(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func _t(fi: String,en: String) -> String:
	return fi if GameState.language == "fi" else en
