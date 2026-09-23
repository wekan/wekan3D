extends Node
## Single authority for editable bilingual content and exactly-once card ownership.
signal language_changed
signal cards_changed
signal stats_changed
signal entities_changed
signal organizations_changed
signal layout_changed
const Catalog = preload("res://scripts/core/catalog.gd")
const SpatialState = preload("res://scripts/core/spatial_state.gd")
const CardSchema = preload("res://scripts/core/card_schema.gd")
const SQLiteStore = preload("res://scripts/core/sqlite_store.gd")
const SAVE_VERSION = 1
var catalog = Catalog.new()
var _store = SQLiteStore.new()
var language: String = "fi"
var organizations: Dictionary = {}
var floors: Dictionary = {}
var teams: Dictionary = {}
var boards: Dictionary = {}
var board_slots: Dictionary = {}
var cards: Dictionary = {}
var rooms: Dictionary = {}
var entities: Dictionary = {}
var pocket: Array = []
var pocket_items: Array = []
var visited_rooms: Dictionary = {}
var started_at: String = ""
var elapsed_seconds: float = 0.0
var last_error: String = ""
var last_storage_error: String = ""
## Root enables this only after registering all defaults and loading/creating DB.
var autosave_enabled: bool = false
var storage_read_blocked: bool = false
var database_path: String:
	get:
		return _store.path
var _stat_clock: float = 0.0
var _board_specs: Dictionary = {}
var _slot_specs: Dictionary = {}
var _organization_specs: Dictionary = {}
var _room_specs: Dictionary = {}
var _entity_specs: Dictionary = {}
var _next_id: int = 0

const UI = {
	"game_title": ["Kanban-toimisto", "Kanban Office"],
	"started": ["Aloitettu", "Started"], "elapsed": ["Kulunut aika", "Elapsed"],
	"rooms_visited": ["Huoneissa käyty", "Rooms visited"],
	"pocket": ["Tasku", "Pocket"], "pocket_count": ["Taskussa: %d", "Pocket: %d"],
	"pocket_title": ["Taskussa olevat kortit", "Cards in your pocket"],
	"pocket_empty": ["Taskussasi ei ole kortteja.", "Your pocket is empty."],
	"page": ["Sivu %d / %d", "Page %d / %d"], "previous": ["Edellinen", "Previous"],
	"next": ["Seuraava", "Next"], "close": ["Sulje", "Close"], "back": ["Takaisin", "Back"],
	"take": ["Ota", "Take"], "take_to_pocket": ["Laita taskuun", "Put in pocket"],
	"place": ["Aseta kortti", "Place card"], "carry": ["Kanna korttia", "Carry card"],
	"carrying": ["Kannat: %s", "Carrying: %s"], "cancel_carry": ["Peru kantaminen", "Cancel carrying"],
	"board": ["Taulu", "Board"], "board_workspace": ["Kanban-työpiste", "Kanban workspace"],
	"board_left": ["Vasen taulu", "Left board"], "board_right": ["Oikea taulu", "Right board"],
	"choose_board": ["Valitse taulu", "Choose board"], "choose_list": ["Valitse lista", "Choose list"],
	"move": ["Siirrä kortti", "Move card"], "swimlane": ["Uimarata 1", "Swimlane 1"],
	"list_0": ["Ideat", "Ideas"], "list_1": ["Valmiina", "Ready"],
	"list_2": ["Työn alla", "In progress"], "list_3": ["Valmis", "Done"],
	"select_card": ["Valitse kortti", "Select a card"],
	"drag_hint": ["Vedä kortteja taululta toiselle tai taskuun.", "Drag cards between boards or into your pocket."],
	"board_hint": ["E / A: avaa taulu • Klikkaa korttia kantaaksesi", "E / A: open board • Click a card to carry it"],
	"npc_hint": ["E / A: keskustele", "E / A: talk"],
	"place_hint": ["Klikkaa taulua tai paina E / A asettaaksesi kortin", "Click a board or press E / A to place the card"],
	"controls": ["Nuolet: kävele/käänny • WASD: liiku • Hiiren oikea: katso • E/A: käytä • I/Y: tasku • P/X: kortti taskuun • Esc/B: takaisin", "Arrows: walk/turn • WASD: move • RMB: look • E/A: interact • I/Y: pocket • P/X: pocket card • Esc/B: back"],
	"card_pocketed": ["Kortti laitettu taskuun.", "Card put in pocket."],
	"card_placed": ["Kortti asetettu taululle.", "Card placed on board."],
	"card_moved": ["Kortti siirretty.", "Card moved."],
	"move_failed": ["Korttia ei voitu siirtää.", "The card could not be moved."],
	"save": ["Tallenna", "Save"], "load": ["Lataa", "Load"], "new_game": ["Uusi vierailu", "New visit"],
	"saved": ["Peli tallennettu.", "Game saved."], "loaded": ["Peli ladattu.", "Game loaded."],
	"save_failed": ["Pelin tallennus epäonnistui.", "Could not save the game."],
	"load_failed": ["Yhteensopivaa tallennusta ei löytynyt.", "No compatible saved game was found."],
	"reception": ["Vastaanotto", "Reception"], "receptionist": ["Vastaanottovirkailija", "Receptionist"],
	"hello": ["Hei! Miten voin auttaa?", "Hello! How can I help you?"],
	"ask_directions": ["Missä toimistot ovat?", "Where are the offices?"],
	"answer_directions": ["Toimistot ovat käytävän molemmin puolin. Portaat ovat rakennuksen takaosassa.", "Offices are on both sides of the corridor. The stairs are at the back."],
	"ask_kanban": ["Miten siirrän kortteja?", "How do I move cards?"],
	"answer_kanban": ["Avaa taulu, niin voit vetää kortteja. Taskun avulla kuljetat kortteja huoneesta toiseen.", "Open a board to drag cards. Your pocket lets you carry cards between rooms."],
	"ask_controls": ["Miten täällä liikutaan?", "How do I move around?"],
	"answer_controls": ["Liiku nuolinäppäimillä tai peliohjaimella. Pidä hiiren oikeaa painiketta pohjassa katsellaksesi.", "Use the arrow keys or your controller. Hold the right mouse button to look around."],
	"ask_topics": ["Mitä tiimit tekevät?", "What do the teams work on?"],
	"answer_topics": ["Tiimimme rakentavat ohjelmistoja, ajoneuvoja, robotteja ja paljon muuta. Joka seinällä on eri aihe.", "Our teams build software, vehicles, robots and many other things. Every wall has a different topic."],
	"ask_accessibility": ["Voinko käyttää peliohjainta?", "Can I use a controller?"],
	"answer_accessibility": ["Kyllä. Liiku ja katso tateilla. A avaa taulun, Y taskun ja B palaa takaisin.", "Yes. Use both sticks to walk and look. A opens boards, Y opens your pocket and B goes back."],
	"goodbye": ["Kiitos, näkemiin!", "Thanks, goodbye!"],
	"thanks": ["Ole hyvä! Mukavaa vierailua.", "You're welcome! Enjoy your visit."],
	"floor": ["Kerros %d", "Floor %d"], "room": ["Huone %s", "Room %s"],
	"welcome": ["Tervetuloa Kanban-toimistoon", "Welcome to Kanban Office"],
	"click_pocket": ["Avaa tasku klikkaamalla", "Click here to open your pocket"],
	"selected": ["Valittu", "Selected"], "transfer": ["Siirrä", "Transfer"],
	"dialogue": ["Keskustelu", "Conversation"], "source": ["Lähde", "Source"],
	"destination": ["Kohde", "Destination"], "language": ["Kieli", "Language"]
}


func _ready() -> void:
	if started_at.is_empty():
		started_at = Time.get_datetime_string_from_system(false, false)

