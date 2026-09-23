extends Node3D
## Procedural office colleagues. All movement remains inside their assigned room.
## A card remains at its source until the visible journey is complete, so interrupted
## journeys never strand cards or put NPC cards in the player's pocket.

const PersonProfiles = preload("res://scripts/actors/person_profiles.gd")

var display_name: String = ""
var entity_id: String = ""
var receptionist: bool = false
var room_id: String = ""
var topic: int = 0
var female: bool = false
var age_group: String = "middle"
var _default_profile: Dictionary = {}

var _player: Node3D
var _waypoints: Array = []
var _board_ids: Array = []
var _room_bounds: AABB
var _floor_y: float = 0.0
var _rng = RandomNumberGenerator.new()
var _visual: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _bubble_root: Node3D
var _speech: Label3D
var _name_label: Label3D
var _carried_visual: Node3D
var _route: Array = []
var _state: String = "idle"
var _wait_time: float = 0.0
var _bubble_time: float = 0.0
var _bubble_index: int = 0
var _walk_phase: float = 0.0
var _source_board: String = ""
var _destination_board: String = ""
var _source_list: int = 0
var _destination_list: int = 0
var _carried_card_id: String = ""
var _stuck_seconds: float = 0.0
var _ready_to_run: bool = false
var _last_position: Vector3
var _normal_speed: float = 0.84
var _navigation_shape = CapsuleShape3D.new()

const SKIN_TONES = [Color("edbea0"), Color("be8764"), Color("81533f"), Color("dca98b")]
const SHIRT_COLORS = [Color("348e93"), Color("5274b7"), Color("b56367"), Color("9070ad"), Color("a38241"), Color("467c5a")]


func setup(spec: Dictionary, player: Node3D) -> void:
	_player = player
	entity_id = str(spec.get("entity_id", ""))
	display_name = String(spec.get("name", "Alex"))
	receptionist = bool(spec.get("receptionist", false))
	female = bool(spec.get("female", false))
	age_group = str(spec.get("age_group", "middle"))
	if age_group not in ["young", "middle", "old"]:
		age_group = "middle"
	set_meta("age_group", age_group)
	room_id = String(spec.get("room_id", "reception"))
	topic = int(spec.get("topic", 0))
	_default_profile = PersonProfiles.make_profile(spec)
	global_position = spec.get("position", Vector3.ZERO)
	_floor_y = global_position.y
	_waypoints = spec.get("waypoints", []).duplicate()
	_board_ids = spec.get("board_ids", []).duplicate()
	_rng.seed = abs(hash(display_name + room_id)) + 71
	_normal_speed = _rng.randf_range(0.7, 0.95)
	_navigation_shape.radius = 0.27
	_navigation_shape.height = 1.74
	_wait_time = _rng.randf_range(3.0, 8.0)
	_bubble_time = _rng.randf_range(3.0, 7.0)
	_bubble_index = _rng.randi_range(0, 2)
	_room_bounds = spec.get("bounds", _infer_bounds())
	_build_person()
	_build_bubble()
	_build_interaction_target()
	_refresh_speech()
	GameState.language_changed.connect(_refresh_speech)
	if GameState.has_signal("entities_changed"):
		GameState.entities_changed.connect(_refresh_speech)
	_last_position = global_position
	_ready_to_run = true
	add_to_group("office_npcs")


func interact() -> Dictionary:
	_bubble_time = 8.0
	_bubble_index = 0 if receptionist else 1
	_refresh_speech()
	var profile = _person_profile().duplicate(true)
	var information = {"name": display_name, "topic": topic, "room_id": room_id, "receptionist": receptionist, "entity_id":entity_id, "age_group": age_group, "profile": profile}
	for field in ["title", "team_role", "expertise", "qa"]:
		information[field] = profile.get(field, [] if field == "qa" else {})
	return information


