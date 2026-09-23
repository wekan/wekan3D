extends CanvasLayer

signal modal_changed(is_open: bool)
signal placement_requested(card_id: String)
signal cancel_carry_requested
signal search_requested(query: String)
signal search_navigation_requested(result: Dictionary)
signal text_input_changed(active: bool)
signal container_placement_requested(item_id: String)
signal remote_connection_requested(entity_id: String)

const CardControl = preload("res://scripts/ui/card_control.gd")
const DropZone = preload("res://scripts/ui/drop_zone.gd")
const PocketButton = preload("res://scripts/ui/pocket_button.gd")
const TextEditor = preload("res://scripts/ui/text_editor.gd")
const SpatialDestination = preload("res://scripts/ui/spatial_destination.gd")
const PAGE_SIZE = 12

var root: Control
var modal_root: Control
var modal_content: VBoxContainer
var pocket_button: Button
var start_label: Label
var elapsed_label: Label
var rooms_label: Label
var hint_label: Label
var controls_label: Label
var toast_label: Label
var carry_label: Label
var cancel_button: Button
var finnish_button: Button
var english_button: Button
var brand_button: Button
var search_field: LineEdit
var search_button: Button
var search_query: String = ""
var organization_name_field: LineEdit
var remote_entity_id: String = ""
var remote_npc: Node3D
var active_board_view_id: String = ""
var person_name_field: LineEdit
var person_workspace_picker: OptionButton
var person_gender_picker: OptionButton
var person_age_picker: OptionButton
var person_workspace_ids: Array = []
var spatial_context: Dictionary = {}
var selected_label: Label
var destination_board_picker: OptionButton
var destination_list_picker: OptionButton
var destination_lane_picker: OptionButton
var move_button: Button
var take_button: Button
var carry_button: Button
var edit_button: Button
var card_nodes: Array = []
var modal_kind: String = ""
var room_board_ids: Array = []
var left_board_id: String = ""
var right_board_id: String = ""
var destination_board_id: String = ""
var destination_list_index: int = 0
var destination_lane_index: int = 0
var selected_card_id: String = ""
var carried_card_id: String = ""
var carried_container_id: String = ""
var active_container_id: String = ""
var editor_data: Dictionary = {}
var editor_return_kind: String = ""
var pocket_page: int = 0
var dialogue_info: Dictionary = {}
var dialogue_answer: String = "hello"
var toast_time: float = 0.0
var stat_timer: float = 0.0
var refresh_pending: bool = false
var reset_focus_pending: bool = false
var built: bool = false

func build() -> void:
	if built:
		return
	built = true
	_configure_controller_ui()
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	_build_hud()
	modal_root = Control.new()
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_root.hide()
	root.add_child(modal_root)
	GameState.language_changed.connect(_language_changed)
	GameState.cards_changed.connect(_cards_changed)
	GameState.stats_changed.connect(_update_stats)
	if GameState.has_signal("organizations_changed"): GameState.organizations_changed.connect(_organizations_changed)
	if GameState.has_signal("entities_changed"): GameState.entities_changed.connect(_entities_changed)
	if GameState.has_signal("layout_changed"): GameState.layout_changed.connect(_layout_changed)
	_update_stats()
	_language_changed()

func _configure_controller_ui() -> void:
	# Redot's built-in UI actions only contain keyboard events, so bind pads explicitly.
	var buttons: Dictionary = {
		"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B,
		"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
		"ui_focus_next": JOY_BUTTON_RIGHT_SHOULDER, "ui_focus_prev": JOY_BUTTON_LEFT_SHOULDER
	}
	for action in buttons:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.45)
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = int(buttons[action])
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	var axes: Dictionary = {"ui_left": [JOY_AXIS_LEFT_X, -1.0], "ui_right": [JOY_AXIS_LEFT_X, 1.0], "ui_up": [JOY_AXIS_LEFT_Y, -1.0], "ui_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var event = InputEventJoypadMotion.new()
		event.device = -1
		event.axis = int(axes[action][0])
		event.axis_value = float(axes[action][1])
		if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)

func _make_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("edf5f6"))
	theme.set_color("font_color", "Button", Color("edf5f6"))
	theme.set_color("font_color", "OptionButton", Color("edf5f6"))
	theme.set_color("font_disabled_color", "Button", Color("627884"))
	for type_name in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "disabled"]:
			var color = Color("213b49")
			if state == "hover": color = Color("2c5961")
			if state == "pressed": color = Color("256c66")
			if state == "disabled": color = Color("172c37")
			var style = _style(color, 7, 1, Color("385965"))
			style.content_margin_left = 13
			style.content_margin_right = 13
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			theme.set_stylebox(state, type_name, style)
		var focus = _style(Color(0, 0, 0, 0), 7, 2, Color("ffda85"))
		theme.set_stylebox("focus", type_name, focus)
	theme.set_stylebox("panel", "PanelContainer", _style(Color("162c38"), 10, 1, Color("2d4956")))
	theme.set_stylebox("panel", "PopupMenu", _style(Color("18343f"), 8, 1, Color("4e7f87")))
	theme.set_color("font_color", "PopupMenu", Color("f4f7f3"))
	theme.set_stylebox("hover", "PopupMenu", _style(Color("2a665f"), 4))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme

func _style(color: Color, radius: int = 8, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border)
	style.border_color = border_color
	return style

func _margin(parent: Node, amount: int = 12) -> MarginContainer:
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, amount)
	parent.add_child(margin)
	return margin

