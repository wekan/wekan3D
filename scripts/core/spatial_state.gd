extends RefCounted
## Spatial graph rules. References are stable; pocket containers never copy graphs.
const TEMPLATES = ["desk", "chair", "monitor", "plant", "sofa", "bookshelf", "tree", "car", "bench", "bicycle", "moped", "motorcycle", "rollator", "cat", "dog", "cow", "horse", "chicken", "newspaper", "coffee_cup", "plate", "spoon", "drinking_glass", "book", "table", "cabinet", "lamp", "printer", "keyboard", "mouse", "mug", "notebook", "road", "flower"]
const ROOM_FI = ["Ajoneuvolaboratorio", "Ohjelmistostudio", "Robotiikkahuone", "Tuotesuunnittelu", "Pilvipalvelut", "Testausstudio", "Mobiilikehitys", "Verkkopalvelut", "Datastudio", "Turvallisuushuone", "Pelikehitys", "Muotoiluhuone", "Energiastudio", "Tutkimuslaboratorio", "Asiakaspalvelut", "Tulevaisuushuone"]
const ROOM_EN = ["Vehicle laboratory", "Software studio", "Robotics room", "Product design", "Cloud services", "Testing studio", "Mobile development", "Web services", "Data studio", "Security room", "Game development", "Design room", "Energy studio", "Research laboratory", "Customer services", "Future studio"]

static func slot_position(slot: int, floor_number: int = 1) -> Vector3:
	var y = (floor_number - 1) * 4.0
	if slot < 4:
		return Vector3(-9 if slot < 2 else 9, y, -6.5 if slot % 2 == 0 else 6.5)
	return Vector3(-9 if slot % 2 == 0 else 9, y, -6.5 - 12.0 * (1 + int((slot - 4) / 2)))

static func vector(value) -> Vector3:
	if value is Vector3: return value
	return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0))) if value is Dictionary else Vector3.ZERO

static func active_floors(s, org_id: String) -> Array:
	var result: Array = []
	for floor in s.floors.values():
		if floor.organization_id == org_id and not floor.get("deleted", false) and not floor.get("in_pocket", false): result.append(floor)
	result.sort_custom(func(a, b): return int(a.number) < int(b.number))
	return result

static func ensure_layout(s, org_id: String) -> void:
	if not s.organizations.has(org_id): return
	for floor in s.floors.values():
		if floor.organization_id == org_id: return
	var existing: Array = []
	for room in s.rooms.values():
		if room.organization_id == org_id: existing.append(room)
	if not existing.is_empty():
		for room in existing:
			ensure_room(s, room)
		return
	for number in range(1, 5):
		var floor_id = org_id + "_floor_" + str(number)
		s.floors[floor_id] = _floor(floor_id, org_id, number)
		for slot in range(4):
			var prefix = "" if org_id == "org_main" else org_id + "_"
			var room_id = prefix + "room_%d%02d" % [number, slot + 1]
			_seed_room(s, room_id, floor_id, slot, {"fi": ROOM_FI[(number - 1) * 4 + slot], "en": ROOM_EN[(number - 1) * 4 + slot]})

static func _floor(id: String, org: String, number: int) -> Dictionary:
	return {"id": id, "organization_id": org, "name": {"fi": "Kerros " + str(number), "en": "Floor " + str(number)}, "number": number, "deleted": false, "in_pocket": false}

static func ensure_room(s, room: Dictionary) -> void:
	var org_id = str(room.get("organization_id", "org_main"))
	var number = int(room.get("floor", 1))
	var floor_id = str(room.get("floor_id", org_id + "_floor_" + str(number)))
	if not s.floors.has(floor_id): s.floors[floor_id] = _floor(floor_id, org_id, number)
	room["floor_id"] = floor_id
	if not room.has("slot_index"):
		var ordinal = 0
		for other in s.rooms.values():
			if other.id != room.id and other.get("floor_id", "") == floor_id: ordinal += 1
		room["slot_index"] = ordinal
	room["deleted"] = room.get("deleted", false)
	room["in_pocket"] = room.get("in_pocket", false)
	var team_id = "team_" + str(room.id)
	if not s.teams.has(team_id):
		s.teams[team_id] = {"id": team_id, "organization_id": org_id, "room_id": room.id, "name": {"fi": "Tiimi " + str(room.number), "en": "Team " + str(room.number)}}
	room["team_id"] = room.get("team_id", team_id)

