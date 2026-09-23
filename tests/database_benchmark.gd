extends SceneTree
## Representative real GameState snapshot, disposable SQLite file, no player save.
const WekanSchema = preload("res://scripts/core/wekan_schema.gd")

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): push_error("Database benchmark timeout"); quit(2))
	_run.call_deferred()

func _run() -> void:
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	state.set_process(false)
	var unique = "%d_%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
	var path = ProjectSettings.globalize_path("res://.test_tmp/database_benchmark_" + unique + ".sqlite")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	state._store.path = path
	state.register_organization({"id": "bench_org", "name": {"fi": "Vertailutalo", "en": "Benchmark office"}})
	for floor_index in range(4):
		for room_index in range(4):
			var room_id = "bench_room_%d_%d" % [floor_index, room_index]
			state.register_room({"id": room_id, "organization_id": "bench_org", "floor": floor_index, "center": Vector3(room_index * 9, floor_index * 4, 0)})
			for wall in range(4):
				var topic = floor_index * 16 + room_index * 4 + wall
				state.ensure_board("bench_board_%d" % topic, room_id, topic)
			for person_index in range(2):
				state.register_entity({"id": room_id + "_person_%d" % person_index, "room_id": room_id, "kind": "person", "name": {"fi": "Aino Malli %d" % person_index, "en": "Aino Example %d" % person_index}, "floor": floor_index + 1, "topic": room_index})
			for furniture_index in range(8):
				state.register_entity({"id": room_id + "_desk_%d" % furniture_index, "room_id": room_id, "kind": "furniture", "name": {"fi": "Sähköpöytä %d" % furniture_index, "en": "Standing desk %d" % furniture_index}, "floor": floor_index + 1})
	if state.cards.size() != 1024:
		push_error("Benchmark expected exactly 1024 actual cards")
		quit(1)
		return
	var start = Time.get_ticks_usec()
	if not state.save_game():
		push_error(state.last_error)
		quit(1)
		return
	var first_save_ms = (Time.get_ticks_usec() - start) / 1000.0
	if not state._store.integrity_check():
		push_error("Benchmark first-save integrity: " + state._store.last_error)
		quit(1)
		return
	var samples: Array = []
	for index in range(3):
		state.elapsed_seconds += 1.0
		start = Time.get_ticks_usec()
		if not state.save_game():
			push_error(state.last_error)
			quit(1)
			return
		samples.append((Time.get_ticks_usec() - start) / 1000.0)
	var sorted_samples = samples.duplicate()
	sorted_samples.sort()
	start = Time.get_ticks_usec()
	var errors = state._validate_save(state._snapshot())
	var validation_ms = (Time.get_ticks_usec() - start) / 1000.0
	if not errors.is_empty():
		push_error(str(errors))
		quit(1)
		return
	var projection = WekanSchema.new()
	state._store._query("BEGIN IMMEDIATE")
	start = Time.get_ticks_usec()
	if not projection.sync_snapshot(state._store._db, state._snapshot()):
		push_error(projection.last_error)
		quit(1)
		return
	var projection_ms = (Time.get_ticks_usec() - start) / 1000.0
	state._store._query("ROLLBACK")
	var file = FileAccess.open(path, FileAccess.READ)
	var bytes = file.get_length()
	file.close()
	print(JSON.stringify({"benchmark": "actual_game_state_full_sqlite_save", "rooms": state.rooms.size(), "boards": state.boards.size(), "cards": state.cards.size(), "entities": state.entities.size(), "first_save_ms": first_save_ms, "existing_save_ms": samples, "median_existing_save_ms": sorted_samples[1], "validation_only_ms": validation_ms, "projection_only_ms": projection_ms, "sqlite_bytes": bytes, "includes": "validation, schema augmentation, normalized graph, full model-field projection, bilingual translations, transaction commit"}))
	state._store.close_database()
	DirAccess.remove_absolute(path)
	quit(0)