func _process(delta: float) -> void:
	elapsed_seconds += maxf(delta, 0.0)
	_stat_clock += delta
	if _stat_clock >= 1.0:
		_stat_clock = fmod(_stat_clock, 1.0)
		stats_changed.emit()

func tr_key(key: String) -> String:
	if UI.has(key):
		return UI[key][0 if language == "fi" else 1]
	return key

func localize(value) -> String:
	if value is Dictionary:
		return str(value.get(language, value.get("en", value.get("fi", ""))))
	return str(value)

func set_language(value: String) -> void:
	if value not in ["fi", "en"] or language == value:
		return
	var previous = language
	language = value
	if autosave_enabled and not save_game():
		language = previous
		return
	language_changed.emit()

func ensure_board(board_id: String, room_id: String, topic_index: int) -> void:
	if board_id.is_empty():
		return
	_board_specs[board_id] = {"room_id": room_id, "topic": topic_index}
	if boards.has(board_id):
		return
	var board = catalog.make_board(board_id, room_id, topic_index)
	if not board_slots.has(board_id):
		register_board_slot({"id": board_id, "room_id": room_id})
	board["workspace_id"] = room_id
	board["organization_id"] = rooms.get(room_id, {}).get("organization_id", "org_main")
	board["slot_id"] = board_id
	board_slots[board_id]["board_id"] = board_id
	_canonicalize_board(board)
	var initial_cards = catalog.make_cards(board_id, topic_index)
	for index in range(initial_cards.size()):
		var card = initial_cards[index]
		_ensure_card_details(card)
		cards[card.id] = card
		board.cards[index / 4].append(card.id)
	boards[board_id] = board

func register_board_slot(spec: Dictionary) -> void:
	var id = str(spec.get("id", ""))
	if id.is_empty():
		return
	var data = {"id": id, "room_id": str(spec.get("room_id", "")), "position": _vector_dict(spec.get("position", Vector3.ZERO)), "yaw": float(spec.get("yaw", 0.0)), "board_id": id}
	_slot_specs[id] = data.duplicate(true)
	if board_slots.has(id):
		data.board_id = board_slots[id].board_id
	board_slots[id] = data

func _canonicalize_board(board: Dictionary) -> void:
	if not board.has("swimlanes"):
		board["swimlanes"] = [{"id": str(board.id) + "_lane_0", "title": {"fi": "Uimarata 1", "en": "Swimlane 1"}, "lists": board.get("lists", Catalog.LISTS.duplicate(true)), "cards": board.get("cards", [[], [], [], []])}]
	if board.swimlanes.is_empty():
		board.swimlanes.append(_empty_lane(str(board.id)))
	for lane in board.swimlanes:
		if not lane.has("lists"):
			lane["lists"] = board.get("lists", Catalog.LISTS.duplicate(true)).duplicate(true)
	board["lists"] = board.swimlanes[0].lists
	board["cards"] = board.swimlanes[0].cards

func _empty_lane(board_id: String) -> Dictionary:
	return {"id": _unique_id(board_id + "_lane"), "title": {"fi": "Uimarata", "en": "Swimlane"}, "lists": [{"fi": "Ideat", "en": "Ideas"}], "cards": [[]]}

func _unique_id(prefix: String) -> String:
	_next_id += 1
	return prefix + "_" + str(Time.get_ticks_usec()) + "_" + str(_next_id)

func register_organization(spec: Dictionary) -> void:
	var id = str(spec.get("id", ""))
	if id.is_empty():
		return
	var data = spec.duplicate(true)
	data["id"] = id
	data["name"] = spec.get("name", {"fi": "Kanban-toimisto", "en": "Kanban Office"})
	if data.name is String:
		data.name = {"fi": data.name, "en": data.name}
	data["deleted"] = spec.get("deleted", false)
	data["in_pocket"] = spec.get("in_pocket", false)
	data["building_index"] = int(spec.get("building_index", 0))
	data["position"] = _vector_dict(spec.get("position", Vector3.ZERO))
	_organization_specs[id] = data.duplicate(true)
	if not organizations.has(id):
		organizations[id] = data

func create_organization(text_value: String) -> String:
	if not _text(text_value):
		return ""
	var before = _before_edit()
	var index = 0
	for organization in organizations.values():
		index = maxi(index, int(organization.building_index) + 1)
	var id = _unique_id("org")
	organizations[id] = {"id": id, "name": _translated(text_value), "building_index": index, "position": {"x": index * 60.0, "y": 0.0, "z": 0.0}}
	ensure_spatial_layout(id)
	# Root synchronously constructs/registers the new building before transaction.
	organizations_changed.emit()
	return id if _commit_edit(before, true) else ""

func register_room(spec: Dictionary) -> void:
	var id = str(spec.get("id", ""))
	if id.is_empty():
		return
	var org_id = str(spec.get("organization_id", "org_main"))
	if not organizations.has(org_id):
		register_organization({"id": org_id})
	var floor_number = int(spec.get("floor", 0)) + 1
	var ordinal = 1
	for existing in rooms.values():
		if int(existing.get("floor", 1)) == floor_number and existing.id != id and existing.get("organization_id", "org_main") == org_id:
			ordinal += 1
	var number = str(spec.get("number", floor_number * 100 + ordinal))
	var data = {"id": id, "organization_id": org_id, "workspace_id": id, "number": number, "floor": floor_number, "name": spec.get("name", {"fi": "Toimisto " + number, "en": "Office " + number}), "topic": int(spec.get("topic", 0)), "position": _vector_dict(spec.get("center", Vector3.ZERO))}
	if data.name is String:
		data.name = {"fi": data.name, "en": data.name}
	data["floor_id"] = spec.get("floor_id", rooms.get(id, {}).get("floor_id", org_id + "_floor_" + str(floor_number)))
	data["slot_index"] = int(spec.get("slot_index", rooms.get(id, {}).get("slot_index", ordinal - 1)))
	data["deleted"] = spec.get("deleted", false)
	data["in_pocket"] = spec.get("in_pocket", false)
	_room_specs[id] = data.duplicate(true)
	if not rooms.has(id):
		rooms[id] = data
	else:
		# Geometry-derived coordinates may change while persisted names/content stay.
		for field in ["floor_id", "slot_index", "floor", "position", "number", "organization_id"]:
			rooms[id][field] = data[field]
	SpatialState.ensure_room(self, rooms[id])

func register_entity(spec: Dictionary) -> void:
	var id = str(spec.get("id", ""))
	if id.is_empty():
		return
	var data = spec.duplicate(true)
	data["id"] = id
	data["position"] = _vector_dict(spec.get("position", Vector3.ZERO))
	data["floor"] = int(spec.get("floor", 1))
	data["kind"] = spec.get("kind", "furniture")
	data["organization_id"] = spec.get("organization_id", rooms.get(spec.get("room_id", ""), {}).get("organization_id", "org_main"))
	data["name"] = spec.get("name", {"fi": id, "en": id})
	if data.name is String:
		data.name = {"fi": data.name, "en": data.name}
	data["description"] = spec.get("description", {"fi": "", "en": ""})
	if data.description is String:
		data.description = {"fi": data.description, "en": data.description}
	data["template"] = spec.get("template", "person" if data.kind == "person" else _guess_template(data.name))
	data["deleted"] = spec.get("deleted", false)
	data["in_pocket"] = spec.get("in_pocket", false)
	data["floor_id"] = spec.get("floor_id", rooms.get(spec.get("room_id", ""), {}).get("floor_id", ""))
	if data.kind == "person":
		data["age_group"] = spec.get("age_group", "middle")
		data["team_id"] = spec.get("team_id", rooms.get(spec.get("room_id", ""), {}).get("team_id", ""))
	if data.kind == "person" and not data.has("profile"):
		data["profile"] = _make_person_profile(data)
	_entity_specs[id] = data.duplicate(true)
	if not entities.has(id):
		entities[id] = data