static func _seed_room(s, id: String, floor_id: String, slot: int, name: Dictionary) -> void:
	var floor = s.floors[floor_id]
	var org = s.organizations[floor.organization_id]
	var pos = vector(org.position) + slot_position(slot, int(floor.number))
	s.rooms[id] = {"id": id, "workspace_id": id, "organization_id": org.id, "floor_id": floor_id, "floor": floor.number, "slot_index": slot, "number": "%d%02d" % [int(floor.number), slot + 1], "name": name, "topic": posmod((int(floor.number) - 1) * 16 + slot * 4, 64), "position": s._vector_dict(pos), "deleted": false, "in_pocket": false}
	ensure_room(s, s.rooms[id])

static func add_floor(s, org_id: String, name: String) -> String:
	if not s.organizations.has(org_id) or s.organizations[org_id].get("deleted", false) or not s._text(name): return ""
	ensure_layout(s, org_id)
	var before = s._before_edit()
	var number = active_floors(s, org_id).size() + 1
	var id = s._unique_id(org_id + "_floor")
	s.floors[id] = _floor(id, org_id, number)
	s.floors[id].name = s._translated(name)
	for slot in range(4): _seed_room(s, s._unique_id("room"), id, slot, {"fi": "Toimisto %d%02d" % [number, slot + 1], "en": "Office %d%02d" % [number, slot + 1]})
	return id if _commit_layout(s, before) else ""

static func rename_floor(s, id: String, name: String) -> bool:
	if not s.floors.has(id) or s.floors[id].get("deleted", false) or not s._text(name): return false
	var before = s._before_edit()
	s.floors[id].name[s.language] = name.strip_edges()
	return _commit_layout(s, before)

static func add_room(s, floor_id: String, name: String) -> String:
	if not s.floors.has(floor_id) or s.floors[floor_id].get("deleted", false) or not s._text(name): return ""
	var before = s._before_edit()
	var slot = _next_slot(s, floor_id)
	var id = s._unique_id("room")
	_seed_room(s, id, floor_id, slot, s._translated(name))
	return id if _commit_layout(s, before) else ""

static func _next_slot(s, floor_id: String) -> int:
	var used: Dictionary = {}
	for room in s.rooms.values():
		if room.floor_id == floor_id and not room.get("deleted", false) and not room.get("in_pocket", false): used[int(room.slot_index)] = true
	var slot = 0
	while used.has(slot): slot += 1
	return slot

static func _commit_layout(s, before: Dictionary) -> bool:
	# Root finishes structural meshes and registers all new defaults before save.
	s.layout_changed.emit()
	return s._commit_edit(before, true)

static func delete_floor(s, id: String) -> bool:
	if not s.floors.has(id) or s.floors[id].get("deleted", false): return false
	var floor = s.floors[id]
	if not floor.get("in_pocket", false) and active_floors(s, floor.organization_id).size() <= 1:
		s.last_error = "The last active floor cannot be deleted."
		return false
	var before = s._before_edit()
	for room in s.rooms.values():
		if room.floor_id == id and not room.get("deleted", false): _delete_room(s, room.id)
	_remove_reference(s, "floor", id)
	floor.deleted = true
	floor.in_pocket = false
	relayout(s, floor.organization_id)
	return _commit_layout(s, before)

static func delete_room(s, id: String) -> bool:
	if not s.rooms.has(id) or s.rooms[id].get("deleted", false): return false
	var before = s._before_edit()
	_delete_room(s, id)
	return _commit_layout(s, before)

