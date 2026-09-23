extends SceneTree
## Run: redot --headless --path . --script res://tests/board_mapping_test.gd
## Exercises production board geometry and actual GameState transfers.

const Board3D = preload("res://scripts/kanban/board_3d.gd")
const BoardCanvas = preload("res://scripts/kanban/board_canvas.gd")
var checks = 0
var failures = 0


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_on_timeout)
	call_deferred("_run")


func _run() -> void:
	var state = root.get_node_or_null("GameState")
	if state == null:
		push_error("GameState autoload is required for the board integration test.")
		quit(1)
		return
	var board = Board3D.new()
	root.add_child(board)
	board.setup({"id": "mapping_test", "room_id": "test_room", "topic": 0, "position": Vector3(12, 6, -7), "yaw": 0.0})
	_expect(board.is_in_group("kanban_boards"), "NPC discovery group")
	_expect(board.get_node("BoardTarget").collision_layer == 2, "interaction collision layer")
	_expect(board.get_node("BoardTarget").get_meta("board_node") == board, "ray target metadata")
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
		board.rotation.y = angle
		for column in range(4):
			for row in range(4):
				var point = _world_point(board, BoardCanvas.card_rect(column, row).get_center())
				var info = board.hit_info(point)
				_expect(info.get("board_id") == "mapping_test", "board identity")
				_expect(info.get("list") == column, "column at yaw %.2f" % angle)
				_expect(info.get("index") == row, "row at yaw %.2f" % angle)
				_expect(info.get("card_id") == state.boards["mapping_test"]["cards"][column][row], "actual card at yaw %.2f" % angle)
				_expect(info.get("kind") == "card" and info.get("text_kind") == "card" and info.get("lane") == 0, "card edit target identifies first lane")
		var first = BoardCanvas.card_rect(0, 0)
		var gap = board.hit_info(_world_point(board, Vector2(first.get_center().x, first.end.y + BoardCanvas.CARD_GAP * 0.5)))
		_expect(gap.get("card_id") == "" and gap.get("index") == 1, "gap inserts after preceding card")
		var header = board.hit_info(_world_point(board, Vector2(first.get_center().x, BoardCanvas.COLUMN_TOP + 10)))
		_expect(header.get("card_id") == "" and header.get("index") == 0, "header prepends")
		_expect(header.get("kind") == "list" and header.get("text_kind") == "list", "list edit target")
		var title = board.hit_info(_world_point(board, Vector2(300, 70)))
		_expect(title.get("list") == -1 and title.get("card_id") == "", "title is not a card")
		_expect(title.get("kind") == "title" and title.get("text_kind") == "board", "board title edit target")
		var calendar = board.hit_info(_world_point(board, BoardCanvas.calendar_rect().get_center()))
		_expect(calendar.get("text_kind") == "calendar" and calendar.get("board_id") == "mapping_test", "calendar header target")
		var lane = board.hit_info(_world_point(board, Vector2(300, 130)))
		_expect(lane.get("kind") == "swimlane" and lane.get("text_kind") == "lane" and lane.get("lane") == 0, "swimlane edit target")
		_expect(board.hit_info(_world_point(board, Vector2(-10, 100))).is_empty(), "outside board rejected")
		var horizontal_gap = BoardCanvas.column_rect(0).end.x + BoardCanvas.COLUMN_GAP * 0.5
		var between_lists = board.hit_info(_world_point(board, Vector2(horizontal_gap, 240)))
		_expect(between_lists.get("list") == -1, "space between columns is not a list")
	state.ensure_board("mapping_source", "test_room", 1)
	var extra_card = str(state.boards["mapping_source"]["cards"][0][0])
	_expect(state.move_card(extra_card, "mapping_test", 0), "overflow transfer succeeds")
	var footer_pixel = Vector2(BoardCanvas.column_rect(0).get_center().x, 694)
	var footer = board.hit_info(_world_point(board, footer_pixel))
	_expect(footer.get("index") == 5 and footer.get("card_id") == "", "overflow footer appends after all cards")
	_expect(board.get_node("BoardViewport/BoardCanvas").column_counts[0] == 5, "overflow count updated")
	_expect(board.get_node("BoardViewport/BoardCanvas").column_cards[0].size() == 4, "visible grid is bounded")
	var top_card = str(state.boards["mapping_test"]["cards"][0][0])
	_expect(state.pocket_card(top_card), "pocket removes visible card")
	var updated = board.hit_info(_world_point(board, BoardCanvas.card_rect(0, 0).get_center()))
	_expect(updated.get("card_id") != top_card, "picking immediately follows model changes")
	state.set_language("en")
	_expect(board.get_node("BoardViewport/BoardCanvas").language == "en", "language redraw")
	var fingerprint = board._last_fingerprint
	board.update_board()
	_expect(board._last_fingerprint == fingerprint, "unchanged model uses same render fingerprint")
	_test_dynamic_schema(state, board)
	_test_slot_occupancy(state, board)
	await process_frame
	print("Board mapping: %d checks, %d failures" % [checks, failures])
	board.queue_free()
	quit(0 if failures == 0 else 1)


