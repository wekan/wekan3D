extends RefCounted
## Declarative model schema + actual game-data projection. No JavaScript is run.
## Caller owns the surrounding SQLite transaction, connection and rollback.

const SCHEMA_PATH = "res://data/wekan_schema.json"
const GAME_COLLECTIONS = ["rooms", "floors", "boards", "swimlanes", "lists", "cards", "entities"]
var last_error: String = ""
var _collections: Dictionary = {}
var _db: Object

func ensure_tables(db: Object) -> bool:
	_db = db
	last_error = ""
	if not _load_schema():
		return false
	for table in _collections:
		var columns: Dictionary = _collections[table].columns
		if not _query("PRAGMA table_info(" + _quote(table) + ")"):
			return false
		var existing: Dictionary = {}
		for row in _rows():
			existing[str(row.name)] = true
		if existing.is_empty():
			var definitions: Array = []
			for field in columns:
				definitions.append(_quote(field) + " " + str(columns[field].sqlite_type) + (" UNIQUE" if field == "_id" else ""))
			if not _query("CREATE TABLE " + _quote(table) + " (" + ",".join(definitions) + ")"):
				return false
		else:
			for field in columns:
				if not existing.has(field) and not _query("ALTER TABLE " + _quote(table) + " ADD COLUMN " + _quote(field) + " " + str(columns[field].sqlite_type)):
					return false
		var identity_index = "wekan_identity_" + str(table).replace("-", "_")
		if not _query("CREATE UNIQUE INDEX IF NOT EXISTS " + _quote(identity_index) + " ON " + _quote(table) + "(\"_id\") WHERE \"_id\" IS NOT NULL"):
			return false
		for relationship in _collections[table].get("relationships", []):
			var field = str(relationship.field)
			var index = "wekan_" + str(table).replace("-", "_") + "_" + field
			if not _query("CREATE INDEX IF NOT EXISTS " + _quote(index) + " ON " + _quote(table) + "(" + _quote(field) + ")"):
				return false
	for statement in [
		"CREATE TABLE IF NOT EXISTS model_translations (collection TEXT NOT NULL, document_id TEXT NOT NULL, field TEXT NOT NULL, language TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(collection,document_id,field,language))",
		"CREATE TABLE IF NOT EXISTS game_model_projection (collection TEXT NOT NULL, document_id TEXT NOT NULL, PRIMARY KEY(collection,document_id))"
	]:
		if not _query(statement):
			return false
	return true

