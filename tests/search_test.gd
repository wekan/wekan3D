extends SceneTree

const SearchIndex = preload("res://scripts/core/search_index.gd")
const SearchPanel = preload("res://scripts/ui/search_panel.gd")

class SearchState extends RefCounted:
	var language = "fi"
	var rooms = {
		"r1": {"id": "r1", "name": {"fi": "Älyrobotit", "en": "Smart robotics"}, "number": "101", "floor": 1, "position": {"x": 1, "y": 0, "z": 2}},
		"r2": {"id": "r2", "name": {"fi": "Autopaja", "en": "Automotive lab"}, "number": "403", "floor": 4, "position": {"x": 8, "y": 12, "z": 9}}
	}
	var boards = {
		"b1": {"id": "b1", "room_id": "r1", "title": {"fi": "Robotin rakentaminen", "en": "Robot construction"}, "lists": [{"fi": "Valmis", "en": "Done"}], "cards": [["c1"]], "position": {"x": 2, "y": 2, "z": 3}},
		"b2": {"id": "b2", "room_id": "r2", "title": {"fi": "Auton kokoaminen", "en": "Car assembly"}, "lists": [{"fi": "Työn alla", "en": "In progress"}], "cards": [[]], "position": {"x": 9, "y": 14, "z": 10}}
	}
	var cards = {"c1": {"id": "c1", "lines": {"fi": ["Näyttöyksikkö", "Asenna näytön kiinnitys", "Säädä korkeus", "Tarkista kuva"], "en": ["Display module", "Install monitor bracket", "Adjust height", "Verify picture"]}}}
	var entities = {
		"p1": {"id": "p1", "kind": "person", "name": {"fi": "Aino Järvinen", "en": "Aino Järvinen"}, "room_id": "r1", "floor": 1, "description": {"fi": "Ohjelmoija", "en": "Software developer"}},
		"f1": {"id": "f1", "kind": "furniture", "name": {"fi": "Sähköpöytä", "en": "Standing desk"}, "room_id": "r2", "floor": 4, "description": {"fi": "Leveä työpöytä", "en": "Wide workstation"}, "attributes": {"finish": {"fi": "Keltainen koivu", "en": "Yellow birch"}}}
	}
	var pocket = []
	var pocket_items = []
	var organizations = {"org_test": {"id": "org_test", "name": {"fi": "Anturitalo", "en": "Sensor building"}, "position": {"x": 80, "y": 0, "z": 0}}}
	var started_at = "2026-09-07T21:00:00"
	var future_records = {"extra1": {"id": "extra1", "name": {"fi": "Kattopuutarha", "en": "Roof garden"}, "nested": ["Harvinainen kasvi"]}}

class MinimalState extends RefCounted:
	var language = "fi"
	var cards = {"orphan": {"id": "orphan", "lines": {"fi": ["Koekortti", "Toinen", "Kolmas", "Neljäs"], "en": ["Sample card", "Second", "Third", "Fourth"]}}}

class MethodState extends SearchState:
	var actual_location: Dictionary = {}
	func get_card_location(_card_id: String) -> Dictionary:
		return actual_location

var failed = 0

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): push_error("Search test timed out"); quit(2))
	_run_tests.call_deferred()