func _label(text: String, font_size: int = 16, muted: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	if muted:
		label.add_theme_color_override("font_color", Color("a2bdc7"))
	return label

func _button(text: String, action: Callable, focus_id: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	if not focus_id.is_empty(): button.set_meta("focus_id", focus_id)
	return button

func _text(fi: String, en: String) -> String:
	return fi if GameState.language == "fi" else en

func _build_hud() -> void:
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 12
	panel.offset_right = -12
	panel.offset_top = 12
	panel.offset_bottom = 77
	root.add_child(panel)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_margin(panel, 10).add_child(row)
	var brand = _button("KANBAN\nOFFICE", open_organizations, "organizations")
	brand_button = brand
	brand.add_theme_font_size_override("font_size", 14)
	brand.tooltip_text = _text("Organisaatiot ja rakennukset", "Organizations and buildings")
	brand.add_theme_color_override("font_color", Color("65d7bc"))
	row.add_child(brand)
	start_label = _label("", 13, true)
	row.add_child(start_label)
	elapsed_label = _label("", 14)
	row.add_child(elapsed_label)
	rooms_label = _label("", 14)
	row.add_child(rooms_label)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	search_field = LineEdit.new()
	search_field.custom_minimum_size = Vector2(195, 40)
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.add_theme_font_size_override("font_size", 14)
	search_field.text_submitted.connect(_submit_search)
	search_field.focus_entered.connect(func(): text_input_changed.emit(true))
	search_field.focus_exited.connect(func(): text_input_changed.emit(false))
	row.add_child(search_field)
	search_button = _button("", func(): _submit_search(search_field.text))
	search_button.custom_minimum_size = Vector2(42, 40)
	search_button.draw.connect(func():
		var center = search_button.size * 0.5 - Vector2(3, 3)
		search_button.draw_arc(center, 7, 0.0, TAU, 24, Color("a2f0dc"), 2.0, true)
		search_button.draw_line(center + Vector2(5, 5), center + Vector2(12, 12), Color("a2f0dc"), 2.5, true))
	row.add_child(search_button)
	pocket_button = PocketButton.new()
	pocket_button.custom_minimum_size = Vector2(130, 42)
	pocket_button.pressed.connect(open_pocket)
	pocket_button.card_pocketed.connect(_transfer_result)
	row.add_child(pocket_button)
	finnish_button = _button("Suomi", func(): GameState.set_language("fi"))
	english_button = _button("English", func(): GameState.set_language("en"))
	row.add_child(finnish_button)
	row.add_child(english_button)
	var footer = VBoxContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 18
	footer.offset_right = -18
	footer.offset_top = -80
	footer.offset_bottom = -12
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(footer)
	var carry_row = HBoxContainer.new()
	footer.add_child(carry_row)
	carry_label = _label("", 15)
	carry_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carry_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	carry_row.add_child(carry_label)
	cancel_button = _button("", func(): cancel_carry_requested.emit())
	cancel_button.hide()
	carry_row.add_child(cancel_button)
	hint_label = _label("", 16)
	hint_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint_label.add_theme_constant_override("shadow_offset_x", 1)
	hint_label.add_theme_constant_override("shadow_offset_y", 1)
	footer.add_child(hint_label)
	controls_label = _label("", 12)
	controls_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	controls_label.add_theme_constant_override("shadow_offset_x", 1)
	controls_label.add_theme_constant_override("shadow_offset_y", 1)
	footer.add_child(controls_label)
	toast_label = _label("", 18)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 94
	toast_label.offset_left = -450
	toast_label.offset_right = 450
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_x", 2)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)

func _process(delta: float) -> void:
	if not built: return
	stat_timer += delta
	if stat_timer >= 0.5:
		stat_timer = 0.0
		_update_stats()
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0: toast_label.text = ""

func _input(event: InputEvent) -> void:
	if is_modal_open() and event.is_action_pressed("ui_cancel"):
		if modal_kind == "editor" and not editor_return_kind.is_empty(): _finish_edit()
		else: close_modal()
		get_viewport().set_input_as_handled()

func _update_stats() -> void:
	if not built: return
	start_label.text = GameState.tr_key("started") + "\n" + GameState.started_at.replace("T", " ")
	var total_seconds = int(GameState.elapsed_seconds)
	elapsed_label.text = GameState.tr_key("elapsed") + "\n%02d:%02d:%02d" % [total_seconds / 3600, (total_seconds / 60) % 60, total_seconds % 60]
	rooms_label.text = GameState.tr_key("rooms_visited") + "\n%d / %d" % [GameState.visited_rooms.size(), maxi(16, GameState.rooms.size())]
	var pocket_count: int = int(GameState.call("pocket_card_count")) if GameState.has_method("pocket_card_count") else GameState.pocket.size()
	pocket_button.text = GameState.tr_key("pocket_count") % pocket_count
	pocket_button.tooltip_text = GameState.tr_key("click_pocket")

func _language_changed() -> void:
	if not built: return
	toast_label.text = ""
	toast_time = 0.0
	_update_stats()
	controls_label.text = GameState.tr_key("controls")
	cancel_button.text = GameState.tr_key("cancel_carry") + "  [Esc / B]"
	finnish_button.modulate = Color("74e0c4") if GameState.language == "fi" else Color.WHITE
	english_button.modulate = Color("74e0c4") if GameState.language == "en" else Color.WHITE
	search_field.placeholder_text = _text("Hae kaikki tekstit…", "Search all text…")
	search_field.tooltip_text = _text("Hae kortteja, huoneita, ihmisiä ja huonekaluja", "Search cards, rooms, people and furniture")
	search_button.tooltip_text = _text("Hae", "Search")
	brand_button.tooltip_text = _text("Organisaatiot, rakennukset ja ihmiset", "Organizations, buildings and people")
	set_carry(carried_card_id)
	if not carried_container_id.is_empty(): set_container_carry(carried_container_id)
	_queue_refresh()

func set_hint(text: String) -> void:
	if hint_label: hint_label.text = text

func set_carry(card_id: String) -> void:
	if not card_id.is_empty() and not GameState.cards.has(card_id): card_id = ""
	carried_card_id = card_id
	if not built: return
	cancel_button.visible = not card_id.is_empty()
	if card_id.is_empty():
		carry_label.text = ""
	else:
		var lines: Array = GameState.get_card_lines(card_id)
		carry_label.text = (GameState.tr_key("carrying") % str(lines[0])) + " — " + GameState.tr_key("place_hint")

func set_container_carry(item_id: String) -> void:
	carried_container_id = item_id
	if not built: return
	if item_id.is_empty():
		set_carry(carried_card_id)
		return
	var item = _find_pocket_item(item_id)
	if item.is_empty():
		carried_container_id = ""
		set_carry(carried_card_id)
		return
	cancel_button.show()
	var placement_hint: String = _text("Valitse kohdetaulu ja paina E / A.", "Choose the destination board and press E / A.")
	if item.get("kind", "") in ["entity", "building", "floor", "room"]:
		placement_hint = _text("Klikkaa sijoituspaikkaa tai paina E / A. Esc / B jättää taskuun.", "Click a placement location or press E / A. Esc / B leaves it in your pocket.")
	carry_label.text = (GameState.tr_key("carrying") % _pocket_item_title(item)) + " — " + placement_hint

func show_toast(text: String) -> void:
	if not built: return
	toast_label.text = text
	toast_time = 4.0
	root.move_child(toast_label, root.get_child_count() - 1)

func is_pointer_over_pocket(screen_position: Vector2) -> bool:
	return built and pocket_button.is_visible_in_tree() and pocket_button.get_global_rect().has_point(screen_position)

func is_modal_open() -> bool:
	return not modal_kind.is_empty()

func is_text_input_focused() -> bool:
	return built and search_field.has_focus()

func _submit_search(query: String) -> void:
	search_field.release_focus()
	search_requested.emit(query)

func open_search(query: String = "") -> void:
	search_query = query
	search_field.text = query
	_open("search")

func open_organizations() -> void:
	_open("organizations")

func open_people() -> void:
	_open("people")

func open_spatial(context: Dictionary = {}) -> void:
	spatial_context = context.duplicate(true)
	_open("spatial")

func _layout_changed() -> void:
	_update_stats()
	if modal_kind in ["organizations", "people", "container", "pocket"]: _queue_refresh()

func _entities_changed() -> void:
	if modal_kind == "people" or modal_kind == "dialogue": _queue_refresh()

func open_remote_call(entity_id: String, npc_node: Node3D) -> void:
	remote_entity_id = entity_id
	remote_npc = npc_node
	_open("remote")

func _organizations_changed() -> void:
	_update_stats()
	if modal_kind == "organizations": _queue_refresh()

func _open(kind: String) -> void:
	var was_open = is_modal_open()
	if modal_kind != kind:
		toast_label.text = ""
		toast_time = 0.0
	modal_kind = kind
	reset_focus_pending = true
	modal_root.show()
	_refresh_modal()
	if not was_open: modal_changed.emit(true)

func close_modal() -> void:
	if not is_modal_open(): return
	modal_kind = ""
	modal_root.hide()
	card_nodes.clear()
	get_viewport().gui_release_focus()
	modal_changed.emit(false)

func open_pocket() -> void:
	pocket_page = 0
	selected_card_id = ""
	_open("pocket")

func open_board(board_id: String) -> void:
	if not GameState.boards.has(board_id): return
	var room_id: String = str(GameState.boards[board_id].room_id)
	room_board_ids.clear()
	for id in GameState.boards.keys():
		if str(GameState.boards[id].room_id) == room_id: room_board_ids.append(str(id))
	room_board_ids.sort()
	left_board_id = board_id
	right_board_id = board_id
	for id in room_board_ids:
		if id != board_id:
			right_board_id = id
			break
	destination_board_id = right_board_id
	destination_list_index = 0
	destination_lane_index = 0
	selected_card_id = ""
	_open("board")

func open_dialogue(npc_info: Dictionary) -> void:
	dialogue_info = npc_info.duplicate()
	dialogue_answer = "hello"
	_open("dialogue")

func open_entity(entity_id: String) -> void:
	if not GameState.entities.has(entity_id): return
	var entity: Dictionary = GameState.entities[entity_id]
	if entity.get("kind", "") == "person":
		open_person_editor(entity_id)
		return
	# A world click keeps the fast one-field rename flow. The management view
	# exposes the same entity's pocket, colour-wheel and X/Y/Z size controls.
	_edit_text("entity", {"entity_id": entity_id}, [GameState.localize(entity.get("name", entity_id))])

func open_person_editor(entity_id: String) -> void:
	if not GameState.entities.has(entity_id): return
	_edit_text("person", {"entity_id": entity_id}, [])

func open_board_view(board_id: String, view: String) -> void:
	if not GameState.boards.has(board_id): return
	if view == "swimlanes" or view == "board":
		open_board(board_id)
		return
	if view not in ["calendar", "gantt", "reports"]: return
	active_board_view_id = board_id
	_open(view)

func open_calendar(board_id: String) -> void:
	open_board_view(board_id, "calendar")

func open_gantt(board_id: String) -> void:
	open_board_view(board_id, "gantt")

func open_reports(board_id: String) -> void:
	open_board_view(board_id, "reports")

func open_card_editor(card_id: String) -> void:
	if not GameState.cards.has(card_id): return
	_edit_text("card", {"card_id": card_id}, GameState.get_card_lines(card_id))

func open_board_text(board_id: String, hit_info: Dictionary) -> void:
	if not GameState.boards.has(board_id): return
	if modal_kind != "board": open_board(board_id)
	var kind: String = str(hit_info.get("text_kind", hit_info.get("kind", "board")))
	var lane_index: int = int(hit_info.get("lane", 0))
	var list_index: int = int(hit_info.get("list", 0))
	var lanes: Array = _lanes(GameState.boards[board_id])
	if kind in ["calendar", "gantt", "reports"]:
		open_board_view(board_id, kind)
	elif kind == "card" and not str(hit_info.get("card_id", "")).is_empty():
		open_card_editor(str(hit_info.card_id))
	elif kind == "lane" or kind == "swimlane":
		if lane_index >= 0 and lane_index < lanes.size(): _edit_text("lane", {"board_id": board_id, "lane": lane_index}, [GameState.localize(lanes[lane_index].title)])
	elif kind == "list":
		if lane_index >= 0 and lane_index < lanes.size() and list_index >= 0 and list_index < lanes[lane_index].lists.size(): _edit_text("list", {"board_id": board_id, "lane": lane_index, "list": list_index}, [GameState.localize(lanes[lane_index].lists[list_index])])
	else:
		_edit_text("board", {"board_id": board_id}, [GameState.localize(GameState.boards[board_id].title)])

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _queue_refresh() -> void:
	if not is_modal_open() or refresh_pending: return
	refresh_pending = true
	call_deferred("_refresh_modal")

func _cards_changed() -> void:
	_update_stats()
	set_carry(carried_card_id)
	if not carried_container_id.is_empty(): set_container_carry(carried_container_id)
	if modal_kind != "editor": _queue_refresh()

func _refresh_modal() -> void:
	refresh_pending = false
	if not is_modal_open(): return
	var focus_id: String = ""
	var current_focus = get_viewport().gui_get_focus_owner()
	if not reset_focus_pending and is_instance_valid(current_focus): focus_id = str(current_focus.get_meta("focus_id", ""))
	reset_focus_pending = false
	_clear_children(modal_root)
	card_nodes.clear()
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.025, 0.07, 0.11, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(backdrop)
	# The world is fully covered, while session stats and language controls stay visible.
	backdrop.offset_top = 83
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_top = 91
	margin.offset_bottom = -10
	margin.offset_left = 20
	margin.offset_right = -20
	modal_root.add_child(margin)
	modal_content = VBoxContainer.new()
	modal_content.add_theme_constant_override("separation", 10)
	margin.add_child(modal_content)
	if modal_kind == "pocket": _build_pocket()
	elif modal_kind == "board": _build_board()
	elif modal_kind == "dialogue": _build_dialogue()
	elif modal_kind == "search": _build_search()
	elif modal_kind == "editor": _build_editor()
	elif modal_kind == "container": _build_container()
	elif modal_kind == "organizations": _build_organizations()
	elif modal_kind == "remote": _build_remote_call()
	elif modal_kind == "people": _build_people()
	elif modal_kind == "spatial": _build_spatial()
	elif modal_kind in ["calendar", "gantt", "reports"]: _build_alternate_board_view(modal_kind)
	_restore_focus.call_deferred(focus_id)

func _restore_focus(focus_id: String) -> void:
	if not is_modal_open(): return
	var controls: Array = []
	_collect_focusable(modal_content, controls)
	for control in controls:
		if not focus_id.is_empty() and str(control.get_meta("focus_id", "")) == focus_id:
			control.grab_focus()
			return
	if modal_kind == "editor" or modal_kind == "search":
		if modal_kind == "editor":
			for control in controls:
				if str(control.get_meta("focus_id", "")) == "card_field:title":
					control.grab_focus()
					return
		for control in controls:
			if control is LineEdit or control is TextEdit:
				control.grab_focus()
				return
	if modal_kind == "board" and not selected_card_id.is_empty():
		for control in controls:
			if str(control.get_meta("focus_id", "")) == "card:" + selected_card_id:
				control.grab_focus()
				return
	if not controls.is_empty(): controls[0].grab_focus()

func _collect_focusable(node: Node, controls: Array) -> void:
	for child in node.get_children():
		if child is Control and child.focus_mode == Control.FOCUS_ALL and child.is_visible_in_tree():
			if not (child is BaseButton and child.disabled): controls.append(child)
		_collect_focusable(child, controls)

func _header(title: String, subtitle: String = "") -> void:
	var row = HBoxContainer.new()
	modal_content.add_child(row)
	var title_label = _label(title, 27)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.tooltip_text = title
	row.add_child(title_label)
	var close_action: Callable = _finish_edit if modal_kind == "editor" and not editor_return_kind.is_empty() else close_modal
	row.add_child(_button(GameState.tr_key("close") + "  [Esc / B]", close_action, "close"))
	if not subtitle.is_empty():
		var label = _label(subtitle, 13, true)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(label)

func _build_pocket() -> void:
	_header(GameState.tr_key("pocket_title"), _text("Valitse kortti ja kanna se taululle. Selaa sivuja painikkeilla; Esc / B palaa toimistoon.", "Choose a card and carry it to a board. Use the page buttons to browse; Esc / B returns to the office."))
	var entries: Array = []
	for id in GameState.pocket: entries.append({"kind": "card", "id": str(id)})
	entries.append_array(_pocket_items())
	_build_inventory_grid(entries)

func _build_inventory_grid(entries: Array) -> void:
	var page_count: int = maxi(1, ceili(float(entries.size()) / PAGE_SIZE))
	pocket_page = clampi(pocket_page, 0, page_count - 1)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal_content.add_child(scroll)
	if entries.is_empty():
		var empty = _label(GameState.tr_key("pocket_empty") + "\n\n" + _text("Avaa toimiston taulu ja valitse ‘Laita taskuun’.", "Open an office board and choose ‘Put in pocket’."), 21, true)
		empty.custom_minimum_size.y = 250
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		scroll.add_child(empty)
	else:
		var grid = GridContainer.new()
		grid.columns = 4 if root.size.x >= 1050 else 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		scroll.add_child(grid)
		for i in range(pocket_page * PAGE_SIZE, mini((pocket_page + 1) * PAGE_SIZE, entries.size())):
			var entry: Dictionary = entries[i]
			var id: String = str(entry.id)
			var tile = VBoxContainer.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(tile)
			if entry.kind == "card":
				var card = _card(id, false)
				tile.add_child(card)
				tile.add_child(_button(GameState.tr_key("carry"), func(): _carry(id), "carry:" + id))
			else:
				_build_container_tile(tile, entry)
	var navigation = HBoxContainer.new()
	modal_content.add_child(navigation)
	var previous = _button("‹ " + GameState.tr_key("previous"), func(): pocket_page -= 1; _queue_refresh(), "previous")
	previous.disabled = pocket_page <= 0
	navigation.add_child(previous)
	var page = _label(GameState.tr_key("page") % [pocket_page + 1, page_count], 16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	navigation.add_child(page)
	var next = _button(GameState.tr_key("next") + " ›", func(): pocket_page += 1; _queue_refresh(), "next")
	next.disabled = pocket_page >= page_count - 1
	navigation.add_child(next)
	modal_content.add_child(_label(_text("Ohjain: ristiohjain / vasen sauva valitsee, A vahvistaa, B sulkee. LB / RB selaa painikkeita.", "Controller: D-pad / left stick selects, A confirms, B closes. LB / RB cycles through buttons."), 12, true))

func _card(id: String, compact: bool = true, board_id: String = "", list_index: int = -1, card_index: int = -1, lane_index: int = 0):
	var card = CardControl.new()
	card.setup(id, compact, board_id, list_index, card_index)
	card.destination_lane = lane_index
	card.chosen.connect(_select_card)
	card.edit_requested.connect(open_card_editor)
	card.transferred.connect(_transfer_result)
	card.set_selected(id == selected_card_id)
	card_nodes.append(card)
	return card

func _build_board() -> void:
	_header(GameState.tr_key("board_workspace"), GameState.tr_key("drag_hint") + " " + _text("Ohjaimella: valitse kortti, kohde ja Siirrä. Valikoissa ovat tämän huoneen taulut.", "Controller: select a card, destination and Move. The selectors show boards in this room."))
	var panels = HBoxContainer.new()
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", 14)
	modal_content.add_child(panels)
	_build_board_panel(panels, left_board_id, true)
	_build_board_panel(panels, right_board_id, false)
	var action_panel = PanelContainer.new()
	modal_content.add_child(action_panel)
	var actions = VBoxContainer.new()
	_margin(action_panel, 10).add_child(actions)
	selected_label = _label("", 14)
	selected_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	actions.add_child(selected_label)
	var action_row = HBoxContainer.new()
	actions.add_child(action_row)
	destination_board_picker = _board_picker(destination_board_id, "destination_board")
	destination_board_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination_board_picker.custom_minimum_size.x = 180
	destination_board_picker.item_selected.connect(func(index): destination_board_id = str(room_board_ids[index]); destination_lane_index = 0; _populate_destination_lanes())
	action_row.add_child(destination_board_picker)
	destination_lane_picker = OptionButton.new()
	destination_lane_picker.custom_minimum_size = Vector2(140, 38)
	destination_lane_picker.clip_text = true
	destination_lane_picker.set_meta("focus_id", "destination_lane")
	destination_lane_picker.item_selected.connect(func(index): destination_lane_index = index; destination_list_index = 0; _populate_destination_lists())
	action_row.add_child(destination_lane_picker)
	destination_list_picker = OptionButton.new()
	destination_list_picker.custom_minimum_size = Vector2(140, 38)
	destination_list_picker.set_meta("focus_id", "destination_list")
	destination_list_picker.item_selected.connect(func(index): destination_list_index = index)
	action_row.add_child(destination_list_picker)
	_populate_destination_lanes()
	move_button = _button(GameState.tr_key("move"), _move_selected, "move")
	action_row.add_child(move_button)
	take_button = _button(GameState.tr_key("take_to_pocket"), _pocket_selected, "take")
	action_row.add_child(take_button)
	carry_button = _button(GameState.tr_key("carry"), func(): _carry(selected_card_id), "carry")
	action_row.add_child(carry_button)
	edit_button = _button(_text("Muokkaa", "Edit"), func(): open_card_editor(selected_card_id), "edit_card")
	action_row.add_child(edit_button)
	var pocket_zone = DropZone.new()
	pocket_zone.to_pocket = true
	pocket_zone.transferred.connect(_transfer_result)
	var pocket_hint = _label("↓ " + GameState.tr_key("pocket") + "  ·  " + _text("Pudota kortti tähän", "Drop a card here"), 13)
	pocket_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pocket_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pocket_hint.custom_minimum_size.y = 28
	pocket_zone.add_child(pocket_hint)
	actions.add_child(pocket_zone)
	_update_selection()

func _board_picker(selected_id: String, focus_id: String) -> OptionButton:
	var picker = OptionButton.new()
	picker.set_meta("focus_id", focus_id)
	picker.custom_minimum_size.y = 38
	picker.clip_text = true
	for i in range(room_board_ids.size()):
		var id: String = str(room_board_ids[i])
		picker.add_item(GameState.localize(GameState.boards[id].title))
		if id == selected_id: picker.select(i)
	return picker

func _lanes(board: Dictionary) -> Array:
	if board.has("swimlanes"): return board.swimlanes
	return [{"id": "initial", "title": {"fi": "Uimarata 1", "en": "Swimlane 1"}, "lists": board.lists, "cards": board.cards}]

func _build_board_panel(parent: Node, board_id: String, is_left: bool) -> void:
	var board: Dictionary = GameState.boards[board_id]
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var content = VBoxContainer.new()
	_margin(panel, 10).add_child(content)
	var heading = HBoxContainer.new()
	content.add_child(heading)
	var picker = _board_picker(board_id, "left_board" if is_left else "right_board")
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.item_selected.connect(func(index):
		if is_left: left_board_id = str(room_board_ids[index])
		else: right_board_id = str(room_board_ids[index])
		_queue_refresh())
	heading.add_child(picker)
	var rename = _button(_text("Nimi", "Name"), func(): open_board_text(board_id, {"text_kind": "board"}), "rename_board:" + board_id)
	rename.tooltip_text = _text("Muokkaa taulun nimeä", "Edit board title")
	heading.add_child(rename)
	var pocket_board_button = _button("↓", func(): _pocket_board(board_id), "pocket_board:" + board_id)
	pocket_board_button.tooltip_text = _text("Laita koko taulu sisältöineen taskuun", "Put the whole board and its contents in your pocket")
	heading.add_child(pocket_board_button)
	heading.add_child(_button(_text("+ Uimarata", "+ Swimlane"), func(): _edit_text("add_lane", {"board_id": board_id}, [_text("Uusi uimarata", "New swimlane")]), "add_lane:" + board_id))
	_board_view_buttons(content, board_id, "swimlanes")
	var board_scroll = ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_scroll.follow_focus = true
	content.add_child(board_scroll)
	var lane_rows = VBoxContainer.new()
	lane_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane_rows.add_theme_constant_override("separation", 18)
	board_scroll.add_child(lane_rows)
	var lanes: Array = _lanes(board)
	for lane_index in range(lanes.size()):
		_build_lane(lane_rows, board_id, lane_index, lanes[lane_index])
	if lanes.is_empty():
		var empty = _label(_text("Taulu on tyhjä. Lisää uimarata tai tuo sellainen taskusta.", "This board is empty. Add a swimlane or bring one from your pocket."), 16, true)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lane_rows.add_child(empty)

func _build_lane(parent: Node, board_id: String, lane_index: int, lane: Dictionary) -> void:
	var lane_content = VBoxContainer.new()
	parent.add_child(lane_content)
	var row = HBoxContainer.new()
	lane_content.add_child(row)
	var title = _button(GameState.localize(lane.title), func(): open_board_text(board_id, {"text_kind": "lane", "lane": lane_index}), "lane:" + board_id + ":" + str(lane_index))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.add_theme_color_override("font_color", Color("77d3bd"))
	row.add_child(title)
	var pocket_lane = _button("↓ " + _text("Taskuun", "Pocket"), func(): _pocket_container(board_id, lane_index, -1), "pocket_lane:" + board_id + ":" + str(lane_index))
	pocket_lane.tooltip_text = _text("Laita koko uimarata listoineen ja kortteineen taskuun", "Put this whole swimlane, lists and cards in your pocket")
	row.add_child(pocket_lane)
	row.add_child(_button(_text("+ Lista", "+ List"), func(): _edit_text("add_list", {"board_id": board_id, "lane": lane_index}, [_text("Uusi lista", "New list")]), "add_list:" + board_id + ":" + str(lane_index)))
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	lane_content.add_child(scroll)
	var columns = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 7)
	scroll.add_child(columns)
	for list_index in range(lane.lists.size()):
		_build_list(columns, board_id, lane_index, list_index, lane)
	if lane.lists.is_empty():
		columns.add_child(_label(_text("Lisää lista tai tuo lista taskusta.", "Add a list or bring one from your pocket."), 14, true))

func _build_list(parent: Node, board_id: String, lane_index: int, list_index: int, lane: Dictionary) -> void:
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size.x = 142
	parent.add_child(column)
	var row = HBoxContainer.new()
	column.add_child(row)
	var title = _button(GameState.localize(lane.lists[list_index]), func(): open_board_text(board_id, {"text_kind": "list", "lane": lane_index, "list": list_index}), "list:" + board_id + ":" + str(lane_index) + ":" + str(list_index))
	title.add_theme_font_size_override("font_size", 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.tooltip_text = title.text + " — " + _text("muokkaa nimeä", "edit title")
	row.add_child(title)
	var pocket_list = _button("↓", func(): _pocket_container(board_id, lane_index, list_index), "pocket_list:" + board_id + ":" + str(lane_index) + ":" + str(list_index))
	pocket_list.tooltip_text = _text("Laita koko lista kortteineen taskuun", "Put this whole list and its cards in your pocket")
	row.add_child(pocket_list)
	var zone = DropZone.new()
	zone.destination_board = board_id
	zone.destination_lane = lane_index
	zone.destination_list = list_index
	zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	zone.add_theme_stylebox_override("panel", _style(Color("10232f"), 7))
	zone.transferred.connect(_transfer_result)
	column.add_child(zone)
	var cards = VBoxContainer.new()
	cards.mouse_filter = Control.MOUSE_FILTER_PASS
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 7)
	zone.add_child(cards)
	var ids: Array = lane.cards[list_index]
	for index in range(ids.size()): cards.add_child(_card(str(ids[index]), true, board_id, list_index, index, lane_index))
	var empty = _label("+", 22, true)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.custom_minimum_size.y = 40
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_child(empty)
	var add = _button(_text("+ Kortti", "+ Card"), func(): _edit_text("add_card", {"board_id": board_id, "lane": lane_index, "list": list_index}, [_text("Uusi kortti", "New card"), _text("Seuraava työvaihe", "Next work step"), _text("Vastuuhenkilö: sovitaan", "Owner: to be agreed"), _text("Valmis kun tarkistettu", "Done when reviewed")]), "add_card:" + board_id + ":" + str(lane_index) + ":" + str(list_index))
	add.add_theme_font_size_override("font_size", 13)
	column.add_child(add)

func _populate_destination_lanes() -> void:
	if not is_instance_valid(destination_lane_picker) or not GameState.boards.has(destination_board_id): return
	destination_lane_picker.clear()
	var lanes: Array = _lanes(GameState.boards[destination_board_id])
	for lane in lanes: destination_lane_picker.add_item(GameState.localize(lane.title))
	destination_lane_index = clampi(destination_lane_index, 0, maxi(0, lanes.size() - 1))
	if not lanes.is_empty(): destination_lane_picker.select(destination_lane_index)
	_populate_destination_lists()

func _populate_destination_lists() -> void:
	if not is_instance_valid(destination_list_picker) or not GameState.boards.has(destination_board_id): return
	destination_list_picker.clear()
	var lanes: Array = _lanes(GameState.boards[destination_board_id])
	if lanes.is_empty():
		_update_selection()
		return
	destination_lane_index = clampi(destination_lane_index, 0, lanes.size() - 1)
	var lane: Dictionary = lanes[destination_lane_index]
	for list_info in lane.lists: destination_list_picker.add_item(GameState.localize(list_info))
	destination_list_index = clampi(destination_list_index, 0, maxi(0, lane.lists.size() - 1))
	if not lane.lists.is_empty(): destination_list_picker.select(destination_list_index)
	_update_selection()

func _select_card(id: String) -> void:
	selected_card_id = id
	for card in card_nodes:
		if is_instance_valid(card): card.set_selected(card.card_id == id)
	if modal_kind == "board": _update_selection()

func _update_selection() -> void:
	var valid: bool = GameState.cards.has(selected_card_id)
	if is_instance_valid(selected_label):
		selected_label.text = GameState.tr_key("selected") + ": " + " · ".join(PackedStringArray(GameState.get_card_lines(selected_card_id))) if valid else GameState.tr_key("select_card")
		selected_label.tooltip_text = selected_label.text
	for button in [move_button, take_button, carry_button, edit_button]:
		if is_instance_valid(button): button.disabled = not valid
	if is_instance_valid(move_button) and is_instance_valid(destination_list_picker):
		move_button.disabled = not valid or destination_list_picker.item_count == 0

func _move_selected() -> void:
	if selected_card_id.is_empty(): return
	_transfer_result(GameState.call("move_card", selected_card_id, destination_board_id, destination_list_index, -1, destination_lane_index))

func _pocket_selected() -> void:
	if selected_card_id.is_empty(): return
	_transfer_result(GameState.pocket_card(selected_card_id))

func _carry(id: String) -> void:
	if not GameState.cards.has(id): return
	close_modal()
	placement_requested.emit(id)

func _transfer_result(success: bool) -> void:
	show_toast(GameState.tr_key("card_moved") if success else GameState.tr_key("move_failed"))
	_queue_refresh()

func _build_dialogue() -> void:
	var name_text: String = str(dialogue_info.get("name", GameState.tr_key("receptionist")))
	var entity_id: String = str(dialogue_info.get("entity_id", ""))
	if GameState.entities.has(entity_id): name_text = GameState.localize(GameState.entities[entity_id].name)
	var profile: Dictionary = dialogue_info.duplicate(true)
	if GameState.entities.has(entity_id): profile.merge(GameState.entities[entity_id], true)
	if profile.get("profile", {}) is Dictionary: profile.merge(profile.get("profile", {}), true)
	var questions: Array = profile.get("qa", [])
	var is_receptionist: bool = bool(dialogue_info.get("receptionist", false))
	_header((GameState.tr_key("reception") if is_receptionist else GameState.tr_key("dialogue")) + " · " + name_text)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 22)
	modal_content.add_child(body)
	var bubble_panel = PanelContainer.new()
	bubble_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_panel.size_flags_stretch_ratio = 1.2
	body.add_child(bubble_panel)
	var bubble_content = VBoxContainer.new()
	bubble_content.add_theme_constant_override("separation", 20)
	_margin(bubble_panel, 26).add_child(bubble_content)
	var name_label = _label(name_text, 28)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_color_override("font_color", Color("6dddd0"))
	bubble_content.add_child(name_label)
	var profile_lines: Array = []
	for key in ["title", "team_role", "expertise"]:
		var value: String = GameState.localize(profile.get(key, ""))
		if not value.is_empty(): profile_lines.append(value)
	if not profile_lines.is_empty():
		var profile_label = _label("\n".join(PackedStringArray(profile_lines)), 14, true)
		profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble_content.add_child(profile_label)
	if not entity_id.is_empty():
		bubble_content.add_child(_button(_text("Muokkaa tietoja", "Edit profile"), func(): open_entity(entity_id), "rename_npc"))
	var bubble = _label(GameState.tr_key(dialogue_answer), 22)
	if dialogue_answer.begins_with("profile:"):
		var question_index: int = dialogue_answer.trim_prefix("profile:").to_int()
		if question_index >= 0 and question_index < questions.size(): bubble.text = GameState.localize(questions[question_index].get("answer", ""))
	elif not is_receptionist and dialogue_answer == "hello":
		bubble.text = _text("Hei! Tiimimme aihe on ", "Hello! Our team is working on ") + GameState.topic_text(int(dialogue_info.get("topic", 0))) + ". " + _text("Katsotaan seuraavaa korttia yhdessä.", "Let's look at the next card together.")
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bubble_content.add_child(bubble)
	bubble_content.add_child(_label(_text("Valitse vastaus oikealta →", "Choose a reply on the right →"), 14, true))
	var choices_scroll = ScrollContainer.new()
	choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.size_flags_stretch_ratio = 1.0
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices_scroll.follow_focus = true
	body.add_child(choices_scroll)
	var choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.add_child(choices)
	choices.add_child(_label(_text("Sinä", "You"), 20, true))
	for index in range(questions.size()):
		var answer_id: String = "profile:" + str(index)
		choices.add_child(_wrapped_button(GameState.localize(questions[index].get("question", "")), func(): dialogue_answer = answer_id; _queue_refresh(), answer_id))
	var question_keys: Array = ["directions", "kanban", "controls", "topics", "accessibility"] if questions.is_empty() or is_receptionist else ["directions", "controls"]
	for key in question_keys:
		var answer_key: String = "answer_" + str(key)
		var question_key: String = "ask_" + str(key)
		var button = _wrapped_button(GameState.tr_key(question_key), func(): dialogue_answer = answer_key; _queue_refresh(), question_key)
		choices.add_child(button)
	choices.add_child(_button(GameState.tr_key("goodbye"), close_modal, "goodbye"))
	modal_content.add_child(_label(_text("Ohjain: ristiohjain / vasen sauva valitsee vastauksen, A vahvistaa, Esc / B palaa.", "Controller: D-pad / left stick chooses a reply, A confirms, Esc / B returns."), 13, true))

func _wrapped_button(text: String, action: Callable, focus_id: String = "") -> Button:
	var button = _button("", action, focus_id)
	button.custom_minimum_size.y = 66
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = text
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 14)
	button.add_child(margin)
	var label = _label(text, 16)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size.y = 60
	margin.add_child(label)
	return button

