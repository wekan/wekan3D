extends Node3D
## Physical board + cached 2D canvas. Only changed boards render a new texture.

const BoardCanvas = preload("res://scripts/kanban/board_canvas.gd")
const BOARD_WIDTH = 4.6
const BOARD_HEIGHT = 2.65

var board_id: String = ""
var slot_id: String = ""
var room_id: String = ""
var _state: Node
var _viewport: SubViewport
var _canvas: Control
var _last_fingerprint: int = -1
var _setup_complete = false


func setup(spec: Dictionary) -> void:
	if _setup_complete:
		return
	_setup_complete = true
	board_id = str(spec.get("id", ""))
	slot_id = str(spec.get("slot_id", board_id))
	room_id = str(spec.get("room_id", ""))
	name = "Board_" + board_id
	position = spec.get("position", Vector3.ZERO)
	rotation.y = float(spec.get("yaw", 0.0))
	add_to_group("kanban_boards")
	_state = get_node("/root/GameState")
	_sync_occupancy()
	if not board_id.is_empty():
		_state.ensure_board(board_id, room_id, int(spec.get("topic", 0)))
	_make_frame()
	_make_canvas()
	_make_collider()
	_state.language_changed.connect(update_board)
	_state.cards_changed.connect(update_board)
	update_board()


func _make_frame() -> void:
	var frame = MeshInstance3D.new()
	frame.name = "PowderCoatedFrame"
	var box = BoxMesh.new()
	box.size = Vector3(BOARD_WIDTH + 0.095, BOARD_HEIGHT + 0.095, 0.082)
	frame.mesh = box
	frame.position.z = -0.045
	var material = StandardMaterial3D.new()
	material.albedo_color = Color("213842")
	material.metallic = 0.45
	material.roughness = 0.5
	frame.material_override = material
	add_child(frame)


func _make_canvas() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "BoardViewport"
	_viewport.size = Vector2i(BoardCanvas.CANVAS_SIZE)
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_canvas = BoardCanvas.new()
	_canvas.name = "BoardCanvas"
	_viewport.add_child(_canvas)
	var panel = MeshInstance3D.new()
	panel.name = "ReadableSurface"
	var quad = QuadMesh.new()
	quad.size = Vector2(BOARD_WIDTH, BOARD_HEIGHT)
	panel.mesh = quad
	panel.position.z = 0.005
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _viewport.get_texture()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode = BaseMaterial3D.CULL_BACK
	panel.material_override = material
	add_child(panel)


func _make_collider() -> void:
	var body = StaticBody3D.new()
	body.name = "BoardTarget"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("board_node", self)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	# The front plane matches the visual surface at z=0.005, keeping oblique
	# ray hits aligned with the printed cards rather than a thick proxy slab.
	box.size = Vector3(BOARD_WIDTH, BOARD_HEIGHT, 0.010)
	shape.shape = box
	shape.position.z = 0.0
	body.add_child(shape)
	add_child(body)
	set_meta("board_node", self)