func _person_profile() -> Dictionary:
	if GameState.entities.has(entity_id):
		var entity = GameState.entities[entity_id]
		if entity.get("profile") is Dictionary:
			return entity.profile
		# Compatibility with directly supplied fictional profiles during setup.
		if entity.get("qa") is Array:
			return {"title": entity.get("title", {}), "team_role": entity.get("team_role", {}), "expertise": entity.get("expertise", {}), "qa": entity.qa}
	return _default_profile


func _physics_process(delta: float) -> void:
	if not _ready_to_run:
		return
	_bubble_time -= delta
	if _bubble_time <= 0.0:
		_bubble_index = (_bubble_index + 1) % 3
		_bubble_time = _rng.randf_range(6.0, 10.0)
		_refresh_speech()
	_update_bubble()
	if receptionist:
		_face_reception_visitor(delta)
		_animate_limbs(delta, false)
		return
	_wait_time = maxf(0.0, _wait_time - delta)
	var avoided = _step_aside(delta)
	if not avoided:
		_tick_task(delta)
	var walking = global_position.distance_to(_last_position) > 0.001
	_animate_limbs(delta, walking)
	_last_position = global_position


func _tick_task(delta: float) -> void:
	if _state in ["to_source", "to_destination"] and (not _board_in_room(_source_board) or not _board_in_room(_destination_board)):
		_finish_task(false)
		return
	if not _route.is_empty():
		_follow_route(delta)
		return
	if _wait_time > 0.0:
		return
	match _state:
		"to_source":
			if _player_near_board(_source_board) or _player_near_board(_destination_board):
				_wait_time = 2.0
				return
			if not _card_is_at_source():
				_finish_task(false)
				return
			_carried_visual.visible = true
			_state = "to_destination"
			_bubble_index = 1
			_refresh_speech()
			var board = _find_board(_destination_board)
			if not is_instance_valid(board) or not _plan_route(_board_approach(board)):
				_finish_task(false)
		"to_destination":
			if _player_near_board(_destination_board) or _player_near_board(_source_board):
				_wait_time = 1.5
				return
			var success = false
			if _card_is_at_source():
				success = GameState.move_card(_carried_card_id, _destination_board, _destination_list)
			_finish_task(success)
		"wandering":
			_state = "idle"
			_wait_time = _rng.randf_range(2.0, 5.0)
		_:
			if not _begin_card_journey():
				_begin_wander()


func _begin_card_journey() -> bool:
	# Board slots can change occupants after a player carries a whole board.
	_board_ids.clear()
	for board_id in GameState.boards:
		if _board_in_room(str(board_id)):
			_board_ids.append(str(board_id))
	if _board_ids.size() < 2:
		return false
	var candidates = _board_ids.duplicate()
	# Seeded rotation spreads coworkers' choices without changing the global RNG.
	var offset = _rng.randi_range(0, candidates.size() - 1)
	for iteration in range(candidates.size()):
		var source_id = String(candidates[(iteration + offset) % candidates.size()])
		var source = _find_board(source_id)
		if not is_instance_valid(source) or _player_near_board(source_id):
			continue
		var source_data = GameState.boards.get(source_id, {})
		var card_lists = source_data.get("cards", [])
		if card_lists.is_empty():
			continue
		for list_offset in range(card_lists.size()):
			var list_index = (list_offset + _rng.randi_range(0, card_lists.size()-1)) % card_lists.size()
			if card_lists[list_index].is_empty():
				continue
			var card_id = String(card_lists[list_index].back())
			if _card_claimed_by_colleague(card_id):
				continue
			for target_offset in range(1, candidates.size()):
				var target_id = String(candidates[(iteration + offset + target_offset) % candidates.size()])
				var target = _find_board(target_id)
				if not is_instance_valid(target) or _player_near_board(target_id):
					continue
				var target_data = GameState.boards.get(target_id, {})
				var target_lists = target_data.get("cards", [])
				if target_lists.is_empty():
					continue
				# Prefer the least populated column; do not keep filling a crowded board.
				var destination_list = 0
				for column in range(1, target_lists.size()):
					if target_lists[column].size() < target_lists[destination_list].size():
						destination_list = column
				if target_lists[destination_list].size() >= 8:
					continue
				if not _plan_route(_board_approach(source)):
					continue
				_source_board = source_id
				_destination_board = target_id
				_source_list = list_index
				_destination_list = destination_list
				_carried_card_id = card_id
				_state = "to_source"
				_bubble_index = 0
				_refresh_speech()
				return true
	return false


