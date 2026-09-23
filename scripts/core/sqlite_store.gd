extends RefCounted
## Real SQLite persistence. SQL values are always bound parameters. A snapshot is
## replaced in one transaction; failed reads/writes never reset an existing game.

const SCHEMA_VERSION = 2
const WekanSchema = preload("res://scripts/core/wekan_schema.gd")
const FILE_NAME = "officegame.sqlite"
const USER_PATH = "user://" + FILE_NAME
const TABLES = ["organizations", "floors", "teams", "rooms", "boards", "swimlanes", "lists", "cards", "card_locations", "entities", "session", "pocket_items"]
const POCKET_KINDS = ["card", "list", "swimlane", "board", "entity", "building", "floor", "room"]
const OWNERSHIP_COLUMNS = {
	"swimlanes": "owner_key,id,board_id,pocket_item_id,ordinal,name_json,data_json",
	"lists": "owner_key,id,swimlane_id,ordinal,name_json,data_json",
	"card_locations": "card_id,owner_key,board_id,pocket_item_id,swimlane_id,list_id,position,in_pocket",
	"pocket_items": "id,kind,position,data_json"
}

var database_path: String = ""
var last_error: String = ""
var is_new_database: bool = false
var _db: Object = null
var _opened: bool = false
var _models = WekanSchema.new()
var _loaded_schema_version: int = SCHEMA_VERSION
var path: String:
	get:
		if database_path.is_empty():
			database_path = select_database_path()
		return database_path
	set(value):
		close_database()
		database_path = ProjectSettings.globalize_path(value)


func _init(override_path: String = "") -> void:
	if not override_path.is_empty():
		database_path = ProjectSettings.globalize_path(override_path)


func database_exists() -> bool:
	return FileAccess.file_exists(path)


func write_snapshot(snapshot: Dictionary) -> bool:
	return save_snapshot(snapshot)


func read_snapshot() -> Dictionary:
	return load_snapshot()


func open_database(override_path: String = "") -> Dictionary:
	close_database()
	last_error = ""
	is_new_database = false
	if not ClassDB.class_exists("SQLite"):
		last_error = "SQLite extension is unavailable. Enable the bundled godot-sqlite GDExtension."
		return _open_result(false, false)
	if override_path.is_empty() and database_path.is_empty():
		database_path = select_database_path()
	elif not override_path.is_empty():
		database_path = ProjectSettings.globalize_path(override_path)
	if database_path.is_empty():
		return _open_result(false, false)
	var existed = FileAccess.file_exists(database_path)
	_db = ClassDB.instantiate("SQLite")
	_db.set("path", database_path)
	_db.set("default_extension", "")
	_db.set("foreign_keys", true)
	_db.set("verbosity_level", 0)
	if not _db.call("open_db"):
		last_error = "Cannot open SQLite database: " + _database_error()
		_db = null
		return _open_result(false, existed)
	_opened = true
	if not _query("PRAGMA busy_timeout = 2500"):
		return _reject_open(existed)
	if existed:
		if not _validate_schema() or not integrity_check():
			return _reject_open(true)
		if _loaded_schema_version < SCHEMA_VERSION and not _migrate_spatial_schema():
			return _reject_open(true)
		if not _query("BEGIN IMMEDIATE"):
			return _reject_open(true)
		if not _models.ensure_tables(_db):
			last_error = _models.last_error
			_rollback()
			return _reject_open(true)
		if not _query("COMMIT"):
			_rollback()
			return _reject_open(true)
	else:
		if not _create_schema():
			return _reject_open(false)
		is_new_database = true
	last_error = ""
	return _open_result(true, existed)


func _open_result(ok: bool, existed: bool) -> Dictionary:
	return {"ok": ok, "exists": existed, "path": database_path, "error": last_error}


func _reject_open(existed: bool) -> Dictionary:
	var reason = last_error
	close_database()
	last_error = reason
	return _open_result(false, existed)


func close_database() -> void:
	if _db != null and _opened:
		_db.call("close_db")
	_db = null
	_opened = false


