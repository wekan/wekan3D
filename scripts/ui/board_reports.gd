extends VBoxContainer
## Counts from canonical board ownership, with explicit date-only semantics.
signal closed
const Dates = preload("res://scripts/ui/board_dates.gd")
var board_id = ""
var report: Dictionary = {}
var _fingerprint = -1

class CountBar extends Control:
	var count = 0
	var maximum = 1
	var color = Color("57b89c")
	func _draw() -> void:
		draw_rect(Rect2(0,8,size.x,14),Color("264553"))
		if count > 0:
			draw_rect(Rect2(0,8,size.x*float(count)/float(maxi(1,maximum)),14),color)

func setup(id: String) -> void:
	board_id = id
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",15)
	GameState.cards_changed.connect(refresh)
	GameState.language_changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_inside_tree():return
	report = Dates.snapshot(GameState,board_id)
	var fingerprint = hash([report,GameState.language,Dates.today().key])
	if fingerprint == _fingerprint:return
	_fingerprint = fingerprint
	for child in get_children():remove_child(child);child.queue_free()
	var heading = HBoxContainer.new()
	add_child(heading)
	var title = Label.new()
	title.text = report.title + " · " + _t("Raportit","Reports")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",23)
	heading.add_child(title)
	var close = Button.new()
	close.text = _t("Takaisin taululle","Back to board")
	close.custom_minimum_size.y = 38
	close.pressed.connect(func():closed.emit())
	heading.add_child(close)
	var metrics = GridContainer.new()
	metrics.columns = 4
	metrics.add_theme_constant_override("h_separation",12)
	add_child(metrics)
	_metric(metrics,_t("Kortteja yhteensä","Total cards"),report.total_cards,Color("87cddd"))
	_metric(metrics,_t("Aikataulutettuja","Scheduled cards"),report.scheduled,Color("70c6a5"))
	_metric(metrics,_t("Ilman päiväystä","Without schedule dates"),report.undated.size(),Color("bba5d6"))
	_metric(metrics,_t("Menneet määräpäivät","Past due dates"),report.past_due,Color("e6b26c"))
	var note = Label.new()
	note.text = _t("Aikataulutettu = vastaanotto-, aloitus-, määrä- tai päättymispäivä. Menneet määräpäivät lasketaan ennen tätä päivää olevista määräajoista; valmistumista ei päätellä.","Scheduled means a received, start, due or end date exists. Past due dates count due dates before today; no completion status is inferred.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.modulate = Color("adc6cf")
	note.add_theme_font_size_override("font_size",14)
	add_child(note)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",13)
	scroll.add_child(content)
	var lanes_heading = Label.new()
	lanes_heading.text = "%s (%d)" % [_t("Kortit uimaradoittain","Cards by swimlane"),report.lanes.size()]
	lanes_heading.add_theme_font_size_override("font_size",20)
	content.add_child(lanes_heading)
	var maximum = 1
	for lane in report.lanes:maximum = maxi(maximum,lane.count)
	for lane in report.lanes:_bar_row(content,lane.title,lane.count,maximum,Color("60bea3"))
	var lists_heading = Label.new()
	lists_heading.text = "%s (%d)" % [_t("Kortit listoittain","Cards by list"),report.lists.size()]
	lists_heading.add_theme_font_size_override("font_size",20)
	content.add_child(lists_heading)
	maximum = 1
	for item in report.lists:maximum = maxi(maximum,item.count)
	for item in report.lists:_bar_row(content,item.lane_title + " / " + item.title,item.count,maximum,Color("88b4d2"))
	var footnote = Label.new()
	footnote.text = _t("Mukana ovat tämän taulun kaikki uimaradat ja listat. Taskuun siirretyt kortit eivät sisälly taulun lukuihin.","Includes every swimlane and list on this board. Cards moved into the pocket are excluded from board counts.")
	footnote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footnote.modulate = Color("8faeba")
	footnote.add_theme_font_size_override("font_size",13)
	content.add_child(footnote)

func _metric(parent: Node,label_text: String,value: int,color: Color) -> void:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color("203c49")
	style.set_corner_radius_all(10)
	style.content_margin_left = 16;style.content_margin_right = 16
	style.content_margin_top = 14;style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box = VBoxContainer.new();panel.add_child(box)
	var number = Label.new();number.text = str(value);number.modulate = color
	number.add_theme_font_size_override("font_size",34);box.add_child(number)
	var label = Label.new();label.text = label_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 150
	label.add_theme_font_size_override("font_size",14);box.add_child(label)

func _bar_row(parent: Node,label_text: String,value: int,maximum: int,color: Color) -> void:
	var row = HBoxContainer.new();row.add_theme_constant_override("separation",15);parent.add_child(row)
	var label = Label.new();label.text = label_text
	label.custom_minimum_size.x = 280
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = label_text
	row.add_child(label)
	var bar = CountBar.new();bar.count = value;bar.maximum = maximum;bar.color = color
	bar.custom_minimum_size = Vector2(80,32);bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	var count = Label.new();count.text = str(value);count.custom_minimum_size.x = 50
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(count)

func _t(fi: String,en: String) -> String:
	return fi if GameState.language == "fi" else en