func _card_is_at_source() -> bool:
	if _carried_card_id.is_empty() or not _board_in_room(_source_board) or not _board_in_room(_destination_board):
		return false
	var location = GameState.get_card_location(_carried_card_id)
	return not location.get("pocket", false) and String(location.get("board_id", "")) == _source_board and int(location.get("list", -1)) == _source_list and int(location.get("lane",0)) == 0


func _board_in_room(board_id: String) -> bool:
	var board = GameState.boards.get(board_id, {})
	return str(board.get("room_id", "")) == room_id and not str(board.get("slot_id", "")).is_empty() and not bool(board.get("deleted", false)) and not bool(board.get("in_pocket", false))


func _card_claimed_by_colleague(card_id: String) -> bool:
	for colleague in get_tree().get_nodes_in_group("office_npcs"):
		if colleague != self and colleague.get("_carried_card_id") == card_id:
			return true
	return false


func _finish_task(success: bool) -> void:
	_carried_visual.visible = false
	_carried_card_id = ""
	_source_board = ""
	_destination_board = ""
	_route.clear()
	_state = "idle"
	_stuck_seconds = 0.0
	_wait_time = _rng.randf_range(5.0, 10.0)
	if success:
		_bubble_index = 2
		_bubble_time = 7.0
	_refresh_speech()


func _begin_wander() -> void:
	if not _waypoints.is_empty():
		var index = _rng.randi_range(0, _waypoints.size() - 1)
		var goal: Vector3 = _waypoints[index]
		if _plan_route(goal):
			_state = "wandering"
			return
	_wait_time = _rng.randf_range(2.0, 5.0)


func _find_board(identifier: String) -> Node3D:
	for board in get_tree().get_nodes_in_group("kanban_boards"):
		if String(board.get("board_id")) == identifier:
			return board
	return null


func _player_near_board(identifier: String) -> bool:
	if not is_instance_valid(_player) or absf(_player.global_position.y - _floor_y) > 1.2:
		return false
	var board = _find_board(identifier)
	if not is_instance_valid(board):
		return false
	var relative = _player.global_position - board.global_position
	relative.y = 0.0
	return relative.length() < 2.0


func _board_approach(board: Node3D) -> Vector3:
	var result: Vector3 = board.global_position + board.global_basis.z.normalized() * 1.12
	if board.has_method("carry_anchor"):
		result = board.carry_anchor()
		# The board's anchor may be close to the board. Stand at least 0.9 m out.
		var outward = board.global_basis.z.normalized()
		var distance = (result - board.global_position).dot(outward)
		if distance < 0.9:
			result += outward * (0.9 - distance)
	result.y = _floor_y
	return _clamp_to_room(result)


func _infer_bounds() -> AABB:
	# A generous but room-safe fallback for the documented 4-room floor plan.
	var room_x = -9.0 if global_position.x < 0.0 else 9.0
	var room_z = -6.5 if global_position.z < 0.0 else 6.5
	return AABB(Vector3(room_x - 5.45, _floor_y, room_z - 5.0), Vector3(10.9, 3.5, 10.0))


func _clamp_to_room(point: Vector3) -> Vector3:
	var low = _room_bounds.position + Vector3(0.42, 0.0, 0.42)
	var high = _room_bounds.end - Vector3(0.42, 0.0, 0.42)
	return Vector3(clampf(point.x, low.x, high.x), _floor_y, clampf(point.z, low.z, high.z))