func _vector_dict(value) -> Dictionary:
	if value is Vector3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Dictionary:
		return value.duplicate(true)
	return {"x": 0.0, "y": 0.0, "z": 0.0}

func room_name(room_id: String) -> String:
	return localize(rooms[room_id].name) if rooms.has(room_id) else room_id

func topic_text(topic_index: int) -> String:
	return localize(catalog.topic(topic_index).get("title", ""))

func get_card_lines(card_id: String) -> Array:
	if not cards.has(card_id):
		return []
	return cards[card_id].lines.get(language, cards[card_id].lines.get("en", [])).duplicate()

func _lane(board_id: String, lane_index: int):
	if not boards.has(board_id) or lane_index < 0 or lane_index >= boards[board_id].swimlanes.size():
		return null
	return boards[board_id].swimlanes[lane_index]

func get_card_location(card_id: String) -> Dictionary:
	if not cards.has(card_id):
		return {}
	var index = pocket.find(card_id)
	if index >= 0:
		return {"pocket": true, "index": index}
	for item in pocket_items:
		if item.kind == "list":
			index = item.cards.find(card_id)
			if index >= 0:
				return {"pocket": true, "item_id": item.id, "kind": "list", "lane": 0, "list": 0, "index": index}
		elif item.kind == "swimlane":
			for list_index in range(item.cards.size()):
				index = item.cards[list_index].find(card_id)
				if index >= 0:
					return {"pocket": true, "item_id": item.id, "kind": "swimlane", "lane": 0, "list": list_index, "index": index}
	for board_id in boards:
		for lane_index in range(boards[board_id].swimlanes.size()):
			var lane = boards[board_id].swimlanes[lane_index]
			for list_index in range(lane.cards.size()):
				index = lane.cards[list_index].find(card_id)
				if index >= 0:
					var location = {"board_id": board_id, "lane": lane_index, "list": list_index, "index": index}
					var enclosing = get_effective_pocket("board", board_id)
					if not enclosing.is_empty():
						location["pocket"] = true
						location["item_id"] = enclosing
						location["kind"] = get_pocket_item(enclosing).kind
					return location
	return {}

func get_pocket_item(item_id: String) -> Dictionary:
	for item in pocket_items:
		if item.id == item_id:
			return item
	return {}

func pocket_card_count() -> int:
	var count = pocket.size()
	for item in pocket_items: count += get_pocket_item_card_ids(item.id).size()
	return count

func move_card(card_id: String, target_board_id: String, target_list: int, target_index: int = -1, target_lane: int = 0) -> bool:
	var destination_lane = _lane(target_board_id, target_lane)
	if not cards.has(card_id) or destination_lane == null or target_list < 0 or target_list >= destination_lane.cards.size() or target_index < -1:
		return false
	var source = get_card_location(card_id)
	if source.is_empty():
		return false
	var destination: Array = destination_lane.cards[target_list]
	if target_index > destination.size():
		return false
	var insert_index = destination.size() if target_index == -1 else target_index
	if source.get("board_id", "") == target_board_id and source.get("lane", -1) == target_lane and source.get("list", -1) == target_list:
		if int(source.index) < insert_index:
			insert_index -= 1
		if int(source.index) == insert_index:
			return true
	var before = _before_edit()
	_remove_from_location(source)
	destination.insert(insert_index, card_id)
	return _commit_edit(before)

func pocket_card(card_id: String) -> bool:
	if not cards.has(card_id):
		return false
	var source = get_card_location(card_id)
	if source.is_empty():
		return false
	if source.get("pocket", false) and not source.has("item_id"):
		return true
	var before = _before_edit()
	_remove_from_location(source)
	pocket.append(card_id)
	return _commit_edit(before)

func _remove_from_location(location: Dictionary) -> void:
	if location.has("item_id"):
		var item = get_pocket_item(location.item_id)
		if item.kind == "list":
			item.cards.remove_at(int(location.index))
		elif item.kind == "swimlane":
			item.cards[int(location.list)].remove_at(int(location.index))
		else:
			boards[location.board_id].swimlanes[int(location.lane)].cards[int(location.list)].remove_at(int(location.index))
	elif location.get("pocket", false):
		pocket.remove_at(int(location.index))
	else:
		boards[location.board_id].swimlanes[int(location.lane)].cards[int(location.list)].remove_at(int(location.index))

