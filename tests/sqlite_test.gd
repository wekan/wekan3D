extends SceneTree
## redot --headless --path . --script res://tests/sqlite_test.gd
## Uses disposable scratch databases; never opens the actual player's save.

const Store = preload("res://scripts/core/sqlite_store.gd")
var checks: int = 0
var failures: int = 0
var test_directory: String


func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("_run")


func _run() -> void:
	test_directory = ProjectSettings.globalize_path("res://").path_join(".test_tmp/sqlite_%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)])
	_expect(DirAccess.make_dir_recursive_absolute(test_directory) == OK, "create isolated scratch directory")
	var database_file = test_directory.path_join("roundtrip.sqlite")
	var store = Store.new(database_file)
	_expect(not store.database_exists(), "missing database detected before first save")
	var opened = store.open_database()
	_expect(opened.ok and not opened.exists and store.is_new_database, "first run creates SQLite schema")
	_expect(store.path == database_file, "constructor override preserved")
	var original = _fixture()
	var first_save = store.write_snapshot(original)
	_expect(first_save, "write full first-run defaults: " + store.last_error)
	if not first_save:
		store.close_database()
		quit(1)
		return
	_expect(store.integrity_check(), "SQLite integrity and foreign-key checks")
	var header = FileAccess.open(database_file, FileAccess.READ)
	_expect(header != null and header.get_buffer(15).get_string_from_ascii() == "SQLite format 3" and header.get_8() == 0, "actual SQLite file signature")
	if header != null:
		header.close()
	var loaded = store.read_snapshot()
	_expect(_same_json(loaded, original), "exact localized metadata and nested-container reload: " + store.last_error)
	for table in Store.TABLES:
		_expect(store._query("SELECT COUNT(*) AS amount FROM " + table), "real SQL table exists: " + table)
	_expect(store._query("SELECT COUNT(*) AS amount FROM card_locations"), "query all card ownership")
	_expect(int(store._rows()[0].amount) == 10, "all ten cards have normalized ownership rows")
	_expect(store._query("SELECT COUNT(*) AS amount FROM swimlanes"), "query board and pocket swimlanes")
	_expect(int(store._rows()[0].amount) == 5, "all board and pocket lanes stored")
	_expect(store._query("SELECT COUNT(*) AS amount FROM lists"), "query varying lane lists")
	_expect(int(store._rows()[0].amount) == 10, "all ten dynamic lists stored")
	_expect(store._query("SELECT board_id,pocket_item_id,in_pocket FROM card_locations WHERE card_id = ?", ["d"]), "query card inside carried whole board")
	var carried_board_card = store._rows()[0]
	_expect(carried_board_card.board_id == "board2" and carried_board_card.pocket_item_id == "carried_board" and int(carried_board_card.in_pocket) == 1, "whole-board pocket retains nested ownership")
	_expect(store._query("SELECT COUNT(*) AS amount FROM organizations"), "query actual organization records")
	_expect(int(store._rows()[0].amount) == 1, "building organization is a real SQL row")
	_expect(store._query("SELECT title,description,boardId,swimlaneId,listId FROM cards WHERE id = ?", ["a"]), "query projected source-model card fields")
	var projected = store._rows()[0]
	_expect(projected.title == "Tehtävä a" and projected.description == "Suomenkielinen kuvaus" and projected.boardId == "board", "source-model title, description and ownership are real SQL fields")
	_expect(store._query("SELECT COUNT(*) AS amount FROM workspaces"), "query workspace model table")
	_expect(int(store._rows()[0].amount) == 1, "office room projected as workspace")
	_expect(store._query("SELECT orgDisplayName FROM org WHERE _id = ?", ["org_main"]), "query source-model organization")
	_expect(store._rows()[0].orgDisplayName == "Päärakennus", "building name projected into organization model")
	# A database-enforced rejection happens after DELETE statements. The previous
	# complete snapshot must remain intact when the transaction rolls back.
	_expect(store._query("CREATE TRIGGER reject_test_card BEFORE INSERT ON cards WHEN NEW.id = 'a' BEGIN SELECT RAISE(ABORT, 'test rollback'); END"), "install transaction fault")
	var edited = original.duplicate(true)
	edited.rooms.room.name.fi = "Muokattu huone"
	edited.cards.a.lines.en[0] = "A changed task"
	_expect(not store.write_snapshot(edited), "SQL write failure reported")
	_expect(not store.last_error.is_empty(), "write error retained")
	_expect(_same_json(store.read_snapshot(), original), "failed save rolls back every table")
	_expect(store._query("DROP TRIGGER reject_test_card"), "remove transaction fault")
	_expect(store._query("CREATE TRIGGER reject_test_projection BEFORE UPDATE ON cards WHEN NEW._id = 'a' BEGIN SELECT RAISE(ABORT, 'test projection rollback'); END"), "install model-projection fault")
	_expect(not store.write_snapshot(edited), "model projection failure reported")
	_expect(_same_json(store.read_snapshot(), original), "model-projection failure rolls back base and source tables together")
	_expect(store._query("DROP TRIGGER reject_test_projection"), "remove model-projection fault")
	_expect(store.write_snapshot(edited), "later healthy save succeeds")
	store.close_database()
	var reopened = Store.new(database_file)
	var reopen_result = reopened.open_database()
	_expect(reopen_result.ok and reopen_result.exists and not reopened.is_new_database, "existing SQLite game reopened")
	_expect(_same_json(reopened.read_snapshot(), edited), "existing valid game never resets defaults")
	# Corrupt ownership and JSON are rejected on read, without repairing/resetting.
	_expect(reopened._query("UPDATE card_locations SET position = ? WHERE card_id = ?", [99, "a"]), "inject inconsistent ownership")
	_expect(reopened.read_snapshot().is_empty() and not reopened.last_error.is_empty(), "ownership inconsistency rejected")
	_expect(reopened._query("SELECT position FROM card_locations WHERE card_id = ?", ["a"]), "inspect unchanged bad ownership")
	_expect(int(reopened._rows()[0].position) == 99, "failed read never silently repairs data")
	_expect(reopened.write_snapshot(edited), "explicit known-good replacement succeeds")
	_expect(reopened._query("UPDATE cards SET data_json = ? WHERE id = ?", ["{invalid-json", "a"]), "inject damaged payload")
	_expect(reopened.read_snapshot().is_empty() and not reopened.last_error.is_empty(), "JSON read failure returned")
	reopened.close_database()
	var corrupt_file = test_directory.path_join("corrupt.sqlite")
	var bad_file = FileAccess.open(corrupt_file, FileAccess.WRITE)
	bad_file.store_string("This is not SQLite; preserve me.")
	bad_file.close()
	var corrupt_store = Store.new(corrupt_file)
	_expect(not corrupt_store.open_database().ok, "non-SQLite existing file rejected")
	_expect(FileAccess.get_file_as_string(corrupt_file) == "This is not SQLite; preserve me.", "corrupt existing file untouched")
	var fallback = test_directory.path_join("fallback.sqlite")
	var paths = Store.new()
	_expect(paths.select_database_path(test_directory, fallback, 0) == test_directory.path_join(Store.FILE_NAME), "writable export saves beside executable")
	_expect(paths.select_database_path("/proc/officegame_unwritable_test", fallback, 0) == fallback, "unwritable export uses user-data fallback")
	_expect(paths.select_database_path(test_directory, fallback, 1) == fallback, "editor always uses user-data location")
	# Data-provided quotes and SQL fragments remain opaque text via bindings.
	var escaped_store = Store.new(test_directory.path_join("bindings.sqlite"))
	_expect(escaped_store.write_snapshot(original), "bound values include quotes and SQL punctuation")
	_expect(escaped_store._query("SELECT data_json FROM entities WHERE id = ?", ["person"]), "query localized person metadata")
	_expect("DROP TABLE" in str(escaped_store._rows()[0].data_json), "SQL-like text roundtrips as data")
	escaped_store.close_database()
	# Clean only files created inside this process's own test folder.
	for filename in DirAccess.get_files_at(test_directory):
		DirAccess.remove_absolute(test_directory.path_join(filename))
	DirAccess.remove_absolute(test_directory)
	print("SQLite persistence: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _fixture() -> Dictionary:
	var names = [{"fi": "Ideat", "en": "Ideas"}, {"fi": "Valmis", "en": "Done"}]
	var lane_one = {"id": "lane_a", "title": {"fi": "Rakennus", "en": "Build"}, "lists": [names[0], names[1], names[0], names[1]], "cards": [["a"], ["b"], ["c"], []]}
	lane_one["details"] = {"sort": 1, "estimate": 2.5}
	var lane_two = {"id": "lane_b", "title": {"fi": "Testaus", "en": "Testing"}, "lists": names.duplicate(true), "cards": [["e"], []]}
	var lane_three = {"id": "lane_c", "title": {"fi": "Julkaisu", "en": "Release"}, "lists": [names[1]], "cards": [["d"]]}
	var board_one = {"id": "board", "room_id": "room", "topic": 0, "title": {"fi": "Robotin kokoaminen", "en": "Robot assembly"}, "swimlanes": [lane_one, lane_two], "lists": lane_one.lists, "cards": lane_one.cards}
	var board_two = {"id": "board2", "room_id": "", "slot_id": "", "topic": 1, "title": {"fi": "Julkaisutaulu", "en": "Release board"}, "swimlanes": [lane_three], "lists": lane_three.lists, "cards": lane_three.cards}
	var card_data: Dictionary = {}
	for identifier in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j"]:
		card_data[identifier] = {"id": identifier, "topic": 0, "lines": {"fi": ["Tehtävä " + identifier, "Tarkista osat", "Kokoa robotti", "Testaa liike"], "en": ["Task " + identifier, "Check the parts", "Assemble robot", "Test movement"]}, "details": {"custom": "säilytä kaikki", "estimate": 12.5}, "localized_details": {"fi": {"description": "Suomenkielinen kuvaus"}, "en": {"description": "English description"}}, "related": {"comments": [{"text": "Test note"}]}}
	return {
		"version": 2, "catalog_version": 1, "language": "fi", "started_at": "2026-09-08T01:02:03", "elapsed_seconds": 123.125,
		"visited_rooms": {"room": true},
		"organizations": {"org_main": {"id": "org_main", "name": {"fi": "Päärakennus", "en": "Main building"}, "building_index": 0, "position": {"x": 0, "y": 0, "z": 0}}},
		"board_slots": {"slot": {"id": "slot", "room_id": "room", "board_id": "board", "position": {"x": -9, "y": 2.05, "z": -11.7}, "yaw": 0}},
		"rooms": {"room": {"id": "room", "floor": 1, "number": "101", "name": {"fi": "Ääkkösten huone", "en": "Developer's office"}, "position": {"x": 1.25, "y": 0.0, "z": -6.5}}},
		"entities": {"person": {"id": "person", "room_id": "room", "kind": "person", "name": {"fi": "Liisa", "en": "Lisa"}, "description": {"fi": "Testiteksti: '; DROP TABLE cards; --", "en": "Programmer's desk"}, "position": {"x": 1.0, "y": 0.0, "z": 2.0}, "custom_extra": {"chair": "blue"}}},
		"boards": {"board": board_one, "board2": board_two}, "cards": card_data, "pocket": ["f"],
		"pocket_items": [{"id": "carried_list", "kind": "list", "title": {"fi": "Kuljetettava lista", "en": "Carried list"}, "cards": ["g", "h"]}, {"id": "carried_lane", "kind": "swimlane", "title": {"fi": "Kuljetettava uimarata", "en": "Carried swimlane"}, "lists": names.duplicate(true), "cards": [["i"], ["j"]]}, {"id": "carried_board", "kind": "board", "board_id": "board2", "title": board_two.title}],
		"unknown_future_key": {"retain": true}
	}


func _same_json(first, second) -> bool:
	return JSON.stringify(JSON.parse_string(JSON.stringify(first)), "", true) == JSON.stringify(JSON.parse_string(JSON.stringify(second)), "", true)


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SQLite test failed: " + label)
