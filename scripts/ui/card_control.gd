extends Button

signal chosen(card_id: String)
signal transferred(success: bool)
signal edit_requested(card_id: String)

var card_id: String = ""
var destination_board: String = ""
var destination_list: int = -1
var destination_index: int = -1
var destination_lane: int = 0
var selected_card: bool = false

func setup(id: String, compact: bool = true, board_id: String = "", list_index: int = -1, card_index: int = -1) -> void:
	card_id = id
	destination_board = board_id
	destination_list = list_index
	destination_index = card_index
	custom_minimum_size = Vector2(105, 125 if compact else 136)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	set_meta("focus_id", "card:" + id)
	var lines: Array = GameState.get_card_lines(id)
	tooltip_text = "\n".join(PackedStringArray(lines))
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 3)
	margin.add_child(rows)
	for i in range(4):
		var line = Label.new()
		line.text = str(lines[i]) if i < lines.size() else ""
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_theme_font_size_override("font_size", (12 if compact else 15) + (1 if i == 0 else 0))
		line.add_theme_color_override("font_color", Color("18333e") if i == 0 else Color("405965"))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rows.add_child(line)
	pressed.connect(func(): chosen.emit(card_id); edit_requested.emit(card_id))
	_update_style()

func set_selected(value: bool) -> void:
	selected_card = value
	_update_style()

func _update_style() -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("fff3ce") if selected_card else Color("f3f6f2")
	normal.set_corner_radius_all(7)
	normal.set_border_width_all(2 if selected_card else 1)
	normal.border_color = Color("ecc571") if selected_card else Color("b8ccd1")
	add_theme_stylebox_override("normal", normal)
	var hover = normal.duplicate()
	hover.bg_color = Color("e1f2ec")
	hover.border_color = Color("50cbb2")
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	var focused = StyleBoxFlat.new()
	focused.bg_color = Color(0, 0, 0, 0)
	focused.set_corner_radius_all(7)
	focused.set_border_width_all(3)
	focused.border_color = Color("ffda85")
	add_theme_stylebox_override("focus", focused)

func _get_drag_data(_position: Vector2):
	var preview = PanelContainer.new()
	preview.custom_minimum_size = Vector2(220, 115)
	var text_label = Label.new()
	text_label.text = "\n".join(PackedStringArray(GameState.get_card_lines(card_id)))
	text_label.add_theme_font_size_override("font_size", 14)
	preview.add_child(text_label)
	set_drag_preview(preview)
	chosen.emit(card_id)
	return {"type": "kanban_card", "card_id": card_id}

func _can_drop_data(_position: Vector2, data) -> bool:
	return destination_list >= 0 and data is Dictionary and data.get("type", "") == "kanban_card" and str(data.get("card_id", "")) != card_id

func _drop_data(_position: Vector2, data) -> void:
	transferred.emit(GameState.call("move_card", str(data.card_id), destination_board, destination_list, destination_index, destination_lane))