func sync_snapshot(db: Object, snapshot: Dictionary) -> bool:
	_db = db
	last_error = ""
	if not _load_schema():
		return false
	var language = str(snapshot.get("language", "fi"))
	# Remove only rows previously projected by this game, preserving external rows.
	if not _query("SELECT collection,document_id FROM game_model_projection"):
		return false
	for row in _rows():
		var table = str(row.collection)
		if not _collections.has(table) or table in GAME_COLLECTIONS:
			last_error = "Invalid projection registry collection: " + table
			return false
		if not _query("DELETE FROM " + _quote(table) + " WHERE \"_id\" = ?", [row.document_id]):
			return false
		if not _query("DELETE FROM model_translations WHERE collection = ? AND document_id = ?", [table, row.document_id]):
			return false
	if not _query("DELETE FROM game_model_projection"):
		return false
	for table in GAME_COLLECTIONS:
		if not _query("DELETE FROM model_translations WHERE collection = ?", [table]):
			return false
	for board_id in snapshot.get("boards", {}):
		var board: Dictionary = snapshot.boards[board_id]
		var values = _source_values("boards", board, language)
		values["_id"] = str(board_id)
		values["title"] = _localize(board.get("title", ""), language)
		if not values.has("createdAt"):
			values["createdAt"] = snapshot.get("started_at", "")
		if not values.has("archived"):
			values["archived"] = false
		if not str(board.get("organization_id", "")).is_empty():
			values["orgs"] = [{"orgId": str(board.organization_id)}]
			values["orgIds"] = [str(board.organization_id)]
		values["workspaceId"] = str(board.get("workspace_id", board.get("room_id", "")))
		if not _update_game_row("boards", "\"id\" = ?", [str(board_id)], values):
			return false
		if not _translations("boards", str(board_id), {"title": board.get("title", {}), "description": board.get("description", {})}):
			return false
	# Canonical relationships come from the same normalized ownership graph used
	# by the save validator, including loose cards and pocketed containers/boards.
	if not _query("SELECT card_id,board_id,swimlane_id,list_id,position FROM card_locations"):
		return false
	var locations: Dictionary = {}
	for row in _rows():
		locations[str(row.card_id)] = row
	for card_id in snapshot.get("cards", {}):
		var card: Dictionary = snapshot.cards[card_id]
		var values = _source_values("cards", card, language)
		values["_id"] = str(card_id)
		var translations: Dictionary = {}
		for locale in ["fi", "en"]:
			var lines = card.get("lines", {}).get(locale, [])
			var localized_fields = card.get("localized_details", {}).get(locale, {})
			var title = str(localized_fields.get("title", lines[0] if lines.size() > 0 else ""))
			var description = str(localized_fields.get("description", "\n".join(lines.slice(1)) if lines.size() > 1 else ""))
			if not translations.has("title"):
				translations["title"] = {}
				translations["description"] = {}
			translations.title[locale] = title
			translations.description[locale] = description
			for field in localized_fields:
				if not translations.has(field):
					translations[field] = {}
				translations[field][locale] = localized_fields[field]
		values["title"] = translations.title.get(language, translations.title.get("en", ""))
		values["description"] = translations.description.get(language, translations.description.get("en", ""))
		var location: Dictionary = locations.get(str(card_id), {})
		values["boardId"] = location.get("board_id", null)
		values["swimlaneId"] = location.get("swimlane_id", null)
		values["listId"] = location.get("list_id", null)
		values["sort"] = location.get("position", 0)
		if not values.has("createdAt"):
			values["createdAt"] = snapshot.get("started_at", "")
		if not values.has("archived"):
			values["archived"] = false
		if not _update_game_row("cards", "\"id\" = ?", [str(card_id)], values) or not _translations("cards", str(card_id), translations):
			return false
		if not _sync_related(card, str(card_id), location.get("board_id", null), language):
			return false
	if not _query("SELECT owner_key,id,board_id,ordinal,name_json,data_json FROM swimlanes"):
		return false
	var lane_rows = _rows()
	var lane_boards: Dictionary = {}
	for row in lane_rows:
		lane_boards[str(row.owner_key) + "|" + str(row.id)] = row.board_id
		var lane = _json_dictionary(row.data_json)
		var values = _source_values("swimlanes", lane, language)
		values.merge({"_id": str(row.id), "title": _localize(_json_dictionary(row.name_json), language), "boardId": row.board_id, "sort": row.ordinal}, true)
		if not _update_game_row("swimlanes", "\"owner_key\" = ? AND \"id\" = ?", [row.owner_key, row.id], values):
			return false
		if not _translations("swimlanes", str(row.id), {"title": _json_dictionary(row.name_json)}):
			return false
	if not _query("SELECT owner_key,id,swimlane_id,ordinal,name_json,data_json FROM lists"):
		return false
	for row in _rows():
		var list_data = _json_dictionary(row.data_json)
		var values = _source_values("lists", list_data, language)
		values.merge({"_id": str(row.id), "title": _localize(_json_dictionary(row.name_json), language), "boardId": lane_boards.get(str(row.owner_key) + "|" + str(row.swimlane_id), null), "swimlaneId": row.swimlane_id, "sort": row.ordinal}, true)
		if not _update_game_row("lists", "\"owner_key\" = ? AND \"id\" = ?", [row.owner_key, row.id], values):
			return false
		if not _translations("lists", str(row.id), {"title": _json_dictionary(row.name_json)}):
			return false
	for room_id in snapshot.get("rooms", {}):
		var room: Dictionary = snapshot.rooms[room_id]
		var workspace_id = str(room.get("workspace_id", room_id))
		var workspace_values = {"_id": workspace_id, "orgId": str(room.get("organization_id", "")), "floorId": str(room.get("floor_id", "")), "name": _localize(room.get("name", {}), language), "title": _localize(room.get("name", {}), language), "room_number": str(room.get("number", "")), "floor": room.get("floor", 1), "slot_index": room.get("slot_index", 0), "deleted": bool(room.get("deleted", false)), "in_pocket": bool(room.get("in_pocket", false)), "position": room.get("position", {}), "document_json": room}
		if not _insert_model_row("workspaces", workspace_values) or not _translations("workspaces", workspace_id, {"name": room.get("name", {}), "title": room.get("name", {})}):
			return false
		if not _translations("rooms", str(room_id), {"name": room.get("name", {}), "description": room.get("description", {})}):
			return false
	for floor_id in snapshot.get("floors", {}):
		var floor_data: Dictionary = snapshot.floors[floor_id]
		var floor_values = {"_id": str(floor_id), "orgId": str(floor_data.get("organization_id", "")), "name": _localize(floor_data.get("name", {}), language), "title": _localize(floor_data.get("name", {}), language), "number": int(floor_data.get("number", 1)), "deleted": bool(floor_data.get("deleted", false)), "in_pocket": bool(floor_data.get("in_pocket", false))}
		if not _update_game_row("floors", "\"id\" = ?", [str(floor_id)], floor_values) or not _translations("floors", str(floor_id), {"name": floor_data.get("name", {}), "title": floor_data.get("name", {})}):
			return false
	for team_id in snapshot.get("teams", {}):
		var team: Dictionary = snapshot.teams[team_id]
		var team_values = _source_values("team", team, language)
		team_values.merge({"_id": str(team_id), "teamDisplayName": _localize(team.get("name", {}), language), "teamShortName": str(team_id), "teamIsActive": not bool(team.get("deleted", false)), "orgId": str(team.get("organization_id", "")), "workspaceId": str(team.get("room_id", ""))}, true)
		if not _insert_model_row("team", team_values) or not _translations("team", str(team_id), {"teamDisplayName": team.get("name", {})}):
			return false
	for entity_id in snapshot.get("entities", {}):
		var entity: Dictionary = snapshot.entities[entity_id]
		if not _translations("entities", str(entity_id), {"name": entity.get("name", {}), "description": entity.get("description", {})}):
			return false
		if entity.get("kind", "") == "person":
			var user_values = _source_values("users", entity, language)
			var profile: Dictionary = entity.get("profile", {}).duplicate(true)
			# Keep the complete bilingual staff profile, including all Q&A. Add the
			# source model's display name and real location without losing fields.
			profile.merge({"fullname": _localize(entity.get("name", {}), language), "room_id": entity.get("room_id", ""), "organization_id": entity.get("organization_id", ""), "team_id": entity.get("team_id", ""), "age_group": entity.get("age_group", "middle"), "template": entity.get("template", "person"), "in_pocket": bool(entity.get("in_pocket", false)), "floor": entity.get("floor", 0), "position": entity.get("position", {}), "description": _localize(entity.get("description", {}), language), "archived": bool(entity.get("deleted", false)), "deleted": bool(entity.get("deleted", false))}, true)
			if entity.has("deletedAt"):
				profile["deletedAt"] = entity.deletedAt
			user_values.merge({"_id": str(entity_id), "username": str(entity_id), "profile": profile, "loginDisabled": true}, true)
			if not str(entity.get("team_id", "")).is_empty():
				user_values["teams"] = [{"teamId": str(entity.team_id)}]
			if not str(entity.get("organization_id", "")).is_empty():
				user_values["orgs"] = [{"orgId": str(entity.organization_id)}]
			var profile_translations = {"profile.fullname": entity.get("name", {}), "profile.description": entity.get("description", {})}
			for field in ["title", "team_role", "expertise"]:
				profile_translations["profile." + field] = profile.get(field, {})
			for pair in profile.get("qa", []):
				if pair is Dictionary:
					profile_translations["profile.qa." + str(pair.get("id", "")) + ".question"] = pair.get("question", {})
					profile_translations["profile.qa." + str(pair.get("id", "")) + ".answer"] = pair.get("answer", {})
			if not _insert_model_row("users", user_values) or not _translations("users", str(entity_id), profile_translations):
				return false
	for organization_id in snapshot.get("organizations", {}):
		var organization: Dictionary = snapshot.organizations[organization_id]
		var values = _source_values("org", organization, language)
		values["_id"] = str(organization_id)
		values["orgDisplayName"] = _localize(organization.get("name", {}), language)
		values["orgShortName"] = str(organization_id)
		values["orgIsActive"] = not bool(organization.get("deleted", false))
		if not _insert_model_row("org", values) or not _translations("org", str(organization_id), {"orgDisplayName": organization.get("name", {})}):
			return false
	return true