static func _delete_room(s, id: String) -> void:
	for board in s.boards.values():
		if board.room_id == id and not str(board.get("slot_id", "")).is_empty(): s._pocket_board_internal(board.id)
	for entity in s.entities.values():
		if entity.get("room_id", "") == id and not entity.get("deleted", false) and not entity.get("in_pocket", false): _pocket_entity(s, entity.id)
	for slot in s.board_slots.values():
		if slot.room_id == id: slot["deleted"] = true
	_remove_reference(s, "room", id)
	s.rooms[id].deleted = true
	s.rooms[id].in_pocket = false
	for team in s.teams.values():
		if team.room_id == id: team["deleted"] = true

static func create_object(s, template: String, name: String, room_id: String, position: Vector3, org_id: String = "") -> String:
	if template not in TEMPLATES or not s._text(name):
		s.last_error = "Choose a supported object type and a name."
		return ""
	if not room_id.is_empty():
		if not s.rooms.has(room_id) or s.rooms[room_id].get("deleted", false): return ""
		org_id = s.rooms[room_id].organization_id
	if org_id.is_empty(): org_id = "org_main"
	if not s.organizations.has(org_id) or s.organizations[org_id].get("deleted", false) or not position.is_finite(): return ""
	var before = s._before_edit()
	var id = s._unique_id("object_" + template)
	var room = s.rooms.get(room_id, {})
	s.entities[id] = {"id": id, "kind": "furniture", "template": template, "name": s._translated(name), "description": {"fi": "Siirrettävä kohde: " + template, "en": "Portable object: " + template}, "room_id": room_id, "organization_id": org_id, "floor_id": room.get("floor_id", ""), "floor": int(room.get("floor", 1)), "position": s._vector_dict(position), "deleted": false, "in_pocket": false, "custom": true}
	return id if s._commit_edit(before, true) else ""

static func delete_entity(s, id: String) -> bool:
	if not s.entities.has(id): return false
	if s.entities[id].get("deleted", false): return true
	var before = s._before_edit()
	_remove_reference(s, "entity", id)
	s.entities[id]["deleted"] = true
	s.entities[id]["in_pocket"] = false
	s.entities[id]["deletedAt"] = Time.get_datetime_string_from_system(true) + "Z"
	return s._commit_edit(before, true)

static func _reference_key(kind: String) -> String:
	return {"entity": "entity_id", "building": "organization_id", "floor": "floor_id", "room": "room_id", "board": "board_id"}.get(kind, "")

static func _remove_reference(s, kind: String, id: String) -> void:
	var field = _reference_key(kind)
	for index in range(s.pocket_items.size() - 1, -1, -1):
		var item = s.pocket_items[index]
		if item.kind == kind and str(item.get(field, "")) == id: s.pocket_items.remove_at(index)

static func _append_reference(s, kind: String, id: String, title: Dictionary) -> String:
	var item = {"id": s._unique_id("pocket_" + kind), "kind": kind, "title": title}
	item[_reference_key(kind)] = id
	s.pocket_items.append(item)
	return item.id

static func _pocket_entity(s, id: String) -> String:
	var entity = s.entities[id]
	entity["in_pocket"] = true
	return _append_reference(s, "entity", id, entity.name)

static func pocket_entity(s, id: String) -> String:
	if not s.entities.has(id) or s.entities[id].get("deleted", false) or s.entities[id].get("in_pocket", false): return ""
	var before = s._before_edit()
	var item = _pocket_entity(s, id)
	return item if s._commit_edit(before, true) else ""

static func pocket_building(s, id: String) -> String:
	if not s.organizations.has(id) or s.organizations[id].get("deleted", false) or s.organizations[id].get("in_pocket", false): return ""
	var before = s._before_edit()
	s.organizations[id]["in_pocket"] = true
	var item = _append_reference(s, "building", id, s.organizations[id].name)
	return item if _commit_layout(s, before) else ""

