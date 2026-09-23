extends Node3D
## Composition root. Feature modules live under world/, actors/, kanban/, ui/, core/.
const WorldScript = preload("res://scripts/world/office_world.gd")
const BoardScript = preload("res://scripts/kanban/board_3d.gd")
const PlayerScript = preload("res://scripts/actors/player.gd")
const NPCScript = preload("res://scripts/actors/office_npc.gd")
const PersonProfiles = preload("res://scripts/actors/person_profiles.gd")
const UIScript = preload("res://scripts/ui/game_ui.gd")
var world
var worlds: Dictionary = {}
var all_rooms: Array = []
var player
var ui
var board_nodes: Dictionary = {}
var npcs: Array = []
var carried_card = ""
var carried_container = ""
var pending_card = ""
var pending_board = ""
var navigation_marker: Node3D
var navigation_target = {}
var dragging = false
var drag_start = Vector2.ZERO
var ready_to_play = false
var _hint_clock = 0.0
var _save_clock = 0.0
var _room_id = ""

func _ready() -> void:
	PlayerScript.configure_inputs()
	GameState.register_organization({"id":"org_main","name":{"fi":"Kanban-talo","en":"Kanban House"},"building_index":0,"position":Vector3.ZERO})
	GameState.ensure_spatial_layout("org_main")
	player = PlayerScript.new()
	add_child(player)
	_sync_buildings()
	player.position = world.spawn_position if world != null else Vector3(0, 0.12, 10.6)
	var existed = GameState.database_exists()
	var loaded = GameState.load_game()
	_sync_buildings()
	GameState.organizations_changed.connect(_sync_buildings)
	GameState.layout_changed.connect(_sync_buildings)
	GameState.entities_changed.connect(_sync_people)
	GameState.entities_changed.connect(_sync_world_entities)
	_sync_people()
	_sync_world_entities()
	if not existed and not loaded:
		GameState.save_game()
	GameState.autosave_enabled = GameState.last_storage_error.is_empty()
	ui = UIScript.new()
	add_child(ui)
	ui.build()
	ui.modal_changed.connect(_on_modal)
	ui.text_input_changed.connect(_on_modal)
	ui.search_requested.connect(ui.open_search)
	ui.search_navigation_requested.connect(_navigate_to_result)
	ui.remote_connection_requested.connect(_open_remote_call)
	ui.container_placement_requested.connect(_carry_container)
	ui.placement_requested.connect(_carry_from_pocket)
	ui.cancel_carry_requested.connect(_cancel_carry)
	GameState.language_changed.connect(_refresh_hint)
	get_tree().auto_accept_quit = false
	ready_to_play = true
	if not GameState.last_storage_error.is_empty():
		ui.show_toast(_t("Tallennusta ei voitu avata: ","Could not open save: ")+GameState.last_storage_error)
		return
	ui.show_toast(_t("Tervetuloa! Nuolilla liikut ja käännyt. E: keskustele / avaa taulu. F1: ohjeet.","Welcome! Arrows walk and turn. E: talk / open board. F1: help."))

func _sync_buildings() -> void:
	# A layout transaction may relocate whole buildings, floors and rooms. Rebuild
	# the procedural shell from the authoritative graph, then reapply saved state.
	for child in get_children().duplicate():
		if child.has_meta("organization_id"):
			remove_child(child)
			child.queue_free()
	worlds.clear()
	board_nodes.clear()
	all_rooms.clear()
	npcs.clear()
	world = null
	for org_id in GameState.organizations:
		var org: Dictionary = GameState.organizations[org_id]
		if org.get("deleted", false) or org.get("in_pocket", false):
			continue
		_build_organization(org)
	_sync_people()
	_sync_world_entities()

