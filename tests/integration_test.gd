extends SceneTree
## Real composed-scene integration, isolated SQLite DB, actual 3D picking and UI.
## Run: redot --headless --path . --script res://tests/integration_test.gd
const BoardCanvas = preload("res://scripts/kanban/board_canvas.gd")
const Board3D = preload("res://scripts/kanban/board_3d.gd")
const SearchIndex = preload("res://scripts/core/search_index.gd")
var game
var state
var checks: int = 0
var failures: Array = []
var metrics: Dictionary = {}
var test_directory: String = ""
var cold_reopen: bool = false

func _initialize() -> void:
	test_directory = "/tmp/kanban_integration_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--reopen="):
			cold_reopen = true
			test_directory = str(argument).trim_prefix("--reopen=")
	DirAccess.make_dir_recursive_absolute(test_directory)
	OS.set_environment("OFFICEGAME_DATA_DIR", test_directory)
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	state = root.get_node("GameState")
	state.set_process(false)
	state._store.path = test_directory.path_join("officegame.sqlite")
	var started = Time.get_ticks_usec()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	metrics.initial_boot_ms = (Time.get_ticks_usec() - started) / 1000.0
	_freeze()
	await process_frame
	await physics_frame
	if cold_reopen:
		await _run_reopen()
		return
	check(game.ready_to_play, "composition root ready")
	check(state.last_storage_error.is_empty(), "initial SQLite write succeeded: " + state.last_storage_error)
	check(state.autosave_enabled, "complete defaults enable immediate persistence")
	check(state.database_exists(), "first run creates SQLite database")
	check(state.database_path == test_directory.path_join("officegame.sqlite"), "database isolated from real user data")
	check(game.worlds.size() == 1 and state.organizations.size() == 1, "one default organization/building")
	check(game.all_rooms.size() == 16 and state.rooms.size() == 16, "16 real and stored office workspaces")
	check(game.board_nodes.size() == 64 and state.boards.size() == 64, "64 physical and stored boards")
	check(state.cards.size() == 1024, "1024 default bilingual cards")
	check(game.npcs.size() == 34 and _people_count() == 34, "34 actual and stored fictional people")
	var floors: Dictionary = {}
	for room in game.all_rooms:
		floors[int(room.floor)] = int(floors.get(int(room.floor), 0)) + 1
		check(state.rooms[room.id].workspace_id == room.id, "room is its workspace")
		check(int(state.rooms[room.id].floor) == int(room.floor) + 1, "stored floor is one-based")
	check(floors == {0: 4, 1: 4, 2: 4, 3: 4}, "all four floors have four rooms")
	check(game.player.position.is_equal_approx(game.world.spawn_position), "player starts at reception spawn")
	check(game.npcs[0].receptionist and game.npcs[1].receptionist, "two receptionists instantiated")
	check(state.entities[game.npcs[0].entity_id].receptionist and state.entities[game.npcs[0].entity_id].female, "receptionist role and appearance persisted")
	check(state.entities[game.npcs[0].entity_id].profile.qa.size() >= 5, "default receptionist has bilingual QA")
	check(state.validate_state().is_empty(), "initial graph has exactly-once card ownership")
	_check_sql_counts(1, 16, 64, 1024, 34)
	check(state.load_game(), "actual initial SQLite reload succeeds: " + state.last_error)
	_freeze()
	check(game.worlds.size() == 1 and game.npcs.size() == 34, "reload does not duplicate scene objects")

	# A physical ray through the camera hits a real card; a short click opens all fields.
	var first_slot: String = game.board_nodes.keys()[0]
	var first_board = game.board_nodes[first_slot]
	var point = _world_card_center(first_board, 0, 0)
	var front = first_board.global_basis.z.normalized()
	game.player.position = point + front * 0.8 - Vector3(0, 1.65, 0)
	game.player.camera.look_at(point, Vector3.UP)
	game.player.using_controller = true
	await physics_frame
	var target: Dictionary = game._target(true)
	check(target.get("kind", "") == "board", "camera ray hits actual wall board")
	check(not str(target.get("card_id", "")).is_empty(), "physical ray maps to an actual card")
	if not str(target.get("card_id", "")).is_empty():
		var click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(640, 360)
		game._unhandled_input(click)
		check(game.pending_card == target.card_id, "mouse-down selects ray-target card")
		click.pressed = false
		game._input(click)
		await process_frame
		check(game.ui.modal_kind == "editor", "short 3D click opens full editor")
		var editor = _find_script(game.ui, "res://scripts/ui/card_editor.gd")
		check(editor != null, "schema-driven card editor is instantiated")
		if editor != null:
			check(editor.card_id == target.card_id and editor.field_controls.size() >= 53, "full source card fields are represented")
	game.ui.close_modal()
	_freeze()

	# Whole-board pocketing updates actual rendered slots, and occupied placement swaps safely.
	var second_slot: String = game.board_nodes.keys()[1]
	var original_board_id: String = state.board_slots[first_slot].board_id
	var displaced_board_id: String = state.board_slots[second_slot].board_id
	var card_id: String = state.boards[original_board_id].swimlanes[0].cards[0][0]
	started = Time.get_ticks_usec()
	var carried = state.pocket_board(original_board_id)
	metrics.single_board_mutation_ms = (Time.get_ticks_usec() - started) / 1000.0
	check(not carried.is_empty(), "pocket board commits immediately")
	check(game.board_nodes[first_slot].board_id.is_empty(), "source physical wall becomes empty immediately")
	check(state.get_card_location(card_id).get("item_id", "") == carried, "board contents become nested pocket ownership")
	check(state.place_pocket_board(carried, second_slot), "place into occupied actual wall slot")
	check(game.board_nodes[second_slot].board_id == original_board_id, "physical destination shows carried board")
	check(state.boards[displaced_board_id].room_id.is_empty(), "displaced board safely remains in pocket")
	check(state.cards.size() == 1024 and state.validate_state().is_empty(), "wall swap loses or duplicates no card")

	# Organization signal constructs a complete second 3D world before SQLite commits.
	started = Time.get_ticks_usec()
	var second_org = state.create_organization("Integraation toinen talo")
	metrics.second_building_ms = (Time.get_ticks_usec() - started) / 1000.0
	_freeze()
	await process_frame
	check(not second_org.is_empty(), "create second organization: " + state.last_error)
	check(game.worlds.size() == 2 and state.organizations.size() == 2, "two actual organization buildings")
	check(game.all_rooms.size() == 32 and state.rooms.size() == 32, "second building adds 16 workspaces")
	check(game.board_nodes.size() == 128 and state.boards.size() == 128, "second building adds 64 physical boards")
	check(state.cards.size() == 2048, "second building adds 1024 cards")
	check(game.npcs.size() == 68 and _people_count() == 68, "second building adds 34 real people")
	check(game.worlds[second_org].position.is_equal_approx(Vector3(60, 0, 0)), "second building located 60 meters away")
	_check_sql_counts(2, 32, 128, 2048, 68)
	var destination_slot = ""
	for slot_id in state.board_slots:
		var room_id: String = state.board_slots[slot_id].room_id
		if state.rooms[room_id].organization_id == second_org:
			destination_slot = slot_id
			break
	carried = state.pocket_board(original_board_id)
	check(state.place_pocket_board(carried, destination_slot), "whole board can cross organization buildings")
	check(state.boards[original_board_id].organization_id == second_org, "carried board organization changes to destination")
	check(state.boards[original_board_id].workspace_id == state.board_slots[destination_slot].room_id, "carried board workspace updates")
	check(game.board_nodes[destination_slot].board_id == original_board_id, "second building physical wall shows imported board")
	check(state.load_game(), "multi-building full SQLite load succeeds: " + state.last_error)
	_freeze()
	check(state.boards[original_board_id].slot_id == destination_slot, "cross-organization board slot survives reload")
	check(game.board_nodes[destination_slot].board_id == original_board_id, "loaded wall occupancy remains correct")

	# Name/profile changes are live, searchable, navigable and usable in remote UI.
	var room_id: String = state.board_slots[destination_slot].room_id
	var new_person = state.create_person(room_id, "Integraatio Helmi", true)
	_freeze()
	check(not new_person.is_empty(), "create person in second workspace")
	check(game.npcs.size() == 69 and _find_person(new_person) != null, "entities_changed spawns actual new NPC")
	check(state.edit_person_profile(new_person, {"title": "Robotin rakentaja", "qa": [{"question": "Mikä integraatio?", "answer": "Testaamme tallennetun rakennuksen."}]}, "fi"), "editable live person QA")
	var results = SearchIndex.search("Integraatio Helmi", state, "fi")
	var person_result: Dictionary = {}
	for result in results:
		if str(result.get("id", "")) == new_person and result.get("kind", "") == "person":
			person_result = result
	check(not person_result.is_empty(), "full text search finds newly created person")
	if not person_result.is_empty():
		game._navigate_to_result(person_result)
		check(is_instance_valid(game.navigation_marker), "search navigation creates actual marker")
		check(game.navigation_target.id == new_person, "navigation tracks selected person identity")
	game._open_remote_call(new_person)
	await process_frame
	check(game.ui.modal_kind == "remote" and game.ui.remote_entity_id == new_person, "root opens remote UI for real NPC")
	var remote = _find_script(game.ui, "res://scripts/ui/remote_call.gd")
	check(remote != null, "remote call panel is instantiated")
	if remote != null:
		check(remote.video != null and remote.video_camera != null, "remote call has actual viewport camera")
	game.ui.close_modal()
	_freeze()
	check(state.delete_person(new_person), "person soft-delete saves")
	check(_find_person(new_person) == null and game.npcs.size() == 68, "deleted person disappears from scene")
	check(state.entities[new_person].deleted, "deleted identity remains in persistence model")
	results = SearchIndex.search("Integraatio Helmi", state, "fi")
	var found_deleted = false
	for result in results:
		if str(result.get("id", "")) == new_person: found_deleted = true
	check(not found_deleted, "deleted person excluded from search")

	# Failure after a third building was synchronously constructed must remove ALL
	# speculative scene objects as core restores its complete graph and defaults.
	var before_orgs = state.organizations.keys().duplicate()
	var before_rooms = game.all_rooms.size()
	state.storage_read_blocked = true
	started = Time.get_ticks_usec()
	var rejected = state.create_organization("This building must roll back")
	metrics.rejected_building_ms = (Time.get_ticks_usec() - started) / 1000.0
	state.storage_read_blocked = false
	_freeze()
	await process_frame
	await process_frame
	check(rejected.is_empty(), "save failure rejects organization creation")
	check(state.organizations.keys() == before_orgs and game.worlds.size() == 2, "failed organization leaves no phantom world")
	check(game.all_rooms.size() == before_rooms and game.board_nodes.size() == 128 and game.npcs.size() == 68, "rollback removes speculative rooms, boards and NPCs")
	var phantom = false
	for child in game.get_children():
		var org_id = str(child.get_meta("organization_id", ""))
		if not org_id.is_empty() and not state.organizations.has(org_id): phantom = true
	check(not phantom, "scene graph contains no orphan organization roots")
	check(state.validate_state().is_empty(), "final card ownership remains valid")
	check(state.save_game(), "database writable again after rollback")
	_check_sql_counts(2, 32, 128, 2048, 69)
	state.autosave_enabled = false
	game.queue_free()
	await process_frame
	state._store.close_database()
	# A separate engine process proves real restart reconstruction, with a fresh
	# autoload and no surviving scene caches from the mutation tests above.
	var output: Array = []
	var exit_code = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/integration_test.gd", "--", "--reopen=" + test_directory], output, true)
	for text_output in output:
		print(str(text_output))
	check(exit_code == 0, "independent process reconstructs saved multiple buildings")
	print("Integration metrics: " + JSON.stringify(metrics))
	print("Integration tests: %d checks, %d failures" % [checks, failures.size()])
	for suffix in ["", "-wal", "-shm", "-journal"]:
		DirAccess.remove_absolute(test_directory.path_join("officegame.sqlite" + suffix))
	DirAccess.remove_absolute(test_directory)
	quit(0 if failures.is_empty() else 1)

