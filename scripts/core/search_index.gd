extends RefCounted
## Search the persistent data directly so moved cards never have stale locations.
## No result cap: the view, not the search service, paginates the full result set.

const KINDS = ["room", "board", "swimlane", "list", "card", "furniture", "person", "record"]

static func search(query: String, state: Object, language: String = "") -> Array:
	if state == null:
		return []
	var words = normalize(query).split(" ", false)
	if words.is_empty():
		return []
	if language.is_empty():
		language = str(property_value(state, "language", "fi"))
	var rooms = dictionary_value(property_value(state, "rooms", {}))
	var boards = dictionary_value(property_value(state, "boards", {}))
	var cards = dictionary_value(property_value(state, "cards", {}))
	var entities = dictionary_value(property_value(state, "entities", {}))
	var organizations = dictionary_value(property_value(state, "organizations", {}))
	var floors = dictionary_value(property_value(state, "floors", {}))
	var teams = dictionary_value(property_value(state, "teams", {}))
	var pocket_items = property_value(state, "pocket_items", [])
	var records: Array = []
	for collection_name in ["rooms", "boards", "cards", "entities", "organizations", "floors", "teams"]:
		var collection = {"rooms": rooms, "boards": boards, "cards": cards, "entities": entities, "organizations": organizations, "floors": floors, "teams": teams}[collection_name]
		for record_id in collection:
			if not collection[record_id] is Dictionary:
				continue
			var data: Dictionary = collection[record_id]
			var kind = {"rooms": "room", "boards": "board", "cards": "card", "entities": str(data.get("kind", "record")), "organizations": "organization", "floors": "floor", "teams": "team"}[collection_name]
			if bool(data.get("deleted", false)):
				continue
			var result = make_result(str(record_id), kind, data, state, rooms, boards, language)
			var searchable: Array = [data]
			var organization_id = str(result.get("organization_id", ""))
			if not organization_id.is_empty():
				searchable.append(organizations.get(organization_id, {}))
			if not str(result.get("floor_id", "")).is_empty():
				searchable.append(floors.get(str(result.floor_id), {}))
			if not str(data.get("team_id", "")).is_empty():
				searchable.append(teams.get(str(data.team_id), {}))
			# Room/board context can be searched together with the actual object text.
			if not str(result.get("room_id", "")).is_empty():
				searchable.append(rooms.get(result.room_id, {}))
			if not str(result.get("board_id", "")).is_empty():
				var board: Dictionary = boards.get(result.board_id, {})
				searchable.append(board.get("title", ""))
				searchable.append(board.get("topic", ""))
				if kind == "card":
					var lane = board_lane(board, int(result.get("lane", 0)))
					searchable.append(lane.get("title", ""))
					var lists = lane.get("lists", [])
					var list_index = int(result.get("list", -1))
					if list_index >= 0 and list_index < lists.size():
						searchable.append(lists[list_index])
			searchable.append(result.title)
			searchable.append(result.detail)
			searchable.append(result.location)
			if int(result.get("floor", 0)) > 0:
				searchable.append("kerros %d floor %d" % [result.floor, result.floor])
			if result.get("pocket", false):
				searchable.append("tasku taskussa pocket inventory")
				if not str(result.get("item_id", "")).is_empty():
					searchable.append(find_pocket_item(pocket_items, str(result.item_id)))
			append_match(records, result, searchable, words)
			if kind == "board":
				append_board_structure(records, str(record_id), data, state, rooms, boards, language, words)
	if pocket_items is Array:
		for item in pocket_items:
			if not item is Dictionary:
				continue
			if item.get("kind", "") in ["board", "entity", "building", "floor", "room"]:
				continue # The actual referenced graph is indexed with its effective location.
			var data: Dictionary = item.duplicate(true)
			data["pocket"] = true
			data["room_id"] = ""
			data["floor"] = 0
			var result = make_result(str(data.get("id", "")), str(data.get("kind", "record")), data, state, rooms, boards, language)
			result["item_id"] = result.id
			append_match(records, result, [data, "tasku taskussa pocket inventory"], words)
	# Include future database collections and persistent session text automatically.
	# Only script fields are considered: engine internals are not database content.
	var session: Dictionary = {}
	for spec in state.get_property_list():
		var property_name = str(spec.name)
		if property_name.begins_with("_") or property_name in ["last_error"]:
			continue
		if property_name in ["rooms", "boards", "cards", "entities", "pocket_items", "organizations", "floors", "teams"]:
			continue
		if not (int(spec.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value = state.get(property_name)
		if value is Dictionary:
			for record_id in value:
				var data = value[record_id]
				if data is Dictionary:
					if bool(data.get("deleted", false)):
						continue
					var record = make_result(str(record_id), "record", data, state, rooms, boards, language)
					record["collection"] = property_name
					append_match(records, record, [data, record.title, record.location], words)
				else:
					session[property_name + ":" + str(record_id)] = data
		elif value is Array or value is String or value is StringName or value is int or value is float or value is bool:
			session[property_name] = value
	if not session.is_empty():
		var session_record = {
			"kind": "record", "id": "session", "title": "Pelin tiedot" if language == "fi" else "Game details",
			"room_id": "", "floor": 0, "detail": localized(session.get("started_at", ""), language),
			"location": "Tallennettu peli" if language == "fi" else "Saved game", "collection": "session", "organization_id": "", "organization_name": ""
		}
		append_match(records, session_record, [session], words)
	# Equal scores sort reproducibly by title, kind, and stable record ID.
	records.sort_custom(func(a, b):
		if a._score != b._score:
			return a._score > b._score
		var left = normalize(a.title) + "|" + a.kind + "|" + a.id
		var right = normalize(b.title) + "|" + b.kind + "|" + b.id
		return left < right)
	for record in records:
		record.erase("_score")
	return records

static func append_board_structure(records: Array, board_id: String, board: Dictionary, state: Object, rooms: Dictionary, boards: Dictionary, language: String, words: PackedStringArray) -> void:
	var lanes = board.get("swimlanes", [])
	if not lanes is Array:
		return
	for lane_index in range(lanes.size()):
		if not lanes[lane_index] is Dictionary:
			continue
		var lane: Dictionary = lanes[lane_index]
		var spec = {"title": lane.get("title", ""), "room_id": board.get("room_id", ""), "board_id": board_id, "lane": lane_index, "position": board.get("position", null)}
		var pocket_board = find_pocket_board(property_value(state, "pocket_items", []), board_id)
		if not pocket_board.is_empty():
			spec["pocket"] = true
			spec["item_id"] = str(pocket_board.id)
			spec["room_id"] = ""
		var lane_id = str(lane.get("id", board_id + ":lane:" + str(lane_index)))
		var lane_result = make_result(lane_id, "swimlane", spec, state, rooms, boards, language)
		lane_result["lane"] = lane_index
		var context = [board.get("title", ""), rooms.get(str(spec.room_id), {}), lane_result.location, "kerros %d floor %d" % [lane_result.floor, lane_result.floor]]
		context.append(dictionary_value(property_value(state, "organizations", {})).get(str(lane_result.organization_id), {}))
		if lane_result.get("pocket", false):
			context.append("tasku taskussa pocket inventory")
		append_match(records, lane_result, [lane, context], words)
		var lists = lane.get("lists", [])
		for list_index in range(lists.size()):
			var list_spec = spec.duplicate(true)
			list_spec["title"] = lists[list_index]
			list_spec["list"] = list_index
			var list_result = make_result(board_id + ":lane:" + str(lane_index) + ":list:" + str(list_index), "list", list_spec, state, rooms, boards, language)
			list_result["lane"] = lane_index
			list_result["list"] = list_index
			list_result["detail"] = localized(lane.get("title", ""), language)
			append_match(records, list_result, [lists[list_index], lane.get("title", ""), context], words)

static func append_match(results: Array, result: Dictionary, searchable: Array, words: PackedStringArray) -> void:
	var fragments: Array = []
	collect_text(searchable, fragments)
	var haystack = normalize(" ".join(fragments))
	for word in words:
		if not haystack.contains(word):
			return
	var title = normalize(result.title)
	var score = 0
	for word in words:
		if title.contains(word):
			score += 10
		if title == word:
			score += 10
	if result.kind == "room":
		score += 2
	result["_score"] = score
	results.append(result)

static func make_result(id: String, kind: String, data: Dictionary, state: Object, rooms: Dictionary, boards: Dictionary, language: String) -> Dictionary:
	var room_id = str(data.get("room_id", ""))
	if kind == "room":
		room_id = id
	var board_id = str(data.get("board_id", ""))
	var pocket = bool(data.get("pocket", false))
	var item_id = str(data.get("item_id", ""))
	var container_kind = ""
	var lane_index = int(data.get("lane", 0))
	var list_index = int(data.get("list", -1))
	if kind == "board":
		board_id = id
		var pocket_board = find_pocket_board(property_value(state, "pocket_items", []), id)
		if not pocket_board.is_empty():
			pocket = true
			item_id = str(pocket_board.id)
			room_id = ""
	elif kind == "card":
		var current: Dictionary = {}
		if state.has_method("get_card_location"):
			current = state.call("get_card_location", id)
		else:
			current = find_card_location(id, state, boards)
		pocket = bool(current.get("pocket", false))
		item_id = str(current.get("item_id", ""))
		container_kind = str(current.get("kind", ""))
		board_id = str(current.get("board_id", ""))
		list_index = int(current.get("list", -1))
		lane_index = int(current.get("lane", 0))
		room_id = "" if pocket else str(dictionary_value(boards.get(board_id, {})).get("room_id", ""))
	var spatial_kind = {"organization": "building", "person": "entity", "furniture": "entity", "fixture": "entity", "swimlane": "board", "list": "board", "card": "board"}.get(kind, kind)
	var spatial_id = board_id if spatial_kind == "board" and not board_id.is_empty() else id
	var effective = effective_pocket(state, str(spatial_kind), spatial_id, data, rooms, boards)
	if not effective.is_empty() and (not pocket or item_id.is_empty()):
		pocket = true
		item_id = str(effective.get("id", ""))
		container_kind = str(effective.get("kind", ""))
	if pocket and container_kind.is_empty():
		container_kind = str(find_pocket_item(property_value(state, "pocket_items", []), item_id).get("kind", ""))
	if kind == "card" and pocket and container_kind in ["building", "floor", "room"]:
		room_id = str(dictionary_value(boards.get(board_id, {})).get("room_id", ""))
	if spatial_kind == "entity" and container_kind == "entity":
		room_id = ""
	var room: Dictionary = rooms.get(room_id, {})
	var floor_id = id if kind == "floor" else str(room.get("floor_id", data.get("floor_id", "")))
	var organization_id = str(room.get("organization_id", data.get("organization_id", "")))
	if kind == "organization":
		organization_id = id
	elif not board_id.is_empty():
		organization_id = str(room.get("organization_id", dictionary_value(boards.get(board_id, {})).get("organization_id", organization_id)))
	elif kind == "card" and pocket:
		organization_id = ""
	var organization: Dictionary = dictionary_value(property_value(state, "organizations", {})).get(organization_id, {})
	var organization_name = localized(organization.get("name", organization_id), language)
	var floor_number = int(data.get("floor", room.get("floor", 0)))
	if kind == "floor":
		floor_number = int(data.get("number", 0))
	if pocket and container_kind not in ["building", "floor", "room"]:
		floor_number = 0
	if kind == "card":
		floor_number = 0 if pocket and container_kind not in ["building", "floor", "room"] else int(room.get("floor", 0))
	var title = localized(data.get("name", data.get("title", "")), language)
	var detail = localized(data.get("description", ""), language)
	if kind == "person":
		var profile = dictionary_value(data.get("profile", {}))
		var profile_parts: Array = []
		for field in ["title", "team_role", "expertise"]:
			var value = localized(profile.get(field, ""), language)
			if not value.is_empty():
				profile_parts.append(value)
		if not detail.is_empty():
			profile_parts.append(detail)
		detail = " · ".join(profile_parts)
	if kind == "card":
		var lines = data.get("lines", {})
		var localized_lines = lines.get(language, lines.get("en", lines.get("fi", []))) if lines is Dictionary else lines
		if localized_lines is Array and not localized_lines.is_empty():
			title = str(localized_lines[0])
			detail = " · ".join(localized_lines.slice(1))
		var localized_details = data.get("localized_details", {}).get(language, {})
		if localized_details is Dictionary:
			title = str(localized_details.get("title", title))
			detail = str(localized_details.get("description", detail))
	if title.is_empty():
		title = id
	var room_name = localized(room.get("name", room.get("title", room_id)), language)
	var room_number = str(room.get("number", ""))
	var location_parts: PackedStringArray = []
	if not organization_name.is_empty():
		location_parts.append(organization_name)
	if floor_number > 0:
		location_parts.append(("Kerros %d" if language == "fi" else "Floor %d") % floor_number)
	if not room_name.is_empty():
		location_parts.append(room_name + (" (" + room_number + ")" if not room_number.is_empty() and not room_name.contains(room_number) else ""))
	if kind in ["card", "swimlane", "list"] and not board_id.is_empty():
		var board: Dictionary = boards.get(board_id, {})
		location_parts.append(localized(board.get("title", board_id), language))
		var lane = board_lane(board, lane_index)
		var lane_title = localized(lane.get("title", ""), language)
		if not lane_title.is_empty():
			location_parts.append(lane_title)
		var lists = lane.get("lists", [])
		if list_index >= 0 and list_index < lists.size():
			location_parts.append(localized(lists[list_index], language))
	if pocket:
		location_parts.append("Taskussa" if language == "fi" else "In pocket")
		if not item_id.is_empty():
			var item = find_pocket_item(property_value(state, "pocket_items", []), item_id)
			location_parts.append(localized(item.get("title", item_id), language))
			var item_lists = item.get("lists", [])
			if list_index >= 0 and list_index < item_lists.size():
				location_parts.append(localized(item_lists[list_index], language))
	if location_parts.is_empty():
		location_parts.append(("Toimistorakennus" if language == "fi" else "Office building") if kind == "organization" else ("Tallennetut tiedot" if language == "fi" else "Saved data"))
	var result = {
		"kind": kind, "id": id, "title": title, "room_id": room_id,
		"organization_id": organization_id, "organization_name": organization_name,
		"floor_id": floor_id, "template": str(data.get("template", "")), "team_id": str(data.get("team_id", "")), "entity_id": id if spatial_kind == "entity" else "",
		"floor": floor_number, "detail": detail, "location": "  /  ".join(location_parts),
		"board_id": board_id, "pocket": pocket, "list": list_index, "lane": lane_index, "item_id": item_id, "container_kind": container_kind
	}
	var position = data.get("position", null)
	if kind == "card":
		position = null if pocket else dictionary_value(boards.get(board_id, {})).get("position", room.get("position", room.get("center", null)))
	elif position == null:
		position = data.get("center", room.get("position", room.get("center", null)))
	if kind == "floor" and position == null and organization.get("position") is Dictionary:
		position = organization.position.duplicate(true)
		position["y"] = float(position.get("y", 0.0)) + maxf(0.0, float(floor_number - 1)) * 4.0
	if position != null and not pocket:
		result["position"] = position
	return result

static func find_card_location(card_id: String, state: Object, boards: Dictionary) -> Dictionary:
	var pocket = property_value(state, "pocket", [])
	if pocket is Array and pocket.has(card_id):
		return {"pocket": true, "index": pocket.find(card_id)}
	var items = property_value(state, "pocket_items", [])
	if items is Array:
		for item in items:
			if not item is Dictionary:
				continue
			if item.get("kind", "") == "board":
				var carried_id = str(item.get("board_id", ""))
				var carried_board = dictionary_value(boards.get(carried_id, {}))
				var carried_lanes = carried_board.get("swimlanes", [carried_board])
				for lane_index in range(carried_lanes.size()):
					var carried_columns = dictionary_value(carried_lanes[lane_index]).get("cards", [])
					for list_index in range(carried_columns.size()):
						if carried_columns[list_index] is Array and carried_columns[list_index].has(card_id):
							return {"pocket": true, "item_id": str(item.get("id", "")), "kind": "board", "board_id": carried_id, "lane": lane_index, "list": list_index, "index": carried_columns[list_index].find(card_id)}
				continue
			var columns = item.get("cards", [])
			if str(item.get("kind", "")) == "list":
				columns = [columns]
			for list_index in range(columns.size()):
				if columns[list_index] is Array and columns[list_index].has(card_id):
					return {"pocket": true, "item_id": str(item.get("id", "")), "kind": str(item.get("kind", "")), "lane": 0, "list": list_index, "index": columns[list_index].find(card_id)}
	for board_id in boards:
		var board = dictionary_value(boards[board_id])
		var lanes = board.get("swimlanes", [board])
		for lane_index in range(lanes.size()):
			var columns = dictionary_value(lanes[lane_index]).get("cards", [])
			for list_index in range(columns.size()):
				if columns[list_index] is Array and columns[list_index].has(card_id):
					return {"board_id": board_id, "lane": lane_index, "list": list_index, "index": columns[list_index].find(card_id)}
	return {}

static func board_lane(board: Dictionary, lane_index: int) -> Dictionary:
	var lanes = board.get("swimlanes", [])
	if lanes is Array and lane_index >= 0 and lane_index < lanes.size():
		return dictionary_value(lanes[lane_index])
	return board

static func find_pocket_item(items, item_id: String) -> Dictionary:
	if items is Array:
		for item in items:
			if item is Dictionary and str(item.get("id", "")) == item_id:
				return item
	return {}

static func find_pocket_board(items, board_id: String) -> Dictionary:
	if items is Array:
		for item in items:
			if item is Dictionary and item.get("kind", "") == "board" and str(item.get("board_id", "")) == board_id:
				return item
	return {}

static func effective_pocket(state: Object, kind: String, id: String, data: Dictionary, rooms: Dictionary, boards: Dictionary) -> Dictionary:
	var items = property_value(state, "pocket_items", [])
	if state.has_method("get_effective_pocket") and kind in ["entity", "board", "room", "floor", "building"]:
		var item_id = str(state.call("get_effective_pocket", kind, id))
		if not item_id.is_empty():
			return find_pocket_item(items, item_id)
	var record = dictionary_value(boards.get(id, {})) if kind == "board" else data
	var room_id = id if kind == "room" else str(record.get("room_id", ""))
	var room = dictionary_value(rooms.get(room_id, {}))
	var floor_id = id if kind == "floor" else str(room.get("floor_id", record.get("floor_id", "")))
	var organization_id = id if kind == "building" else str(room.get("organization_id", record.get("organization_id", "")))
	var keys: Array = []
	if kind in ["entity", "board"]:
		keys.append([kind, ("entity_id" if kind == "entity" else "board_id"), id])
	if not room_id.is_empty():
		keys.append(["room", "room_id", room_id])
	if not floor_id.is_empty():
		keys.append(["floor", "floor_id", floor_id])
	if not organization_id.is_empty():
		keys.append(["building", "organization_id", organization_id])
	if items is Array:
		for key in keys:
			for item in items:
				if item is Dictionary and str(item.get("kind", "")) == key[0] and str(item.get(key[1], "")) == key[2]:
					return item
	return {}

static func dictionary_value(value) -> Dictionary:
	return value if value is Dictionary else {}

static func property_value(state: Object, property_name: String, fallback):
	if state == null:
		return fallback
	for spec in state.get_property_list():
		if str(spec.name) == property_name:
			return state.get(property_name)
	return fallback

static func localized(value, language: String) -> String:
	if value is Dictionary:
		return str(value.get(language, value.get("en", value.get("fi", ""))))
	return str(value) if value != null else ""

static func collect_text(value, output: Array) -> void:
	if value is Dictionary:
		for key in value:
			collect_text(value[key], output)
	elif value is Array or value is PackedStringArray:
		for item in value:
			collect_text(item, output)
	elif value is String or value is StringName or value is int or value is float or value is bool:
		output.append(str(value))

static func normalize(value: String) -> String:
	var normalized = value.to_lower().replace("ä", "a").replace("ö", "o").replace("å", "a")
	for separator in ["\t", "\n", "\r", ",", ";", ":", "/", "\\", "(", ")", "[", "]", "\"", "'", "—", "–"]:
		normalized = normalized.replace(separator, " ")
	return normalized.strip_edges()