func update_board() -> void:
	if _state == null or _canvas == null:
		return
	_sync_occupancy()
	if board_id.is_empty() or not _state.boards.has(board_id):
		var empty_data = {"title": "Tyhjä taulupaikka" if _state.language == "fi" else "Empty board slot", "empty_slot": true, "lane": "", "lane_count": 0, "list_count": 0, "total_lists": 0, "total_cards": 0, "lists": [], "cards": [], "counts": [], "language": _state.language}
		if hash(empty_data) != _last_fingerprint:
			_last_fingerprint = hash(empty_data)
			_canvas.set_data(empty_data)
			_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	var board: Dictionary = _state.boards[board_id]
	var lanes = _lanes_for(board)
	var first_lane: Dictionary = lanes[0] if not lanes.is_empty() else {}
	var lane_lists: Array = first_lane.get("lists", [])
	var lane_cards: Array = first_lane.get("cards", [])
	var columns: Array = []
	var counts: Array = []
	var titles: Array = []
	var total_cards = 0
	var total_lists = 0
	var lane_names: Array = []
	for lane in lanes:
		lane_names.append(_state.localize(lane.get("title", "")))
		total_lists += lane.get("lists", []).size()
		for ids in lane.get("cards", []):
			total_cards += ids.size()
	for column in range(mini(4, lane_lists.size())):
		var card_ids: Array = lane_cards[column] if column < lane_cards.size() else []
		counts.append(card_ids.size())
		titles.append(_state.localize(lane_lists[column]))
		var lines: Array = []
		for index in range(mini(card_ids.size(), BoardCanvas.VISIBLE_ROWS)):
			lines.append(_state.get_card_lines(str(card_ids[index])))
		columns.append(lines)
	var data = {
		"empty_slot": false,
		"title": _state.localize(board["title"]),
		"lane": _state.localize(first_lane.get("title", "")),
		"lane_names": lane_names,
		"lane_count": lanes.size(),
		"list_count": lane_lists.size(),
		"total_lists": total_lists,
		"total_cards": total_cards,
		"lists": titles,
		"cards": columns,
		"counts": counts,
		"language": _state.language,
	}
	var fingerprint = hash(data)
	if fingerprint == _last_fingerprint:
		return
	_last_fingerprint = fingerprint
	_canvas.set_data(data)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func hit_info(world_position: Vector3) -> Dictionary:
	_sync_occupancy()
	var local_point = to_local(world_position)
	var pixel = Vector2((local_point.x / BOARD_WIDTH + 0.5) * BoardCanvas.CANVAS_SIZE.x, (0.5 - local_point.y / BOARD_HEIGHT) * BoardCanvas.CANVAS_SIZE.y)
	# A small tolerance absorbs the ray/physics floating point error at edges.
	if pixel.x < -0.1 or pixel.y < -0.1 or pixel.x > BoardCanvas.CANVAS_SIZE.x + 0.1 or pixel.y > BoardCanvas.CANVAS_SIZE.y + 0.1:
		return {}
	if board_id.is_empty():
		return {"slot_id": slot_id, "board_id": "", "kind": "empty", "text_kind": "empty", "lane": 0, "lane_id": "", "list": 0, "card_id": "", "index": -1}
	var result = {"slot_id": slot_id, "board_id": board_id, "kind": "title", "text_kind": "board", "lane": -1, "lane_id": "", "list": -1, "card_id": "", "index": -1}
	if BoardCanvas.calendar_rect().has_point(pixel):
		result["kind"] = "calendar"
		result["text_kind"] = "calendar"
		return result
	if _state == null or not _state.boards.has(board_id):
		return result
	var board: Dictionary = _state.boards[board_id]
	var lanes = _lanes_for(board)
	if lanes.is_empty():
		return result
	var first_lane: Dictionary = lanes[0]
	result["lane"] = 0
	result["lane_id"] = str(first_lane.get("id", ""))
	if pixel.y >= 105.0 and pixel.y < BoardCanvas.COLUMN_TOP:
		result["kind"] = "swimlane"
		result["text_kind"] = "lane"
		return result
	var lists: Array = first_lane.get("lists", [])
	var lane_cards: Array = first_lane.get("cards", [])
	for column in range(mini(4, lists.size())):
		if not BoardCanvas.column_rect(column).has_point(pixel):
			continue
		var ids: Array = lane_cards[column] if column < lane_cards.size() else []
		result["kind"] = "list"
		result["text_kind"] = "list"
		result["list"] = column
		result["index"] = ids.size()
		for row in range(mini(ids.size(), BoardCanvas.VISIBLE_ROWS)):
			if BoardCanvas.card_rect(column, row).has_point(pixel):
				result["kind"] = "card"
				result["text_kind"] = "card"
				result["card_id"] = str(ids[row])
				result["index"] = row
				return result
		# Header = prepend, gaps = insert at the following row, footer = append.
		if pixel.y < BoardCanvas.CARD_TOP:
			result["index"] = 0
		elif pixel.y < BoardCanvas.card_rect(column, BoardCanvas.VISIBLE_ROWS - 1).end.y:
			result["index"] = clampi(int(floor((pixel.y - BoardCanvas.CARD_TOP) / (BoardCanvas.CARD_HEIGHT + BoardCanvas.CARD_GAP))) + 1, 0, ids.size())
		return result
	return result


func _lanes_for(board: Dictionary) -> Array:
	# Legacy aliases are accepted until an older save has been migrated. An
	# explicitly empty canonical swimlanes array must stay empty after removal.
	if board.has("swimlanes"):
		return board["swimlanes"]
	return [{"id": "", "title": _state.tr_key("swimlane"), "lists": board.get("lists", []), "cards": board.get("cards", [])}]


func refresh_occupancy() -> void:
	update_board()


func _sync_occupancy() -> void:
	if _state == null:
		return
	var slots = _state.get("board_slots")
	if not slots is Dictionary or not slots.has(slot_id):
		return
	var occupant: Dictionary = slots[slot_id]
	var next_id = str(occupant.get("board_id", ""))
	if next_id != board_id:
		_last_fingerprint = -1
	board_id = next_id
	room_id = str(occupant.get("room_id", room_id))


func carry_anchor() -> Vector3:
	return to_global(Vector3(0.0, -0.45, 0.75))
