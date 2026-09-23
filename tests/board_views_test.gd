extends SceneTree
const Dates = preload("res://scripts/ui/board_dates.gd")
var checks = 0
var failures = 0
var selected = ""
var capture_directory = ""
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):capture_directory = argument.trim_prefix("--capture=")
	create_timer(30).timeout.connect(func():push_error("Board views test timeout");quit(1))
	call_deferred("_run")
func _run() -> void:
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.reset_game();state.set_language("fi")
	state.ensure_board("views_board","views_room",0)
	state.ensure_board("other_board","other_room",1)
	var first = str(state.boards.views_board.cards[0][0])
	var second = str(state.boards.views_board.cards[0][1])
	var today = Dates.today().number
	_expect(state.edit_card_details(first,{"startAt":Dates.date_from_day(today-5).key,"endAt":Dates.date_from_day(today+3).key,"dueAt":Dates.date_from_day(today-1).key,"dueComplete":true}),"explicit bar/end/due fixture")
	_expect(state.edit_card_details(second,{"dueAt":Dates.date_from_day(today+7).key}),"due-only milestone fixture")
	_expect(not state.add_swimlane("views_board","Lisäuimarata").is_empty(),"second lane")
	_expect(state.add_list("views_board",1,"Lisälista") == 1,"dynamic list")
	var third = state.add_card("views_board",1,1,["Käänteiset päivät","Tarkasta","Sovi","Korjaa"])
	_expect(not third.is_empty() and state.edit_card_details(third,{"startAt":Dates.date_from_day(today+8).key,"endAt":Dates.date_from_day(today+4).key}),"reversed dates fixture")
	var snapshot = Dates.snapshot(state,"views_board")
	_expect(snapshot.total_cards == 17 and snapshot.lanes.size() == 2 and snapshot.lists.size() == 6,"report includes every lane/list")
	_expect(snapshot.scheduled == 3 and snapshot.past_due == 1,"past due dates do not infer completion")
	var all_lanes = 0;var all_lists = 0
	for lane in snapshot.lanes:all_lanes += lane.count
	for list in snapshot.lists:all_lists += list.count
	_expect(all_lanes == snapshot.total_cards and all_lists == snapshot.total_cards,"breakdowns sum to total")
	for card in snapshot.cards:
		var interval = Dates.gantt_interval(card)
		if card.card_id == first:
			_expect(interval.has_bar and interval.start == today-5 and interval.end == today+3 and interval.end_field == "endAt","end date takes bar precedence over due")
			_expect(interval.markers.size() == 3,"due milestone remains separate")
		elif card.card_id == second:
			_expect(not interval.has_bar and interval.markers.size() == 1,"due-only card gets no invented start")
		elif card.card_id == third:
			_expect(interval.has_bar and interval.reversed,"reversed interval stays explicit")
	var fallback = Dates.gantt_interval({"dates":{"startAt":Dates.parse_date("2026-09-01"),"dueAt":Dates.parse_date("2026-09-03")}})
	_expect(fallback.has_bar and fallback.end_field == "dueAt","due fallback without end")
	var gantt_script = load("res://scripts/ui/board_gantt.gd")
	var reports_script = load("res://scripts/ui/board_reports.gd")
	if gantt_script == null or reports_script == null:push_error("Board view compilation failed");quit(1);return
	root.size = Vector2i(1440,900)
	var background = ColorRect.new();background.color = Color("102431");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
	var shell = VBoxContainer.new();shell.size = Vector2(1360,820);shell.position = Vector2(40,40);root.add_child(shell)
	var ui = load("res://scripts/ui/game_ui.gd").new();shell.theme = ui._make_theme();ui.free()
	var gantt = gantt_script.new();shell.add_child(gantt);gantt.setup("views_board")
	gantt.card_selected.connect(func(id):selected=id)
	await process_frame
	await process_frame
	await _capture("gantt-fi.png")
	_expect(gantt.intervals.size() == 3,"Gantt shows all dated cards")
	gantt._open_card(third)
	_expect(selected == third,"Gantt opens exact selected card")
	gantt.hide()
	var reports = reports_script.new();shell.add_child(reports);reports.setup("views_board")
	await process_frame
	await process_frame
	await _capture("reports-fi.png")
	_expect(reports.report.total_cards == 17 and reports.report.past_due == 1,"reports show actual counts")
	state.set_language("en")
	_expect("Reports" in reports.get_child(0).get_child(0).text,"report heading localizes")
	await process_frame
	await _capture("reports-en.png")
	_expect(state.pocket_card(second),"pocket transfer")
	_expect(reports.report.total_cards == 16 and reports.report.scheduled == 2 and gantt.intervals.size() == 2,"all views track pocket ownership")
	_expect(state.move_card(first,"other_board",0),"cross-board transfer")
	_expect(reports.report.total_cards == 15 and reports.report.past_due == 0 and gantt.intervals.size() == 1,"all views track current board ownership")
	gantt.queue_free();reports.queue_free();shell.queue_free()
	await process_frame
	print("Board views: %d checks, %d failures" % [checks,failures])
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