func _run_tests() -> void:
	var state = SearchState.new()
	check(has_result(SearchIndex.search("ÄLYROBOTIT", state), "room", "r1"), "Finnish uppercase room name")
	check(has_result(SearchIndex.search("alyrobotit", state), "room", "r1"), "ASCII accent tolerant Finnish")
	check(has_result(SearchIndex.search("Smart robotics", state), "room", "r1"), "English data searched in Finnish UI")
	check(has_result(SearchIndex.search("403", state), "room", "r2"), "Room numbers searchable")
	check(has_result(SearchIndex.search("kerros 4", state), "furniture", "f1"), "Floor and furniture context")
	check(has_result(SearchIndex.search("yellow BIRCH", state), "furniture", "f1"), "Nested arbitrary entity data")
	check(has_result(SearchIndex.search("Aino jarvinen", state), "person", "p1"), "Fictional names searchable")
	check(has_result(SearchIndex.search("monitor bracket", state), "card", "c1"), "All card lines both languages")
	check(has_result(SearchIndex.search("nayttoyksikko 101", state), "card", "c1"), "AND query combines card and room context")
	check(not has_result(SearchIndex.search("nayttoyksikko 403", state), "card", "c1"), "AND rejects wrong location")
	check(has_result(SearchIndex.search("Harvinainen kasvi", state), "record", "extra1"), "Future collections included")
	check(has_result(SearchIndex.search("2026-09-07", state), "record", "session"), "Persistent session strings included")
	check(SearchIndex.search(" \t ", state).is_empty(), "Empty search")
	var result = get_result(SearchIndex.search("display module", state, "en"), "card", "c1")
	check(result.get("title", "") == "Display module", "Explicit result language")
	check(result.get("floor", 0) == 1 and result.get("room_id", "") == "r1", "Initial card location")
	check(result.get("position", {}).get("x", 0) == 2, "Card points at board position")
	state.boards.b1.cards[0].clear()
	state.boards.b2.cards[0].append("c1")
	result = get_result(SearchIndex.search("nayttoyksikko 403", state), "card", "c1")
	check(result.get("room_id", "") == "r2" and result.get("floor", 0) == 4, "Moving cards immediately updates search location")
	check(result.get("board_id", "") == "b2", "Destination board is current")
	state.boards.b2.cards[0].clear()
	state.pocket.append("c1")
	result = get_result(SearchIndex.search("display pocket", state), "card", "c1")
	check(result.get("pocket", false) and result.get("room_id", "bad") == "" and result.get("floor", -1) == 0, "Pocket cards have no stale room/floor")
	check(not result.has("position"), "Pocket cards have no stale 3D position")
	state.pocket.clear()
	state.boards.b2["swimlanes"] = [
		{"id": "lane_first", "title": {"fi": "Kehitys", "en": "Development"}, "lists": [{"fi": "Valmis", "en": "Done"}], "cards": [[]]},
		{"id": "lane_release", "title": {"fi": "Julkaisukierros", "en": "Release cycle"}, "lists": [{"fi": "Laaduntarkastus", "en": "Quality assurance"}], "cards": [["c1"]]}
	]
	check(has_result(SearchIndex.search("release cycle", state), "swimlane", "lane_release"), "Swimlane has its own searchable result")
	check(has_result(SearchIndex.search("quality assurance", state), "list", "b2:lane:1:list:0"), "List has its own searchable result")
	result = get_result(SearchIndex.search("display quality release", state), "card", "c1")
	check(result.get("lane", -1) == 1 and result.get("board_id", "") == "b2", "Cards inherit both language lane/list text and correct lane location")
	state.boards.b2.swimlanes[1].cards[0].clear()
	state.pocket_items.append({"id": "portable_lane", "kind": "swimlane", "title": {"fi": "Kannettava julkaisu", "en": "Portable release"}, "lists": [{"fi": "Laaduntarkastus", "en": "Quality assurance"}], "cards": [["c1"]]})
	result = get_result(SearchIndex.search("display portable pocket", state), "card", "c1")
	check(result.get("item_id", "") == "portable_lane" and result.get("pocket", false), "Cards nested inside pocket swimlane searchable at current location")
	check(result.get("floor", -1) == 0 and not result.has("position"), "Nested pocket cards have no stale world location")
	check(has_result(SearchIndex.search("portable pocket", state), "swimlane", "portable_lane"), "Pocket swimlane title searchable directly")
	state.pocket_items.clear()
	state.pocket_items.append({"id": "portable_list", "kind": "list", "title": {"fi": "Kannettava lista", "en": "Portable list"}, "cards": ["c1"]})
	check(get_result(SearchIndex.search("display portable", state), "card", "c1").get("item_id", "") == "portable_list", "Cards nested inside pocket list searchable")
	var authoritative_state = MethodState.new()
	authoritative_state.actual_location = {"pocket": true, "item_id": "portable_list", "kind": "list", "lane": 0, "list": 0, "index": 0}
	authoritative_state.pocket_items = state.pocket_items.duplicate(true)
	result = get_result(SearchIndex.search("display pocket", authoritative_state), "card", "c1")
	check(result.get("pocket", false) and result.get("item_id", "") == "portable_list", "Authoritative GameState location takes precedence over board references")
	state.pocket_items = [{"id": "portable_board", "kind": "board", "board_id": "b2", "title": state.boards.b2.title}]
	state.boards.b2.room_id = ""
	state.boards.b2.swimlanes[1].cards[0].append("c1")
	result = get_result(SearchIndex.search("display pocket", state), "card", "c1")
	check(result.get("pocket", false) and result.get("board_id", "") == "b2" and result.get("item_id", "") == "portable_board", "Whole pocket board retains real card graph")
	result = get_result(SearchIndex.search("car pocket", state), "board", "b2")
	check(result.get("pocket", false) and result.get("room_id", "bad") == "" and not result.has("position"), "Pocketed board has no stale room marker")
	check(has_result(SearchIndex.search("quality pocket", state), "list", "b2:lane:1:list:0"), "Lists inside whole pocket boards remain searchable")
	check(has_result(SearchIndex.search("Sensor building", state), "organization", "org_test"), "Organization/building names are first-class results")
	state.cards.c1["localized_details"] = {"fi": {"title": "Kortin täydellinen otsikko", "description": "Pitkä erillinen kuvaus"}, "en": {"title": "Complete detailed title", "description": "Full detailed description"}}
	result = get_result(SearchIndex.search("täydellinen", state), "card", "c1")
	check(result.get("title", "") == "Kortin täydellinen otsikko" and result.get("detail", "") == "Pitkä erillinen kuvaus", "Full card details displayed beyond the 3D preview")
	check(has_result(SearchIndex.search("sample", MinimalState.new()), "card", "orphan"), "Optional collections absent")
	for index in range(205):
		state.entities["many_%d" % index] = {"id": "many_%d" % index, "kind": "furniture", "name": "Paginationproof %d" % index}
	check(SearchIndex.search("Paginationproof", state).size() == 205, "No hidden result cap")
	var panel = SearchPanel.new()
	root.add_child(panel)
	panel.setup(state)
	panel.open("Paginationproof")
	check(panel.results.size() == 205 and panel.results_box.get_child_count() == 8, "Search UI renders first page and retains every result")
	check(panel.previous_button.disabled and not panel.next_button.disabled, "First page navigation state")
	panel.next_button.pressed.emit()
	check(panel.page == 1 and panel.results_box.get_child_count() == 8, "Next page displays next results")
	panel.page = 25
	panel._render_results()
	check(panel.results_box.get_child_count() == 5 and panel.next_button.disabled, "Last page exposes all remaining results")
	state.language = "en"
	panel.refresh_language()
	check(panel.count_label.text.begins_with("205 results"), "Search UI switches language without losing query")
	var activated: Array = []
	panel.navigation_requested.connect(func(value): activated.append(value))
	var first_row = panel.results_box.get_child(0)
	var activation_button = first_row if first_row is Button else first_row.get_child(0)
	activation_button.pressed.emit()
	check(activated.size() == 1 and activated[0].kind == "furniture", "Result activation emits navigation record")
	panel.free()
	var actual_state = root.get_node("GameState")
	actual_state.autosave_enabled = false
	actual_state.set_process(false)
	actual_state.register_organization({"id": "actual_org_a", "name": {"fi": "Anturirakennus", "en": "Sensor building"}})
	actual_state.register_organization({"id": "actual_org_b", "name": {"fi": "Ohjelmistorakennus", "en": "Software building"}})
	actual_state.register_room({"id": "actual_room_a", "organization_id": "actual_org_a", "floor": 0, "number": "101", "name": {"fi": "Työtila 101", "en": "Workspace 101"}})
	actual_state.register_room({"id": "actual_room_b", "organization_id": "actual_org_b", "floor": 0, "number": "101", "name": {"fi": "Työtila 101", "en": "Workspace 101"}})
	actual_state.register_entity({"id": "actual_person", "kind": "person", "room_id": "actual_room_b", "name": {"fi": "Henkilökoe", "en": "Person probe"}, "profile": {"title": {"fi": "Anturisuunnittelija", "en": "Sensor designer"}, "team_role": {"fi": "Arkkitehti", "en": "Architect"}, "expertise": {"fi": "Kalibrointitekniikka", "en": "Calibration technology"}, "qa": [{"id": "q_probe", "question": {"fi": "Miten robotti suunnataan?", "en": "How is the robot aligned?"}, "answer": {"fi": "Kohdista lasersäde", "en": "Align the laser beam"}}]}})
	check(has_result(SearchIndex.search("calibration technology", actual_state), "person", "actual_person"), "Actual GameState nested expertise searchable cross language")
	check(has_result(SearchIndex.search("laser beam", actual_state), "person", "actual_person"), "Actual GameState nested Q&A searchable")
	result = get_result(SearchIndex.search("Anturisuunnittelija", actual_state), "person", "actual_person")
	check(result.get("organization_id", "") == "actual_org_b" and result.get("location", "").contains("Ohjelmistorakennus"), "Actual person result includes correct organization context")
	var room_a = get_result(SearchIndex.search("101", actual_state), "room", "actual_room_a")
	var room_b = get_result(SearchIndex.search("101", actual_state), "room", "actual_room_b")
	check(room_a.get("organization_name", "") != room_b.get("organization_name", "") and room_a.get("location", "") != room_b.get("location", ""), "Duplicate workspace numbers disambiguated by building name")
	check(has_result(SearchIndex.search("Software 101", actual_state), "room", "actual_room_b") and not has_result(SearchIndex.search("Software 101", actual_state), "room", "actual_room_a"), "Organization and workspace terms combine across languages")
	check(actual_state.edit_person_profile("actual_person", {"expertise": "Ainutlaatuinen muokattu osaaminen"}, "fi"), "Actual profile edit succeeds")
	check(has_result(SearchIndex.search("Ainutlaatuinen muokattu", actual_state), "person", "actual_person"), "Edited person profile immediately searchable")
	check(actual_state.delete_person("actual_person"), "Actual soft-delete succeeds")
	check(not has_result(SearchIndex.search("Henkilökoe", actual_state), "person", "actual_person") and not has_result(SearchIndex.search("laser beam", actual_state), "person", "actual_person"), "Soft-deleted people absent from name and Q&A search")
	check(actual_state.entities.has("actual_person") and actual_state.entities.actual_person.deleted, "Deleted person history preserved in actual database state")
	if failed == 0:
		print("SEARCH TESTS PASSED: bilingual recursive fields, AND terms, dynamic locations, optional schemas, 205-result UI pagination and activation.")
	quit(0 if failed == 0 else 1)

func has_result(results: Array, kind: String, id: String) -> bool:
	return not get_result(results, kind, id).is_empty()

func get_result(results: Array, kind: String, id: String) -> Dictionary:
	for result in results:
		if result.kind == kind and result.id == id:
			return result
	return {}

func check(condition: bool, description: String) -> void:
	if not condition:
		failed += 1
		push_error("SEARCH FAILED: " + description)