func _build_search() -> void:
	_header(_text("Hae toimistosta", "Search the office"))
	var panel_script = load("res://scripts/ui/search_panel.gd")
	if panel_script == null:
		modal_content.add_child(_label(_text("Hakua ladataan…", "Loading search…"), 22))
		return
	var panel = panel_script.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_content.add_child(panel)
	panel.setup(GameState)
	if panel.has_signal("close_requested"): panel.close_requested.connect(close_modal)
	panel.navigation_requested.connect(func(result: Dictionary): close_modal(); search_navigation_requested.emit(result))
	if panel.has_signal("query_changed"):
		panel.query_changed.connect(func(query: String): search_query = query; search_field.text = query)
	if panel.has_signal("remote_connection_requested"):
		panel.remote_connection_requested.connect(func(entity_id: String): remote_connection_requested.emit(entity_id))
	panel.open(search_query)

func _pocket_items() -> Array:
	var items = GameState.get("pocket_items")
	return items if items is Array else []

func _find_pocket_item(item_id: String) -> Dictionary:
	for item in _pocket_items():
		if str(item.id) == item_id: return item
	return {}

func _item_card_ids(item: Dictionary) -> Array:
	if GameState.has_method("get_pocket_item_card_ids"):
		return GameState.call("get_pocket_item_card_ids", str(item.id))
	var ids: Array = []
	if item.get("kind", "") == "board":
		var board_id: String = str(item.get("board_id", ""))
		if GameState.boards.has(board_id):
			for lane in _lanes(GameState.boards[board_id]):
				for column in lane.cards: ids.append_array(column)
	elif item.get("kind", "") == "swimlane":
		for column in item.get("cards", []): ids.append_array(column)
	else:
		ids.append_array(item.get("cards", []))
	return ids