func select_database_path(executable_directory: String = "", user_path: String = "", editor_mode: int = -1) -> String:
	# Optional arguments let tests exercise the genuine exported-game fallback
	# without writing beside the editor or into the user's real save directory.
	var data_override = OS.get_environment("OFFICEGAME_DATA_DIR")
	if not data_override.is_empty() and executable_directory.is_empty() and user_path.is_empty():
		var override_directory = ProjectSettings.globalize_path(data_override)
		if DirAccess.make_dir_recursive_absolute(override_directory) != OK:
			last_error = "Cannot create the specified SQLite data directory."
			return ""
		return override_directory.path_join(FILE_NAME)
	var fallback = ProjectSettings.globalize_path(USER_PATH if user_path.is_empty() else user_path)
	var in_editor = OS.has_feature("editor") if editor_mode < 0 else editor_mode != 0
	if in_editor:
		return fallback
	var directory = OS.get_executable_path().get_base_dir() if executable_directory.is_empty() else executable_directory
	var candidate = directory.path_join(FILE_NAME)
	if _directory_is_writable(directory) and _existing_file_is_writable(candidate):
		return candidate
	if FileAccess.file_exists(candidate) and not _validate_existing_portable_database(candidate):
		return ""
	# Moving an installation to a protected directory must not discard its game.
	# Preserve an existing fallback; otherwise copy the portable database once.
	if FileAccess.file_exists(candidate) and not FileAccess.file_exists(fallback):
		var copy_error = DirAccess.copy_absolute(candidate, fallback)
		if copy_error != OK:
			last_error = "Cannot preserve the existing portable SQLite game in the writable save directory: " + str(copy_error)
			return ""
	return fallback


func _validate_existing_portable_database(candidate: String) -> bool:
	# Do not hide a corrupt portable save by selecting a different fallback file.
	# Read-only validation also avoids touching the protected installation.
	var reader = ClassDB.instantiate("SQLite")
	reader.set("path", candidate)
	reader.set("default_extension", "")
	reader.set("read_only", true)
	reader.set("verbosity_level", 0)
	var ok = bool(reader.call("open_db"))
	if ok:
		ok = bool(reader.call("query_with_bindings", "PRAGMA integrity_check", []))
	if ok:
		var rows: Array = reader.get("query_result")
		ok = rows.size() == 1 and str(rows[0].get("integrity_check", "")) == "ok"
	if ok:
		ok = bool(reader.call("query_with_bindings", "PRAGMA user_version", []))
	if ok:
		var rows: Array = reader.get("query_result")
		ok = rows.size() == 1 and int(rows[0].get("user_version", -1)) in [1, SCHEMA_VERSION]
	reader.call("close_db")
	if not ok:
		last_error = "The existing portable SQLite database cannot be read safely; no different game was loaded."
	return ok