static func pocket_floor(s, id: String) -> String:
	if not s.floors.has(id) or s.floors[id].get("deleted", false) or s.floors[id].get("in_pocket", false): return ""
	var floor = s.floors[id]
	if active_floors(s, floor.organization_id).size() <= 1:
		s.last_error = "The last active floor cannot be pocketed. Pocket the whole building instead."
		return ""
	var before = s._before_edit()
	floor.in_pocket = true
	var item = _append_reference(s, "floor", id, floor.name)
	relayout(s, floor.organization_id)
	return item if _commit_layout(s, before) else ""

static func pocket_room(s, id: String) -> String:
	if not s.rooms.has(id) or s.rooms[id].get("deleted", false) or s.rooms[id].get("in_pocket", false): return ""
	var before = s._before_edit()
	s.rooms[id].in_pocket = true
	var item = _append_reference(s, "room", id, s.rooms[id].name)
	return item if _commit_layout(s, before) else ""

static func effective_item(s, kind: String, id: String) -> String:
	var field = _reference_key(kind)
	for item in s.pocket_items:
		if item.kind == kind and str(item.get(field, "")) == id: return item.id
	match kind:
		"board":
			return effective_item(s, "room", str(s.boards.get(id, {}).get("room_id", "")))
		"entity":
			var entity = s.entities.get(id, {})
			var room_id = str(entity.get("room_id", ""))
			return effective_item(s, "room", room_id) if not room_id.is_empty() else effective_item(s, "building", str(entity.get("organization_id", "")))
		"room":
			var room = s.rooms.get(id, {})
			return effective_item(s, "floor", str(room.get("floor_id", ""))) if room.has("floor_id") else effective_item(s, "building", str(room.get("organization_id", "")))
		"floor":
			return effective_item(s, "building", str(s.floors.get(id, {}).get("organization_id", "")))
	return ""

static func item_card_ids(s, item_id: String) -> Array:
	var item = s.get_pocket_item(item_id)
	var result: Array = []
	if item.is_empty(): return result
	if item.kind == "list": return item.cards.duplicate()
	if item.kind == "swimlane":
		for list_cards in item.cards: result.append_array(list_cards)
		return result
	for board in s.boards.values():
		if effective_item(s, "board", board.id) != item_id: continue
		for lane in board.swimlanes:
			for list_cards in lane.cards: result.append_array(list_cards)
	return result

static func move_person_to_team(s, id: String, team_id: String) -> bool:
	if not s.entities.has(id) or s.entities[id].kind != "person" or s.entities[id].get("deleted", false) or not s.teams.has(team_id) or s.teams[team_id].get("deleted", false): return false
	var room_id = str(s.teams[team_id].room_id)
	if not s.rooms.has(room_id) or s.rooms[room_id].get("deleted", false): return false
	var before = s._before_edit()
	assign_team(s, id, team_id)
	return s._commit_edit(before, true)

static func assign_team(s, id: String, team_id: String) -> void:
	var entity = s.entities[id]
	var room = s.rooms[s.teams[team_id].room_id]
	_remove_reference(s, "entity", id)
	entity["in_pocket"] = false
	entity["team_id"] = team_id
	entity.room_id = room.id
	entity.organization_id = room.organization_id
	entity["floor_id"] = room.floor_id
	entity.floor = room.floor
	entity.position = room.position.duplicate(true)