func _path_clear(start: Vector3, finish: Vector3) -> bool:
	var vector = finish - start
	vector.y = 0.0
	if vector.length_squared() < 0.001:
		return true
	# A swept adult-sized capsule catches thin desktop surfaces and chair backs
	# at every height, and costs fewer queries than a fan of shoulder/leg rays.
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = _navigation_shape
	query.transform = Transform3D(Basis.IDENTITY, start + Vector3.UP * 0.91)
	query.motion = vector
	query.margin = 0.02
	query.collision_mask = 1
	query.collide_with_areas = false
	var fractions = get_world_3d().direct_space_state.cast_motion(query)
	return fractions.size() == 2 and fractions[0] >= 0.999


func _plan_route(destination: Vector3) -> bool:
	var goal = _clamp_to_room(destination)
	_route.clear()
	_stuck_seconds = 0.0
	if _path_clear(global_position, goal):
		_route.append(goal)
		return true
	# A visibility graph joins supplied clear aisle waypoints. The small perimeter
	# grid gives paths around desks when a board lies between two aisle waypoints.
	var points: Array = [global_position, goal]
	for waypoint in _waypoints:
		points.append(_clamp_to_room(waypoint))
	var low = _room_bounds.position + Vector3(0.85, 0.0, 0.85)
	var high = _room_bounds.end - Vector3(0.85, 0.0, 0.85)
	for ratio in [0.0, 0.33, 0.67, 1.0]:
		points.append(Vector3(lerpf(low.x, high.x, ratio), _floor_y, low.z))
		points.append(Vector3(lerpf(low.x, high.x, ratio), _floor_y, high.z))
		points.append(Vector3(low.x, _floor_y, lerpf(low.z, high.z, ratio)))
		points.append(Vector3(high.x, _floor_y, lerpf(low.z, high.z, ratio)))
	var distances: Array = []
	var parents: Array = []
	var visited: Array = []
	for index in range(points.size()):
		distances.append(INF)
		parents.append(-1)
		visited.append(false)
	distances[0] = 0.0
	for iteration in range(points.size()):
		var current = -1
		var shortest = INF
		for index in range(points.size()):
			if not visited[index] and distances[index] < shortest:
				shortest = distances[index]
				current = index
		if current < 0:
			break
		if current == 1:
			break
		visited[current] = true
		for next_index in range(points.size()):
			if visited[next_index] or next_index == current:
				continue
			var trial_distance = distances[current] + points[current].distance_to(points[next_index])
			if trial_distance < distances[next_index] and _path_clear(points[current], points[next_index]):
				distances[next_index] = trial_distance
				parents[next_index] = current
	if parents[1] < 0:
		return false
	var cursor = 1
	while cursor != 0:
		_route.push_front(points[cursor])
		cursor = parents[cursor]
	return not _route.is_empty()


func _follow_route(delta: float) -> void:
	var goal: Vector3 = _route[0]
	var direction = goal - global_position
	direction.y = 0.0
	if direction.length() < 0.13:
		_route.pop_front()
		if _route.is_empty():
			_wait_time = 0.7
		return
	var movement = direction.normalized() * minf(_normal_speed * delta, direction.length())
	if _safe_move(movement):
		_stuck_seconds = 0.0
		_face_direction(direction, delta)
	else:
		_stuck_seconds += delta
		# Retest only a short sidestep; never teleport across a collision.
		var sideways = Vector3(-direction.z, 0.0, direction.x).normalized() * _normal_speed * delta * 0.7
		if not _safe_move(sideways):
			_safe_move(-sideways)
		if _stuck_seconds > 3.0:
			_finish_task(false)


func _safe_move(movement: Vector3) -> bool:
	var goal = _clamp_to_room(global_position + movement)
	if global_position.distance_squared_to(goal) < 0.000001:
		return false
	# Look slightly beyond this frame to keep shoulders away from solid furniture.
	var lookahead = goal + movement.normalized() * 0.28
	if not _path_clear(global_position, lookahead):
		return false
	global_position = goal
	return true


