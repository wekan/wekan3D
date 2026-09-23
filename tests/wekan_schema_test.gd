extends SceneTree
## Complete manifest coverage and actual SQL projection; disposable database only.
const Store = preload("res://scripts/core/sqlite_store.gd")
const WekanSchema = preload("res://scripts/core/wekan_schema.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory = ProjectSettings.globalize_path("res://.test_tmp")
	DirAccess.make_dir_recursive_absolute(directory)
	var path = directory.path_join("wekan_schema_%d_%d.sqlite" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)])
	var store = Store.new(path)
	var fixture = _fixture()
	fixture.entities.e1["profile"] = {"title": {"fi": "Arkkitehti", "en": "Architect"}, "team_role": {"fi": "Suunnittelija", "en": "Designer"}, "expertise": {"fi": "Anturit", "en": "Sensors"}, "qa": [{"id": "q1", "question": {"fi": "Miten mitataan?", "en": "How to measure?"}, "answer": {"fi": "Kalibroi anturi", "en": "Calibrate the sensor"}}]}
	fixture.cards.c1.details["locations"] = [{"_id": "loc1", "latitude": 60.17, "longitude": 24.94}]
	fixture.cards.c1.localized_details.fi["locations"] = [{"__item_id": "loc1", "name": "Helsingin toimisto"}]
	fixture.cards.c1.related["cardCommentReactions"] = [{"_id": "reaction1", "cardCommentId": "comment1", "reactions": [{"userId": "e1", "reaction": "ok"}]}]
	_expect(store.write_snapshot(fixture), "save and augment actual game: " + store.last_error)
	if failures > 0:
		store.close_database()
		quit(1)
		return
	var schema = JSON.parse_string(FileAccess.get_file_as_string("res://data/wekan_schema.json"))
	_expect(schema.source_file_count == 65 and schema.source_collection_count == 49, "all uploaded sources inventoried")
	for collection in schema.collections:
		_expect(store._query("PRAGMA table_info(\"" + str(collection.name) + "\")"), "read SQL columns: " + str(collection.name))
		var columns: Dictionary = {}
		for row in store._rows():
			columns[str(row.name)] = str(row.type)
		for field in collection.columns:
			_expect(columns.get(field, "") == str(collection.columns[field].sqlite_type), "exact source name/type: " + str(collection.name) + "." + str(field))
		for field in collection.nested_fields:
			_expect(columns.has(str(field).get_slice(".", 0)), "nested JSON root retained: " + str(collection.name) + "." + str(field))
	_expect(store._query("SELECT _id,title,description,boardId,swimlaneId,listId,spentTime,isOvertime,vote FROM cards WHERE id = ?", ["c1"]), "query actual canonical card columns")
	var row = store._rows()[0]
	_expect(row._id == "c1" and row.title == "Kortin koko nimi" and row.description == "Laaja kuvaus", "actual translated title and full description projected")
	_expect(row.boardId == "b1" and row.swimlaneId == "lane1" and row.listId == "lane1:list:0", "actual card relationships projected")
	_expect(float(row.spentTime) == 12.5 and int(row.isOvertime) == 1 and JSON.parse_string(row.vote).positive == ["e1"], "Number Boolean and nested JSON projected")
	_expect(store._query("SELECT boardId,listId FROM cards WHERE id = ?", ["c2"]), "query loose pocket card")
	_expect(store._rows()[0].boardId == null and store._rows()[0].listId == null, "loose pocket has no invented board or list")
	_expect(store._query("SELECT title,workspaceId,orgIds FROM boards WHERE id = ?", ["b1"]), "board links workspace and organization")
	row = store._rows()[0]
	_expect(row.title == "Robottitaulu" and row.workspaceId == "r1" and JSON.parse_string(row.orgIds) == ["org1"], "actual board workspace organization columns")
	_expect(store._query("SELECT _id,orgId,name,room_number,floor FROM workspaces"), "workspace table exists")
	row = store._rows()[0]
	_expect(row._id == "r1" and row.orgId == "org1" and row.name == "Robottihuone" and row.room_number == "201" and int(row.floor) == 2, "one actual workspace per room")
	_expect(store._query("SELECT orgDisplayName FROM org WHERE _id = ?", ["org1"]), "original org source field name")
	_expect(store._rows()[0].orgDisplayName == "Robottitalo", "actual building organization projected")
	_expect(store._query("SELECT profile,loginDisabled FROM users WHERE _id = ?", ["e1"]), "fictional person in original users model")
	row = store._rows()[0]
	_expect(JSON.parse_string(row.profile).fullname == "Aino Järvinen" and int(row.loginDisabled) == 1, "fictional person name and non-login status")
	var profile = JSON.parse_string(row.profile)
	_expect(profile.title.fi == "Arkkitehti" and profile.team_role.en == "Designer" and profile.expertise.en == "Sensors" and profile.qa[0].answer.en == "Calibrate the sensor", "full bilingual title role expertise and Q&A preserved in source users.profile")
	_expect(store._query("SELECT locations FROM cards WHERE id = ?", ["c1"]), "query nested translated array")
	var locations = JSON.parse_string(store._rows()[0].locations)
	_expect(locations[0]._id == "loc1" and float(locations[0].latitude) == 60.17 and locations[0].name == "Helsingin toimisto", "locale overlay retains shared nested identity and numeric fields")
	_expect(store._query("SELECT cardCommentId FROM card_comment_reactions WHERE _id = ?", ["reaction1"]), "canonical reaction collection alias projected")
	_expect(store._rows()[0].cardCommentId == "comment1", "reaction preserves true related record link")
	_expect(store._query("SELECT text,cardId FROM card_comments WHERE _id = ?", ["comment1"]), "related record projected")
	row = store._rows()[0]
	_expect(row.text == "Kokeile anturia" and row.cardId == "c1", "related localized comment text and card relationship")
	_expect(store._query("SELECT value FROM model_translations WHERE collection = ? AND document_id = ? AND field = ? AND language = ?", ["cards", "c1", "title", "en"]), "query other language")
	_expect(store._rows()[0].value == "Complete card title", "both languages persist independently")
	var helper = WekanSchema.new()
	_expect(helper.ensure_tables(store._db), "schema augmentation is idempotent: " + helper.last_error)
	fixture.boards.b1.swimlanes[0].cards[0].clear()
	fixture.pocket.append("c1")
	fixture.cards.c1.localized_details.fi.title = "Muokattu 'nimi'; DROP TABLE cards; --"
	fixture.cards.c1.related = {}
	fixture.rooms.r1.name.fi = "Uusi huonenimi"
	fixture.entities.e1["deleted"] = true
	fixture.entities.e1["deletedAt"] = "2026-09-08T04:00:00Z"
	_expect(store.write_snapshot(fixture), "updated snapshot with edit/move/deletion: " + store.last_error)
	_expect(store._query("SELECT title,boardId,listId FROM cards WHERE id = ?", ["c1"]), "updated card projection query")
	row = store._rows()[0]
	_expect(row.title == fixture.cards.c1.localized_details.fi.title and row.boardId == null and row.listId == null, "bound edited text and pocket move immediately visible in source columns")
	_expect(store._query("SELECT COUNT(*) AS n FROM card_comments WHERE _id = ?", ["comment1"]), "query removed related record")
	_expect(int(store._rows()[0].n) == 0, "deleted related records do not linger in parallel tables")
	_expect(store._query("SELECT name FROM workspaces WHERE _id = ?", ["r1"]), "query renamed room workspace")
	_expect(store._rows()[0].name == "Uusi huonenimi", "room rename updates real workspace")
	_expect(store._query("SELECT profile,loginDisabled FROM users WHERE _id = ?", ["e1"]), "query archived fictional person")
	row = store._rows()[0]
	profile = JSON.parse_string(row.profile)
	_expect(profile.deleted and profile.archived and profile.deletedAt == fixture.entities.e1.deletedAt and int(row.loginDisabled) == 1, "soft-delete marks source user disabled archived without losing data")
	_expect(profile.qa[0].answer.en == "Calibrate the sensor", "soft-deleted profile and Q&A preserved")
	_expect(store.integrity_check(), "final SQLite integrity")
	store.close_database()
	var reopened = Store.new(path)
	_expect(reopened.open_database().ok, "reopen augmented existing schema")
	_expect(reopened.read_snapshot().cards.c1.localized_details.fi.title == fixture.cards.c1.localized_details.fi.title, "full snapshot reload keeps edits")
	reopened.close_database()
	DirAccess.remove_absolute(path)
	print("WeKan schema/projection: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _fixture() -> Dictionary:
	var lane = {"id": "lane1", "title": {"fi": "Kehitys", "en": "Development"}, "lists": [{"fi": "Valmis", "en": "Done"}], "cards": [["c1"]]}
	var board = {"id": "b1", "room_id": "r1", "workspace_id": "r1", "organization_id": "org1", "title": {"fi": "Robottitaulu", "en": "Robot board"}, "swimlanes": [lane], "cards": lane.cards, "lists": lane.lists}
	var card = {"id": "c1", "lines": {"fi": ["Kortti", "Rivi kaksi", "Rivi kolme", "Rivi neljä"], "en": ["Card", "Line two", "Line three", "Line four"]}, "details": {"spentTime": 12.5, "isOvertime": true, "vote": {"positive": ["e1"], "negative": []}}, "localized_details": {"fi": {"title": "Kortin koko nimi", "description": "Laaja kuvaus"}, "en": {"title": "Complete card title", "description": "Full description"}}, "related": {"card_comments": [{"_id": "comment1", "localized_details": {"fi": {"text": "Kokeile anturia"}, "en": {"text": "Try the sensor"}}}]}}
	var second = card.duplicate(true)
	second.id = "c2"
	second.related = {}
	return {"version": 2, "catalog_version": 1, "language": "fi", "started_at": "2026-09-08T02:00:00", "elapsed_seconds": 10.0, "visited_rooms": {}, "organizations": {"org1": {"id": "org1", "name": {"fi": "Robottitalo", "en": "Robotics building"}}}, "rooms": {"r1": {"id": "r1", "workspace_id": "r1", "organization_id": "org1", "name": {"fi": "Robottihuone", "en": "Robotics room"}, "number": "201", "floor": 2}}, "boards": {"b1": board}, "cards": {"c1": card, "c2": second}, "entities": {"e1": {"id": "e1", "kind": "person", "name": {"fi": "Aino Järvinen", "en": "Aino Järvinen"}, "description": {"fi": "Ohjelmoija", "en": "Programmer"}, "room_id": "r1", "floor": 2}}, "pocket": ["c2"], "pocket_items": []}

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("WeKan schema test: " + message)