func _sync_related(card: Dictionary, card_id: String, board_id, language: String) -> bool:
	var related = card.get("related", {})
	if not related is Dictionary:
		return true
	var aliases = {"comments": "card_comments", "cardComments": "card_comments", "cardCommentReactions": "card_comment_reactions", "checklist_items": "checklistItems", "reactions": "card_comment_reactions", "custom_fields": "customFields"}
	for key in related:
		var table = str(aliases.get(key, key))
		if not _collections.has(table) or table in GAME_COLLECTIONS:
			continue
		var documents = related[key]
		if not documents is Array:
			continue
		for index in range(documents.size()):
			if not documents[index] is Dictionary:
				continue
			var document: Dictionary = documents[index]
			var values = _source_values(table, document, language)
			values["_id"] = str(document.get("_id", document.get("id", card_id + ":" + table + ":" + str(index))))
			if _collections[table].columns.has("cardId"):
				values["cardId"] = card_id
			if _collections[table].columns.has("boardId") and not values.has("boardId"):
				values["boardId"] = board_id
			if _collections[table].columns.has("document_json"):
				values["document_json"] = document
			if not _insert_model_row(table, values):
				return false
			var translations: Dictionary = {}
			for locale in ["fi", "en"]:
				var localized = document.get("localized_details", {}).get(locale, {})
				if localized is Dictionary:
					for field in localized:
						if not translations.has(field):
							translations[field] = {}
						translations[field][locale] = localized[field]
			if not _translations(table, str(values._id), translations):
				return false
	return true

