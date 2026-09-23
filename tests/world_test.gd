extends SceneTree
## Run: redot --headless --fixed-fps 60 --path . --script res://tests/world_test.gd
## Exercises real architecture, world metadata and the shipping player controller.

const PlayerScript = preload("res://scripts/actors/player.gd")
var world
var player
var failures: Array = []
var clearance_samples = 0
var collider_entity_ids: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = load("res://scripts/world/office_world.gd").new()
	root.add_child(world)
	world.build()
	await physics_frame
	await physics_frame
	_check_metadata()
	_check_stair_clearances()
	_check_room_clearances()
	await _walk_all_stairs()
	print("WORLD: %d rooms, %d boards, %d searchable/selectable entities" % [world.rooms.size(), world.board_specs.size(), world.entities.size()])
	print("WORLD: %d capsule-clearance samples; climbed and descended all three floor connections" % clearance_samples)
	if failures.is_empty():
		print("PASS: world geometry, entity targets, room doors and actual player stair traversal")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _check_metadata() -> void:
	_expect(world.rooms.size() == 16, "Expected sixteen offices")
	_expect(world.board_specs.size() == 64, "Expected sixty-four kanban boards")
	var room_counts = [0, 0, 0, 0]
	var topics: Dictionary = {}
	var board_ids: Dictionary = {}
	for room in world.rooms:
		room_counts[room.floor] += 1
		_expect(not room.number.is_empty() and room.name.has("fi") and room.name.has("en"), "Missing bilingual room metadata: " + room.id)
		var board_count = 0
		for spec in world.board_specs:
			if spec.room_id == room.id:
				board_count += 1
		_expect(board_count == 4, "Office must have four boards: " + room.id)
	for count in room_counts:
		_expect(count == 4, "Each floor must have four offices")
	for spec in world.board_specs:
		_expect(not board_ids.has(spec.id), "Duplicate board identifier: " + spec.id)
		board_ids[spec.id] = true
		topics[spec.topic] = true
	_expect(topics.size() == 64, "Every board must have a distinct topic")
	_collect_entity_colliders(world)
	var entities_by_id: Dictionary = {}
	for entity in world.entities:
		_expect(not entities_by_id.has(entity.id), "Duplicate entity identifier: " + entity.id)
		entities_by_id[entity.id] = entity
		_expect(entity.floor >= 1 and entity.floor <= 4, "Entity floor must use one-based numbering: " + entity.id)
		_expect(entity.name.has("fi") and entity.name.has("en"), "Entity must have Finnish and English names: " + entity.id)
		_expect(collider_entity_ids.has(entity.id), "Entity has no selectable collider: " + entity.id)
	_expect(world.entities.size() >= 400, "Furniture and fixture catalog is incomplete")


func _collect_entity_colliders(node: Node) -> void:
	if node is StaticBody3D and node.has_meta("entity_id"):
		collider_entity_ids[node.get_meta("entity_id")] = true
		_expect(node.collision_layer == 1 or node.collision_layer == 16, "Entity uses an unexpected collision layer")
	for child in node.get_children():
		_collect_entity_colliders(child)


func _check_stair_clearances() -> void:
	for floor_index in range(3):
		var route = world.get_stair_route(floor_index)
		for segment in range(route.size() - 1):
			for sample_index in range(11):
				_check_capsule(route[segment].lerp(route[segment + 1], float(sample_index) / 10.0), "stairs %d segment %d" % [floor_index + 1, segment])


func _check_room_clearances() -> void:
	for room in world.rooms:
		var points = room.waypoints
		for segment in range(points.size()):
			for sample_index in range(9):
				_check_capsule(points[segment].lerp(points[(segment + 1) % points.size()], float(sample_index) / 8.0), room.id + " worker path")
		for sample_index in range(13):
			_check_capsule(Vector3(sign(room.center.x) * float(sample_index) * 0.42, room.center.y, sign(room.center.z) * 2.4), room.id + " doorway")


func _check_capsule(point: Vector3, label: String) -> void:
	var query = PhysicsShapeQueryParameters3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	query.shape = capsule
	query.collision_mask = 1
	query.transform.origin = point + Vector3(0, 0.98, 0)
	var hits = world.get_world_3d().direct_space_state.intersect_shape(query, 4)
	clearance_samples += 1
	if not hits.is_empty():
		_expect(false, "%s blocked at %s by %s" % [label, point, hits[0].collider.get_path()])


func _walk_all_stairs() -> void:
	PlayerScript.configure_inputs()
	player = PlayerScript.new()
	root.add_child(player)
	player.set_enabled(false)
	player.position = Vector3(0, 0.08, -11.7)
	for frame in range(10):
		await physics_frame
	for floor_index in range(3):
		await _walk_route(world.get_stair_route(floor_index))
	for floor_index in [2, 1, 0]:
		var route = world.get_stair_route(floor_index)
		route.reverse()
		await _walk_route(route)
	player.test_move = Vector2.ZERO


func _walk_route(route: Array) -> void:
	for target in route:
		var frames = 0
		while Vector2(target.x - player.position.x, target.z - player.position.z).length() > 0.14:
			player.test_move = Vector2(target.x - player.position.x, target.z - player.position.z).normalized()
			frames += 1
			await physics_frame
			if frames > 650:
				_expect(false, "Player stuck en route to %s at %s" % [target, player.position])
				player.position = target + Vector3(0, 0.08, 0)
				player.velocity = Vector3.ZERO
				break
		_expect(abs(player.position.y - target.y) <= 0.4, "Player stair height incorrect at %s: actual %s" % [target, player.position])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