func _build_organization(org: Dictionary) -> void:
	var org_id = str(org.id)
	var building = WorldScript.new()
	building.name = "Building_" + org_id
	building.set_meta("organization_id", org_id)
	building.campus_mode = true
	var pos = org.get("position", {})
	var offset = Vector3(float(pos.get("x", 0)), float(pos.get("y", 0)), float(pos.get("z", 0)))
	building.position = offset
	var floor_specs: Array = []
	for floor in GameState.floors.values():
		if str(floor.get("organization_id", "")) == org_id:
			floor_specs.append(floor)
	var room_specs: Array = []
	for room in GameState.rooms.values():
		if str(room.get("organization_id", "")) == org_id:
			room_specs.append(room)
	building.configure_layout(org_id, floor_specs, room_specs)
	add_child(building)
	building.build()
	if world == null:
		world = building
	else:
		for child in building.get_children().duplicate():
			if child is WorldEnvironment or child is DirectionalLight3D:
				building.remove_child(child)
				child.queue_free()
	worlds[org_id] = building
	for room in building.rooms:
		var record = room.duplicate(true)
		record["center"] = room.center + offset
		record["floor_id"] = room.floor_id
		record["slot_index"] = room.slot_index
		GameState.register_room(record)
		room.center += offset
		room.bounds.position += offset
		for i in range(room.npc_positions.size()): room.npc_positions[i] += offset
		for i in range(room.waypoints.size()): room.waypoints[i] += offset
		all_rooms.append(room)
	for entity in building.entities:
		var record = entity.duplicate(true)
		var local = entity.get("position", {})
		record["position"] = Vector3(float(local.get("x", 0)), float(local.get("y", 0)), float(local.get("z", 0))) + offset
		GameState.register_entity(record)
	var boards_root = Node3D.new()
	boards_root.name = "Boards_" + org_id
	boards_root.set_meta("organization_id", org_id)
	add_child(boards_root)
	for spec_value in building.board_specs:
		var spec = spec_value.duplicate(true)
		spec["position"] = spec.position + offset
		GameState.register_board_slot(spec)
		GameState.ensure_board(spec.id, spec.room_id, spec.topic)
		var board = BoardScript.new()
		boards_root.add_child(board)
		board.setup(spec)
		board_nodes[spec.id] = board
	_create_people(building, org_id)
	building.apply_saved_entities(GameState)
	var sign = Label3D.new()
	sign.name = "OrganizationSign"
	sign.set_meta("organization_id", org_id)
	sign.position = offset + Vector3(0, 3.4, 12.4)
	sign.font_size = 58
	sign.pixel_size = 0.012
	sign.outline_size = 5
	sign.modulate = Color("ffd291")
	add_child(sign)
	sign.text = GameState.localize(org.name)
	GameState.language_changed.connect(func():
		if is_instance_valid(sign) and GameState.organizations.has(org_id): sign.text = GameState.localize(GameState.organizations[org_id].name)
	)

func _sync_world_entities() -> void:
	for building in worlds.values():
		if is_instance_valid(building):
			building.apply_saved_entities(GameState)

func _create_people(building, org_id: String) -> void:
	var people = Node3D.new()
	people.name = "Colleagues"
	people.set_meta("organization_id",org_id)
	add_child(people)
	var reception_names = ["Aino Aalto", "Maya Koski"]
	for i in range(building.reception_positions.size()):
		_spawn_npc(people,{"entity_id":org_id+"_person_reception_"+str(i),"name":reception_names[i % 2],"female":true,"receptionist":true,"position":building.reception_positions[i] + building.position,"room_id":org_id+"_reception","organization_id":org_id,"floor":1,"topic":0,"waypoints":[],"board_ids":[]})
	var names = ["Sofia Laine", "Elias Salmi", "Lin Korpi", "Noah Salo", "Amira Lehto", "Leo Niemi", "Emma Rinne", "Omar Saari", "Ines Valo", "Aki Vuori", "Sara Kivi", "Mika Kuusi", "Ada Tuuli", "Kai Aava", "Nora Virta", "Luca Tammi", "Asta Keto", "Joonas Elo", "Leila Puro", "Rami Harju", "Elina Repo", "Otto Sumu", "Alma Raita", "Niko Halla", "Mira Pilvi", "Alex Meri", "Tara Lumo", "Eero Kajo", "Iris Sointu", "Emil Taito", "Vera Runo", "Samir Jalava"]
	for room in building.rooms:
		var ids: Array = []
		for spec in building.board_specs:
			if spec.room_id == room.id:
				ids.append(spec.id)
		for i in range(2):
			_spawn_npc(people,{"entity_id":"person_"+room.id+"_"+str(i),"name":names[(npcs.size()-2)%names.size()],"female":i==0,"receptionist":false,"position":room.npc_positions[i],"room_id":room.id,"organization_id":org_id,"floor":room.floor+1,"topic":room.topic,"waypoints":room.waypoints,"board_ids":ids,"bounds":room.bounds})