func _step_aside(delta: float) -> bool:
	if not is_instance_valid(_player):
		return false
	var away = global_position - _player.global_position
	if absf(away.y) > 1.1:
		return false
	away.y = 0.0
	if away.length() >= 1.05:
		return false
	if away.length_squared() < 0.001:
		away = Vector3.RIGHT
	var movement = away.normalized() * 1.55 * delta
	var moved = _safe_move(movement)
	if not moved:
		var side = Vector3(-away.z, 0.0, away.x).normalized() * 1.55 * delta
		moved = _safe_move(side)
		if not moved:
			moved = _safe_move(-side)
	if moved:
		_face_direction(away, delta)
	return moved


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.001:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 7.0))


func _face_reception_visitor(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var direction = _player.global_position - global_position
	direction.y = 0.0
	if direction.length() < 6.0:
		_face_direction(direction, delta)


func _animate_limbs(delta: float, walking: bool) -> void:
	if walking:
		_walk_phase += delta * 8.0
	var swing = sin(_walk_phase) * 0.37 if walking else 0.0
	_left_leg.rotation.x = lerpf(_left_leg.rotation.x, swing, minf(1.0, delta * 12.0))
	_right_leg.rotation.x = lerpf(_right_leg.rotation.x, -swing, minf(1.0, delta * 12.0))
	if _carried_visual.visible:
		_left_arm.rotation.x = -0.7
		_right_arm.rotation.x = -0.7
	else:
		_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -swing * 0.75, minf(1.0, delta * 10.0))
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, swing * 0.75, minf(1.0, delta * 10.0))


func _refresh_speech() -> void:
	if GameState.entities.has(entity_id):
		display_name = GameState.localize(GameState.entities[entity_id].name)
	if not is_instance_valid(_speech):
		return
	var fi = GameState.language == "fi"
	var lines: Array
	if receptionist:
		lines = [
			"Tervetuloa! Kuinka voin auttaa?" if fi else "Welcome! How can I help you?",
			"Portaat ovat käytävän päässä.\nToimistoja on neljässä kerroksessa." if fi else "Stairs are at the end of the hall.\nOffices are on all four floors.",
			"Voit viedä kortteja taskussa.\nKlikkaa minua, jos tarvitset apua!" if fi else "Carry cards in your pocket.\nClick me if you need help!"
		]
	else:
		var subject = _speech_subject()
		lines = [
			(subject + "\nMikä on seuraava työvaihe?") if fi else (subject + "\nWhat should we work on next?"),
			(subject + "\nTarkistetaan tämä yhdessä.") if fi else (subject + "\nLet's review this together."),
			(subject + "\nSovittu, siirretään kortti eteenpäin.") if fi else (subject + "\nAgreed. Let's move the card along.")
		]
	_speech.text = String(lines[_bubble_index % lines.size()])
	var job_title = GameState.localize(_person_profile().get("title", {}))
	_name_label.text = display_name + ("\n" + job_title if not job_title.is_empty() else "")


func _speech_subject() -> String:
	var label = GameState.topic_text(topic)
	if not _source_board.is_empty() and GameState.boards.has(_source_board):
		label = GameState.localize(GameState.boards[_source_board].get("title", label))
	# Keep full topic wording, wrapping instead of truncating meaningful phrases.
	return _wrap_words(label, 35)


func _wrap_words(value: String, width: int) -> String:
	var result = ""
	var line_length = 0
	for word in value.split(" "):
		if line_length > 0 and line_length + word.length() + 1 > width:
			result += "\n"
			line_length = 0
		elif line_length > 0:
			result += " "
			line_length += 1
		result += word
		line_length += word.length()
	return result


func _update_bubble() -> void:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var offset = camera.global_position - _bubble_root.global_position
	var distance = offset.length()
	_bubble_root.visible = distance < 10.0 and absf(camera.global_position.y - (_floor_y + 1.65)) < 2.0
	if receptionist:
		# Alternate the two reception bubbles so their text never overlaps.
		var speaking = int(Time.get_ticks_msec() / 6500) % 2
		_bubble_root.visible = _bubble_root.visible and entity_id.ends_with(str(speaking))
	if _bubble_root.visible and offset.length_squared() > 0.01:
		_bubble_root.look_at(camera.global_position, Vector3.UP, true)