static func place_item(s, item_id: String, room_id: String, position: Vector3, org_id: String = "", floor_id: String = "", floor_number: int = -1) -> bool:
	var item = s.get_pocket_item(item_id)
	if item.is_empty() or not position.is_finite(): return false
	if not room_id.is_empty() and s.rooms.has(room_id):
		if s.rooms[room_id].get("deleted", false): return false
		if org_id.is_empty(): org_id = s.rooms[room_id].organization_id
		if floor_id.is_empty(): floor_id = s.rooms[room_id].floor_id
	if org_id.is_empty() and s.organizations.has("org_main"): org_id = "org_main"
	if not s.organizations.has(org_id) or s.organizations[org_id].get("deleted", false): return false
	if item.kind == "room" and (not s.floors.has(floor_id) or s.floors[floor_id].get("deleted", false) or s.floors[floor_id].get("in_pocket", false)): return false
	if item.kind == "entity" and not room_id.is_empty() and not s.rooms.has(room_id): return false
	if item.kind not in ["entity", "building", "floor", "room"]: return false
	var before = s._before_edit()
	match item.kind:
		"entity":
			var entity = s.entities[item.entity_id]
			entity["in_pocket"] = false
			entity.room_id = room_id
			entity.organization_id = org_id
			entity.position = s._vector_dict(position)
			entity["floor_id"] = floor_id
			entity.floor = int(s.floors.get(floor_id, {}).get("number", 1))
			if entity.kind == "person" and s.rooms.has(room_id): entity["team_id"] = s.rooms[room_id].team_id
		"building":
			var org = s.organizations[item.organization_id]
			var occupied: Dictionary = {}
			for other in s.organizations.values():
				if other.id != org.id and not other.get("in_pocket", false) and not other.get("deleted", false): occupied[int(round(vector(other.position).x / 60.0))] = true
			var plot = maxi(0, int(round(position.x / 60.0)))
			while occupied.has(plot): plot += 1
			var delta = Vector3(plot * 60.0, 0, 0) - vector(org.position)
			org.position = s._vector_dict(Vector3(plot * 60.0, 0, 0))
			org.building_index = plot
			org["in_pocket"] = false
			for room in s.rooms.values():
				if room.organization_id == org.id: _translate_room(s, room, delta)
			for entity in s.entities.values():
				if entity.organization_id == org.id and str(entity.get("room_id", "")).is_empty(): entity.position = s._vector_dict(vector(entity.position) + delta)
		"floor":
			var floor = s.floors[item.floor_id]
			var old_org: String = floor.organization_id
			var existing = active_floors(s, org_id)
			var insertion = existing.size() + 1 if floor_number < 1 else clampi(floor_number, 1, existing.size() + 1)
			for other in existing:
				if int(other.number) >= insertion: other.number = int(other.number) + 1
			floor.organization_id = org_id
			floor.number = insertion
			floor.in_pocket = false
			for room in s.rooms.values():
				if room.floor_id == floor.id: room.organization_id = org_id
			relayout(s, old_org)
			if old_org != org_id: relayout(s, org_id)
		"room":
			var room = s.rooms[item.room_id]
			room.floor_id = floor_id
			room.organization_id = s.floors[floor_id].organization_id
			room.slot_index = _next_slot(s, floor_id)
			room.in_pocket = false
			relayout(s, room.organization_id)
	s.pocket_items.erase(item)
	return s._commit_edit(before, true) if item.kind == "entity" else _commit_layout(s, before)

static func _translate_room(s, room: Dictionary, delta: Vector3) -> void:
	room.position = s._vector_dict(vector(room.position) + delta)
	for entity in s.entities.values():
		if entity.get("room_id", "") == room.id:
			entity.position = s._vector_dict(vector(entity.position) + delta)
			entity.organization_id = room.organization_id
			entity.floor = room.floor
			entity["floor_id"] = room.floor_id
	for slot in s.board_slots.values():
		if slot.room_id == room.id: slot.position = s._vector_dict(vector(slot.position) + delta)
	for board in s.boards.values():
		if board.room_id == room.id: board.organization_id = room.organization_id
	for team in s.teams.values():
		if team.room_id == room.id: team.organization_id = room.organization_id

static func relayout(s, org_id: String) -> void:
	if not s.organizations.has(org_id): return
	var ordered = active_floors(s, org_id)
	for index in range(ordered.size()):
		var floor = ordered[index]
		floor.number = index + 1
		for room in s.rooms.values():
			if room.floor_id != floor.id or room.get("deleted", false) or room.get("in_pocket", false): continue
			var old = vector(room.position)
			room.floor = floor.number
			room.organization_id = org_id
			room.number = "%d%02d" % [floor.number, int(room.slot_index) + 1]
			var current = vector(s.organizations[org_id].position) + slot_position(int(room.slot_index), int(floor.number))
			_translate_room(s, room, current - old)