func _spawn_npc(parent: Node3D, spec: Dictionary) -> void:
	GameState.register_entity({"id":spec.entity_id,"kind":"person","name":{"fi":spec.name,"en":spec.name},"description":{"fi":"Vastaanottovirkailija" if spec.receptionist else "Ohjelmistokehittäjä, tiimin jäsen", "en":"Receptionist" if spec.receptionist else "Software developer, team member"},"room_id":spec.room_id,"organization_id":spec.organization_id,"floor":spec.floor,"position":spec.position,"topic":spec.topic,"female":spec.female,"receptionist":spec.receptionist,"deleted":false,"profile":PersonProfiles.make_profile(spec)})
	var npc = NPCScript.new()
	parent.add_child(npc)
	npc.setup(spec,player)
	npcs.append(npc)
	if is_instance_valid(ui) and ui.is_modal_open():
		npc.set_physics_process(false)
		npc.set_process(false)

func _sync_people() -> void:
	var present = {}
	for npc in npcs.duplicate():
		if not is_instance_valid(npc):
			npcs.erase(npc)
			continue
		var entity = GameState.entities.get(npc.entity_id,{})
		if entity.is_empty() or entity.get("deleted",false) or GameState.entity_is_pocketed(npc.entity_id):
			npcs.erase(npc)
			if npc.get_parent(): npc.get_parent().remove_child(npc)
			npc.queue_free()
		else:
			present[npc.entity_id] = true
	for entity_id in GameState.entities:
		var entity = GameState.entities[entity_id]
		if entity.get("kind","") != "person" or entity.get("deleted",false) or GameState.entity_is_pocketed(entity_id) or present.has(entity_id):
			continue
		var room = {}
		for candidate in all_rooms:
			if candidate.id == entity.room_id:
				room = candidate
				break
		if room.is_empty():
			continue
		var ids = []
		for board_id in GameState.boards:
			if GameState.boards[board_id].room_id == room.id: ids.append(board_id)
		var point = room.waypoints[abs(hash(entity_id)) % room.waypoints.size()]
		var npc = NPCScript.new()
		npc.set_meta("organization_id",str(entity.get("organization_id","org_main")))
		add_child(npc)
		npc.setup({"entity_id":entity_id,"name":GameState.localize(entity.name),"female":entity.get("female",false),"receptionist":false,"position":point,"room_id":room.id,"topic":entity.get("topic",room.topic),"waypoints":room.waypoints,"board_ids":ids,"bounds":room.bounds},player)
		npcs.append(npc)
		if is_instance_valid(ui) and ui.is_modal_open():
			npc.set_physics_process(false)
			npc.set_process(false)

func _process(delta: float) -> void:
	if not ready_to_play:
		return
	_hint_clock += delta
	_save_clock += delta
	if _hint_clock > 0.16:
		_hint_clock = 0
		_visit_room()
		_refresh_hint()
	if _save_clock > 20.0:
		_save_clock = 0
		if GameState.autosave_enabled:
			GameState.save_game()
	_update_navigation()

func _visit_room() -> void:
	_room_id = ""
	for room in all_rooms:
		if room.bounds.has_point(player.global_position + Vector3(0,0.3,0)):
			_room_id = room.id
			GameState.visit_room(room.id)
			break

func _pointer() -> Vector2:
	if player.using_controller or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return get_viewport().get_visible_rect().size * 0.5
	return get_viewport().get_mouse_position()

func _target(center: bool = false) -> Dictionary:
	var point = get_viewport().get_visible_rect().size*0.5 if center else _pointer()
	var hit = player.point_ray(point)
	if hit.is_empty():
		return {}
	var collider = hit.collider
	if collider.has_meta("board_node"):
		var board = collider.get_meta("board_node")
		var info = board.hit_info(hit.position)
		info["board"] = board
		info["part"] = info.get("kind", "board")
		info["kind"] = "board"
		return info
	if collider.has_meta("npc_node"):
		return {"kind":"npc","npc":collider.get_meta("npc_node")}
	if collider.has_meta("entity_id"):
		return {"kind":"entity","entity_id":str(collider.get_meta("entity_id"))}
	return {}