func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, material: Material, size_scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = material
	instance.position = at
	instance.scale = size_scale
	parent.add_child(instance)
	return instance


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var result = CapsuleMesh.new()
	result.radius = radius
	result.height = maxf(height, radius * 2.0)
	result.radial_segments = 10
	result.rings = 4
	return result


func _sphere(radius: float) -> SphereMesh:
	var result = SphereMesh.new()
	result.radius = radius
	result.height = radius * 2.0
	result.radial_segments = 12
	result.rings = 6
	return result


func _box(size: Vector3) -> BoxMesh:
	var result = BoxMesh.new()
	result.size = size
	return result


func _build_person() -> void:
	_visual = Node3D.new()
	_visual.name = "Person"
	add_child(_visual)
	var age_scale = 1.025 if age_group == "young" else (0.96 if age_group == "old" else 1.0)
	_visual.scale = Vector3.ONE * age_scale
	var index = _rng.randi_range(0, SHIRT_COLORS.size() - 1)
	var skin = _material(SKIN_TONES[_rng.randi_range(0, SKIN_TONES.size() - 1)])
	var shirt = _material(SHIRT_COLORS[index] if not receptionist else Color("406186"))
	var trousers = _material(Color("283442") if index % 2 == 0 else Color("434c57"))
	var hair_colors = [Color("302820"), Color("503626"), Color("b99b63"), Color("333438")]
	if age_group == "old":
		hair_colors = [Color("c3c1b9"), Color("a7aaa7"), Color("e1ded3"), Color("979d9c")]
	var hair = _material(hair_colors[_rng.randi_range(0, hair_colors.size() - 1)])
	var shoe = _material(Color("17242c"))
	var eye = _material(Color("222b32"))
	var white = _material(Color("eceddf"))
	_mesh(_visual, _capsule(0.245, 0.65), Vector3(0, 1.12, 0), shirt, Vector3(1.0, 1.0, 0.72))
	_mesh(_visual, _capsule(0.086, 0.16), Vector3(0, 1.46, 0), skin)
	_mesh(_visual, _sphere(0.205), Vector3(0, 1.65, 0), skin, Vector3(0.86, 1.05, 0.9))
	_mesh(_visual, _sphere(0.208), Vector3(0, 1.745, -0.035), hair, Vector3(0.89, 0.64, 0.87))
	if female:
		_mesh(_visual, _capsule(0.10, 0.33), Vector3(-0.155, 1.59, -0.072), hair, Vector3(0.65, 1.0, 0.75))
		_mesh(_visual, _capsule(0.10, 0.33), Vector3(0.155, 1.59, -0.072), hair, Vector3(0.65, 1.0, 0.75))
		_mesh(_visual, _sphere(0.115), Vector3(0, 1.66, -0.155), hair, Vector3(1.0, 1.7, 0.7))
	for sign_value in [-1.0, 1.0]:
		_mesh(_visual, _sphere(0.026), Vector3(sign_value * 0.063, 1.667, 0.164), white, Vector3(0.86, 0.8, 0.45))
		_mesh(_visual, _sphere(0.013), Vector3(sign_value * 0.063, 1.667, 0.176), eye)
		_mesh(_visual, _sphere(0.04), Vector3(sign_value * 0.18, 1.64, 0), skin, Vector3(0.65, 1.0, 0.8))
	_mesh(_visual, _sphere(0.032), Vector3(0, 1.62, 0.183), skin, Vector3(0.7, 0.7, 0.9))
	_mesh(_visual, _box(Vector3(0.067, 0.008, 0.009)), Vector3(0, 1.572, 0.166), _material(Color("8b554d")))
	for sign_value in [-1.0, 1.0]:
		var leg = Node3D.new()
		leg.position = Vector3(sign_value * 0.105, 0.86, 0)
		_visual.add_child(leg)
		_mesh(leg, _capsule(0.093, 0.78), Vector3(0, -0.35, 0), trousers)
		_mesh(leg, _box(Vector3(0.16, 0.11, 0.30)), Vector3(0, -0.78, 0.065), shoe)
		var arm = Node3D.new()
		arm.position = Vector3(sign_value * 0.27, 1.36, 0)
		_visual.add_child(arm)
		_mesh(arm, _capsule(0.075, 0.38), Vector3(0, -0.15, 0), shirt)
		_mesh(arm, _capsule(0.059, 0.25), Vector3(0, -0.39, 0), skin)
		_mesh(arm, _sphere(0.062), Vector3(0, -0.51, 0), skin, Vector3(0.82, 1.1, 0.72))
		if sign_value < 0.0:
			_left_leg = leg
			_left_arm = arm
		else:
			_right_leg = leg
			_right_arm = arm
	# Lanyard and badge signal an ordinary fully clothed workplace.
	_mesh(_visual, _box(Vector3(0.028, 0.30, 0.025)), Vector3(0.10, 1.26, 0.176), _material(Color("d8aa4e")))
	_mesh(_visual, _box(Vector3(0.105, 0.13, 0.025)), Vector3(0.10, 1.085, 0.18), white)
	_carried_visual = Node3D.new()
	_carried_visual.name = "CarriedKanbanCard"
	_carried_visual.position = Vector3(0, 1.05, 0.39)
	_carried_visual.rotation.x = -0.12
	_visual.add_child(_carried_visual)
	_mesh(_carried_visual, _box(Vector3(0.37, 0.27, 0.025)), Vector3.ZERO, _material(Color("ffe39a")))
	for line_index in range(4):
		_mesh(_carried_visual, _box(Vector3(0.27 - line_index * 0.035, 0.009, 0.008)), Vector3(-line_index * 0.014, 0.075 - line_index * 0.048, 0.017), _material(Color("78552c")))
	_carried_visual.visible = false