func _source_values(table: String, record: Dictionary, language: String) -> Dictionary:
	var columns: Dictionary = _collections[table].columns
	var output: Dictionary = {}
	for field in columns:
		var descriptor: Dictionary = columns[field]
		var declared_default = descriptor.get("defaultValue", {})
		if declared_default.get("literal", false):
			output[field] = declared_default.get("value", null)
		if record.has(field):
			output[field] = record[field]
	var details = record.get("details", {})
	if details is Dictionary:
		for field in details:
			if columns.has(field):
				output[field] = details[field]
	var localized_fields = record.get("localized_details", {}).get(language, {})
	if localized_fields is Dictionary:
		for field in localized_fields:
			if columns.has(field):
				output[field] = _merge_localized(output.get(field), localized_fields[field])
	return output

func _merge_localized(shared, overlay):
	# Locale overlays contain only translated leaves. Retain numeric/identity
	# fields and align editable array entries by CardSchema's __item_id marker.
	if shared is Dictionary and overlay is Dictionary:
		var result = shared.duplicate(true)
		for field in overlay:
			if field != "__item_id":
				result[field] = _merge_localized(result.get(field), overlay[field])
		return result
	if shared is Array and overlay is Array:
		var result: Array = []
		for index in range(shared.size()):
			var patch = overlay[index] if index < overlay.size() else null
			if shared[index] is Dictionary and shared[index].has("_id"):
				patch = null
				for candidate in overlay:
					if candidate is Dictionary and str(candidate.get("__item_id", "")) == str(shared[index]._id):
						patch = candidate
						break
			result.append(_merge_localized(shared[index], patch) if patch != null else shared[index])
		return result
	return overlay if overlay != null else shared