func _refresh_hint() -> void:
	if not ready_to_play or ui.is_modal_open():
		return
	var target = _target()
	if target.get("kind","") == "entity":
		var entity = GameState.entities.get(target.entity_id,{})
		ui.set_hint(_t("Klikkaa / E / A: muuta nimeä — ","Click / E / A: rename — ")+GameState.localize(entity.get("name",target.entity_id)))
	elif target.get("kind","") == "npc":
		ui.set_hint(_t("E / A: keskustele — ","E / A: talk — ") + target.npc.display_name)
	elif target.get("kind","") == "board":
		if str(target.board_id).is_empty():
			ui.set_hint(_t("Tyhjä taulupaikka · Aseta kannettava taulu klikkaamalla / A", "Empty board slot · Click / A to place a carried board"))
			return
		var title = GameState.localize(GameState.boards[target.board_id].title)
		if not carried_card.is_empty() or not carried_container.is_empty():
			ui.set_hint(_t("Klikkaa / A: aseta kortti tähän listaan · P / X: pidä taskussa — ","Click / A: place card in this list · P / X: keep in pocket — ")+title)
		elif not str(target.get("card_id","")).is_empty():
			ui.set_hint(_t("Klikkaa: muokkaa · Vedä: siirrä · P / X: taskuun · E / A: avaa taulu — ","Click: edit · Drag: move · P / X: pocket · E / A: open board — ")+title)
		else:
			ui.set_hint(_t("E / A: avaa taulu — ","E / A: open board — ")+title)
	else:
		var floor_number = clampi(int(round(player.global_position.y/4.0))+1,1,4)
		ui.set_hint(_t("Kerros %d/4 · Portaat käytävän perällä · F1: ohjeet","Floor %d/4 · Stairs at the rear of the corridor · F1: help") % floor_number)

func _input(event: InputEvent) -> void:
	if not ready_to_play:
		return
	# A short click edits; dragging starts only after a deliberate pointer motion.
	if event is InputEventMouseMotion and not pending_card.is_empty() and not ui.is_modal_open():
		if event.position.distance_to(drag_start) > 9 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if GameState.pocket_card(pending_card):
				carried_card = pending_card
				carried_container = ""
				ui.set_carry(carried_card)
				dragging = true
			pending_card = ""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging:
			dragging = false
			if ui.is_pointer_over_pocket(event.position):
				_cancel_carry()
			elif not ui.is_modal_open():
				var target = _target()
				if target.get("kind","") == "board":
					_place_on_target(target)
			get_viewport().set_input_as_handled()
		elif not pending_card.is_empty():
			var card_id = pending_card
			pending_card = ""
			ui.open_board(pending_board)
			ui.open_card_editor(card_id)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_play:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		ui.open_dialogue({"name":_t("Opas","Guide"),"topic":0,"room_id":"reception","receptionist":true})
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		if ui.is_modal_open():
			ui.close_modal()
		else:
			ui.open_pocket()
		get_viewport().set_input_as_handled()
		return
	if ui.is_modal_open() or ui.is_text_input_focused():
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_carry()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("take_card"):
		if not carried_card.is_empty() or not carried_container.is_empty():
			_cancel_carry()
		else:
			var target = _target()
			var card_id = str(target.get("card_id",""))
			if not card_id.is_empty() and GameState.pocket_card(card_id):
				ui.show_toast(_t("Kortti lisätty taskuun.","Card added to your pocket."))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var target = _target()
		if target.get("kind","") == "board":
			if not carried_card.is_empty() or not carried_container.is_empty():
				_place_on_target(target)
			elif not str(target.get("card_id","")).is_empty():
				pending_card = str(target.card_id)
				pending_board = str(target.board_id)
				drag_start = event.position
			elif not str(target.board_id).is_empty():
				if target.get("text_kind","") == "calendar":
					ui.open_calendar(target.board_id)
				else:
					ui.open_board_text(target.board_id,target)
		elif target.get("kind","") == "npc":
			ui.open_dialogue(target.npc.interact())
		elif target.get("kind","") == "entity":
			ui.open_entity(target.entity_id)
		get_viewport().set_input_as_handled()

func _interact() -> void:
	var target = _target()
	if target.is_empty():
		target = _target(true)
	if target.get("kind","") == "board":
		if not carried_card.is_empty() or not carried_container.is_empty():
			_place_on_target(target)
		elif not str(target.board_id).is_empty():
			ui.open_board(target.board_id)
	elif target.get("kind","") == "npc":
		ui.open_dialogue(target.npc.interact())
	elif target.get("kind","") == "entity":
		ui.open_entity(target.entity_id)