func _run_reopen() -> void:
	check(game.ready_to_play and state.last_storage_error.is_empty(), "cold restart loads saved database")
	check(state.autosave_enabled, "cold restart permits future mutations")
	check(game.worlds.size() == 2 and state.organizations.size() == 2, "cold restart reconstructs two buildings")
	check(game.all_rooms.size() == 32 and state.rooms.size() == 32, "cold restart reconstructs workspaces")
	check(game.board_nodes.size() == 128 and state.boards.size() == 128, "cold restart reconstructs all physical wall slots")
	check(state.cards.size() == 2048, "cold restart preserves full card data")
	check(game.npcs.size() == 68 and _people_count() == 68, "cold restart retains live people and excludes deleted person")
	var deleted_found = false
	for entity in state.entities.values():
		if entity.get("kind", "") == "person" and entity.get("deleted", false):
			deleted_found = true
			check(_find_person(entity.id) == null, "cold restart does not respawn soft-deleted person")
	check(deleted_found, "soft-delete history survives cold restart")
	var occupancy_matches = true
	for slot_id in state.board_slots:
		if game.board_nodes[slot_id].board_id != state.board_slots[slot_id].board_id:
			occupancy_matches = false
	check(occupancy_matches, "cold restart renders actual saved wall occupants")
	check(state.pocket_items.filter(func(item): return item.kind == "board").size() == 2, "cold restart preserves displaced whole boards in pocket")
	check(state.validate_state().is_empty(), "cold restart ownership valid")
	print("Cold restart integration: %d checks, %d failures" % [checks, failures.size()])
	state.autosave_enabled = false
	game.queue_free()
	await process_frame
	state._store.close_database()
	quit(0 if failures.is_empty() else 1)