func _update_game_row(table: String, selector: String, keys: Array, values: Dictionary) -> bool:
	var assignments: Array = []
	var bindings: Array = []
	for field in values:
		if not _collections[table].columns.has(field):
			continue
		assignments.append(_quote(field) + " = ?")
		bindings.append(_sql_value(values[field]))
	if assignments.is_empty():
		return true
	bindings.append_array(keys)
	return _query("UPDATE " + _quote(table) + " SET " + ",".join(assignments) + " WHERE " + selector, bindings)

func _insert_model_row(table: String, values: Dictionary) -> bool:
	var names: Array = []
	var marks: Array = []
	var bindings: Array = []
	for field in values:
		if not _collections[table].columns.has(field):
			continue
		names.append(_quote(field))
		marks.append("?")
		bindings.append(_sql_value(values[field]))
	if not _query("INSERT OR REPLACE INTO " + _quote(table) + " (" + ",".join(names) + ") VALUES (" + ",".join(marks) + ")", bindings):
		return false
	return _query("INSERT OR IGNORE INTO game_model_projection(collection,document_id) VALUES (?,?)", [table, str(values.get("_id", ""))])

func _translations(table: String, document_id: String, fields: Dictionary) -> bool:
	for field in fields:
		var translations = fields[field]
		if not translations is Dictionary:
			continue
		for language in ["fi", "en"]:
			if translations.has(language):
				var value = translations[language]
				var text = JSON.stringify(value) if value is Dictionary or value is Array else str(value)
				if not _query("INSERT OR REPLACE INTO model_translations(collection,document_id,field,language,value) VALUES (?,?,?,?,?)", [table, document_id, str(field), language, text]):
					return false
	return true

func _load_schema() -> bool:
	if not _collections.is_empty():
		return true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SCHEMA_PATH))
	if not parsed is Dictionary or not parsed.get("collections") is Array:
		last_error = "Invalid or missing WeKan schema descriptor."
		return false
	var identifier = RegEx.new()
	identifier.compile("^[A-Za-z_][A-Za-z0-9_-]*$")
	for collection in parsed.collections:
		if not collection is Dictionary or identifier.search(str(collection.get("name", ""))) == null or not collection.get("columns") is Dictionary:
			last_error = "Invalid WeKan collection identifier."
			_collections.clear()
			return false
		for field in collection.columns:
			if identifier.search(str(field)) == null or str(collection.columns[field].get("sqlite_type", "")) not in ["TEXT", "INTEGER", "REAL"]:
				last_error = "Invalid WeKan column descriptor."
				_collections.clear()
				return false
		_collections[str(collection.name)] = collection
	return true

func _quote(identifier: String) -> String:
	return "\"" + identifier.replace("\"", "\"\"") + "\""

func _query(statement: String, bindings: Array = []) -> bool:
	if _db == null or not _db.call("query_with_bindings", statement, bindings):
		last_error = "WeKan schema/projection query failed: " + (str(_db.get("error_message")) if _db != null else "no database")
		return false
	return true

func _rows() -> Array:
	return _db.get("query_result").duplicate(true)

func _sql_value(value):
	if value is Dictionary or value is Array:
		return JSON.stringify(value)
	if value is bool:
		return 1 if value else 0
	return value

func _localize(value, language: String) -> String:
	if value is Dictionary:
		return str(value.get(language, value.get("en", value.get("fi", ""))))
	return str(value) if value != null else ""

func _json_dictionary(value) -> Dictionary:
	var parsed = JSON.parse_string(str(value))
	return parsed if parsed is Dictionary else {}
