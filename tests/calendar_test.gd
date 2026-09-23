extends SceneTree
const Dates = preload("res://scripts/ui/board_dates.gd")
var checks = 0
var failures = 0
var selected = ""
var capture_directory = ""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="): capture_directory = argument.trim_prefix("--capture=")
	create_timer(30).timeout.connect(func():push_error("Calendar test timeout");quit(1))
	call_deferred("_run")
func _run() -> void:
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.reset_game();state.set_language("fi")
	state.ensure_board("calendar_board","calendar_room",0)
	state.ensure_board("outside_board","outside_room",1)
	_expect(Dates.days_in_month(2024,2) == 29,"leap year February")
	_expect(Dates.days_in_month(1900,2) == 28 and Dates.days_in_month(2000,2) == 29,"century leap rules")
	_expect(Dates.shift_month(2026,12,1) == Vector2i(2027,1),"December rollover")
	_expect(Dates.shift_month(2026,1,-1) == Vector2i(2025,12),"January rollover")
	var cells = Dates.month_grid(2024,2)
	_expect(cells.size() == 42 and cells[0].key == "2024-01-29" and cells[41].key == "2024-03-10","six weeks Monday-first")
	_expect(Dates.parse_date("2024-02-29T23:00:00+03:00").key == "2024-02-29","stored date preserved across timezone suffix")
	_expect(Dates.parse_date("2023-02-29").is_empty() and Dates.parse_date(null).is_empty(),"invalid and absent dates excluded")
	var id = str(state.boards.calendar_board.cards[0][0])
	var second = str(state.boards.calendar_board.cards[0][1])
	_expect(state.edit_card_details(id,{"receivedAt":"2024-02-26","startAt":"2024-02-27","dueAt":"2024-02-29","endAt":"2024-03-02"}),"date edit fixture")
	_expect(state.edit_card_details(second,{"startAt":"2024-02-29","dueAt":"2024-02-29"}),"same-day distinct date fields")
	_expect(not state.add_swimlane("calendar_board","Toinen uimarata").is_empty(),"second lane fixture")
	var added = state.add_card("calendar_board",1,0,["Lisäkortti","Rivi2","Rivi3","Rivi4"])
	_expect(not added.is_empty() and state.edit_card_details(added,{"dueAt":"2024-03-01"}),"additional lane dated card")
	var facts = Dates.snapshot(state,"calendar_board")
	_expect(facts.total_cards == 17 and facts.scheduled == 3 and facts.undated.size() == 14,"all lanes counted, other board excluded")
	var events = Dates.events(facts)
	_expect(events.by_day["2024-02-26"][0].field == "receivedAt","received date assigned")
	_expect(events.by_day["2024-02-27"][0].field == "startAt","start date assigned")
	_expect(events.by_day["2024-02-29"].size() == 3,"same-day events preserve each date kind")
	_expect(events.by_day["2024-03-02"][0].field == "endAt","end date assigned to next month")
	var calendar_script = load("res://scripts/ui/board_calendar.gd")
	if calendar_script == null:
		push_error("Calendar did not compile");quit(1);return
	root.size = Vector2i(1440,900)
	var background = ColorRect.new();background.color = Color("102431");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
	var shell = Control.new();shell.size = Vector2(1360,820);shell.position = Vector2(40,40);root.add_child(shell)
	var ui = load("res://scripts/ui/game_ui.gd").new();shell.theme = ui._make_theme();ui.free()
	var calendar = calendar_script.new();shell.add_child(calendar)
	calendar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	calendar.setup("calendar_board")
	calendar.card_selected.connect(func(card_id):selected=card_id)
	calendar.show_month(2024,2)
	await process_frame
	await process_frame
	await _capture("calendar-fi.png")
	_expect(calendar.day_cells.size() == 42 and calendar.month_label.text == "Helmikuu 2024","Finnish month grid rendered")
	calendar._open_card(id)
	_expect(selected == id,"calendar selection opens exact card")
	calendar.change_month(10)
	_expect(calendar.display_year == 2024 and calendar.display_month == 12,"month navigation")
	calendar.change_month(1)
	_expect(calendar.display_year == 2025 and calendar.display_month == 1,"UI year navigation")
	state.set_language("en")
	_expect(calendar.month_label.text == "January 2025","English month labels update")
	calendar.show_month(2024,2)
	await process_frame
	await _capture("calendar-en.png")
	calendar._select_fields(1)
	_expect(calendar.selected_fields.size() == Dates.DATE_FIELDS.size(),"all schema dates available in picker")
	_expect(state.pocket_card(second),"card moves to pocket")
	_expect(calendar.schedule.total_cards == 16 and calendar.schedule.scheduled == 2,"live calendar excludes pocket ownership")
	calendar._select_fields(0)
	_expect(calendar.selected_fields == Dates.SCHEDULE_FIELDS,"default scheduling date filter restored")
	calendar.queue_free();shell.queue_free()
	await process_frame
	print("Calendar: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _expect(condition: bool,label: String) -> void:
	checks += 1
	if not condition:failures += 1;push_error(label)

func _capture(filename: String) -> void:
	if capture_directory.is_empty():return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	var picture = root.get_texture().get_image()
	if picture != null and not picture.is_empty():picture.save_png(capture_directory.path_join(filename))