func _freeze() -> void:
	game.set_process(false)
	game.player.set_process(false)
	game.player.set_physics_process(false)
	for npc in game.npcs:
		if is_instance_valid(npc):
			npc.set_process(false)
			npc.set_physics_process(false)

func _people_count() -> int:
	var count = 0
	for entity in state.entities.values():
		if entity.get("kind", "") == "person" and not entity.get("deleted", false): count += 1
	return count

func _find_person(id: String):
	for npc in game.npcs:
		if is_instance_valid(npc) and npc.entity_id == id: return npc
	return null

func _find_script(node: Node, path: String):
	if node.get_script() != null and node.get_script().resource_path == path: return node
	for child in node.get_children():
		var found = _find_script(child, path)
		if found != null: return found
	return null

func _world_card_center(board: Node3D, column: int, row: int) -> Vector3:
	var pixel = BoardCanvas.card_rect(column, row).get_center()
	return board.to_global(Vector3((pixel.x / BoardCanvas.CANVAS_SIZE.x - 0.5) * Board3D.BOARD_WIDTH, (0.5 - pixel.y / BoardCanvas.CANVAS_SIZE.y) * Board3D.BOARD_HEIGHT, 0.005))

func _check_sql_counts(orgs: int, workspaces: int, boards: int, cards: int, people: int) -> void:
	var db = ClassDB.instantiate("SQLite")
	db.path = state.database_path
	db.default_extension = ""
	db.read_only = true
	if not db.open_db():
		check(false, "independent SQLite reader opens complete database")
		return
	for record in [["organizations", orgs], ["workspaces", workspaces], ["boards", boards], ["cards", cards]]:
		var success = db.query("SELECT COUNT(*) AS count FROM " + str(record[0]))
		check(success and int(db.query_result[0].count) == int(record[1]), "actual SQL " + str(record[0]) + " row count")
	var success = db.query("SELECT COUNT(*) AS count FROM entities WHERE kind='person'")
	check(success and int(db.query_result[0].count) == people, "actual SQL people include retained soft-deletes")
	check(db.query("PRAGMA integrity_check") and str(db.query_result[0].values()[0]) == "ok", "actual SQLite integrity check")
	db.close_db()