func _build_bubble() -> void:
	_bubble_root = Node3D.new()
	_bubble_root.name = "SpeechBubble"
	_bubble_root.position = Vector3(0, 2.48, 0)
	add_child(_bubble_root)
	var bubble_shader = Shader.new()
	bubble_shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 vec2 q = abs(vec2(p.x, p.y - 0.1)) - vec2(0.88, 0.62);
 float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 0.09;
 float body = 1.0 - smoothstep(-0.008, 0.008, d);
 float tail = (1.0 - step(-0.61, p.y)) * step(-0.96, p.y) * (1.0 - step((0.96 + p.y) * 0.38, abs(p.x + 0.15)));
 ALBEDO = vec3(0.98, 0.975, 0.92);
 ALPHA = max(body, tail) * 0.96;
}
"""
	var bubble_material = ShaderMaterial.new()
	bubble_material.shader = bubble_shader
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 0.93)
	_mesh(_bubble_root, quad, Vector3.ZERO, bubble_material)
	_speech = Label3D.new()
	_speech.name = "TopicDialogue"
	_speech.position = Vector3(0, 0.05, 0.025)
	_speech.font_size = 34
	_speech.pixel_size = 0.0035
	_speech.modulate = Color("273641")
	_speech.outline_size = 0
	_speech.no_depth_test = false
	_speech.shaded = false
	_speech.width = 800.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_root.add_child(_speech)
	_name_label = Label3D.new()
	_name_label.position = Vector3(0, -0.59, 0.01)
	_name_label.font_size = 26
	_name_label.pixel_size = 0.0035
	_name_label.modulate = Color("fff8dc")
	_name_label.outline_size = 5
	_name_label.outline_modulate = Color("233744")
	_bubble_root.add_child(_name_label)


func _build_interaction_target() -> void:
	var target = AnimatableBody3D.new()
	target.name = "PersonInteractionTarget"
	target.collision_layer = 4
	target.collision_mask = 0
	target.sync_to_physics = false
	target.set_meta("npc_node", self)
	add_child(target)
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.31
	capsule.height = 1.84
	collision.shape = capsule
	collision.position.y = 0.92
	target.add_child(collision)
