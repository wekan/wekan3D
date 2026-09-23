extends SceneTree
## Real-engine ownership, bilingual editing, dynamic containers and persistence tests.
var state
var checks: int = 0
var failures: Array = []
var temp_path: String = "user://core_test_" + str(OS.get_process_id()) + ".sqlite"

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	state = root.get_node("GameState")
	state.set_process(false)
	state.autosave_enabled = false
	state._store.path = temp_path
	for floor_number in range(4):
		for room_number in range(4):
			var room_id = "room_%d_%d" % [floor_number, room_number]
			state.register_room({"id": room_id, "floor": floor_number})
			for wall in range(4):
				var topic = floor_number * 16 + room_number * 4 + wall
				state.ensure_board("b%d" % topic, room_id, topic)
	state.register_entity({"id": "person_a", "kind": "person", "name": {"fi": "Aino Aalto", "en": "Aino Aalto"}, "room_id": "room_0_0", "floor": 1})
	state.register_entity({"id": "desk_a", "kind": "furniture", "name": {"fi": "Työpöytä", "en": "Desk"}, "room_id": "room_0_0", "floor": 1})
	check(state.boards.size() == 64, "64 boards")
	check(state.cards.size() == 1024, "1024 cards")
	check(state.rooms.size() == 16, "16 registered offices")
	var titles: Dictionary = {}
	for board in state.boards.values():
		titles[board.title.fi] = true
		check(board.swimlanes.size() == 1, "one initial swimlane")
		check(board.lists.size() == 4, "four initial lists")
		for items in board.cards:
			check(items.size() == 4, "four initial cards per list")
	for card in state.cards.values():
		check(card.lines.fi.size() == 4 and card.lines.en.size() == 4, "four bilingual lines")
	check(titles.size() == 64, "distinct topic titles")
	check(state.validate_state().is_empty(), "initial ownership valid")
	var original_count = state.cards.size()
	var card_id = state.boards.b0.cards[0][0]
	check(state.move_card(card_id, "b1", 3), "cross-board move")
	check(state.get_card_location(card_id).board_id == "b1", "target location recorded")
	check(state.pocket_card(card_id), "card into pocket")
	check(state.pocket_card(card_id), "repeated pocket is idempotent")
	check(state.pocket.size() == 1, "pocket has no duplicate")
	check(state.move_card(card_id, "b0", 0, 0), "place pocket card")
	check(state.get_card_location(card_id).index == 0, "explicit insertion index")
	var snapshot = JSON.stringify(state._snapshot())
	check(not state.move_card(card_id, "missing", 0), "reject unknown board")
	check(not state.move_card(card_id, "b0", 90), "reject unknown list")
	check(not state.move_card(card_id, "b0", 0, -2), "reject invalid insertion index")
	check(not state.move_card(card_id, "b0", 0, 90), "reject far insertion index")
	check(not state.move_card(card_id, "b0", 0, -1, 90), "reject unknown lane")
	check(JSON.stringify(state._snapshot()) == snapshot, "rejected moves are atomic")
	check(state.move_card(card_id, "b0", 0, -1), "same-list append")
	check(state.get_card_location(card_id).index == 3, "same-list corrected destination index")
	check(state.move_card(card_id, "b0", 0, 0), "same-list move to front")
	var new_lane = state.add_swimlane("b0", "Lisätyöt")
	check(not new_lane.is_empty(), "create swimlane")
	check(state.boards.b0.swimlanes[1].lists.size() == 1, "new lane has independent list count")
	check(state.add_list("b0", 1, "Tarkistus") == 1, "create list in chosen lane")
	var added = state.add_card("b0", 1, 1, ["Uusi tehtävä", "Toteuta siirto", "Vastuu: Aino", "Ei korttihävikkiä"])
	check(not added.is_empty(), "create four-line card")
	check(state.add_card("b0", 1, 1, ["one line"]).is_empty(), "reject wrong card line count")
	check(state.cards.size() == original_count + 1, "new card accounted for")
	var english_lines = state.cards[added].lines.en.duplicate()
	check(state.edit_card_lines(added, ["Muokattu", "Toinen", "Kolmas", "Neljäs"]), "edit active card language")
	check(state.cards[added].lines.en == english_lines, "other language unchanged")
	state.set_language("en")
	check(state.edit_board_title("b0", "Custom board"), "edit board English title")
	check(state.boards.b0.title.fi == "Auton rakentaminen", "Finnish board title retained")
	check(state.edit_lane_title("b0", 1, "Extra work"), "edit lane title")
	check(state.edit_list_title("b0", 1, 1, "Review"), "edit list title")
	check(state.rename_entity("person_a", "Aino Example"), "rename fictional person")
	check(state.entities.person_a.name.fi == "Aino Aalto", "person other language retained")
	check(state.rename_entity("desk_a", "Oak workstation"), "rename furniture")
	var container = state.pocket_list("b0", 0, 0)
	check(not container.is_empty(), "pocket complete list")
	check(state.get_pocket_item(container).cards.size() == 4, "list contains its four cards")
	check(state.get_card_location(card_id).item_id == container, "nested card location")
	check(state.pocket_card_count() == 4, "nested cards counted in HUD")
	check(state.move_card(card_id, "b1", 1, -1, 0), "extract nested card to board")
	check(state.get_pocket_item(container).cards.size() == 3, "container extraction removes source")
	check(state.place_pocket_item(container, "b1", 0), "place whole list on another board")
	check(state.boards.b1.lists.size() == 5, "destination lane gains list")
	check(state.pocket_items.is_empty(), "placed list removed from pocket")
	var lane_container = state.pocket_swimlane("b0", 1)
	check(not lane_container.is_empty(), "pocket complete extra swimlane")
	check(state.get_card_location(added).item_id == lane_container, "new card carried with lane")
	check(state.place_pocket_item(lane_container, "b2"), "place lane on another board")
	check(state.boards.b2.swimlanes.size() == 2, "destination gains lane")
	check(state.get_card_location(added).board_id == "b2" and state.get_card_location(added).lane == 1, "placed lane owner correct")
	var last_lane = state.pocket_swimlane("b3", 0)
	check(state.boards.b3.swimlanes.size() == 1 and state.boards.b3.cards[0].is_empty(), "last removed lane replaced with empty lane")
	check(state.place_pocket_item(last_lane, "b3"), "return original lane")
	var empty_list = state.pocket_list("b3", 0, 0)
	check(state.boards.b3.lists.size() == 1 and state.boards.b3.cards[0].is_empty(), "last removed list replaced empty")
	check(state.place_pocket_item(empty_list, "b3", 0), "place empty list")
	check(state.validate_state().is_empty(), "all container mutations preserve ownership")
	# Repeat moves across varied dynamically-sized lanes and nested/loose pockets.
	var rng = RandomNumberGenerator.new()
	rng.seed = 918273
	var all_cards = state.cards.keys()
	for iteration in range(300):
		var chosen: String = all_cards[rng.randi_range(0, all_cards.size() - 1)]
		if iteration % 5 == 0:
			check(state.pocket_card(chosen), "random pocket move")
		else:
			var board_id = "b%d" % rng.randi_range(0, 63)
			var lane_index = rng.randi_range(0, state.boards[board_id].swimlanes.size() - 1)
			var list_index = rng.randi_range(0, state.boards[board_id].swimlanes[lane_index].lists.size() - 1)
			check(state.move_card(chosen, board_id, list_index, -1, lane_index), "random board move")
		if iteration % 25 == 0:
			check(state.validate_state().is_empty(), "randomized ownership checkpoint")
	var board_before_count = state.pocket_card_count()
	var board_card: String = state.boards.b6.swimlanes[0].cards[0][0]
	var board_container = state.pocket_board("b6")
	check(not board_container.is_empty(), "pocket whole board")
	check(state.boards.b6.room_id.is_empty() and state.boards.b6.slot_id.is_empty(), "pocket board has no room or wall")
	check(state.board_slots.b6.board_id.is_empty(), "source wall slot empty")
	check(state.get_card_location(board_card).item_id == board_container, "whole-board card location points to container")
	check(state.pocket_card_count() > board_before_count, "whole-board cards counted in pocket")
	check(state.place_pocket_board(board_container, "b7"), "place whole board in occupied wall slot")
	check(state.board_slots.b7.board_id == "b6" and state.boards.b6.room_id == "room_0_1", "board assigned to destination room and slot")
	check(state.boards.b7.room_id.is_empty(), "displaced board safely put in pocket")
	check(state.validate_state().is_empty(), "whole-board swap preserves card ownership")
	check(state._validate_save(state._snapshot()).is_empty(), "whole-board slots and graph are valid")
	var full_before_fi = state.cards[added].lines.fi.duplicate()
	var full = state.get_card_details(added, "en")
	check(full.has("createdAt") and full.has("customFields") and full.has("title"), "all schema defaults available")
	check(state.edit_card_details(added, {"title": "Detailed English task", "description": "First detail\nSecond detail\nThird detail\nFourth full detail", "archived": false, "futureModelField": {"value": 7}}, "en"), "full-details patch saves: " + state.last_error)
	check(state.cards[added].lines.fi == full_before_fi, "full-details English patch preserves Finnish")
	check(state.get_card_details(added, "en").description.ends_with("Fourth full detail"), "full description not truncated to board preview")
	check(state.get_card_details(added, "en").futureModelField.value == 7, "unknown future field preserved")
	var details_before = JSON.stringify(state.cards[added])
	check(not state.edit_card_details(added, {"archived": "yes"}, "en"), "invalid typed field rejected")
	check(JSON.stringify(state.cards[added]) == details_before, "invalid full-field edit is atomic")
	check(state.edit_card_details(added, {"related": {"checklists": [{"title": "Acceptance checks", "sort": 0}]}}, "en"), "related checklist auto IDs/timestamps: " + state.last_error)
	var checklist = state.get_card_details(added, "en").related.checklists[0]
	check(checklist.has("_id") and checklist.cardId == added and checklist.has("createdAt"), "related system fields populated")
	var checklist_fi = checklist.duplicate(true)
	checklist_fi.title = "Hyväksymistarkistukset"
	check(state.edit_card_details(added, {"related": {"checklists": [checklist_fi]}}, "fi"), "related Finnish text edit")
	check(state.get_card_details(added, "en").related.checklists[0].title == "Acceptance checks", "related English translation retained")
	check(state.edit_card_details(added, {"related": {"checklistItems": [{"title": "Inspect output", "checklistId": checklist._id}]}}, "en"), "checklist item defaults and foreign key")
	check(not state.edit_card_details(added, {"related": {"checklistItems": [{"title": "Broken", "checklistId": "missing"}]}}, "en"), "dangling related reference rejected")
	state.organizations_changed.connect(_register_test_building)
	var organization = state.create_organization("Toinen organisaatio")
	check(not organization.is_empty(), "create organization")
	check(state.organizations[organization].building_index == 1, "next building index")
	check(state.organizations[organization].position.x == 60.0, "next building 60 meters away")
	check(state.rooms.has(organization + "_room") and state.boards.has(organization + "_board"), "synchronous creation callback registers building before save")
	check(state._validate_save(state._snapshot()).is_empty(), "expanded organization graph validates")
	var new_person = state.create_person("room_0_0", "Helmi Havu", true)
	check(not new_person.is_empty(), "create fictional person")
	check(state.entities[new_person].female and state.entities[new_person].organization_id == "org_main", "new person keeps gender and organization")
	check(state.edit_person_profile(new_person, {"name": "Helmi Havu", "title": "Pääkehittäjä", "team_role": "Vetäjä", "expertise": "Robotit", "qa": [{"question": "Mitä teet?", "answer": "Kokoan robotin."}]}, "fi"), "edit Finnish person and QA")
	var person_fi = state.get_person_profile(new_person, "fi")
	var person_en = state.get_person_profile(new_person, "en")
	check(person_fi.qa.size() == 1 and not person_fi.qa[0].id.is_empty(), "QA generated stable identity")
	check(person_en.qa[0].question.is_empty() and person_en.qa[0].answer.is_empty(), "new QA other language empty")
	check(state.edit_person_profile(new_person, {"title": "Lead developer", "qa": person_en.qa}, "en"), "untranslated existing QA does not prevent profile edit")
	var translated = person_en.qa.duplicate(true)
	translated[0].question = "What do you do?"
	translated[0].answer = "I assemble a robot."
	check(state.edit_person_profile(new_person, {"qa": translated}, "en"), "translate stable QA")
	check(state.get_person_profile(new_person, "fi").qa[0].answer == "Kokoan robotin.", "QA Finnish translation retained")
	check(not state.edit_person_profile(new_person, {"qa": [{"question": "", "answer": ""}]}, "en"), "reject empty new QA")
	check(state.edit_person_profile(new_person, {"qa": []}, "en"), "delete entire QA pair")
	check(state.get_person_profile(new_person, "fi").qa.is_empty(), "deleted QA removed in both languages")
	check(state.delete_person(new_person), "soft-delete person")
	check(state.entities.has(new_person) and state.entities[new_person].deleted and state.entities[new_person].has("deletedAt"), "deleted person identity/history retained")
	check(not state.edit_person_profile(new_person, {"name": "Cannot edit"}), "deleted person edit rejected")
	state.visit_room("room_0_0")
	state.visit_room("room_0_0")
	check(state.visited_rooms.size() == 1, "visit count is distinct")
	state.elapsed_seconds = 123.5
	var saved_start = state.started_at
	var carried_lane = state.pocket_swimlane("b4", 0)
	check(not carried_lane.is_empty(), "prepare nested SQL save")
	check(state.save_game(), "SQLite full save: " + state.last_error)
	check(state.database_exists(), "SQLite file created")
	var expected = state._snapshot().duplicate(true)
	check(state.move_card(card_id, "b9", 0), "change after saved checkpoint")
	check(state.load_game(), "SQLite full load: " + state.last_error)
	check(state.validate_state().is_empty(), "loaded ownership valid")
	check(state.started_at == saved_start and state.elapsed_seconds == 123.5, "clock preserved")
	check(state.cards.size() == expected.cards.size(), "user-created card preserved")
	check(state.pocket_items.size() == expected.pocket_items.size(), "nested pocket preserved")
	check(state.entities.desk_a.name.en == "Oak workstation", "furniture rename persisted")
	check(state.boards.b0.title.en == "Custom board", "board translation persisted")
	# Aliases must refer to the SAME arrays after SQLite JSON reconstruction.
	var alias_card = state.boards.b5.cards[0][0]
	check(state.pocket_card(alias_card), "move from postload compatibility alias")
	check(not state.boards.b5.cards[0].has(alias_card), "postload alias updated with canonical lane")
	var bad = state._snapshot().duplicate(true)
	var duplicate_id: String = state.cards.keys()[0]
	bad.pocket.append(duplicate_id)
	check(not state._validate_save(bad).is_empty(), "duplicate ownership rejected")
	bad = state._snapshot().duplicate(true)
	bad.cards[duplicate_id].lines.fi = ["broken"]
	check(not state._validate_save(bad).is_empty(), "invalid localized line data rejected")
	bad = state._snapshot().duplicate(true)
	bad.elapsed_seconds = -1
	check(not state._validate_save(bad).is_empty(), "negative duration rejected")
	state.autosave_enabled = true
	check(state.edit_board_title("b1", "Immediate saved title"), "edit commits SQLite immediately: " + state.last_error)
	check(state.load_game() and state.boards.b1.title.en == "Immediate saved title", "immediate edit visible after database reload")
	var before_block = JSON.stringify(state._snapshot())
	state.storage_read_blocked = true
	check(not state.pocket_board("b1"), "failed save rolls back board pocket move")
	check(JSON.stringify(state._snapshot()) == before_block, "rollback preserves complete graph")
	state.storage_read_blocked = false
	state.autosave_enabled = false
	state._store.close_database()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	print("Core tests: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _register_test_building() -> void:
	for organization in state.organizations.values():
		if organization.id == "org_main":
			continue
		var room_id = organization.id + "_room"
		if not state.rooms.has(room_id):
			state.register_room({"id": room_id, "floor": 0, "organization_id": organization.id})
			state.ensure_board(organization.id + "_board", room_id, 0)