func _test_dynamic_schema(state: Node, board: Node3D) -> void:
	# Rendering fixtures deliberately exercise the canonical schema directly,
	# independent of editing widgets or persistence implementations.
	var model: Dictionary = state.boards["mapping_test"]
	if not model.has("swimlanes"):
		model["swimlanes"] = [{"id": "lane_first", "title": {"fi": "Uimarata 1", "en": "Swimlane 1"}, "lists": model["lists"], "cards": model["cards"]}]
	var canvas = board.get_node("BoardViewport/BoardCanvas")
	model["swimlanes"][0]["title"] = {"fi": "Uusi nimi", "en": "Renamed workflow"}
	state.cards_changed.emit()
	_expect(canvas.lane_title == "Renamed workflow", "edited canonical swimlane title displayed")
	model["title"] = {"fi": "Uusi taulu", "en": "Renamed board"}
	state.cards_changed.emit()
	_expect(canvas.board_title == "Renamed board", "edited board title displayed")
	model["swimlanes"][0]["lists"][0] = {"fi": "Uusi lista", "en": "Renamed list"}
	state.cards_changed.emit()
	_expect(canvas.list_titles[0] == "Renamed list", "edited list title displayed")
	model["swimlanes"][0]["lists"].append({"fi": "Viides", "en": "Fifth"})
	model["swimlanes"][0]["cards"].append([])
	model["swimlanes"].append({"id": "lane_second", "title": {"fi": "Tulevat", "en": "Upcoming"}, "lists": [{"fi": "Ideat", "en": "Ideas"}], "cards": [[]]})
	state.cards_changed.emit()
	_expect(canvas.lane_count == 2 and canvas.list_count == 5 and canvas.total_lists == 6, "extra lanes and lists counted")
	_expect(canvas.list_titles.size() == 4, "wall remains bounded to four visible columns")
	var before_rename = board._last_fingerprint
	model["swimlanes"][1]["title"]["en"] = "Future ideas"
	state.cards_changed.emit()
	_expect(before_rename != board._last_fingerprint, "offscreen lane rename refreshes snapshot")
	model["swimlanes"][0]["lists"] = [{"fi": "Ainoa", "en": "Only list"}]
	model["swimlanes"][0]["cards"] = [[]]
	state.cards_changed.emit()
	_expect(canvas.list_titles.size() == 1 and canvas.column_counts == [0], "removed lists disappear")
	var no_list = board.hit_info(_world_point(board, BoardCanvas.card_rect(3, 0).get_center()))
	_expect(no_list.get("list") == -1 and no_list.get("card_id") == "", "removed list cannot receive a card")
	var empty_list = board.hit_info(_world_point(board, BoardCanvas.card_rect(0, 0).get_center()))
	_expect(empty_list.get("kind") == "list" and empty_list.get("index") == 0, "empty surviving list is a valid destination")
	model["swimlanes"][0]["lists"] = []
	model["swimlanes"][0]["cards"] = []
	state.cards_changed.emit()
	_expect(canvas.list_titles.is_empty() and canvas.column_cards.is_empty(), "lane with no lists renders safely")
	model["swimlanes"] = []
	state.cards_changed.emit()
	_expect(canvas.lane_count == 0 and canvas.list_titles.is_empty(), "last removed lane does not resurrect legacy aliases")
	var no_lane = board.hit_info(_world_point(board, Vector2(300, 130)))
	_expect(no_lane.get("kind") == "title" and no_lane.get("lane") == -1, "empty board targets board editor")
	model["swimlanes"] = [{"id": "replacement_lane", "title": {"fi": "Uusi uimarata", "en": "Replacement lane"}, "lists": [], "cards": []}]
	state.cards_changed.emit()
	var replacement = board.hit_info(_world_point(board, Vector2(300, 130)))
	_expect(replacement.get("lane_id") == "replacement_lane" and canvas.lane_title == "Replacement lane", "replacement first lane is rendered and picked")


func _world_point(board: Node3D, pixel: Vector2) -> Vector3:
	return board.to_global(Vector3((pixel.x / BoardCanvas.CANVAS_SIZE.x - 0.5) * Board3D.BOARD_WIDTH, (0.5 - pixel.y / BoardCanvas.CANVAS_SIZE.y) * Board3D.BOARD_HEIGHT, 0.005))


func _test_slot_occupancy(state: Node, board: Node3D) -> void:
	var slots = state.get("board_slots")
	if not slots is Dictionary or not slots.has("mapping_test"):
		return
	var fixed_position = board.position
	slots["mapping_test"]["board_id"] = ""
	state.cards_changed.emit()
	var empty = board.hit_info(_world_point(board, Vector2(300, 300)))
	_expect(board.board_id == "" and board.slot_id == "mapping_test", "physical slot identity survives board removal")
	_expect(empty.get("kind") == "empty" and empty.get("slot_id") == "mapping_test" and empty.get("board_id") == "", "empty-slot placement target")
	_expect(board.get_node("BoardViewport/BoardCanvas").empty_slot, "empty slot has visible placement cue")
	slots["mapping_test"]["board_id"] = "mapping_source"
	board.refresh_occupancy()
	var occupied = board.hit_info(_world_point(board, BoardCanvas.card_rect(0, 0).get_center()))
	_expect(board.board_id == "mapping_source" and board.position == fixed_position, "replacement board occupies stationary wall slot")
	_expect(occupied.get("slot_id") == "mapping_test" and occupied.get("board_id") == "mapping_source", "picking follows new occupant")
	_expect(not board.get_node("BoardViewport/BoardCanvas").empty_slot, "replacement board restores card canvas")


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Board mapping failed: " + label)


func _on_timeout() -> void:
	push_error("Board integration test timed out; inspect preceding script errors.")
	quit(1)