func _text(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= 4096

func _translated(text: String, fallback: String = "") -> Dictionary:
	# A newly created item has useful text in both languages; later edits touch only
	# the active language. Users can switch language to provide each translation.
	var result = {"fi": text.strip_edges(), "en": text.strip_edges()}
	if not fallback.is_empty():
		result["en" if language == "fi" else "fi"] = fallback
	return result

func add_swimlane(board_id: String, title: String) -> String:
	if not boards.has(board_id) or not _text(title):
		return ""
	var before = _before_edit()
	var lane = _empty_lane(board_id)
	lane.title = _translated(title)
	boards[board_id].swimlanes.append(lane)
	return lane.id if _commit_edit(before) else ""

func add_list(board_id: String, lane_index: int, title: String) -> int:
	var lane = _lane(board_id, lane_index)
	if lane == null or not _text(title):
		return -1
	var before = _before_edit()
	var index = lane.lists.size()
	lane.lists.append(_translated(title))
	lane.cards.append([])
	return index if _commit_edit(before) else -1

func add_card(board_id: String, lane_index: int, list_index: int, lines: Array) -> String:
	var lane = _lane(board_id, lane_index)
	if lane == null or list_index < 0 or list_index >= lane.cards.size() or not _valid_lines(lines):
		return ""
	var before = _before_edit()
	var id = _unique_id(board_id + "_card")
	cards[id] = {"id": id, "topic": int(boards[board_id].topic), "lines": {"fi": lines.duplicate(), "en": lines.duplicate()}}
	_ensure_card_details(cards[id])
	lane.cards[list_index].append(id)
	return id if _commit_edit(before) else ""

func edit_board_title(board_id: String, text_value: String) -> bool:
	if not boards.has(board_id) or not _text(text_value):
		return false
	var before = _before_edit()
	boards[board_id].title[language] = text_value.strip_edges()
	for item in pocket_items:
		if item.kind == "board" and item.board_id == board_id:
			item.title = boards[board_id].title
	return _commit_edit(before)

func edit_lane_title(board_id: String, lane_index: int, text_value: String) -> bool:
	var lane = _lane(board_id, lane_index)
	if lane == null or not _text(text_value):
		return false
	var before = _before_edit()
	lane.title[language] = text_value.strip_edges()
	return _commit_edit(before)

func edit_swimlane_title(board_id: String, lane_index: int, text_value: String) -> bool:
	return edit_lane_title(board_id, lane_index, text_value)

func edit_list_title(board_id: String, lane_index: int, list_index: int, text_value: String) -> bool:
	var lane = _lane(board_id, lane_index)
	if lane == null or list_index < 0 or list_index >= lane.lists.size() or not _text(text_value):
		return false
	var before = _before_edit()
	lane.lists[list_index][language] = text_value.strip_edges()
	return _commit_edit(before)

func edit_card_lines(card_id: String, lines: Array) -> bool:
	if not cards.has(card_id) or not _valid_lines(lines):
		return false
	var before = _before_edit()
	cards[card_id].lines[language] = lines.duplicate()
	_ensure_card_details(cards[card_id])
	cards[card_id].localized_details[language]["title"] = lines[0]
	cards[card_id].localized_details[language]["description"] = "\n".join(lines.slice(1, 4))
	cards[card_id].details["modifiedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	return _commit_edit(before)

func _ensure_card_details(card: Dictionary) -> void:
	if not card.has("details") or not card.has("localized_details"):
		var defaults = CardSchema.default_details(card.lines)
		card["details"] = defaults.details
		card["localized_details"] = defaults.localized_details
	card.details["_id"] = card.id
	if str(card.details.get("userId", "")).is_empty():
		card.details["userId"] = "local_player"
	if not card.has("related"):
		card["related"] = {"checklists": [], "checklistItems": [], "cardComments": [], "cardCommentReactions": [], "attachments": [], "activities": []}

func _context_fields(card_id: String) -> Dictionary:
	var location = get_card_location(card_id)
	var result = {"_id": card_id, "boardId": "", "swimlaneId": "", "listId": "", "sort": 0}
	if location.has("board_id"):
		var lane = boards[location.board_id].swimlanes[int(location.lane)]
		result.boardId = location.board_id
		result.swimlaneId = lane.id
		result.listId = str(lane.id) + ":list:" + str(location.list)
		result.sort = int(location.index)
	elif location.has("item_id"):
		var item = get_pocket_item(location.item_id)
		result.swimlaneId = str(item.get("lane_id", item.id))
		result.listId = str(result.swimlaneId) + ":list:" + str(location.get("list", 0))
		result.sort = int(location.index)
	return result

func get_card_details(card_id: String, locale: String = "") -> Dictionary:
	if not cards.has(card_id):
		return {}
	var selected = language if locale.is_empty() else locale
	if selected not in ["fi", "en"]:
		return {}
	var card = cards[card_id]
	_ensure_card_details(card)
	var result = CardSchema.compose(card.details, card.localized_details, selected)
	result.merge(_context_fields(card_id), true)
	var related: Dictionary = {}
	for collection in card.related:
		related[collection] = []
		for record in card.related[collection]:
			if not record is Dictionary:
				continue
			var shared = record.duplicate(true)
			var translations = shared.get("localized_details", {})
			shared.erase("localized_details")
			related[collection].append(CardSchema.compose(shared, translations, selected, collection))
	result["related"] = related
	return result

func edit_card_details(card_id: String, values: Dictionary, locale: String = "") -> bool:
	if not cards.has(card_id):
		last_error = "Unknown card."
		return false
	var selected = language if locale.is_empty() else locale
	if selected not in ["fi", "en"]:
		last_error = "Unsupported language."
		return false
	var document = get_card_details(card_id, selected)
	document.erase("related")
	var patch = values.duplicate(true)
	patch.erase("related")
	document.merge(patch, true)
	# Identity and graph references are computed, never editable free text.
	document.merge(_context_fields(card_id), true)
	document["modifiedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	document["dateLastActivity"] = document.modifiedAt
	var errors = CardSchema.validate(document)
	if not errors.is_empty():
		last_error = str(errors[0])
		return false
	var related = cards[card_id].related.duplicate(true)
	if values.has("related"):
		if not values.related is Dictionary:
			last_error = "Related collections must be an object."
			return false
		var normalized = _normalize_related(card_id, values.related, selected)
		if not normalized.ok:
			return false
		related = normalized.value
	var before = _before_edit()
	var split = CardSchema.split(document, selected, cards[card_id].localized_details)
	cards[card_id].details = split.details
	cards[card_id].localized_details = split.localized_details
	cards[card_id].related = related
	var title = str(document.get("title", "")).strip_edges()
	if title.is_empty():
		title = "Nimetön kortti" if selected == "fi" else "Untitled card"
	var description = str(document.get("description", "")).split("\n")
	var lines: Array = [title.substr(0, 4096)]
	for index in range(3):
		var line = str(description[index]).strip_edges() if index < description.size() else ""
		lines.append(line.substr(0, 4096) if not line.is_empty() else "—")
	cards[card_id].lines[selected] = lines
	return _commit_edit(before)

func _normalize_related(card_id: String, changes: Dictionary, locale: String) -> Dictionary:
	var result = cards[card_id].related.duplicate(true)
	var context = _context_fields(card_id)
	var now = Time.get_datetime_string_from_system(true) + "Z"
	for collection in changes:
		if not changes[collection] is Array:
			last_error = str(collection) + ": expected an array of objects."
			return {"ok": false}
		var existing: Dictionary = {}
		for record in result.get(collection, []):
			if record is Dictionary:
				existing[str(record.get("_id", ""))] = record
		var normalized: Array = []
		var used: Dictionary = {}
		for input in changes[collection]:
			if not input is Dictionary:
				last_error = str(collection) + ": expected an object."
				return {"ok": false}
			var record = input.duplicate(true)
			var id = str(record.get("_id", ""))
			if id.is_empty():
				id = _unique_id(str(collection))
			if used.has(id):
				last_error = str(collection) + ": duplicate record ID."
				return {"ok": false}
			used[id] = true
			for field in CardSchema.fields(str(collection)):
				var key: String = field.key
				if not record.has(key) and field.get("has_default", false) and not field.has("default_expression"):
					record[key] = field.get("default")
			record["_id"] = id
			record["cardId"] = card_id
			record["boardId"] = context.boardId
			record["createdAt"] = record.get("createdAt", existing.get(id, {}).get("createdAt", now))
			record["modifiedAt"] = now
			record["userId"] = record.get("userId", "local_player")
			if not record.has("sort"):
				record["sort"] = normalized.size()
			if collection == "checklistItems" and not record.has("isFinished"):
				record["isFinished"] = false
			var errors = CardSchema.validate(record, str(collection))
			if not errors.is_empty():
				last_error = str(collection) + ": " + str(errors[0])
				return {"ok": false}
			var old_localized = existing.get(id, {}).get("localized_details", {})
			var separated = CardSchema.split(record, locale, old_localized, str(collection))
			if not existing.has(id):
				separated.localized_details["en" if locale == "fi" else "fi"] = separated.localized_details[locale].duplicate(true)
			var shared: Dictionary = separated.details
			shared["localized_details"] = separated.localized_details
			normalized.append(shared)
		result[collection] = normalized
	# Related cross-references stay within this card; dangling checklist/comment
	# references are rejected before anything is committed.
	var checklist_ids: Dictionary = {}
	for record in result.get("checklists", []):
		checklist_ids[str(record.get("_id", ""))] = true
	for record in result.get("checklistItems", []):
		if not checklist_ids.has(str(record.get("checklistId", ""))):
			last_error = "Checklist item references an unknown checklist."
			return {"ok": false}
	var comment_ids: Dictionary = {}
	for record in result.get("cardComments", []):
		comment_ids[str(record.get("_id", ""))] = true
	for record in result.get("cardCommentReactions", []):
		if not comment_ids.has(str(record.get("cardCommentId", ""))):
			last_error = "Reaction references an unknown comment."
			return {"ok": false}
	return {"ok": true, "value": result}

func _make_person_profile(spec: Dictionary) -> Dictionary:
	var helper_path = "res://scripts/actors/person_profiles.gd"
	if ResourceLoader.exists(helper_path):
		var helper = load(helper_path)
		if helper != null:
			return helper.make_profile(spec)
	return {"title": {"fi": "Kehittäjä", "en": "Developer"}, "team_role": {"fi": "Tiimin jäsen", "en": "Team member"}, "expertise": {"fi": "Kanban", "en": "Kanban"}, "qa": []}

func create_person(room_id: String, name_value: String, female: bool = false, age_group: String = "middle") -> String:
	if not rooms.has(room_id) or rooms[room_id].get("deleted", false) or not _text(name_value) or age_group not in ["young", "middle", "old"]:
		last_error = "A person needs a known office and a name."
		return ""
	var before = _before_edit()
	var room = rooms[room_id]
	var id = _unique_id("person")
	var position = room.position.duplicate(true)
	position.y = float(position.get("y", (int(room.floor) - 1) * 4.0))
	var spec = {"id": id, "kind": "person", "name": _translated(name_value), "description": {"fi": "Toimiston työtoveri.", "en": "Office colleague."}, "room_id": room_id, "organization_id": room.organization_id, "floor": room.floor, "position": position, "topic": int(room.get("topic", 0)), "female": female, "age_group": age_group, "team_id": room.get("team_id", ""), "floor_id": room.get("floor_id", ""), "template": "person", "in_pocket": false, "receptionist": false, "deleted": false}
	spec["profile"] = _make_person_profile(spec)
	entities[id] = spec
	return id if _commit_edit(before, true) else ""

func get_person_profile(entity_id: String, locale: String = "") -> Dictionary:
	if not entities.has(entity_id) or entities[entity_id].kind != "person":
		return {}
	var selected = language if locale.is_empty() else locale
	if selected not in ["fi", "en"]:
		return {}
	var entity = entities[entity_id]
	if not entity.has("profile"):
		entity["profile"] = _make_person_profile(entity)
	var profile = entity.profile
	var result = {"id": entity_id, "name": str(entity.name.get(selected, "")), "room_id": entity.get("room_id", ""), "organization_id": entity.get("organization_id", ""), "deleted": entity.get("deleted", false), "age_group": entity.get("age_group", "middle"), "team_id": entity.get("team_id", ""), "qa": []}
	for field in ["title", "team_role", "expertise"]:
		result[field] = str(profile.get(field, {}).get(selected, ""))
	for pair in profile.get("qa", []):
		result.qa.append({"id": pair.id, "question": str(pair.question.get(selected, "")), "answer": str(pair.answer.get(selected, ""))})
	return result

func edit_person_profile(entity_id: String, changes: Dictionary, locale: String = "") -> bool:
	if not entities.has(entity_id) or entities[entity_id].kind != "person" or entities[entity_id].get("deleted", false):
		last_error = "Unknown or deleted person."
		return false
	var selected = language if locale.is_empty() else locale
	if selected not in ["fi", "en"]:
		last_error = "Unsupported language."
		return false
	var entity = entities[entity_id]
	var profile = entity.get("profile", _make_person_profile(entity)).duplicate(true)
	for field in ["name", "title", "team_role", "expertise"]:
		if changes.has(field) and (not changes[field] is String or (field == "name" and not _text(changes[field])) or str(changes[field]).length() > 4096):
			last_error = "Invalid person field: " + field
			return false
	if changes.has("age_group") and changes.age_group not in ["young", "middle", "old"]:
		last_error = "Invalid age group."
		return false
	if changes.has("team_id"):
		var team_id = str(changes.team_id)
		if not teams.has(team_id) or teams[team_id].get("deleted", false) or not rooms.has(teams[team_id].room_id) or rooms[teams[team_id].room_id].get("deleted", false):
			last_error = "Choose an active workspace team."
			return false
	if changes.has("qa"):
		if not changes.qa is Array or changes.qa.size() > 200:
			last_error = "Questions and answers must be an array of at most 200 pairs."
			return false
		var existing: Dictionary = {}
		for pair in profile.get("qa", []):
			existing[pair.id] = pair
		var rows: Array = []
		var seen: Dictionary = {}
		for input in changes.qa:
			if not input is Dictionary or not input.get("question") is String or not input.get("answer") is String:
				last_error = "Every question and answer must be text."
				return false
			var id = str(input.get("id", ""))
			if id.is_empty():
				id = _unique_id("qa")
			var untranslated = existing.has(id) and input.question.strip_edges().is_empty() and input.answer.strip_edges().is_empty()
			if not untranslated and (not _text(input.question) or not _text(input.answer)):
				last_error = "Every new or translated question needs both a question and an answer."
				return false
			if seen.has(id):
				last_error = "Question IDs must be unique."
				return false
			seen[id] = true
			var pair = existing.get(id, {"id": id, "question": {"fi": "", "en": ""}, "answer": {"fi": "", "en": ""}}).duplicate(true)
			pair.question[selected] = input.question.strip_edges()
			pair.answer[selected] = input.answer.strip_edges()
			rows.append(pair)
		profile.qa = rows
	for field in ["title", "team_role", "expertise"]:
		if changes.has(field):
			profile[field][selected] = changes[field].strip_edges()
	var before = _before_edit()
	if changes.has("name"):
		entity.name[selected] = changes.name.strip_edges()
	entity.profile = profile
	if changes.has("age_group"): entity["age_group"] = changes.age_group
	if changes.has("team_id"): SpatialState.assign_team(self, entity_id, str(changes.team_id))
	entity["modifiedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	return _commit_edit(before, true)

func delete_person(entity_id: String) -> bool:
	if not entities.has(entity_id) or entities[entity_id].kind != "person":
		last_error = "Unknown person."
		return false
	return delete_entity(entity_id)

func rename_entity(entity_id: String, text_value: String) -> bool:
	if not entities.has(entity_id) or not _text(text_value):
		return false
	var before = _before_edit()
	entities[entity_id].name[language] = text_value.strip_edges()
	for item in pocket_items:
		if item.kind == "entity" and item.entity_id == entity_id: item.title = entities[entity_id].name
	return _commit_edit(before, true)

func rename_room(room_id: String, text_value: String) -> bool:
	if not rooms.has(room_id) or not _text(text_value):
		return false
	var before = _before_edit()
	rooms[room_id].name[language] = text_value.strip_edges()
	for item in pocket_items:
		if item.kind == "room" and item.room_id == room_id: item.title = rooms[room_id].name
	return SpatialState._commit_layout(self, before)

func pocket_list(board_id: String, lane_index: int, list_index: int) -> String:
	var lane = _lane(board_id, lane_index)
	if lane == null or list_index < 0 or list_index >= lane.lists.size():
		return ""
	var before = _before_edit()
	var item = {"id": _unique_id("pocket_list"), "kind": "list", "title": lane.lists[list_index], "cards": lane.cards[list_index]}
	lane.lists.remove_at(list_index)
	lane.cards.remove_at(list_index)
	# An empty replacement list keeps the source usable without copying a card.
	if lane.lists.is_empty():
		lane.lists.append({"fi": "Ideat", "en": "Ideas"})
		lane.cards.append([])
	pocket_items.append(item)
	return item.id if _commit_edit(before) else ""

func pocket_swimlane(board_id: String, lane_index: int) -> String:
	var lane = _lane(board_id, lane_index)
	if lane == null:
		return ""
	var before = _before_edit()
	var item = {"id": _unique_id("pocket_lane"), "kind": "swimlane", "lane_id": lane.id, "title": lane.title, "lists": lane.lists, "cards": lane.cards}
	boards[board_id].swimlanes.remove_at(lane_index)
	_canonicalize_board(boards[board_id])
	pocket_items.append(item)
	return item.id if _commit_edit(before) else ""

func place_pocket_item(item_id: String, board_id: String, target_lane: int = 0) -> bool:
	if not boards.has(board_id):
		return false
	var item = get_pocket_item(item_id)
	if item.is_empty():
		return false
	if item.kind == "board":
		var slot_id = board_id if board_slots.has(board_id) else str(boards[board_id].get("slot_id", ""))
		return place_pocket_board(item_id, slot_id)
	var destination = _lane(board_id, target_lane)
	if item.kind == "list" and destination == null:
		return false
	var before = _before_edit()
	if item.kind == "list":
		destination.lists.append(item.title)
		destination.cards.append(item.cards)
	else:
		boards[board_id].swimlanes.append({"id": item.get("lane_id", _unique_id(board_id + "_lane")), "title": item.title, "lists": item.lists, "cards": item.cards})
	pocket_items.erase(item)
	_canonicalize_board(boards[board_id])
	return _commit_edit(before)

func _pocket_board_internal(board_id: String) -> String:
	var board = boards[board_id]
	var slot_id = str(board.get("slot_id", ""))
	if slot_id.is_empty():
		return ""
	if board_slots.has(slot_id):
		board_slots[slot_id].board_id = ""
	board.slot_id = ""
	board.room_id = ""
	board.workspace_id = ""
	var item = {"id": _unique_id("pocket_board"), "kind": "board", "board_id": board_id, "title": board.title}
	pocket_items.append(item)
	return item.id

func pocket_board(board_id: String) -> String:
	if not boards.has(board_id) or str(boards[board_id].get("slot_id", "")).is_empty():
		return ""
	var before = _before_edit()
	var item_id = _pocket_board_internal(board_id)
	return item_id if _commit_edit(before) else ""

func place_pocket_board(item_id: String, slot_id: String) -> bool:
	var item = get_pocket_item(item_id)
	if item.is_empty() or item.kind != "board" or not board_slots.has(slot_id) or not boards.has(item.board_id):
		return false
	var before = _before_edit()
	var slot = board_slots[slot_id]
	if not str(slot.board_id).is_empty():
		_pocket_board_internal(slot.board_id)
	var board = boards[item.board_id]
	board.slot_id = slot_id
	board.room_id = slot.room_id
	board.workspace_id = slot.room_id
	board.organization_id = rooms.get(slot.room_id, {}).get("organization_id", "org_main")
	slot.board_id = board.id
	pocket_items.erase(item)
	return _commit_edit(before)

func visit_room(room_id: String) -> void:
	if room_id.is_empty() or visited_rooms.has(room_id):
		return
	visited_rooms[room_id] = true
	# Discovery statistics are included in the next save; explicit edits save now.
	stats_changed.emit()

func _valid_lines(lines) -> bool:
	if not lines is Array or lines.size() != 4:
		return false
	for line in lines:
		if not line is String or not _text(line):
			return false
	return true

func _before_edit() -> Dictionary:
	if not autosave_enabled:
		return {}
	return {"floors": floors.duplicate(true), "teams": teams.duplicate(true), "visited_rooms": visited_rooms.duplicate(true), "started_at": started_at, "elapsed_seconds": elapsed_seconds, "_board_specs": _board_specs.duplicate(true), "_slot_specs": _slot_specs.duplicate(true), "_room_specs": _room_specs.duplicate(true), "_entity_specs": _entity_specs.duplicate(true), "_organization_specs": _organization_specs.duplicate(true), "organizations": organizations.duplicate(true), "board_slots": board_slots.duplicate(true), "boards": boards.duplicate(true), "cards": cards.duplicate(true), "pocket": pocket.duplicate(), "pocket_items": pocket_items.duplicate(true), "rooms": rooms.duplicate(true), "entities": entities.duplicate(true)}

func _commit_edit(before: Dictionary, names_changed: bool = false) -> bool:
	if autosave_enabled and not save_game():
		if not before.is_empty():
			floors = before.floors
			teams = before.teams
			visited_rooms = before.visited_rooms
			started_at = before.started_at
			elapsed_seconds = before.elapsed_seconds
			_board_specs = before._board_specs
			_slot_specs = before._slot_specs
			_room_specs = before._room_specs
			_entity_specs = before._entity_specs
			_organization_specs = before._organization_specs
			organizations = before.organizations
			board_slots = before.board_slots
			boards = before.boards
			cards = before.cards
			pocket = before.pocket
			pocket_items = before.pocket_items
			rooms = before.rooms
			entities = before.entities
			for board in boards.values():
				_canonicalize_board(board)
			# Organization creation synchronously spawns scene nodes before saving.
			# Reconcile those views after rollback so failed saves leave no phantom
			# building, person, wall occupant or stale editor in the running scene.
			organizations_changed.emit()
			layout_changed.emit()
			entities_changed.emit()
			cards_changed.emit()
			stats_changed.emit()
		return false
	last_error = ""
	cards_changed.emit()
	stats_changed.emit()
	if names_changed:
		entities_changed.emit()
	return true

func validate_state() -> Array:
	return _validate_content(boards, cards, pocket, pocket_items)

func _is_translation(value) -> bool:
	return value is Dictionary and value.get("fi") is String and value.get("en") is String

func _valid_position(value) -> bool:
	if not value is Dictionary:
		return false
	for axis in ["x", "y", "z"]:
		var coordinate = value.get(axis)
		if (not coordinate is float and not coordinate is int) or not is_finite(float(coordinate)):
			return false
	return true

func _valid_profile(value) -> bool:
	if not value is Dictionary:
		return false
	for field in ["title", "team_role", "expertise"]:
		if not _is_translation(value.get(field)):
			return false
	if not value.get("qa") is Array or value.qa.size() > 200:
		return false
	var used: Dictionary = {}
	for pair in value.qa:
		if not pair is Dictionary or not pair.get("id") is String or pair.id.is_empty() or used.has(pair.id) or not _is_translation(pair.get("question")) or not _is_translation(pair.get("answer")):
			return false
		used[pair.id] = true
		for locale in ["fi", "en"]:
			if pair.question[locale].is_empty() != pair.answer[locale].is_empty():
				return false
	return true

func _count_location(card_id, candidate_cards: Dictionary, seen: Dictionary, problems: Array) -> void:
	if not card_id is String or not candidate_cards.has(card_id):
		problems.append("Unknown card in location: " + str(card_id))
	elif seen.has(card_id):
		problems.append("Card appears more than once: " + str(card_id))
	else:
		seen[card_id] = true

func _validate_lane(lane, candidate_cards: Dictionary, seen: Dictionary, problems: Array, label: String) -> void:
	if not lane is Dictionary or not _is_translation(lane.get("title")) or not lane.get("lists") is Array or not lane.get("cards") is Array:
		problems.append("Invalid swimlane: " + label)
		return
	if lane.lists.is_empty() or lane.lists.size() != lane.cards.size():
		problems.append("Swimlane list count mismatch: " + label)
		return
	for index in range(lane.lists.size()):
		if not _is_translation(lane.lists[index]) or not lane.cards[index] is Array:
			problems.append("Invalid list: " + label)
			continue
		for card_id in lane.cards[index]:
			_count_location(card_id, candidate_cards, seen, problems)

func _validate_content(candidate_boards, candidate_cards, candidate_pocket, candidate_items) -> Array:
	var problems: Array = []
	if not candidate_boards is Dictionary or not candidate_cards is Dictionary or not candidate_pocket is Array or not candidate_items is Array:
		return ["Boards, cards or pocket have the wrong type."]
	var seen: Dictionary = {}
	var lane_ids: Dictionary = {}
	for board_id in candidate_boards:
		var board = candidate_boards[board_id]
		if not board is Dictionary or board.get("id", "") != board_id or not _is_translation(board.get("title")) or not board.get("swimlanes") is Array or board.swimlanes.is_empty():
			problems.append("Invalid board: " + str(board_id))
			continue
		for lane in board.swimlanes:
			if not lane is Dictionary or not lane.get("id") is String or lane.id.is_empty() or lane_ids.has(lane.id):
				problems.append("Invalid/duplicate lane ID: " + str(board_id))
				continue
			lane_ids[lane.id] = true
			_validate_lane(lane, candidate_cards, seen, problems, str(board_id))
	for card_id in candidate_pocket:
		_count_location(card_id, candidate_cards, seen, problems)
	var item_ids: Dictionary = {}
	for item in candidate_items:
		if not item is Dictionary or not item.get("id") is String or item.id.is_empty() or item_ids.has(item.id) or not _is_translation(item.get("title")) or (item.get("kind", "") not in ["board", "entity", "building", "floor", "room"] and not item.get("cards") is Array):
			problems.append("Invalid pocket container.")
			continue
		item_ids[item.id] = true
		if item.get("kind", "") == "list":
			for card_id in item.cards:
				_count_location(card_id, candidate_cards, seen, problems)
		elif item.get("kind", "") == "swimlane":
			if not item.get("lane_id") is String or item.lane_id.is_empty() or lane_ids.has(item.lane_id):
				problems.append("Invalid/duplicate pocket lane ID.")
			else:
				lane_ids[item.lane_id] = true
			_validate_lane(item, candidate_cards, seen, problems, str(item.id))
		elif item.get("kind", "") == "board":
			if not candidate_boards.has(item.get("board_id", "")):
				problems.append("Pocket board is unknown.")
		elif item.get("kind", "") in ["entity", "building", "floor", "room"]:
			pass # Referential integrity is checked against the complete spatial graph.
		else:
			problems.append("Invalid pocket container kind.")
	for card_id in candidate_cards:
		var card = candidate_cards[card_id]
		if not card is Dictionary or card.get("id", "") != card_id or not card.get("lines") is Dictionary:
			problems.append("Invalid card: " + str(card_id))
			continue
		for lang in ["fi", "en"]:
			if not _valid_lines(card.lines.get(lang)):
				problems.append("Card must have four nonempty " + lang + " lines: " + str(card_id))
		if not seen.has(card_id):
			problems.append("Card has no location: " + str(card_id))
	return problems

func _snapshot() -> Dictionary:
	return {"version": SAVE_VERSION, "catalog_version": Catalog.CATALOG_VERSION, "language": language, "started_at": started_at, "elapsed_seconds": elapsed_seconds, "visited_rooms": visited_rooms, "organizations": organizations, "floors": floors, "teams": teams, "rooms": rooms, "entities": entities, "board_slots": board_slots, "boards": boards, "cards": cards, "pocket": pocket, "pocket_items": pocket_items}

func database_exists() -> bool:
	return _store.database_exists()

func save_game() -> bool:
	if storage_read_blocked:
		last_error = "The existing database could not be loaded and has been preserved."
		last_storage_error = last_error
		return false
	var errors = _validate_save(_snapshot())
	if not errors.is_empty():
		last_error = str(errors[0])
		last_storage_error = last_error
		return false
	if not _store.write_snapshot(_snapshot()):
		last_error = _store.last_error
		last_storage_error = last_error
		return false
	last_error = ""
	last_storage_error = ""
	return true

func load_game() -> bool:
	var existed = database_exists()
	var data = _store.read_snapshot()
	if data.is_empty():
		last_error = _store.last_error
		last_storage_error = last_error
		storage_read_blocked = existed
		return false
	var errors = _validate_save(data)
	if not errors.is_empty():
		last_error = str(errors[0])
		last_storage_error = last_error
		storage_read_blocked = existed
		return false
	organizations = data.organizations
	floors = data.get("floors", {})
	teams = data.get("teams", {})
	board_slots = data.board_slots
	boards = data.boards
	cards = data.cards
	pocket = data.pocket
	pocket_items = data.pocket_items
	rooms = data.rooms
	entities = data.entities
	visited_rooms = data.visited_rooms
	started_at = data.started_at
	elapsed_seconds = float(data.elapsed_seconds)
	for board in boards.values():
		_canonicalize_board(board)
	var previous_language = language
	language = data.language
	last_error = ""
	last_storage_error = ""
	storage_read_blocked = false
	if previous_language != language:
		language_changed.emit()
	cards_changed.emit()
	entities_changed.emit()
	organizations_changed.emit()
	layout_changed.emit()
	stats_changed.emit()
	return true

func _validate_save(data: Dictionary) -> Array:
	if data.get("version", -1) != SAVE_VERSION or data.get("catalog_version", -1) != Catalog.CATALOG_VERSION:
		return ["Unsupported save or catalog version."]
	if data.get("language", "") not in ["fi", "en"] or not data.get("started_at") is String or data.started_at.is_empty():
		return ["Invalid language or start timestamp."]
	var duration = data.get("elapsed_seconds", -1)
	if (not duration is float and not duration is int) or not is_finite(float(duration)) or float(duration) < 0.0:
		return ["Invalid elapsed time."]
	for field in ["organizations", "floors", "teams", "board_slots", "boards", "cards", "rooms", "entities", "visited_rooms"]:
		if not data.get(field) is Dictionary:
			return ["Invalid dictionary: " + field]
	if not data.get("pocket") is Array or not data.get("pocket_items") is Array:
		return ["Invalid pocket."]
	# User-added cards and lanes are valid. Fixed building and entity IDs must remain.
	for group in ["board_slots", "boards", "rooms", "entities"]:
		var defaults: Dictionary = _slot_specs if group == "board_slots" else (_board_specs if group == "boards" else (_room_specs if group == "rooms" else _entity_specs))
		for id in defaults:
			if not data[group].has(id):
				return ["Missing " + group + " record: " + str(id)]
	for org_id in data.organizations:
		var organization = data.organizations[org_id]
		if not organization is Dictionary or organization.get("id", "") != org_id or not _is_translation(organization.get("name")) or not _valid_position(organization.get("position")) or int(organization.get("building_index", -1)) < 0:
			return ["Invalid organization: " + str(org_id)]
	var placed: Dictionary = {}
	for slot_id in data.board_slots:
		var slot = data.board_slots[slot_id]
		if not slot is Dictionary or slot.get("id", "") != slot_id   or not data.rooms.has(slot.get("room_id", "")):
			return ["Invalid wall slot: " + str(slot_id)]
		var occupant = str(slot.get("board_id", ""))
		if not occupant.is_empty():
			if not data.boards.has(occupant) or placed.has(occupant):
				return ["Duplicate or unknown wall occupant."]
			var board = data.boards[occupant]
			if not board is Dictionary or board.get("slot_id", "") != slot_id or board.get("room_id", "") != slot.room_id:
				return ["Board does not match its wall slot."]
			placed[occupant] = true
	for item in data.pocket_items:
		if item is Dictionary and item.get("kind", "") == "board":
			var id = str(item.get("board_id", ""))
			if not data.boards.has(id) or placed.has(id):
				return ["Duplicate or unknown pocket board."]
			var board = data.boards[id]
			if not board is Dictionary or not str(board.get("room_id", "")).is_empty() or not str(board.get("slot_id", "")).is_empty():
				return ["Pocket board still has a wall location."]
			placed[id] = true
	if placed.size() != data.boards.size():
		return ["A board has no wall or pocket location."]
	for room_id in data.rooms:
		var room = data.rooms[room_id]
		if not room is Dictionary or room.get("id", "") != room_id or not _is_translation(room.get("name")) or not room.get("number") is String:
			return ["Invalid room metadata: " + str(room_id)]
		if not data.organizations.has(room.get("organization_id", "")):
			return ["Room references unknown organization: " + str(room_id)]
		if int(room.get("floor", 0)) < 1 or not data.floors.has(room.get("floor_id", "")):
			return ["Room floor does not match building: " + str(room_id)]
	for entity_id in data.entities:
		var entity = data.entities[entity_id]
		if not entity is Dictionary or entity.get("id", "") != entity_id or not _is_translation(entity.get("name")) or not _is_translation(entity.get("description")):
			return ["Invalid entity metadata: " + str(entity_id)]
		if entity.get("kind", "") not in ["furniture", "person", "fixture"] or not _valid_position(entity.get("position")):
			return ["Invalid entity kind or position: " + str(entity_id)]
		if entity.get("kind", "") == "person" and entity.has("profile") and not _valid_profile(entity.profile):
			return ["Invalid person profile: " + str(entity_id)]
	for room_id in data.visited_rooms:
		if not data.rooms.has(room_id) or data.visited_rooms[room_id] != true:
			return ["Invalid visited room: " + str(room_id)]
	var spatial_errors = _validate_spatial(data)
	if not spatial_errors.is_empty(): return spatial_errors
	return _validate_content(data.boards, data.cards, data.pocket, data.pocket_items)

func ensure_spatial_layout(org_id: String) -> void:
	SpatialState.ensure_layout(self, org_id)

func add_floor(org_id: String, name_value: String) -> String:
	return SpatialState.add_floor(self, org_id, name_value)

func rename_floor(id: String, name_value: String) -> bool:
	return SpatialState.rename_floor(self, id, name_value)

func delete_floor(id: String) -> bool:
	return SpatialState.delete_floor(self, id)

func add_room(floor_id: String, name_value: String) -> String:
	return SpatialState.add_room(self, floor_id, name_value)

func delete_room(id: String) -> bool:
	return SpatialState.delete_room(self, id)

func create_object(template: String, name_value: String, room_id: String, position: Vector3, org_id: String = "") -> String:
	return SpatialState.create_object(self, template, name_value, room_id, position, org_id)

func delete_entity(id: String) -> bool:
	return SpatialState.delete_entity(self, id)

func pocket_entity(id: String) -> String:
	return SpatialState.pocket_entity(self, id)

func pocket_building(id: String) -> String:
	return SpatialState.pocket_building(self, id)

func pocket_floor(id: String) -> String:
	return SpatialState.pocket_floor(self, id)

func pocket_room(id: String) -> String:
	return SpatialState.pocket_room(self, id)

func place_spatial_item(item_id: String, room_id: String, position: Vector3, org_id: String = "", target_floor_id: String = "", target_floor_number: int = -1) -> bool:
	return SpatialState.place_item(self, item_id, room_id, position, org_id, target_floor_id, target_floor_number)

func move_person_to_team(id: String, team_id: String) -> bool:
	return SpatialState.move_person_to_team(self, id, team_id)

func get_effective_pocket(kind: String, id: String) -> String:
	return SpatialState.effective_item(self, kind, id)

func entity_is_pocketed(id: String) -> bool:
	return not get_effective_pocket("entity", id).is_empty()

func effective_pocket_item_for_entity(id: String) -> String:
	return get_effective_pocket("entity", id)

func get_pocket_item_card_ids(id: String) -> Array:
	return SpatialState.item_card_ids(self, id)

func is_spatial_active(kind: String, id: String) -> bool:
	var collections = {"building": organizations, "organization": organizations, "floor": floors, "room": rooms, "entity": entities, "board": boards}
	if not collections.has(kind) or not collections[kind].has(id): return false
	var record = collections[kind][id]
	if record.get("deleted", false) or not get_effective_pocket("building" if kind == "organization" else kind, id).is_empty(): return false
	if kind in ["building", "organization"]: return true
	if kind == "floor": return is_spatial_active("building", str(record.organization_id))
	if kind == "room": return is_spatial_active("floor", str(record.floor_id))
	var room_id = str(record.get("room_id", ""))
	return is_spatial_active("room", room_id) if rooms.has(room_id) else is_spatial_active("building", str(record.get("organization_id", "org_main")))

func edit_entity_appearance(id: String, color_html: String, scale: Vector3) -> bool:
	if not entities.has(id) or entities[id].get("deleted", false) or not scale.is_finite() or scale.x <= 0 or scale.y <= 0 or scale.z <= 0:
		last_error = "Scale must contain three positive finite values."
		return false
	var color_value = color_html.trim_prefix("#")
	if not color_html.is_empty() and (color_value.length() not in [6, 8] or not color_value.is_valid_hex_number()):
		last_error = "Color must be a six- or eight-digit HTML color."
		return false
	var before = _before_edit()
	var appearance = entities[id].get("appearance", {}).duplicate(true)
	if not color_html.is_empty(): appearance["color"] = "#" + Color.from_string("#" + color_value, Color.WHITE).to_html(true)
	appearance["scale"] = _vector_dict(scale)
	entities[id]["appearance"] = appearance
	return _commit_edit(before, true)

func _guess_template(translated_name: Dictionary) -> String:
	var text_value = str(translated_name.get("en", "")).to_lower()
	for pair in [["desk", "desk"], ["chair", "chair"], ["monitor", "monitor"], ["computer", "monitor"], ["keyboard", "keyboard"], ["mouse", "mouse"], ["coffee mug", "mug"], ["notebook", "notebook"], ["sofa", "sofa"], ["bookshelf", "bookshelf"], ["plant", "plant"], ["bench", "bench"], ["light", "lamp"], ["cabinet", "cabinet"], ["printer", "printer"], ["tree", "tree"]]:
		if text_value.contains(pair[0]): return pair[1]
	return "cabinet"

func _validate_spatial(data: Dictionary) -> Array:
	var active_numbers: Dictionary = {}
	for id in data.floors:
		var floor = data.floors[id]
		if not floor is Dictionary or floor.get("id", "") != id or not _is_translation(floor.get("name")) or not data.organizations.has(floor.get("organization_id", "")) or int(floor.get("number", 0)) < 1:
			return ["Invalid floor: " + str(id)]
		if not floor.get("deleted", false) and not floor.get("in_pocket", false):
			var key = str(floor.organization_id) + ":" + str(floor.number)
			if active_numbers.has(key): return ["Two active floors have the same number."]
			active_numbers[key] = true
	for id in data.teams:
		var team = data.teams[id]
		if not team is Dictionary or team.get("id", "") != id or not _is_translation(team.get("name")) or not data.rooms.has(team.get("room_id", "")) or not data.organizations.has(team.get("organization_id", "")):
			return ["Invalid team: " + str(id)]
	var used: Dictionary = {}
	for item in data.pocket_items:
		if not item is Dictionary: continue
		var kind = str(item.get("kind", ""))
		if kind not in ["entity", "building", "floor", "room"]: continue
		var collection = {"entity": data.entities, "building": data.organizations, "floor": data.floors, "room": data.rooms}[kind]
		var id = str(item.get(SpatialState._reference_key(kind), ""))
		if not collection.has(id) or collection[id].get("deleted", false) or not collection[id].get("in_pocket", false) or used.has(kind + ":" + id):
			return ["Invalid or duplicate spatial pocket reference."]
		used[kind + ":" + id] = true
	for kind in ["entity", "building", "floor", "room"]:
		var collection = {"entity": data.entities, "building": data.organizations, "floor": data.floors, "room": data.rooms}[kind]
		for id in collection:
			if collection[id].get("in_pocket", false) and not used.has(kind + ":" + id): return ["Spatial record has no pocket container: " + str(id)]
	return []

func reset_game() -> void:
	var before = _before_edit()
	var specs = _board_specs.duplicate(true)
	boards.clear()
	board_slots = _slot_specs.duplicate(true)
	organizations = _organization_specs.duplicate(true)
	cards.clear()
	pocket.clear()
	pocket_items.clear()
	visited_rooms.clear()
	rooms = _room_specs.duplicate(true)
	entities = _entity_specs.duplicate(true)
	elapsed_seconds = 0.0
	_stat_clock = 0.0
	started_at = Time.get_datetime_string_from_system(false, false)
	for board_id in specs:
		ensure_board(board_id, specs[board_id].room_id, int(specs[board_id].topic))
	_commit_edit(before, true)