func _place_on_target(target: Dictionary) -> void:
	var lane = maxi(0,int(target.get("lane",0)))
	if not carried_container.is_empty():
		var item = GameState.get_pocket_item(carried_container)
		var placed = GameState.place_pocket_board(carried_container,str(target.get("slot_id",target.board_id))) if item.get("kind","") == "board" else GameState.place_pocket_item(carried_container,target.board_id,lane)
		if placed:
			_cancel_carry()
			ui.show_toast(_t("Sisältö siirretty taululle.","Content moved to the board."))
		return
	if carried_card.is_empty():
		return
	var column = maxi(0,int(target.get("list",0)))
	var at = int(target.get("index",-1))
	if GameState.move_card(carried_card,target.board_id,column,at,lane):
		_cancel_carry()
		ui.show_toast(_t("Kortti siirretty taululle.","Card moved to the board."))

func _carry_container(item_id: String) -> void:
	carried_container = item_id
	carried_card = ""
	ui.close_modal()
	ui.set_container_carry(item_id)

func _carry_from_pocket(card_id: String) -> void:
	if not GameState.cards.has(card_id):
		return
	if not GameState.pocket.has(card_id) and not GameState.pocket_card(card_id):
		return
	carried_card = card_id
	carried_container = ""
	ui.close_modal()
	ui.set_carry(card_id)

func _cancel_carry() -> void:
	dragging = false
	pending_card = ""
	carried_card = ""
	carried_container = ""
	ui.set_carry("")
	ui.set_container_carry("")

func _on_modal(open: bool) -> void:
	open = ui.is_modal_open() or ui.is_text_input_focused()
	player.set_enabled(not open)
	dragging = false
	# Coworkers pause during focused interactions so lists never change under the pointer.
	for npc in npcs:
		npc.set_process(not open)
		npc.set_physics_process(not open)

func _navigate_to_result(result: Dictionary) -> void:
	ui.close_modal()
	if result.get("pocket",false):
		ui.open_pocket()
		return
	var board_id = str(result.get("board_id",""))
	if result.get("kind","") == "board":
		board_id = str(result.id)
	var location = Vector3.ZERO
	var slot_id = str(GameState.boards.get(board_id,{}).get("slot_id",board_id))
	if board_nodes.has(slot_id):
		location = board_nodes[slot_id].global_position
	elif result.has("position"):
		var pos = result.position
		location = pos if pos is Vector3 else Vector3(float(pos.get("x",0)),float(pos.get("y",0)),float(pos.get("z",0)))
	elif GameState.rooms.has(str(result.get("room_id",""))):
		var pos = GameState.rooms[str(result.room_id)].position
		location = Vector3(float(pos.x),float(pos.y),float(pos.z))
	else:
		ui.show_toast(str(result.get("detail",result.get("title",""))))
		return
	if is_instance_valid(navigation_marker):
		navigation_marker.queue_free()
	navigation_marker = Node3D.new()
	add_child(navigation_marker)
	navigation_marker.position = location + Vector3(0,1.8,0)
	var label = Label3D.new()
	label.name = "Location"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.pixel_size = 0.005
	label.outline_size = 8
	label.modulate = Color("ffd47f")
	navigation_marker.add_child(label)
	navigation_target = result.duplicate(true)
	navigation_target["point"] = location
	_update_navigation()
	ui.show_toast(_t("Kohde merkitty. Kulje kerrokseen ","Location marked. Go to floor ")+str(result.get("floor",1)))

func _update_navigation() -> void:
	if not is_instance_valid(navigation_marker) or navigation_target.is_empty():
		return
	var target_id = str(navigation_target.get("id",""))
	if navigation_target.get("kind","") == "person":
		for npc in npcs:
			if npc.entity_id == target_id:
				navigation_target["point"] = npc.global_position
				navigation_marker.position = npc.global_position + Vector3(0,2.7,0)
	var distance = player.global_position.distance_to(navigation_target.point)
	var label = navigation_marker.get_node("Location")
	label.text = "◆ " + str(navigation_target.get("title","")) + "\n" + _t("Kerros %d · %.0f m", "Floor %d · %.0f m") % [int(navigation_target.get("floor",1)),distance]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if GameState.autosave_enabled:
			GameState.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and ready_to_play:
		if GameState.autosave_enabled:
			GameState.save_game()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _t(fi: String, en: String) -> String:
	return fi if GameState.language == "fi" else en

func _open_remote_call(entity_id: String) -> void:
	for npc in npcs:
		if npc.entity_id == entity_id:
			ui.open_remote_call(entity_id,npc)
			return
