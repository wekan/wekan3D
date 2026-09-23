extends SceneTree
## Run: redot --headless --path . --script scripts/kanban/test_board_mapping.gd
## Exercises production board geometry and actual GameState transfers.

const Board3D = preload("res://scripts/kanban/board_3d.gd")
const BoardCanvas = preload("res://scripts/kanban/board_canvas.gd")
var checks = 0
var failures = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state = root.get_node("GameState")
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
		var first = BoardCanvas.card_rect(0, 0)
		var gap = board.hit_info(_world_point(board, Vector2(first.get_center().x, first.end.y + BoardCanvas.CARD_GAP * 0.5)))
		_expect(gap.get("card_id") == "" and gap.get("index") == 1, "gap inserts after preceding card")
		var header = board.hit_info(_world_point(board, Vector2(first.get_center().x, BoardCanvas.COLUMN_TOP + 10)))
		_expect(header.get("card_id") == "" and header.get("index") == 0, "header prepends")
		var title = board.hit_info(_world_point(board, Vector2(300, 70)))
		_expect(title.get("list") == -1 and title.get("card_id") == "", "title is not a card")
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
	print("Board mapping: %d checks, %d failures" % [checks, failures])
	board.queue_free()
	quit(0 if failures == 0 else 1)


func _world_point(board: Node3D, pixel: Vector2) -> Vector3:
	return board.to_global(Vector3((pixel.x / BoardCanvas.CANVAS_SIZE.x - 0.5) * Board3D.BOARD_WIDTH, (0.5 - pixel.y / BoardCanvas.CANVAS_SIZE.y) * Board3D.BOARD_HEIGHT, 0.0275))


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Board mapping failed: " + label)