func _pocket_item_title(item: Dictionary) -> String:
	var record: Dictionary = {}
	match str(item.get("kind", "")):
		"entity": record = GameState.entities.get(str(item.get("entity_id", "")), {})
		"building": record = GameState.organizations.get(str(item.get("organization_id", "")), {})
		"room": record = GameState.rooms.get(str(item.get("room_id", "")), {})
		"floor":
			var floors = GameState.get("floors")
			if floors is Dictionary: record = floors.get(str(item.get("floor_id", "")), {})
		"board": record = GameState.boards.get(str(item.get("board_id", "")), {})
	return GameState.localize(record.get("name", record.get("title", item.get("title", ""))))

func _build_container_tile(tile: VBoxContainer, item: Dictionary) -> void:
	var item_id: String = str(item.id)
	var button = _button("", func(): open_container(item_id), "container:" + item_id)
	button.custom_minimum_size = Vector2(180, 136)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_child(button)
	var inner = MarginContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: inner.add_theme_constant_override("margin_" + side, 12)
	button.add_child(inner)
	var labels = VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(labels)
	var kind_name: String = _text("UIMARATA", "SWIMLANE") if item.kind == "swimlane" else _text("LISTA", "LIST")
	if item.kind == "board": kind_name = _text("TAULU", "BOARD")
	elif item.kind == "building": kind_name = _text("RAKENNUS", "BUILDING")
	elif item.kind == "floor": kind_name = _text("KERROS", "FLOOR")
	elif item.kind == "room": kind_name = _text("TYÖTILA", "WORKSPACE")
	elif item.kind == "entity":
		var entity: Dictionary = GameState.entities.get(str(item.get("entity_id", "")), {})
		kind_name = _text("IHMINEN", "PERSON") if entity.get("kind", "") == "person" else _text("ESINE", "OBJECT")
		if str(entity.get("template", "")) in ["cat", "dog", "cow", "horse", "chicken"]: kind_name = _text("ELÄIN", "ANIMAL")
	var kind = _label(kind_name, 12, true)
	kind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(kind)
	var title = _label(_pocket_item_title(item), 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(title)
	var count = _label((_text("%d korttia · näytä sisältö", "%d cards · view contents") % _item_card_ids(item).size()), 14)
	if item.kind == "entity": count.text = _text("Näytä tiedot · sijoita maailmaan", "View details · place in the world")
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_child(count)
	tile.add_child(_button(_text("Kanna kokonaisuus", "Carry this item"), func(): _carry_container(item_id), "carry_container:" + item_id))

func open_container(item_id: String) -> void:
	if _find_pocket_item(item_id).is_empty(): return
	active_container_id = item_id
	pocket_page = 0
	_open("container")

func _build_container() -> void:
	var item: Dictionary = _find_pocket_item(active_container_id)
	if item.is_empty():
		_header(GameState.tr_key("pocket"))
		modal_content.add_child(_label(_text("Kokonaisuus on siirretty taululle.", "This item has been moved to a board."), 22))
		modal_content.add_child(_button(GameState.tr_key("back"), open_pocket))
		return
	if item.get("kind", "") in ["entity", "building", "floor", "room"]:
		_build_spatial_pocket_item(item)
		return
	_header(_pocket_item_title(item), _text("Kokonaisuus säilyttää listansa ja korttinsa. Voit myös poimia yksittäisen kortin.", "This item keeps its lists and cards together. You can also take an individual card."))
	var actions = HBoxContainer.new()
	modal_content.add_child(actions)
	actions.add_child(_button("‹ " + GameState.tr_key("pocket"), open_pocket, "back_pocket"))
	actions.add_child(_button(_text("Kanna koko kokonaisuus", "Carry the whole item"), func(): _carry_container(active_container_id), "carry_container"))
	var entries: Array = []
	for id in _item_card_ids(item): entries.append({"kind": "card", "id": str(id)})
	_build_inventory_grid(entries)

func _carry_container(item_id: String) -> void:
	if _find_pocket_item(item_id).is_empty(): return
	close_modal()
	container_placement_requested.emit(item_id)

func _pocket_container(board_id: String, lane_index: int, list_index: int) -> void:
	var item_id: String
	if list_index < 0:
		item_id = str(GameState.call("pocket_swimlane", board_id, lane_index))
	else:
		item_id = str(GameState.call("pocket_list", board_id, lane_index, list_index))
	show_toast(_text("Kokonaisuus siirrettiin taskuun.", "Item and its cards moved to your pocket.") if not item_id.is_empty() else GameState.tr_key("move_failed"))
	_queue_refresh()

func _pocket_board(board_id: String) -> void:
	var item_id: String = str(GameState.call("pocket_board", board_id))
	if item_id.is_empty():
		show_toast(GameState.tr_key("move_failed"))
		return
	open_pocket()
	show_toast(_text("Koko taulu on taskussa. Kanna se toisen huoneen seinälle.", "The whole board is in your pocket. Carry it to another room's wall."))

func _edit_text(kind: String, data: Dictionary, initial_values: Array) -> void:
	if modal_kind != "editor": editor_return_kind = modal_kind
	editor_data = data.duplicate()
	editor_data["kind"] = kind
	editor_data["initial_values"] = initial_values.duplicate()
	_open("editor")

func _build_editor() -> void:
	var titles: Dictionary = {
		"entity": _text("Muokkaa nimeä", "Edit name"), "board": _text("Taulun nimi", "Board title"),
		"person": _text("Henkilön tiedot", "Person profile"),
		"lane": _text("Uimaradan nimi", "Swimlane title"), "list": _text("Listan nimi", "List title"),
		"card": _text("Muokkaa korttia", "Edit card"), "add_lane": _text("Lisää uimarata", "Add swimlane"),
		"add_list": _text("Lisää lista", "Add list"), "add_card": _text("Lisää nelirivinen kortti", "Add a four-line card")
	}
	_header(str(titles.get(editor_data.get("kind", ""), _text("Muokkaa", "Edit"))))
	if editor_data.get("kind", "") == "person":
		var person_script = load("res://scripts/ui/person_editor.gd")
		if person_script == null: return
		var person_editor = person_script.new()
		person_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_content.add_child(person_editor)
		person_editor.saved.connect(_finish_edit)
		person_editor.cancelled.connect(_finish_edit)
		person_editor.deleted.connect(func(): open_people())
		person_editor.setup(str(editor_data.entity_id))
		return
	if editor_data.get("kind", "") == "card" and ResourceLoader.exists("res://scripts/ui/card_editor.gd") and ResourceLoader.exists("res://scripts/core/card_schema.gd"):
		var card_editor_script = load("res://scripts/ui/card_editor.gd")
		var card_editor = card_editor_script.new()
		card_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_content.add_child(card_editor)
		card_editor.saved.connect(_finish_edit)
		card_editor.cancelled.connect(_finish_edit)
		card_editor.setup(str(editor_data.card_id))
		return
	var panel = TextEditor.new()
	modal_content.add_child(panel)
	panel.setup(editor_data.get("initial_values", [""]), GameState.language)
	panel.save_requested.connect(_save_editor)
	panel.cancel_requested.connect(_finish_edit)

func _save_editor(values: Array) -> void:
	var kind: String = str(editor_data.get("kind", ""))
	var success: bool = false
	var board_id: String = str(editor_data.get("board_id", ""))
	var lane_index: int = int(editor_data.get("lane", 0))
	var list_index: int = int(editor_data.get("list", 0))
	if kind == "entity": success = bool(GameState.call("rename_entity", str(editor_data.entity_id), str(values[0])))
	elif kind == "board": success = bool(GameState.call("edit_board_title", board_id, str(values[0])))
	elif kind == "lane": success = bool(GameState.call("edit_lane_title", board_id, lane_index, str(values[0])))
	elif kind == "list": success = bool(GameState.call("edit_list_title", board_id, lane_index, list_index, str(values[0])))
	elif kind == "card": success = bool(GameState.call("edit_card_lines", str(editor_data.card_id), values))
	elif kind == "add_lane": success = not str(GameState.call("add_swimlane", board_id, str(values[0]))).is_empty()
	elif kind == "add_list": success = int(GameState.call("add_list", board_id, lane_index, str(values[0]))) >= 0
	elif kind == "add_card": success = not str(GameState.call("add_card", board_id, lane_index, list_index, values)).is_empty()
	if success:
		_finish_edit()
		show_toast(_text("Teksti tallennettu suomeksi.", "Text saved in English."))
	else:
		show_toast(_text("Tallennus ei onnistunut. Tarkista teksti ja kohde.", "Could not save. Check the text and destination."))

func _finish_edit() -> void:
	var return_kind: String = editor_return_kind
	editor_return_kind = ""
	if return_kind.is_empty(): close_modal()
	else: _open(return_kind)

func _build_organizations() -> void:
	_header(_text("Organisaatiot ja rakennukset", "Organizations and buildings"), _text("Jokaisella organisaatiolla on oma nelikerroksinen toimistorakennus. Lisää organisaatio rakentaaksesi uuden toimiston.", "Each organization has its own four-floor office building. Add an organization to create a new office."))
	_management_buttons("organizations")
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal_content.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var organizations = GameState.get("organizations")
	if organizations is Dictionary:
		for organization in organizations.values():
			var panel = PanelContainer.new()
			rows.add_child(panel)
			var row = HBoxContainer.new()
			_margin(panel, 18).add_child(row)
			var title = _label(GameState.localize(organization.name), 23)
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			title.tooltip_text = title.text
			row.add_child(title)
			var result: Dictionary = {"kind": "organization", "id": str(organization.id), "title": GameState.localize(organization.name), "position": organization.get("position", {"x": 0.0, "y": 0.0, "z": 0.0}), "floor": 1}
			row.add_child(_button(_text("Näytä sijainti", "Show location"), func(): close_modal(); search_navigation_requested.emit(result), "organization:" + str(organization.id)))
	var add_panel = PanelContainer.new()
	modal_content.add_child(add_panel)
	var form = VBoxContainer.new()
	_margin(add_panel, 18).add_child(form)
	form.add_child(_label(_text("Lisää organisaatio", "Add organization"), 21))
	var input_row = HBoxContainer.new()
	form.add_child(input_row)
	organization_name_field = LineEdit.new()
	organization_name_field.placeholder_text = _text("Organisaation nimi", "Organization name")
	organization_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	organization_name_field.custom_minimum_size.y = 46
	organization_name_field.max_length = 100
	organization_name_field.set_meta("focus_id", "organization_name")
	organization_name_field.text_submitted.connect(func(_text_value): _create_organization())
	input_row.add_child(organization_name_field)
	input_row.add_child(_button(_text("+ Luo rakennus", "+ Create building"), _create_organization, "create_organization"))

func _create_organization() -> void:
	var text_value: String = organization_name_field.text.strip_edges()
	if text_value.is_empty():
		organization_name_field.grab_focus()
		return
	var organization_id: String = str(GameState.call("create_organization", text_value))
	if organization_id.is_empty():
		show_toast(_text("Organisaation luonti ei onnistunut.", "Could not create the organization."))
		return
	organization_name_field.text = ""
	_queue_refresh()
	show_toast(_text("Uusi toimistorakennus on valmis. Valitse Näytä sijainti.", "The new office building is ready. Choose Show location."))

func _build_remote_call() -> void:
	_header(_text("Etäyhteys", "Remote call"))
	if not is_instance_valid(remote_npc):
		modal_content.add_child(_label(_text("Henkilö ei ole tavoitettavissa.", "This person is unavailable."), 24))
		return
	var remote_script = load("res://scripts/ui/remote_call.gd")
	if remote_script == null: return
	var panel = remote_script.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_content.add_child(panel)
	panel.closed.connect(close_modal)
	panel.setup(remote_entity_id, remote_npc)

func _board_view_buttons(parent: Node, board_id: String, active_view: String) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var labels: Dictionary = {"swimlanes": _text("Uimaradat", "Swimlanes"), "calendar": _text("Kalenteri", "Calendar"), "gantt": "Gantt", "reports": _text("Raportit", "Reports")}
	for key in labels:
		var view_key: String = str(key)
		var button = _button(str(labels[key]), func(): open_board_view(board_id, view_key), "view:" + board_id + ":" + view_key)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		if key == active_view:
			button.add_theme_stylebox_override("normal", _style(Color("276b64"), 7, 1, Color("77dbbd")))
			button.add_theme_color_override("font_color", Color("b5f5d9"))
		row.add_child(button)

func _build_alternate_board_view(view: String) -> void:
	if not GameState.boards.has(active_board_view_id): return
	var title: String = GameState.localize(GameState.boards[active_board_view_id].title)
	_header(title)
	_board_view_buttons(modal_content, active_board_view_id, view)
	var path: String = "res://scripts/ui/board_" + view + ".gd"
	if not ResourceLoader.exists(path):
		modal_content.add_child(_label(_text("Näkymää valmistellaan.", "Preparing this view."), 20))
		return
	var view_script = load(path)
	var panel = view_script.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_content.add_child(panel)
	if panel.has_signal("card_selected"): panel.card_selected.connect(open_card_editor)
	if panel.has_signal("closed"): panel.closed.connect(func(): open_board(active_board_view_id))
	panel.setup(active_board_view_id)

func _management_buttons(active: String) -> void:
	var row = HBoxContainer.new()
	modal_content.add_child(row)
	var organizations_button = _button(_text("Organisaatiot", "Organizations"), open_organizations, "manage_organizations")
	organizations_button.disabled = active == "organizations"
	row.add_child(organizations_button)
	var people_button = _button(_text("Ihmiset", "People"), open_people, "manage_people")
	people_button.disabled = active == "people"
	row.add_child(people_button)
	var spatial_button = _button(_text("Tilat ja esineet", "Spaces and objects"), func(): open_spatial({}), "manage_spatial")
	spatial_button.disabled = active == "spatial"
	row.add_child(spatial_button)

func _build_people() -> void:
	_header(_text("Ihmiset ja tehtävät", "People and roles"), _text("Muokkaa nimiä, vastuualueita ja keskustelujen kysymyksiä. Uusi henkilö ilmestyy valittuun työtilaan.", "Edit names, responsibilities and conversation questions. A new person appears in the selected workspace."))
	_management_buttons("people")
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal_content.add_child(scroll)
	var rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var person_ids: Array = []
	for entity_id in GameState.entities:
		var entity: Dictionary = GameState.entities[entity_id]
		if entity.get("kind", "") == "person" and not entity.get("deleted", false): person_ids.append(str(entity_id))
	person_ids.sort()
	for entity_id in person_ids:
		var person: Dictionary = GameState.entities[entity_id]
		var panel = PanelContainer.new()
		rows.add_child(panel)
		var row = HBoxContainer.new()
		_margin(panel, 13).add_child(row)
		var description = VBoxContainer.new()
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(description)
		var person_title = _label(GameState.localize(person.name), 21)
		person_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		person_title.tooltip_text = person_title.text
		description.add_child(person_title)
		var profile: Dictionary = person.get("profile", {})
		var location: String = GameState.room_name(str(person.get("room_id", "")))
		var role: String = GameState.localize(profile.get("title", person.get("title", "")))
		var details = _label(location + (" · " + role if not role.is_empty() else ""), 13, true)
		details.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description.add_child(details)
		row.add_child(_button(_text("Muokkaa", "Edit"), func(): open_person_editor(entity_id), "edit_person:" + entity_id))
		row.add_child(_button(_text("Etäyhteys", "Remote call"), func(): remote_connection_requested.emit(entity_id), "remote:" + entity_id))
	var form_panel = PanelContainer.new()
	modal_content.add_child(form_panel)
	var form = VBoxContainer.new()
	_margin(form_panel, 14).add_child(form)
	form.add_child(_label(_text("Lisää henkilö työtilaan", "Add a person to a workspace"), 20))
	var input_row = HBoxContainer.new()
	form.add_child(input_row)
	person_name_field = LineEdit.new()
	person_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	person_name_field.custom_minimum_size = Vector2(180, 43)
	person_name_field.max_length = 100
	person_name_field.placeholder_text = _text("Henkilön nimi", "Person's name")
	person_name_field.set_meta("focus_id", "new_person_name")
	person_name_field.text_submitted.connect(func(_value): _create_person())
	input_row.add_child(person_name_field)
	person_workspace_picker = OptionButton.new()
	person_workspace_picker.custom_minimum_size = Vector2(260, 43)
	person_workspace_picker.clip_text = true
	person_workspace_picker.set_meta("focus_id", "new_person_workspace")
	person_workspace_ids = GameState.rooms.keys()
	person_workspace_ids.sort()
	for room_id in person_workspace_ids:
		var room: Dictionary = GameState.rooms[room_id]
		var org: Dictionary = GameState.organizations.get(str(room.get("organization_id", "")), {})
		var organization_name: String = GameState.localize(org.get("name", ""))
		person_workspace_picker.add_item((organization_name + " · " if not organization_name.is_empty() else "") + GameState.room_name(str(room_id)))
	input_row.add_child(person_workspace_picker)
	person_gender_picker = OptionButton.new()
	person_gender_picker.add_item(_text("Nainen", "Woman"))
	person_gender_picker.add_item(_text("Mies", "Man"))
	person_gender_picker.custom_minimum_size = Vector2(110, 43)
	input_row.add_child(person_gender_picker)
	person_age_picker = OptionButton.new()
	person_age_picker.add_item(_text("Nuori", "Young"))
	person_age_picker.add_item(_text("Keski-ikäinen", "Middle-aged"))
	person_age_picker.add_item(_text("Iäkäs", "Older"))
	person_age_picker.select(1)
	person_age_picker.custom_minimum_size = Vector2(145, 43)
	person_age_picker.set_meta("focus_id", "new_person_age")
	input_row.add_child(person_age_picker)
	var create = _button(_text("+ Lisää henkilö", "+ Add person"), _create_person, "create_person")
	create.disabled = person_workspace_ids.is_empty()
	input_row.add_child(create)

func _create_person() -> void:
	var name_value: String = person_name_field.text.strip_edges()
	if name_value.is_empty():
		person_name_field.grab_focus()
		return
	var index: int = person_workspace_picker.selected
	if index < 0 or index >= person_workspace_ids.size(): return
	var age_groups: Array = ["young", "middle", "old"]
	var entity_id: String = str(GameState.call("create_person", str(person_workspace_ids[index]), name_value, person_gender_picker.selected == 0, str(age_groups[person_age_picker.selected])))
	if entity_id.is_empty():
		show_toast(_text("Henkilön luonti ei onnistunut.", "Could not create the person."))
		return
	person_name_field.text = ""
	open_person_editor(entity_id)

func _build_spatial() -> void:
	_header(_text("Tilat, ihmiset ja esineet", "Spaces, people and objects"))
	_management_buttons("spatial")
	var panel_script = load("res://scripts/ui/spatial_editor.gd")
	if panel_script == null: return
	var panel = panel_script.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	modal_content.add_child(panel)
	panel.closed.connect(close_modal)
	panel.changed.connect(_update_stats)
	if panel.has_signal("person_selected"): panel.person_selected.connect(open_person_editor)
	panel.setup(spatial_context)

func _spatial_item_context(item: Dictionary) -> Dictionary:
	var context: Dictionary = {"kind": str(item.get("kind", ""))}
	for key in ["organization_id", "floor_id", "room_id", "entity_id"]:
		if item.has(key): context[key] = str(item[key])
	if item.get("kind", "") == "entity":
		var entity: Dictionary = GameState.entities.get(str(item.get("entity_id", "")), {})
		context["room_id"] = str(entity.get("room_id", ""))
		context["organization_id"] = str(entity.get("organization_id", ""))
	if context.has("room_id"):
		var room: Dictionary = GameState.rooms.get(str(context.room_id), {})
		context["floor_id"] = str(room.get("floor_id", context.get("floor_id", "")))
		context["organization_id"] = str(room.get("organization_id", context.get("organization_id", "")))
	if context.has("floor_id"):
		var floors = GameState.get("floors")
		if floors is Dictionary:
			context["organization_id"] = str(floors.get(str(context.floor_id), {}).get("organization_id", context.get("organization_id", "")))
	return context

func _build_spatial_pocket_item(item: Dictionary) -> void:
	_header(_pocket_item_title(item), _text("Sisältö säilyy mukana, kun siirrät kokonaisuuden.", "All contents stay together when you move this item."))
	var item_id: String = str(item.id)
	var actions = HBoxContainer.new()
	modal_content.add_child(actions)
	actions.add_child(_button("‹ " + GameState.tr_key("pocket"), open_pocket, "back_pocket"))
	actions.add_child(_button(_text("Kanna ja sijoita", "Carry and place"), func(): _carry_container(item_id), "carry_spatial"))
	var context: Dictionary = _spatial_item_context(item)
	actions.add_child(_button(_text("Tilat, ihmiset ja esineet", "Spaces, people and objects") if item.kind != "entity" else _text("Muokkaa tietoja", "Edit details"), func(): open_spatial(context), "inspect_spatial"))
	if item.kind == "entity":
		var entity: Dictionary = GameState.entities.get(str(item.get("entity_id", "")), {})
		var description: String = GameState.localize(entity.get("description", ""))
		var text_label = _label(description, 21, true)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		modal_content.add_child(text_label)
		if entity.get("kind", "") == "person":
			var profile: Dictionary = entity.get("profile", {})
			for key in ["title", "team_role", "expertise"]:
				var value = _label(GameState.localize(profile.get(key, "")), 18)
				value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				modal_content.add_child(value)
			modal_content.add_child(_button(_text("Henkilön profiili ja kysymykset", "Person profile and questions"), func(): open_person_editor(str(item.entity_id)), "pocket_person_profile"))
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_content.add_child(spacer)
		modal_content.add_child(_label(_text("Valitse Kanna ja sijoita. Klikkaa sitten lattiaa tai maata, tai paina E / A.", "Choose Carry and place. Then click the floor or ground, or press E / A."), 16, true))
		return
	var ids: Array = _item_card_ids(item)
	var counts: Dictionary = _spatial_item_counts(item)
	var details = _label(_text("%d kerrosta · %d työtilaa · %d henkilöä · %d esinettä · %d korttia", "%d floors · %d workspaces · %d people · %d objects · %d cards") % [counts.floors, counts.rooms, counts.people, counts.objects, ids.size()], 16, true)
	modal_content.add_child(details)
	if item.kind == "floor" or item.kind == "room":
		var destination = SpatialDestination.new()
		modal_content.add_child(destination)
		destination.setup(item)
		destination.placed.connect(func(_id: String): close_modal(); show_toast(_text("Kokonaisuus sisältöineen sijoitettu.", "The item and all contents have been placed.")))
	var entries: Array = []
	for id in ids: entries.append({"kind": "card", "id": str(id)})
	if entries.is_empty():
		var spacer = Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_content.add_child(spacer)
		modal_content.add_child(_label(_text("Tässä kokonaisuudessa ei ole kortteja. Muut sisällöt löydät Tilat, ihmiset ja esineet -painikkeesta.", "This item contains no cards. Use Spaces, people and objects to inspect its other contents."), 16, true))
	else:
		_build_inventory_grid(entries)

func _spatial_item_counts(item: Dictionary) -> Dictionary:
	var counts: Dictionary = {"floors": 0, "rooms": 0, "people": 0, "objects": 0}
	var context: Dictionary = _spatial_item_context(item)
	var floor_ids: Array = []
	var room_ids: Array = []
	var floors = GameState.get("floors")
	if floors is Dictionary:
		for floor_record in floors.values():
			if floor_record.get("deleted", false): continue
			if item.kind == "building" and str(floor_record.get("organization_id", "")) == str(context.get("organization_id", "")) and not floor_record.get("in_pocket", false): floor_ids.append(str(floor_record.id))
			elif item.kind == "floor" and str(floor_record.id) == str(item.floor_id): floor_ids.append(str(floor_record.id))
	counts.floors = floor_ids.size()
	for room in GameState.rooms.values():
		if room.get("deleted", false): continue
		if item.kind == "room" and str(room.id) == str(item.room_id): room_ids.append(str(room.id))
		elif floor_ids.has(str(room.get("floor_id", ""))) and not room.get("in_pocket", false): room_ids.append(str(room.id))
	counts.rooms = room_ids.size()
	for entity in GameState.entities.values():
		if entity.get("deleted", false): continue
		var contained: bool = room_ids.has(str(entity.get("room_id", ""))) and not entity.get("in_pocket", false)
		if GameState.has_method("effective_pocket_item_for_entity"):
			contained = str(GameState.call("effective_pocket_item_for_entity", str(entity.id))) == str(item.id)
		if not contained: continue
		if entity.get("kind", "") == "person": counts.people += 1
		else: counts.objects += 1
	return counts