func _directory_is_writable(directory: String) -> bool:
	if not DirAccess.dir_exists_absolute(directory):
		return false
	var probe_path = directory.path_join(".officegame_write_probe_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var probe = FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.store_8(1)
	probe.flush()
	var success = probe.get_error() == OK
	probe.close()
	var remove_error = DirAccess.remove_absolute(probe_path)
	return success and remove_error == OK


func _existing_file_is_writable(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	# READ_WRITE does not truncate or modify the contents.
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if file == null:
		return false
	file.close()
	return true


func _create_schema() -> bool:
	if not _query("BEGIN IMMEDIATE"):
		return false
	var statements = [
		"CREATE TABLE organizations (id TEXT PRIMARY KEY, name_json TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, in_pocket INTEGER NOT NULL DEFAULT 0, data_json TEXT NOT NULL)",
		"CREATE TABLE floors (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL REFERENCES organizations(id), number INTEGER NOT NULL, name_json TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, in_pocket INTEGER NOT NULL DEFAULT 0, data_json TEXT NOT NULL)",
		"CREATE TABLE rooms (id TEXT PRIMARY KEY, organization_id TEXT, floor_id TEXT, floor INTEGER NOT NULL, number TEXT NOT NULL, slot_index INTEGER NOT NULL DEFAULT 0, deleted INTEGER NOT NULL DEFAULT 0, in_pocket INTEGER NOT NULL DEFAULT 0, name_json TEXT NOT NULL, data_json TEXT NOT NULL)",
		"CREATE TABLE teams (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL REFERENCES organizations(id), room_id TEXT NOT NULL, name_json TEXT NOT NULL, data_json TEXT NOT NULL)",
		"CREATE TABLE boards (id TEXT PRIMARY KEY, room_id TEXT REFERENCES rooms(id), title_json TEXT NOT NULL, data_json TEXT NOT NULL)",
		"CREATE TABLE pocket_items (id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind IN ('card','list','swimlane','board','entity','building','floor','room')), position INTEGER NOT NULL CHECK(position >= 0), data_json TEXT NOT NULL, UNIQUE(kind,position))",
		"CREATE TABLE swimlanes (owner_key TEXT NOT NULL, id TEXT NOT NULL, board_id TEXT REFERENCES boards(id), pocket_item_id TEXT REFERENCES pocket_items(id), ordinal INTEGER NOT NULL CHECK(ordinal >= 0), name_json TEXT NOT NULL, data_json TEXT NOT NULL, PRIMARY KEY(owner_key,id), UNIQUE(owner_key,ordinal))",
		"CREATE TABLE lists (owner_key TEXT NOT NULL, id TEXT NOT NULL, swimlane_id TEXT NOT NULL, ordinal INTEGER NOT NULL CHECK(ordinal >= 0), name_json TEXT NOT NULL, data_json TEXT NOT NULL, PRIMARY KEY(owner_key,id), UNIQUE(owner_key,swimlane_id,ordinal), FOREIGN KEY(owner_key,swimlane_id) REFERENCES swimlanes(owner_key,id))",
		"CREATE TABLE cards (id TEXT PRIMARY KEY, lines_json TEXT NOT NULL, data_json TEXT NOT NULL)",
		"CREATE TABLE card_locations (card_id TEXT PRIMARY KEY REFERENCES cards(id), owner_key TEXT, board_id TEXT REFERENCES boards(id), pocket_item_id TEXT REFERENCES pocket_items(id), swimlane_id TEXT, list_id TEXT, position INTEGER NOT NULL CHECK(position >= 0), in_pocket INTEGER NOT NULL CHECK(in_pocket IN (0,1)), FOREIGN KEY(owner_key,swimlane_id) REFERENCES swimlanes(owner_key,id), FOREIGN KEY(owner_key,list_id) REFERENCES lists(owner_key,id), CHECK((in_pocket = 1 AND pocket_item_id IS NOT NULL) OR (in_pocket = 0 AND board_id IS NOT NULL AND pocket_item_id IS NULL AND owner_key IS NOT NULL)))",
		"CREATE UNIQUE INDEX card_cell_position ON card_locations(owner_key,swimlane_id,list_id,position) WHERE owner_key IS NOT NULL",
		"CREATE TABLE entities (id TEXT PRIMARY KEY, room_id TEXT NOT NULL, organization_id TEXT, team_id TEXT, kind TEXT NOT NULL, template TEXT, age_group TEXT, deleted INTEGER NOT NULL DEFAULT 0, in_pocket INTEGER NOT NULL DEFAULT 0, name_json TEXT NOT NULL, description_json TEXT NOT NULL, data_json TEXT NOT NULL)",
		"CREATE TABLE session (id INTEGER PRIMARY KEY CHECK(id = 1), schema_version INTEGER NOT NULL, data_json TEXT NOT NULL, saved_at TEXT NOT NULL)",
		"PRAGMA user_version = 2"
	]
	for statement in statements:
		if not _query(statement):
			return _rollback()
	if not _models.ensure_tables(_db):
		last_error = _models.last_error
		return _rollback()
	if not _query("COMMIT"):
		return _rollback()
	return true


func _validate_schema() -> bool:
	if not _query("PRAGMA user_version"):
		return false
	var version_rows = _rows()
	if version_rows.size() != 1 or int(version_rows[0].get("user_version", -1)) not in [1, SCHEMA_VERSION]:
		last_error = "Unsupported or uninitialized SQLite schema; the existing file was left unchanged."
		return false
	_loaded_schema_version = int(version_rows[0].user_version)
	if not _query("SELECT name FROM sqlite_master WHERE type = ?", ["table"]):
		return false
	var names: Array = []
	for row in _rows():
		names.append(str(row.name))
	for table in TABLES:
		if _loaded_schema_version == 1 and table in ["floors", "teams"]:
			continue
		if not names.has(table):
			last_error = "SQLite database is missing required table: " + table
			return false
	return true

func _migrate_spatial_schema() -> bool:
	# SQLite cannot widen an existing CHECK constraint with ALTER COLUMN. Replace
	# only the pocket table in one transaction; keep all documents and verify refs.
	if not _query("PRAGMA foreign_keys = OFF") or not _query("BEGIN IMMEDIATE"):
		_query("PRAGMA foreign_keys = ON")
		return false
	var statements = [
		"CREATE TABLE pocket_items_next (id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind IN ('card','list','swimlane','board','entity','building','floor','room')), position INTEGER NOT NULL CHECK(position >= 0), data_json TEXT NOT NULL, UNIQUE(kind,position))",
		"INSERT INTO pocket_items_next(id,kind,position,data_json) SELECT id,kind,position,data_json FROM pocket_items",
		"DROP TABLE pocket_items",
		"ALTER TABLE pocket_items_next RENAME TO pocket_items",
		"CREATE TABLE IF NOT EXISTS floors (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL REFERENCES organizations(id), number INTEGER NOT NULL, name_json TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, in_pocket INTEGER NOT NULL DEFAULT 0, data_json TEXT NOT NULL)",
		"CREATE TABLE IF NOT EXISTS teams (id TEXT PRIMARY KEY, organization_id TEXT NOT NULL REFERENCES organizations(id), room_id TEXT NOT NULL, name_json TEXT NOT NULL, data_json TEXT NOT NULL)"
	]
	for statement in statements:
		if not _query(statement):
			return _migration_failure()
	var additions = {
		"organizations": {"deleted": "INTEGER NOT NULL DEFAULT 0", "in_pocket": "INTEGER NOT NULL DEFAULT 0"},
		"rooms": {"organization_id": "TEXT", "floor_id": "TEXT", "slot_index": "INTEGER NOT NULL DEFAULT 0", "deleted": "INTEGER NOT NULL DEFAULT 0", "in_pocket": "INTEGER NOT NULL DEFAULT 0"},
		"entities": {"organization_id": "TEXT", "team_id": "TEXT", "template": "TEXT", "age_group": "TEXT", "deleted": "INTEGER NOT NULL DEFAULT 0", "in_pocket": "INTEGER NOT NULL DEFAULT 0"}
	}
	for table in additions:
		if not _query("PRAGMA table_info(" + table + ")"):
			return _migration_failure()
		var names: Array = []
		for row in _rows():
			names.append(str(row.name))
		for field in additions[table]:
			if not names.has(field) and not _query("ALTER TABLE " + table + " ADD COLUMN " + str(field) + " " + str(additions[table][field])):
				return _migration_failure()
	if not _models.ensure_tables(_db):
		last_error = _models.last_error
		return _migration_failure()
	if not _query("UPDATE session SET schema_version = ?", [SCHEMA_VERSION]) or not _query("PRAGMA user_version = 2") or not integrity_check():
		return _migration_failure()
	if not _query("COMMIT"):
		return _migration_failure()
	_query("PRAGMA foreign_keys = ON")
	_loaded_schema_version = SCHEMA_VERSION
	return true

func _migration_failure() -> bool:
	var reason = last_error
	_query("ROLLBACK")
	_query("PRAGMA foreign_keys = ON")
	last_error = reason
	return false


func integrity_check() -> bool:
	if not _query("PRAGMA integrity_check"):
		return false
	var result = _rows()
	if result.size() != 1 or str(result[0].get("integrity_check", "")) != "ok":
		last_error = "SQLite integrity check failed. The database was not changed."
		return false
	if not _query("PRAGMA foreign_key_check"):
		return false
	if not _rows().is_empty():
		last_error = "SQLite contains broken record references. The database was not changed."
		return false
	return true


func _query(statement: String, bindings: Array = []) -> bool:
	if not _opened or _db == null:
		last_error = "SQLite database is not open."
		return false
	if not _db.call("query_with_bindings", statement, bindings):
		last_error = "SQLite query failed: " + _database_error()
		return false
	return true


func _rows() -> Array:
	return _db.get("query_result").duplicate(true)


func _database_error() -> String:
	if _db == null:
		return "SQLite connection unavailable."
	return str(_db.get("error_message"))


func _rollback() -> bool:
	var reason = last_error
	_query("ROLLBACK")
	last_error = reason
	return false


func _json(value) -> String:
	return JSON.stringify(value, "", true, true)


func _ensure_open(create_if_missing: bool) -> bool:
	if _opened:
		return true
	if not create_if_missing and not database_exists():
		last_error = "No SQLite game database exists."
		return false
	return bool(open_database(path).ok)


func save_snapshot(snapshot: Dictionary) -> bool:
	last_error = ""
	for field in ["rooms", "boards", "cards", "entities"]:
		if not snapshot.get(field) is Dictionary:
			last_error = "Snapshot has no valid " + field + " dictionary."
			return false
	for collection in ["organizations", "floors", "teams"]:
		if snapshot.has(collection) and not snapshot[collection] is Dictionary:
			last_error = "Snapshot " + collection + " must be a dictionary."
			return false
	if not snapshot.get("pocket", []) is Array or not snapshot.get("pocket_items", []) is Array:
		last_error = "Snapshot pocket collections must be arrays."
		return false
	var ownership = _ownership_records(snapshot)
	if not last_error.is_empty() or not _ensure_open(true):
		return false
	if not _query("BEGIN IMMEDIATE"):
		return false
	# Child-before-parent order is deliberate; foreign keys stay enabled.
	for table in ["card_locations", "lists", "swimlanes", "pocket_items", "cards", "boards", "entities", "teams", "rooms", "floors", "organizations", "session"]:
		if not _query("DELETE FROM " + table):
			return _rollback()
	for identifier in snapshot.get("organizations", {}):
		var organization = snapshot.organizations[identifier]
		if not _query("INSERT INTO organizations (id,name_json,deleted,in_pocket,data_json) VALUES (?,?,?,?,?)", [str(identifier), _json(organization.get("name", {})), int(organization.get("deleted", false)), int(organization.get("in_pocket", false)), _json(organization)]):
			return _rollback()
	for identifier in snapshot.get("floors", {}):
		var floor_data = snapshot.floors[identifier]
		if not _query("INSERT INTO floors (id,organization_id,number,name_json,deleted,in_pocket,data_json) VALUES (?,?,?,?,?,?,?)", [str(identifier), str(floor_data.get("organization_id", "")), int(floor_data.get("number", 1)), _json(floor_data.get("name", {})), int(floor_data.get("deleted", false)), int(floor_data.get("in_pocket", false)), _json(floor_data)]):
			return _rollback()
	for identifier in snapshot.rooms:
		var room = snapshot.rooms[identifier]
		if not _query("INSERT INTO rooms (id,organization_id,floor_id,floor,number,slot_index,deleted,in_pocket,name_json,data_json) VALUES (?,?,?,?,?,?,?,?,?,?)", [str(identifier), str(room.get("organization_id", "")), str(room.get("floor_id", "")), int(room.get("floor", 1)), str(room.get("number", "")), int(room.get("slot_index", 0)), int(room.get("deleted", false)), int(room.get("in_pocket", false)), _json(room.get("name", {})), _json(room)]):
			return _rollback()
	for identifier in snapshot.get("teams", {}):
		var team = snapshot.teams[identifier]
		if not _query("INSERT INTO teams (id,organization_id,room_id,name_json,data_json) VALUES (?,?,?,?,?)", [str(identifier), str(team.get("organization_id", "")), str(team.get("room_id", "")), _json(team.get("name", {})), _json(team)]):
			return _rollback()
	for identifier in snapshot.boards:
		var board = snapshot.boards[identifier]
		var room_id = str(board.get("room_id", ""))
		if not _query("INSERT INTO boards (id,room_id,title_json,data_json) VALUES (?,?,?,?)", [str(identifier), null if room_id.is_empty() else room_id, _json(board.get("title", {})), _json(board)]):
			return _rollback()
	for identifier in snapshot.cards:
		var card = snapshot.cards[identifier]
		if not _query("INSERT INTO cards (id,lines_json,data_json) VALUES (?,?,?)", [str(identifier), _json(card.get("lines", {})), _json(card)]):
			return _rollback()
	for identifier in snapshot.entities:
		var entity = snapshot.entities[identifier]
		if not _query("INSERT INTO entities (id,room_id,organization_id,team_id,kind,template,age_group,deleted,in_pocket,name_json,description_json,data_json) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", [str(identifier), str(entity.get("room_id", "")), str(entity.get("organization_id", "")), str(entity.get("team_id", "")), str(entity.get("kind", "furniture")), str(entity.get("template", "")), str(entity.get("age_group", "")), int(entity.get("deleted", false)), int(entity.get("in_pocket", false)), _json(entity.get("name", {})), _json(entity.get("description", {})), _json(entity)]):
			return _rollback()
	for row in ownership.pocket_items:
		if not _query("INSERT INTO pocket_items (id,kind,position,data_json) VALUES (?,?,?,?)", [row.id, row.kind, row.position, row.data_json]):
			return _rollback()
	for row in ownership.swimlanes:
		if not _query("INSERT INTO swimlanes (owner_key,id,board_id,pocket_item_id,ordinal,name_json,data_json) VALUES (?,?,?,?,?,?,?)", [row.owner_key, row.id, row.board_id, row.pocket_item_id, row.ordinal, row.name_json, row.data_json]):
			return _rollback()
	for row in ownership.lists:
		if not _query("INSERT INTO lists (owner_key,id,swimlane_id,ordinal,name_json,data_json) VALUES (?,?,?,?,?,?)", [row.owner_key, row.id, row.swimlane_id, row.ordinal, row.name_json, row.data_json]):
			return _rollback()
	for row in ownership.card_locations:
		if not _query("INSERT INTO card_locations (card_id,owner_key,board_id,pocket_item_id,swimlane_id,list_id,position,in_pocket) VALUES (?,?,?,?,?,?,?,?)", [row.card_id, row.owner_key, row.board_id, row.pocket_item_id, row.swimlane_id, row.list_id, row.position, row.in_pocket]):
			return _rollback()
	if not _models.sync_snapshot(_db, snapshot):
		last_error = _models.last_error
		return _rollback()
	var session = snapshot.duplicate(true)
	for field in ["rooms", "boards", "cards", "entities", "pocket", "pocket_items"]:
		session.erase(field)
	if not _query("INSERT INTO session (id,schema_version,data_json,saved_at) VALUES (?,?,?,?)", [1, SCHEMA_VERSION, _json(session), Time.get_datetime_string_from_system(false, true)]):
		return _rollback()
	if not _query("COMMIT"):
		return _rollback()
	is_new_database = false
	last_error = ""
	return true


func load_snapshot() -> Dictionary:
	last_error = ""
	if not _ensure_open(false) or not _query("BEGIN"):
		return {}
	if not _query("SELECT schema_version,data_json FROM session WHERE id = ?", [1]):
		return _read_failure()
	var sessions = _rows()
	if sessions.size() != 1 or int(sessions[0].schema_version) != SCHEMA_VERSION:
		last_error = "The existing SQLite database has no complete supported game snapshot; it was not reset."
		return _read_failure()
	var result = _parse_dictionary(str(sessions[0].data_json), "session")
	if not last_error.is_empty():
		return _read_failure()
	var record_tables = ["rooms", "boards", "cards", "entities"]
	for collection in ["organizations", "floors", "teams"]:
		if result.has(collection):
			record_tables.append(collection)
	for table in record_tables:
		result[table] = {}
		if not _query("SELECT id,data_json FROM " + table + " ORDER BY id"):
			return _read_failure()
		for row in _rows():
			var record = _parse_dictionary(str(row.data_json), table + ":" + str(row.id))
			if not last_error.is_empty():
				return _read_failure()
			if record.get("id", "") != row.id:
				last_error = "SQLite record identity does not match its stored payload: " + str(row.id)
				return _read_failure()
			result[table][row.id] = record
	result["pocket"] = []
	result["pocket_items"] = []
	if not _query("SELECT id,kind,position,data_json FROM pocket_items ORDER BY position,id"):
		return _read_failure()
	var container_position = 0
	var card_position = 0
	for row in _rows():
		var item = _parse_dictionary(str(row.data_json), "pocket:" + str(row.id))
		if not last_error.is_empty():
			return _read_failure()
		if str(row.kind) == "card":
			if int(row.position) != card_position or not item.get("card_id") is String:
				last_error = "SQLite loose pocket card ordering is invalid."
				return _read_failure()
			result.pocket.append(item.card_id)
			card_position += 1
		else:
			if int(row.position) != container_position or item.get("id", "") != row.id or item.get("kind", "") != row.kind:
				last_error = "SQLite pocket container ordering or identity is invalid."
				return _read_failure()
			result.pocket_items.append(item)
			container_position += 1
	var expected = _ownership_records(result)
	if not last_error.is_empty() or not _verify_ownership(expected):
		return _read_failure()
	if not _query("COMMIT"):
		return _read_failure()
	last_error = ""
	return result


func _read_failure() -> Dictionary:
	_rollback()
	return {}


func _ownership_records(snapshot: Dictionary) -> Dictionary:
	var result = {"swimlanes": [], "lists": [], "card_locations": [], "pocket_items": []}
	var pocket_boards: Dictionary = {}
	var spatial_pockets: Dictionary = {}
	for item in snapshot.get("pocket_items", []):
		if item is Dictionary and item.get("kind", "") in ["entity", "building", "floor", "room"]:
			var kind = str(item.kind)
			var field = {"entity": "entity_id", "building": "organization_id", "floor": "floor_id", "room": "room_id"}[kind]
			var collection = {"entity": "entities", "building": "organizations", "floor": "floors", "room": "rooms"}[kind]
			var reference = str(item.get(field, ""))
			var key = kind + ":" + reference
			if not snapshot.get(collection, {}).has(reference) or spatial_pockets.has(key):
				last_error = "An unknown or duplicate spatial pocket reference was found: " + key
				return result
			spatial_pockets[key] = str(item.get("id", ""))
		if item is Dictionary and item.get("kind", "") == "board":
			var identifier = str(item.get("board_id", ""))
			if not snapshot.get("boards", {}).has(identifier) or pocket_boards.has(identifier):
				last_error = "A carried board is unknown or appears twice."
				return result
			pocket_boards[identifier] = str(item.get("id", ""))
	for board_id in snapshot.get("boards", {}):
		var board = snapshot.boards[board_id]
		if not board is Dictionary:
			last_error = "Invalid board payload: " + str(board_id)
			return result
		var lanes = board.get("swimlanes", [{"id": str(board_id) + ":lane:0", "title": {"fi": "Uimarata 1", "en": "Swimlane 1"}, "lists": board.get("lists", []), "cards": board.get("cards", [])}])
		var room_id = str(board.get("room_id", ""))
		var room: Dictionary = snapshot.get("rooms", {}).get(room_id, {})
		var floor_id = str(room.get("floor_id", ""))
		var organization_id = str(room.get("organization_id", board.get("organization_id", "")))
		var effective_pocket = pocket_boards.get(board_id, spatial_pockets.get("room:" + room_id, spatial_pockets.get("floor:" + floor_id, spatial_pockets.get("building:" + organization_id, null))))
		if not _append_owner_rows(result, "board:" + str(board_id), str(board_id), effective_pocket, lanes):
			return result
	var loose_cards = snapshot.get("pocket", [])
	for index in range(loose_cards.size()):
		var card_id = str(loose_cards[index])
		var identifier = "loose:" + card_id
		result.pocket_items.append({"id": identifier, "kind": "card", "position": index, "data_json": _json({"card_id": card_id})})
		result.card_locations.append({"card_id": card_id, "owner_key": null, "board_id": null, "pocket_item_id": identifier, "swimlane_id": null, "list_id": null, "position": index, "in_pocket": 1})
	var containers = snapshot.get("pocket_items", [])
	for index in range(containers.size()):
		var item = containers[index]
		if not item is Dictionary or item.get("kind", "") not in ["list", "swimlane", "board", "entity", "building", "floor", "room"] or str(item.get("id", "")).is_empty():
			last_error = "Invalid pocket container payload."
			return result
		var identifier = str(item.id)
		result.pocket_items.append({"id": identifier, "kind": str(item.kind), "position": index, "data_json": _json(item)})
		if item.kind in ["board", "entity", "building", "floor", "room"]:
			continue
		var lane = item.duplicate(true)
		if item.kind == "list":
			lane["lists"] = [item.get("title", {})]
			lane["cards"] = [item.get("cards", [])]
		if not _append_owner_rows(result, "pocket:" + identifier, null, identifier, [lane]):
			return result
	var seen: Dictionary = {}
	for row in result.card_locations:
		if not snapshot.get("cards", {}).has(row.card_id) or seen.has(row.card_id):
			last_error = "A card is unknown or has more than one owner: " + str(row.card_id)
			return result
		seen[row.card_id] = true
	if seen.size() != snapshot.get("cards", {}).size():
		last_error = "Some cards have no persisted owner."
	return result


func _append_owner_rows(output: Dictionary, owner: String, board_id, pocket_item_id, lanes) -> bool:
	if not lanes is Array:
		last_error = "Swimlanes must be an array: " + owner
		return false
	for lane_index in range(lanes.size()):
		var lane = lanes[lane_index]
		if not lane is Dictionary or not lane.get("lists") is Array or not lane.get("cards") is Array or lane.lists.size() != lane.cards.size():
			last_error = "Swimlane list and card columns are inconsistent: " + owner
			return false
		var lane_id = str(lane.get("id", owner + ":lane:" + str(lane_index)))
		output.swimlanes.append({"owner_key": owner, "id": lane_id, "board_id": board_id, "pocket_item_id": pocket_item_id, "ordinal": lane_index, "name_json": _json(lane.get("title", {})), "data_json": _json(lane)})
		for list_index in range(lane.lists.size()):
			var list_id = lane_id + ":list:" + str(list_index)
			var list_title = lane.lists[list_index]
			output.lists.append({"owner_key": owner, "id": list_id, "swimlane_id": lane_id, "ordinal": list_index, "name_json": _json(list_title), "data_json": _json(list_title)})
			if not lane.cards[list_index] is Array:
				last_error = "Swimlane card column must be an array: " + owner
				return false
			for position_index in range(lane.cards[list_index].size()):
				output.card_locations.append({"card_id": str(lane.cards[list_index][position_index]), "owner_key": owner, "board_id": board_id, "pocket_item_id": pocket_item_id, "swimlane_id": lane_id, "list_id": list_id, "position": position_index, "in_pocket": 0 if pocket_item_id == null else 1})
	return true


func _verify_ownership(expected: Dictionary) -> bool:
	for table in ["swimlanes", "lists", "card_locations", "pocket_items"]:
		if not _query("SELECT " + OWNERSHIP_COLUMNS[table] + " FROM " + table):
			return false
		var actual_rows: Array = []
		var expected_rows: Array = []
		for row in _rows():
			actual_rows.append(_canonical_sql_row(row))
		for row in expected[table]:
			expected_rows.append(_canonical_sql_row(row))
		actual_rows.sort()
		expected_rows.sort()
		if actual_rows != expected_rows:
			last_error = "SQLite ownership records disagree with the saved content in " + table + "; the database was not changed."
			return false
	return true


func _canonical_sql_row(row: Dictionary) -> String:
	# JSON represents numeric values independently of GDScript's int/float tags.
	# Compare embedded JSON values, not strings containing "1" versus "1.0".
	var canonical = row.duplicate(true)
	for key in canonical:
		if str(key).ends_with("_json") and canonical[key] is String:
			var parser = JSON.new()
			if parser.parse(canonical[key]) == OK:
				canonical[key] = parser.data
	return _json(canonical)


func _parse_dictionary(value: String, context: String) -> Dictionary:
	var parser = JSON.new()
	if parser.parse(value) != OK or not parser.data is Dictionary:
		last_error = "Invalid SQLite JSON payload in " + context + "; the database was not changed."
		return {}
	return parser.data
