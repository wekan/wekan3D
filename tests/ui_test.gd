extends Node

const UIScript = preload("res://scripts/ui/game_ui.gd")
var failures: Array = []
var carried: String = ""
var search_text: String = ""
var carried_container: String = ""
var remote_person: String = ""
var capture_directory: String = ""

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture="):
			capture_directory = argument.trim_prefix("--ui-capture=")
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("UI TEST: " + message)

func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

func _capture(filename: String) -> void:
	if capture_directory.is_empty(): return
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	if image != null and not image.is_empty(): image.save_png(capture_directory.path_join(filename))

func _all_label_text(node: Node) -> String:
	var text_value: String = node.text + "\n" if node is Label else ""
	for child in node.get_children(): text_value += _all_label_text(child)
	return text_value

func _run() -> void:
	GameState.reset_game()
	for i in range(4): GameState.ensure_board("ui_room_a_" + str(i), "ui_room_a", i)
	GameState.ensure_board("ui_room_b_0", "ui_room_b", 4)
	var ui = UIScript.new()
	add_child(ui)
	ui.build()
	ui.placement_requested.connect(func(id: String): carried = id)
	ui.search_requested.connect(func(query: String): search_text = query)
	ui.container_placement_requested.connect(func(id: String): carried_container = id)
	ui.remote_connection_requested.connect(func(id: String): remote_person = id)
	await _settle()
	_check(not ui.is_modal_open(), "HUD starts outside a modal")
	_check(ui.is_pointer_over_pocket(ui.pocket_button.get_global_rect().get_center()), "HUD pocket hit test")
	ui.open_board("ui_room_a_0")
	await _settle()
	_check(ui.room_board_ids.size() == 4, "Board selectors only include current room")
	_check(not ui.room_board_ids.has("ui_room_b_0"), "Other room board excluded")
	_check(ui.card_nodes.size() == 32, "Both board panels show all 16 initial cards")
	ui.card_nodes[0].grab_focus()
	var accept = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	await _settle()
	accept = InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = false
	Input.parse_input_event(accept)
	await _settle()
	_check(not ui.selected_card_id.is_empty(), "Controller A selects a focused card")
	_check(ui.modal_kind == "editor", "A single card click or controller A opens the editor")
	ui._finish_edit()
	await _settle()
	var first: String = str(GameState.boards["ui_room_a_0"].cards[0][0])
	var drop_target = ui.card_nodes[16]
	var payload: Dictionary = {"type": "kanban_card", "card_id": first}
	_check(drop_target._can_drop_data(Vector2.ZERO, payload), "Card drag payload is accepted by a destination card")
	drop_target._drop_data(Vector2.ZERO, payload)
	await _settle()
	_check(GameState.get_card_location(first).get("board_id", "") == "ui_room_a_1", "Drop inserts source card into another board")
	ui._select_card(first)
	ui.destination_board_id = "ui_room_a_1"
	ui.destination_list_index = 2
	ui._move_selected()
	await _settle()
	var location: Dictionary = GameState.get_card_location(first)
	_check(location.get("board_id", "") == "ui_room_a_1" and location.get("list", -1) == 2, "Accessible Move button transfers selected card")
	_check(ui.card_nodes.size() == 32, "Transfer keeps all cards visible including list overflow")
	await _capture("ui-board-fi.png")
	GameState.set_language("en")
	await _settle()
	_check(ui.start_label.text.begins_with("Started"), "HUD switches to English")
	_check(ui.controls_label.text.contains("Arrows"), "Control instructions switch to English")
	await _capture("ui-board-en.png")
	ui._select_card(first)
	ui._pocket_selected()
	await _settle()
	_check(GameState.pocket.has(first), "Accessible pocket button stores the card")
	var candidates: Array = []
	for id in GameState.cards.keys():
		if id != first: candidates.append(id)
	for i in range(24): GameState.pocket_card(str(candidates[i]))
	ui.open_pocket()
	await _settle()
	_check(ui.card_nodes.size() == 12, "Pocket page one contains 12 cards")
	await _capture("ui-pocket-en.png")
	ui.pocket_page = 2
	ui._refresh_modal()
	await _settle()
	_check(ui.card_nodes.size() == 1, "Pocket page three contains remaining card")
	var carry_id: String = str(ui.card_nodes[0].card_id)
	ui._carry(carry_id)
	_check(carried == carry_id and not ui.is_modal_open(), "Carry button emits exact card and returns to world")
	ui.open_dialogue({"name": "Aino", "receptionist": true, "topic": 0})
	await _settle()
	_check(ui.is_modal_open(), "Reception conversation opens")
	ui.dialogue_answer = "answer_kanban"
	ui._refresh_modal()
	await _settle()
	await _capture("ui-dialogue-en.png")
	var cancel = InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _settle()
	_check(not ui.is_modal_open(), "Escape / controller B closes conversation")
	ui._submit_search("robot")
	_check(search_text == "robot", "Search field submits full query")
	ui.open_search("robot")
	await _settle()
	_check(ui.modal_kind == "search", "Search panel integrates with modal shell")
	await _capture("ui-search-en.png")
	GameState.register_entity({"id": "ui_remote_person", "kind": "person", "name": {"fi": "Etätestaaja", "en": "Remote tester"}, "room_id": "ui_room_a"})
	ui.open_search("Remote tester")
	await _settle()
	var search_controls: Array = []
	ui._collect_focusable(ui.modal_content, search_controls)
	for control in search_controls:
		if str(control.get_meta("focus_id", "")) == "remote:ui_remote_person": control.pressed.emit()
	_check(remote_person == "ui_remote_person", "Person result Remote call forwards the correct entity id")
	await _capture("ui-search-person-en.png")
	ui.open_board("ui_room_a_0")
	var original_fi: String = str(GameState.boards["ui_room_a_0"].title.fi)
	ui.open_board_text("ui_room_a_0", {"text_kind": "board"})
	ui._save_editor(["Custom engineering board"])
	await _settle()
	_check(GameState.boards["ui_room_a_0"].title.en == "Custom engineering board", "Board title editor saves active language")
	_check(GameState.boards["ui_room_a_0"].title.fi == original_fi, "Board title editor preserves other language")
	ui._edit_text("add_lane", {"board_id": "ui_room_a_0"}, ["Release planning"])
	ui._save_editor(["Release planning"])
	await _settle()
	_check(GameState.boards["ui_room_a_0"].swimlanes.size() == 2, "Add swimlane editor creates a lane")
	ui._edit_text("add_list", {"board_id": "ui_room_a_0", "lane": 1}, ["Review queue"])
	ui._save_editor(["Review queue"])
	await _settle()
	ui._edit_text("add_card", {"board_id": "ui_room_a_0", "lane": 1, "list": 1}, ["Release", "Check build", "Owner: team", "Done after tests"])
	ui._save_editor(["Release", "Check build", "Owner: team", "Done after tests"])
	await _settle()
	_check(GameState.boards["ui_room_a_0"].swimlanes[1].cards[1].size() == 1, "Add card editor creates four-line card in selected lane and list")
	var added_id: String = str(GameState.boards["ui_room_a_0"].swimlanes[1].cards[1][0])
	ui.open_card_editor(added_id)
	await _settle()
	await _capture("ui-editor-en.png")
	ui._save_editor(["Release reviewed", "Check build", "Owner: team", "Done after tests"])
	await _settle()
	_check(GameState.cards[added_id].lines.en[0] == "Release reviewed", "Card editor updates requested text")
	_check(GameState.cards[added_id].lines.fi[0] == "Release", "Card editor preserves other language")
	ui._pocket_container("ui_room_a_0", 1, 1)
	await _settle()
	_check(GameState.pocket_items.size() == 1, "List can be pocketed with its cards")
	var list_item: String = str(GameState.pocket_items[0].id)
	ui.open_container(list_item)
	await _settle()
	_check(ui.card_nodes.size() == 1, "Pocket list exposes its contained card")
	ui._carry_container(list_item)
	_check(carried_container == list_item and not ui.is_modal_open(), "Whole-list carry emits correct item")
	_check(GameState.place_pocket_item(list_item, "ui_room_b_0", 0), "Whole list can be placed on another room's board")
	ui.open_board("ui_room_a_0")
	ui._pocket_container("ui_room_a_0", 0, -1)
	await _settle()
	_check(GameState.pocket_items.size() == 1 and GameState.pocket_items[0].kind == "swimlane", "Whole swimlane can be pocketed")
	GameState.register_entity({"id": "ui_desk", "kind": "furniture", "name": {"fi": "Työpöytä", "en": "Desk"}})
	ui.open_entity("ui_desk")
	ui._save_editor(["Build engineer desk"])
	await _settle()
	_check(GameState.entities.ui_desk.name.en == "Build engineer desk" and GameState.entities.ui_desk.name.fi == "Työpöytä", "Furniture rename only changes active language")
	if GameState.has_method("pocket_board"):
		ui.open_board("ui_room_a_2")
		ui._pocket_board("ui_room_a_2")
		await _settle()
		_check(ui.modal_kind == "pocket", "Pocketing whole board opens pocket")
		var board_item: Dictionary = {}
		for item in GameState.pocket_items:
			if item.kind == "board": board_item = item
		_check(not board_item.is_empty(), "Whole board is represented as a pocket item")
		if not board_item.is_empty():
			_check(ui._item_card_ids(board_item).size() == 16, "Whole board pocket view retains all cards")
			ui.open_container(str(board_item.id))
			await _settle()
			_check(ui.card_nodes.size() == 12, "Whole board contents are paginated")
	ui.open_organizations()
	await _settle()
	var organization_count: int = GameState.organizations.size()
	ui.organization_name_field.text = "Robotics laboratory"
	ui._create_organization()
	await _settle()
	_check(GameState.organizations.size() == organization_count + 1, "Organization form creates a new building record")
	await _capture("ui-organizations-en.png")
	GameState.register_room({"id": "ui_room_a", "name": {"fi": "Toimisto 101", "en": "Office 101"}, "floor": 0, "organization_id": str(GameState.organizations.keys()[0]), "topic": 0, "center": Vector3.ZERO})
	ui.open_people()
	await _settle()
	ui.person_name_field.text = "Robotics colleague"
	ui._create_person()
	await _settle()
	_check(ui.modal_kind == "editor" and ui.editor_data.kind == "person", "Add person form opens person profile editor")
	var person_id: String = str(ui.editor_data.entity_id)
	_check(GameState.entities[person_id].name.en == "Robotics colleague", "Person form creates named person in chosen workspace")
	await _capture("ui-person-editor-en.png")
	ui._finish_edit()
	await _settle()
	_check(ui.modal_kind == "people", "Person editor returns to people manager")
	await _capture("ui-people-en.png")
	GameState.edit_person_profile(person_id, {"title": "Robotics reviewer", "team_role": "Safety reviewer", "expertise": "Robot assembly", "qa": [{"id": "review", "question": "What must we check?", "answer": "Check the guard and the stop circuit."}]}, "en")
	ui.open_dialogue({"entity_id": person_id, "name": "Robotics colleague", "receptionist": false, "topic": 0})
	ui.dialogue_answer = "profile:0"
	ui._refresh_modal()
	await _settle()
	var dialogue_text: String = _all_label_text(ui.modal_content)
	_check(dialogue_text.contains("Robotics reviewer") and dialogue_text.contains("Check the guard and the stop circuit."), "Dialogue shows canonical profile and custom question answer")
	await _capture("ui-person-dialogue-en.png")
	for view in ["calendar", "gantt", "reports"]:
		if ResourceLoader.exists("res://scripts/ui/board_" + view + ".gd"):
			ui.open_board_view("ui_room_a_1", view)
			await _settle()
			_check(ui.modal_kind == view, "Board view shell opens " + view)
			await _capture("ui-" + view + "-en.png")
	_check(GameState.validate_state().is_empty(), "All UI transfers preserve single card location invariant")
	if failures.is_empty():
		print("UI TESTS PASSED: controller A/B, drag/drop, transfers, pagination, language-specific CRUD, container/whole-board pocket, search, organizations and card invariants")
		get_tree().quit(0)
	else:
		print("UI TESTS FAILED: ", failures)
		get_tree().quit(1)
