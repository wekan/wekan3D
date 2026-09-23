extends Node3D
## Procedural, asset-free four-storey studio and its walkable neighbourhood.
## All solid architecture is layer 1. Board/NPC interactions are added by main.

const FLOOR_HEIGHT = 4.0
const ROOM_X = 9.0
const ROOM_Z = 6.5
const STAIR_START = -13.2
const STAIR_END = -21.2
const STAIR_RUN = 8.0
const STAIR_RISE = 2.0
const PropFactory = preload("res://scripts/world/prop_factory.gd")

var campus_mode = false
var rooms: Array = []
var board_specs: Array = []
var reception_positions: Array = []
var entities: Array = []
var entity_nodes: Dictionary = {}
var configured_layout = false
var organization_id = "org_main"
var floor_count = 4
var building_depth = 24.0
var stair_offset = 0.0
var _floor_records: Array = []
var _room_records: Dictionary = {}
var _slot_count = 4
var _semantic_counts: Dictionary = {}
var _entity_root: Node3D
var _custom_entity_nodes: Dictionary = {}
var spawn_position = Vector3(0, 0.12, 10.6)
var _materials: Dictionary = {}
var _localized_signs: Array = []
var _built = false


static func slot_position(slot_index: int, floor_number: int = 1) -> Vector3:
	var y = float(floor_number - 1) * FLOOR_HEIGHT
	if slot_index < 4:
		return Vector3(-9 if slot_index < 2 else 9, y, -6.5 if slot_index % 2 == 0 else 6.5)
	return Vector3(-9 if slot_index % 2 == 0 else 9, y, -6.5 - 12.0 * (1 + int((slot_index - 4) / 2)))


func configure_layout(org_id: String, floor_specs: Array, room_specs: Array) -> void:
	if _built:
		push_error("configure_layout must be called before build")
		return
	configured_layout = true
	organization_id = org_id
	set_meta("organization_id", org_id)
	_floor_records.clear()
	_room_records.clear()
	var active_floors: Dictionary = {}
	for floor_spec in floor_specs:
		if str(floor_spec.get("organization_id", org_id)) != org_id or floor_spec.get("deleted", false) or floor_spec.get("in_pocket", false):
			continue
		_floor_records.append(floor_spec.duplicate(true))
	_floor_records.sort_custom(func(a, b): return int(a.get("number", 1)) < int(b.get("number", 1)))
	if _floor_records.is_empty():
		_floor_records.append({"id": org_id + "_ground", "organization_id": org_id, "number": 1, "name": {"fi": "Pohjakerros", "en": "Ground floor"}})
	for floor_spec in _floor_records:
		active_floors[str(floor_spec.id)] = true
		_room_records[str(floor_spec.id)] = {}
	var maximum_slot = 3
	for room_spec in room_specs:
		var floor_id = str(room_spec.get("floor_id", ""))
		if not active_floors.has(floor_id) or room_spec.get("deleted", false) or room_spec.get("in_pocket", false):
			continue
		var slot = maxi(0, int(room_spec.get("slot_index", 0)))
		_room_records[floor_id][slot] = room_spec.duplicate(true)
		maximum_slot = maxi(maximum_slot, slot)
	floor_count = _floor_records.size()
	var extra_rows = 0 if maximum_slot < 4 else 1 + int((maximum_slot - 4) / 2)
	_slot_count = 4 + extra_rows * 2
	building_depth = 24.0 + float(extra_rows) * 12.0
	stair_offset = -float(extra_rows) * 12.0


func _floor_id(index: int) -> String:
	return str(_floor_records[index].id) if configured_layout else organization_id + "_floor_" + str(index + 1)


func build() -> void:
	if _built:
		return
	_built = true
	_make_materials()
	_make_lighting()
	_make_outdoors()
	for floor_index in range(floor_count):
		_make_storey(floor_index)
	_make_stairs()
	_make_reception()
	_make_roof()
	_collect_entities(self)
	_tag_architecture(self)
	_isolate_entity_roots()
	if GameState.has_signal("language_changed"):
		GameState.language_changed.connect(_refresh_signs)
	if GameState.has_signal("entities_changed"):
		GameState.connect("entities_changed", _refresh_signs)
	_refresh_signs()


func _make_materials() -> void:
	_mat("ivory", Color("e6e7de"), 0.92)
	_mat("paper", Color("f5f1e6"), 0.82)
	_mat("concrete", Color("b8c2c1"), 0.94)
	_mat("navy", Color("182f40"), 0.78)
	_mat("teal", Color("277a7c"), 0.69)
	_mat("mint", Color("86bbb0"), 0.77)
	_mat("wood", Color("b9804e"), 0.7)
	_mat("wood_dark", Color("674a37"), 0.8)
	_mat("metal", Color("425563"), 0.35, 0.48)
	_mat("black", Color("14212a"), 0.82)
	_mat("carpet", Color("6b888b"), 1.0)
	_mat("hall_floor", Color("d5d5c8"), 0.72)
	_mat("orange", Color("efad64"), 0.72)
	_mat("leaf", Color("468061"), 0.9)
	_mat("leaf_light", Color("71a578"), 0.9)
	_mat("pot", Color("b46e51"), 0.9)
	_mat("soil", Color("413d34"), 1.0)
	_mat("grass", Color("65826a"), 1.0)
	_mat("path", Color("c2bda9"), 0.94)
	_mat("road", Color("555e62"), 1.0)
	_mat("white", Color("ecf0e8"), 0.83)
	_mat("city", Color("8a9b9c"), 0.98)
	_mat("city_blue", Color("819da6"), 0.88)
	var glass = _mat("glass", Color(0.61, 0.84, 0.88, 0.17), 0.16, 0.12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var glow = _mat("light", Color("f6f0d8"), 0.55)
	glow.emission_enabled = true
	glow.emission = Color("f6e6ba")
	glow.emission_energy_multiplier = 1.25
	var screen = _mat("screen", Color("16475a"), 0.45)
	screen.emission_enabled = true
	screen.emission = Color("174e62")
	screen.emission_energy_multiplier = 0.55
	_mat("code", Color("8cd9c5"), 0.6)
	_mat("code_blue", Color("89bbde"), 0.6)


func _mat(key: String, color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var value = StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	value.metallic = metallic
	_materials[key] = value
	return value


func _group(group_name: String, parent: Node = self) -> Node3D:
	var node = Node3D.new()
	node.name = group_name
	parent.add_child(node)
	var semantic_names = {
		"DeveloperDesk": ["Työpöytä", "Developer desk", "Puinen ohjelmoijan työpiste, tietokone, näyttö, näppäimistö, hiiri, muistikirja ja kahvikuppi.", "Wooden programmer workstation, computer, monitor, keyboard, mouse, notebook and coffee mug.", "furniture"],
		"ErgonomicChair": ["Työtuoli", "Ergonomic chair", "Säädettävä sinivihreä työtuoli käsinojilla.", "Adjustable teal office chair with armrests.", "furniture"],
		"BooksAndEquipment": ["Kirjahylly ja tulostin", "Bookshelf and printer", "Puinen kirjahylly, ohjelmointikirjoja ja toimistotulostin.", "Wooden bookshelf with programming books and an office printer.", "furniture"],
		"Plant": ["Viherkasvi", "Indoor plant", "Lehtevä toimistokasvi terrakottaruukussa.", "Leafy office plant in a terracotta pot.", "furniture"],
		"WindowBay": ["Ikkuna", "Window", "Läpinäkyvä ulkoikkuna, metallikehykset ja puinen ikkunalauta.", "Transparent exterior window with metal frames and a wooden sill.", "fixture"],
		"Reception": ["Vastaanottotiski", "Reception desk", "Aulan vastaanottotiski, kaksi tietokonetta, näyttöä ja nimikylttiä.", "Lobby reception desk with two computers, monitors and nameplates.", "furniture"],
		"ParkBench": ["Puiston penkki", "Park bench", "Puinen ulkopenkki puutarhassa.", "Wooden outdoor bench in the garden.", "furniture"],
		"ParkTree": ["Puiston puu", "Park tree", "Lehtevä puistopuu rakennuksen pihalla.", "Leafy park tree outside the office building.", "furniture"],
		"CampusRoad": ["Kampuksen tie", "Campus road", "Asfalttitie ja ajoratamerkinnät toimiston edessä.", "Asphalt road and lane markings in front of the office.", "furniture"],
		"WalkableSwitchbackStairs": ["Portaikko", "Staircase", "Neljä kerrosta yhdistävät kaksisyöksyiset portaat ja välitasanteet.", "Switchback stairs and intermediate landings connecting all four floors.", "fixture"],
	}
	if semantic_names.has(group_name):
		var values = semantic_names[group_name]
		_mark_entity(node, values[0], values[1], values[2], values[3], values[4])
	return node


func _mark_entity(node: Node3D, fi: String, en: String, description_fi: String, description_en: String, kind: String = "furniture") -> void:
	node.set_meta("entity", {"name": {"fi": fi, "en": en}, "description": {"fi": description_fi, "en": description_en}, "kind": kind})


func _collect_entities(node: Node) -> void:
	if node is Node3D and node.has_meta("entity"):
		var entity = node.get_meta("entity").duplicate(true)
		var pos = node.get_meta("entity_position", _relative_transform(node).origin)
		var room_id = ""
		var floor_id = ""
		var ancestor = node.get_parent()
		while ancestor != null and ancestor != self:
			if room_id.is_empty() and ancestor.has_meta("room_id"):
				room_id = str(ancestor.get_meta("room_id"))
			if floor_id.is_empty() and ancestor.has_meta("floor_id") and not ancestor.has_meta("entity"):
				floor_id = str(ancestor.get_meta("floor_id"))
			ancestor = ancestor.get_parent()
		var explicit_floor_scope = not floor_id.is_empty()
		var number = clampi(int(floor(float(pos.y) / FLOOR_HEIGHT)) + 1, 1, floor_count)
		if floor_id.is_empty():
			floor_id = _floor_id(number - 1)
		var scope = room_id if not room_id.is_empty() else floor_id if explicit_floor_scope else organization_id + "_shared"
		# Scope-local type ordinals survive other rooms/floors being inserted.
		var semantic = str(entity.name.en).to_snake_case().replace(" ", "_").replace("'", "")
		var counter_key = scope + ":" + semantic
		_semantic_counts[counter_key] = int(_semantic_counts.get(counter_key, 0)) + 1
		entity["id"] = "entity_%s_%s_%s_%02d" % [organization_id, scope, semantic, _semantic_counts[counter_key]]
		entity["legacy_id"] = "world_%04d" % (entities.size() + 1)
		entity["room_id"] = room_id
		entity["floor_id"] = floor_id
		entity["organization_id"] = organization_id
		entity["floor"] = number
		entity["template"] = _entity_template(str(entity.name.en))
		entity["deleted"] = false
		entity["in_pocket"] = false
		entity["position"] = {"x": pos.x, "y": pos.y, "z": pos.z}
		entities.append(entity)
		entity_nodes[entity["id"]] = node
		node.set_meta("entity_id", entity["id"])
		node.set_meta("room_id", room_id)
		node.set_meta("floor_id", floor_id)
		node.set_meta("organization_id", organization_id)
		# Solid furniture remains physical layer 1. Small visual objects get
		# separate interaction-only layer 16 shapes, so mugs cannot block feet.
		if _bind_entity_colliders(node, entity["id"], node) == 0:
			_add_entity_target(node, entity["id"])
	for child in node.get_children():
		_collect_entities(child)


func _entity_template(english_name: String) -> String:
	var templates = {"Developer desk": "desk", "Ergonomic chair": "chair", "Computer monitor": "monitor", "Reception computer": "monitor", "Indoor plant": "plant", "Lounge sofa": "sofa", "Bookshelf and printer": "bookshelf", "Park tree": "tree", "Park bench": "bench", "Coffee mug": "mug", "Keyboard": "keyboard", "Reception keyboard": "keyboard", "Computer mouse": "mouse", "Notebook": "notebook", "Reception desk": "reception", "Kitchen cabinet": "cabinet", "Coffee machine": "coffee_machine"}
	return "road" if english_name == "Campus road" else str(templates.get(english_name, "fixture"))


func _tag_architecture(node: Node, inherited: Dictionary = {}) -> void:
	var context = inherited.duplicate()
	context["organization_id"] = organization_id
	for key in ["floor_id", "room_id"]:
		if node.has_meta(key):
			context[key] = node.get_meta(key)
	if node is StaticBody3D:
		if not context.has("floor_id"):
			var index = clampi(int(floor(_relative_transform(node).origin.y / FLOOR_HEIGHT)), 0, floor_count - 1)
			context["floor_id"] = _floor_id(index)
		for key in context:
			node.set_meta(key, context[key])
		if not node.has_meta("room_id"):
			node.set_meta("room_id", "")
	for child in node.get_children():
		_tag_architecture(child, context)


func _isolate_entity_roots() -> void:
	_entity_root = Node3D.new()
	_entity_root.name = "PortableAndNamedObjects"
	add_child(_entity_root)
	for id in entity_nodes:
		var node = entity_nodes[id]
		var original = _relative_transform(node)
		node.get_parent().remove_child(node)
		_entity_root.add_child(node)
		node.transform = original
		node.set_meta("default_transform", original)


func apply_saved_entities(state) -> void:
	var saved_entities = state if state is Dictionary else state.entities
	for id in entity_nodes:
		var node = entity_nodes[id]
		if not is_instance_valid(node):
			continue
		var saved = saved_entities.get(id, {})
		var hidden = saved.get("deleted", false) or saved.get("in_pocket", false) or (not saved.is_empty() and str(saved.get("organization_id", organization_id)) != organization_id)
		node.visible = not hidden
		_set_entity_collision_enabled(node, not hidden)
		if hidden or saved.is_empty():
			continue
		var value = saved.get("position", {})
		if value is Dictionary:
			var world_pos = Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
			var anchor = _relative_transform(node).origin
			var target = to_local(world_pos) if is_inside_tree() else world_pos - position
			# Some fixtures use a semantic anchor separate from their Node origin.
			if node.has_meta("entity_position"):
				var base = node.get_meta("default_transform").origin
				target -= Vector3(node.get_meta("entity_position")) - base
			node.position += target - anchor
		if saved.has("rotation_y"):
			node.rotation.y = float(saved.rotation_y)
		PropFactory.apply_appearance(node, saved.get("appearance", {}))
	_sync_custom_entities(saved_entities)


func _sync_custom_entities(saved_entities: Dictionary) -> void:
	if _entity_root == null:
		return
	for id in _custom_entity_nodes.keys():
		var record: Dictionary = saved_entities.get(id, {})
		var stale = record.is_empty() or record.get("deleted", false) or record.get("in_pocket", false) or str(record.get("organization_id", "")) != organization_id
		if stale:
			var node = _custom_entity_nodes[id]
			if is_instance_valid(node): node.queue_free()
			_custom_entity_nodes.erase(id)
	for id in saved_entities:
		var record: Dictionary = saved_entities[id]
		if not record.get("custom", false) or record.get("kind", "") == "person" or record.get("deleted", false) or record.get("in_pocket", false) or str(record.get("organization_id", "")) != organization_id:
			continue
		var node: Node3D = _custom_entity_nodes.get(id, null)
		if node == null or not is_instance_valid(node):
			node = PropFactory.new().create(record)
			_entity_root.add_child(node)
			_custom_entity_nodes[id] = node
		var p = record.get("position", {})
		if p is Dictionary:
			node.global_position = Vector3(float(p.get("x", 0)), float(p.get("y", 0)), float(p.get("z", 0)))
		node.rotation.y = float(record.get("rotation_y", 0.0))
		PropFactory.apply_appearance(node, record.get("appearance", {}))


func _set_entity_collision_enabled(node: Node, enabled: bool) -> void:
	if node is StaticBody3D:
		if not node.has_meta("saved_collision_layer"):
			node.set_meta("saved_collision_layer", node.collision_layer)
		node.collision_layer = int(node.get_meta("saved_collision_layer")) if enabled else 0
	for child in node.get_children():
		_set_entity_collision_enabled(child, enabled)


func _relative_transform(node: Node3D) -> Transform3D:
	# Keeping this local also allows building the world in isolated test trees.
	var result = node.transform
	var parent = node.get_parent()
	while parent is Node3D and parent != self:
		result = parent.transform * result
		parent = parent.get_parent()
	return result


func _bind_entity_colliders(node: Node, entity_id: String, entity_root: Node) -> int:
	if node != entity_root and node.has_meta("entity"):
		return 0
	var count = 0
	if node is StaticBody3D:
		node.set_meta("entity_id", entity_id)
		count += 1
	for child in node.get_children():
		count += _bind_entity_colliders(child, entity_id, entity_root)
	return count


func _add_entity_target(node: Node3D, entity_id: String) -> void:
	var bounds = _entity_mesh_bounds(node, Transform3D.IDENTITY, node)
	if bounds.size.length_squared() < 0.000001:
		return
	var body = StaticBody3D.new()
	body.name = "EntityTarget"
	body.collision_layer = 16
	body.collision_mask = 0
	body.position = bounds.get_center()
	body.set_meta("entity_id", entity_id)
	var shape = BoxShape3D.new()
	shape.size = bounds.size.max(Vector3(0.035, 0.035, 0.035))
	var collision = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	node.add_child(body)


func _entity_mesh_bounds(node: Node3D, relative: Transform3D, entity_root: Node) -> AABB:
	var result = AABB()
	if node != entity_root and node.has_meta("entity"):
		return result
	if node is MeshInstance3D:
		result = relative * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds = _entity_mesh_bounds(child, relative * child.transform, entity_root)
			if child_bounds.size.length_squared() > 0.000001:
				result = child_bounds if result.size.length_squared() < 0.000001 else result.merge(child_bounds)
	return result


func _box(parent: Node, size: Vector3, pos: Vector3, material_key: String, solid: bool = false, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _materials[material_key]
	mesh.position = pos
	mesh.rotation = rotation_value
	parent.add_child(mesh)
	if material_key == "glass" or material_key == "light":
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		_box_collider(mesh, size)
	return mesh


func _box_collider(parent: Node, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _cylinder(parent: Node, radius: float, height: float, pos: Vector3, material_key: String, top_ratio: float = 1.0) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.top_radius = radius * top_ratio
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.position = pos
	mesh.material_override = _materials[material_key]
	parent.add_child(mesh)
	return mesh


func _sphere(parent: Node, radius: float, pos: Vector3, scale_value: Vector3, material_key: String) -> void:
	var mesh = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 10
	shape.rings = 5
	mesh.mesh = shape
	mesh.position = pos
	mesh.scale = scale_value
	mesh.material_override = _materials[material_key]
	parent.add_child(mesh)


func _sign(parent: Node, pos: Vector3, text_fi: String, text_en: String, yaw: float = 0.0, font_size: int = 40, color: Color = Color("e9f0e8"), pixel_size: float = 0.012) -> Label3D:
	var label = Label3D.new()
	label.position = pos
	label.rotation.y = yaw
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 3
	label.outline_modulate = Color(0.05, 0.1, 0.13, 0.6)
	label.no_depth_test = false
	label.text = text_fi
	parent.add_child(label)
	_localized_signs.append({"node": label, "fi": text_fi, "en": text_en})
	return label


func _refresh_signs() -> void:
	for entry in _localized_signs:
		var value = entry.get(GameState.language, entry["en"])
		if entry.has("room_id"):
			var saved_rooms = GameState.get("rooms")
			if saved_rooms is Dictionary and saved_rooms.has(entry["room_id"]):
				var saved_name = saved_rooms[entry["room_id"]].get("name", {})
				if saved_name is Dictionary:
					value = saved_name.get(GameState.language, value)
		entry["node"].text = value


func _make_lighting() -> void:
	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6b98b9")
	sky_material.sky_horizon_color = Color("d2deda")
	sky_material.ground_bottom_color = Color("8b9483")
	sky_material.ground_horizon_color = Color("d2deda")
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d5e0e3")
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	var sun = DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	add_child(sun)


func _lamp(parent: Node, pos: Vector3, width: float = 2.4, illuminate: bool = true) -> void:
	var fixture = _group("CeilingLightAssembly", parent)
	fixture.position = pos
	_mark_entity(fixture, "Kattovalaisin", "Ceiling light", "Lämmin riippuva LED-toimistovalaisin.", "Warm suspended LED office light.", "fixture")
	_box(fixture, Vector3(width + 0.12, 0.1, 0.44), Vector3.ZERO, "navy")
	_box(fixture, Vector3(width, 0.035, 0.34), Vector3(0, -0.055, 0), "light")
	if illuminate:
		var light = OmniLight3D.new()
		light.position = Vector3(0, -0.3, 0)
		light.light_color = Color("f8f0dc")
		light.light_energy = 0.68
		light.omni_range = 10.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		fixture.add_child(light)


func _wrap_parts(parent: Node3D, first: int, anchor: Vector3, semantic_source: Node3D) -> Node3D:
	var parts = parent.get_children().slice(first)
	var entity = semantic_source.get_meta("entity")
	semantic_source.remove_meta("entity")
	var root = Node3D.new()
	root.name = "CompleteObjectAssembly"
	root.position = anchor
	root.set_meta("entity", entity)
	parent.add_child(root)
	for part in parts:
		parent.remove_child(part)
		root.add_child(part)
		part.position -= anchor
	return root


func _make_storey(floor_index: int) -> void:
	var y = float(floor_index) * FLOOR_HEIGHT
	var storey = _group("Floor_%d" % (floor_index + 1))
	storey.set_meta("floor_id", _floor_id(floor_index))
	_box(storey, Vector3(30.4, 0.24, building_depth + 0.4), Vector3(0, y - 0.12, stair_offset / 2.0), "concrete", true)
	_box(storey, Vector3(5.8, 0.035, building_depth - 0.1), Vector3(0, y + 0.018, stair_offset / 2.0), "hall_floor")
	# The thin teal inlay leads from the lobby to the rear stairwell.
	_box(storey, Vector3(0.13, 0.012, building_depth - 0.4), Vector3(0, y + 0.041, stair_offset / 2.0), "teal")
	for slot in range(_slot_count):
		var center = slot_position(slot, floor_index + 1)
		var side = -1 if center.x < 0 else 1
		var depth_side = 1 if slot in [1, 3] else -1
		var offset = center.z - float(depth_side) * ROOM_Z
		var record = _room_records.get(_floor_id(floor_index), {}).get(slot, {}) if configured_layout else {}
		if configured_layout and record.is_empty():
			_make_empty_slot(storey, floor_index, slot)
			continue
		_make_office(storey, floor_index, side, depth_side, record, offset, slot)
	# Exterior wall above the street entrance, with glazing on upper floors.
	if floor_index == 0:
		_box(storey, Vector3(1.05, 3.76, 0.22), Vector3(-2.52, y + 1.88, 12), "navy", true)
		_box(storey, Vector3(1.05, 3.76, 0.22), Vector3(2.52, y + 1.88, 12), "navy", true)
		_box(storey, Vector3(4.0, 0.68, 0.25), Vector3(0, y + 3.42, 12), "navy", true)
		# Open leaves make the entrance obviously passable in both directions.
		_box(storey, Vector3(0.055, 2.8, 1.4), Vector3(-1.93, y + 1.4, 12.62), "glass")
		_box(storey, Vector3(0.055, 2.8, 1.4), Vector3(1.93, y + 1.4, 12.62), "glass")
		_sign(storey, Vector3(0, y + 3.42, 12.15), "KANBAN HOUSE", "KANBAN HOUSE", 0, 38, Color("ecf0e8"), 0.013)
		_sign(storey, Vector3(0, y + 3.4, 11.84), "ULOS • PUISTO", "EXIT • PARK", PI, 28, Color("ecf0e8"), 0.009)
	else:
		_window_wall(storey, Vector3(0, y, 12), 6.0, 0.0)
		_make_lounge(storey, y, floor_index)
	for z in [-9.0, -3.5, 3.5, 9.0]:
		_lamp(storey, Vector3(0, y + 3.58, z), 2.6, z == -3.5 or z == 9.0)
	for extension in range(int(-stair_offset / 12.0)):
		_lamp(storey, Vector3(0, y + 3.58, -18.0 - float(extension) * 12.0), 2.6)
	# A suspended rear sign is visible all the way from the reception.
	_box(storey, Vector3(4.5, 0.58, 0.14), Vector3(0, y + 3.27, -10.9 + stair_offset), "navy")
	var floor_fi = "%d. KERROS" % (floor_index + 1)
	var floor_en = "FLOOR %d" % (floor_index + 1)
	if configured_layout:
		floor_fi = str(_floor_records[floor_index].get("name", {}).get("fi", floor_fi))
		floor_en = str(_floor_records[floor_index].get("name", {}).get("en", floor_en))
	_sign(storey, Vector3(0, y + 3.27, -10.81 + stair_offset), floor_fi + "   ↑ PORTAAT", floor_en + "   ↑ STAIRS", 0, 32, Color("a7d6c8"), 0.009)


func _room_number(floor_index: int, side: int, depth_side: int) -> String:
	var index = (0 if side < 0 else 2) + (0 if depth_side < 0 else 1) + 1
	return "%d%02d" % [floor_index + 1, index]


func _make_office(parent: Node, floor_index: int, side: int, depth_side: int, record: Dictionary = {}, z_offset: float = 0.0, slot: int = 0) -> void:
	var y = float(floor_index) * FLOOR_HEIGHT
	var x = float(side) * ROOM_X
	var z = float(depth_side) * ROOM_Z
	var room_id = str(record.get("id", "room_%s" % _room_number(floor_index, side, depth_side)))
	var room = _group(room_id, parent)
	room.position.z = z_offset
	room.set_meta("room_id", room_id)
	room.set_meta("floor_id", _floor_id(floor_index))
	var topic = int(record.get("topic", floor_index * 16 + (0 if side < 0 else 8) + (0 if depth_side < 0 else 4)))
	var glass_room = (floor_index + (0 if side < 0 else 1) + (0 if depth_side < 0 else 1)) % 2 == 0
	_box(room, Vector3(11.82, 0.045, 11.84), Vector3(x, y + 0.022, float(depth_side) * 6.0), "carpet")
	# Exterior side has a solid board backing and windows on both sides.
	var exterior_x = float(side) * 15.0
	var side_yaw = PI / 2.0
	_window_wall(room, Vector3(exterior_x, y, float(depth_side) * 2.0), 4.0, side_yaw)
	_window_wall(room, Vector3(exterior_x, y, float(depth_side) * 10.55), 2.9, side_yaw)
	_box(room, Vector3(0.24, 3.76, 5.3), Vector3(exterior_x, y + 1.88, z), "ivory", true)
	# Front/rear facade: board in the middle, daylight at either side.
	var edge_z = float(depth_side) * 12.0
	_box(room, Vector3(5.2, 3.76, 0.24), Vector3(x, y + 1.88, edge_z), "ivory", true)
	_window_wall(room, Vector3(x - 4.3, y, edge_z), 3.25, 0.0)
	_window_wall(room, Vector3(x + 4.3, y, edge_z), 3.25, 0.0)
	# Shared middle wall is built only once, but supports a board on each side.
	if depth_side < 0:
		_box(room, Vector3(12.0, 3.76, 0.2), Vector3(x, y + 1.88, 0), "ivory", true)
	# Two-metre open hall doorway centred at z +/-2.4.
	var hall_x = float(side) * 3.0
	var wall_material = "glass" if glass_room else "ivory"
	_box(room, Vector3(0.18, 3.76, 1.35), Vector3(hall_x, y + 1.88, float(depth_side) * 0.675), wall_material, true)
	_box(room, Vector3(0.18, 3.76, 8.55), Vector3(hall_x, y + 1.88, float(depth_side) * 7.725), wall_material, true)
	_box(room, Vector3(0.21, 0.81, 2.1), Vector3(hall_x, y + 3.355, float(depth_side) * 2.4), "ivory", true)
	for jamb_z in [1.35, 3.45]:
		_box(room, Vector3(0.24, 2.95, 0.09), Vector3(hall_x, y + 1.475, float(depth_side) * jamb_z), "navy")
	if glass_room:
		for mullion_z in [0.05, 5.8, 9.8, 11.92]:
			_box(room, Vector3(0.2, 3.76, 0.065), Vector3(hall_x, y + 1.88, float(depth_side) * mullion_z), "navy")
		_box(room, Vector3(0.2, 0.075, 12), Vector3(hall_x, y + 0.15, float(depth_side) * 6), "navy")
		_box(room, Vector3(0.2, 0.075, 12), Vector3(hall_x, y + 3.65, float(depth_side) * 6), "navy")
		# Opaque mounting panel prevents seeing mirrored cards through glass.
		_box(room, Vector3(0.16, 2.83, 4.82), Vector3(hall_x + float(side) * 0.12, y + 2.05, float(depth_side) * 8.0), "navy", true)
	# Small, readable base strips add scale without covering any board.
	_box(room, Vector3(11.8, 0.13, 0.08), Vector3(x, y + 0.075, float(depth_side) * 0.15), "wood_dark")
	_box(room, Vector3(0.08, 0.13, 11.7), Vector3(float(side) * 14.83, y + 0.075, float(depth_side) * 6.0), "wood_dark")
	_lamp(room, Vector3(x, y + 3.54, z), 3.5)
	_lamp(room, Vector3(x, y + 3.54, float(depth_side) * 3.0), 2.5, false)
	# Central workstations leave a continuous, two-metre-wide board route.
	_make_desk(room, Vector3(x - 1.15, y, float(depth_side) * 6.4), 0.0, floor_index + side)
	_make_desk(room, Vector3(x + 1.15, y, float(depth_side) * 6.4), PI, floor_index + depth_side)
	_make_plant(room, Vector3(x - float(side) * 4.65, y, float(depth_side) * 10.95), 1.05)
	_make_plant(room, Vector3(x + float(side) * 4.6, y, float(depth_side) * 1.15), 0.8)
	_make_shelf(room, Vector3(x + float(side) * 3.15, y, float(depth_side) * 1.05), float(side) * PI / 2.0)
	# Waypoints form an obstacle-free ring; include each board's approach area.
	var near_x = float(side) * 5.0
	var far_x = float(side) * 12.45
	var near_z = float(depth_side) * 2.45
	var far_z = float(depth_side) * 9.65
	var waypoints = [Vector3(near_x, y, near_z), Vector3(x, y, near_z), Vector3(far_x, y, near_z), Vector3(far_x, y, far_z), Vector3(x, y, far_z), Vector3(near_x, y, far_z)]
	var room_names_fi = ["Ajoneuvolaboratorio", "Ohjelmistostudio", "Robotiikkahuone", "Tuotesuunnittelu", "Pilvipalvelut", "Testausstudio", "Mobiilikehitys", "Verkkopalvelut", "Datastudio", "Turvallisuushuone", "Pelikehitys", "Muotoiluhuone", "Energiastudio", "Tutkimuslaboratorio", "Asiakaspalvelut", "Tulevaisuushuone"]
	var room_names_en = ["Vehicle laboratory", "Software studio", "Robotics room", "Product design", "Cloud services", "Testing studio", "Mobile development", "Web services", "Data studio", "Security room", "Game development", "Design room", "Energy studio", "Research laboratory", "Customer services", "Future studio"]
	var room_index = posmod(int(topic / 4), room_names_fi.size())
	var room_name = record.get("name", {"fi": room_names_fi[room_index], "en": room_names_en[room_index]})
	var room_number = str(record.get("number", _room_number(floor_index, side, depth_side)))
	var translated_offset = Vector3(0, 0, z_offset)
	for index in range(waypoints.size()):
		waypoints[index] += translated_offset
	rooms.append({
		"id": room_id, "floor": floor_index, "floor_id": _floor_id(floor_index), "organization_id": organization_id, "slot_index": slot, "center": Vector3(x, y, z + z_offset), "topic": topic,
		"number": room_number, "name": room_name,
		"bounds": AABB(Vector3(-14.8 if side < 0 else 3.2, y - 0.15, (-11.8 if depth_side < 0 else 0.2) + z_offset), Vector3(11.6, 3.9, 11.6)),
		"npc_positions": [Vector3(near_x, y, far_z + z_offset), Vector3(far_x, y, near_z + z_offset)],
		"door_position": Vector3(float(side) * 3, y, float(depth_side) * 2.4 + z_offset),
		"waypoints": waypoints,
	})
	_sign(room, Vector3(float(side) * 2.87, y + 2.9, float(depth_side) * 2.4), str(room_name.get("fi", "")), str(room_name.get("en", "")), -float(side) * PI / 2.0, 22, Color("25565b"), 0.008)
	_localized_signs[-1]["room_id"] = room_id
	_sign(room, Vector3(float(side) * 2.87, y + 3.2, float(depth_side) * 2.4), "STUDIO " + room_number, "STUDIO " + room_number, -float(side) * PI / 2.0, 29, Color("25565b"), 0.012)
	# Local +Z is the readable side of every kanban board.
	var specs = [
		{"position": Vector3(float(side) * 14.73, y + 2.05, z), "yaw": -float(side) * PI / 2.0},
		{"position": Vector3(float(side) * 3.27, y + 2.05, float(depth_side) * 8.0), "yaw": float(side) * PI / 2.0},
		{"position": Vector3(x, y + 2.05, float(depth_side) * 11.72), "yaw": PI if depth_side > 0 else 0.0},
		{"position": Vector3(x, y + 2.05, float(depth_side) * 0.23), "yaw": 0.0 if depth_side > 0 else PI},
	]
	for index in range(specs.size()):
		var spec = specs[index]
		spec.position += translated_offset
		spec["id"] = "%s_board_%d" % [room_id, index + 1]
		spec["room_id"] = room_id
		spec["floor_id"] = _floor_id(floor_index)
		spec["organization_id"] = organization_id
		spec["topic"] = topic + index
		board_specs.append(spec)


func _make_empty_slot(parent: Node, floor_index: int, slot: int) -> void:
	var center = slot_position(slot, floor_index + 1)
	var root = _group("OpenLounge_%d" % slot, parent)
	root.set_meta("floor_id", _floor_id(floor_index))
	var side = sign(center.x)
	var depth_side = 1.0 if slot in [1, 3] else -1.0
	var offset = center.z - depth_side * ROOM_Z
	_box(root, Vector3(11.82, 0.045, 11.84), Vector3(center.x, center.y + 0.022, depth_side * 6 + offset), "carpet")
	for segment in range(3):
		_window_wall(root, Vector3(side * 15.0, center.y, depth_side * (2.0 + float(segment) * 4.0) + offset), 4.0, PI / 2.0)
	if slot in [1, 3]:
		for segment in range(3):
			_window_wall(root, Vector3(center.x - 4.0 + float(segment) * 4.0, center.y, 12), 4.0, 0.0)
	if center.z < -building_depth + 19.0:
		for segment in range(3):
			_window_wall(root, Vector3(center.x - 4.0 + float(segment) * 4.0, center.y, 12.0 - building_depth), 4.0, 0.0)
	_lamp(root, center + Vector3(0, 3.54, 0), 3.0)


func _window_wall(parent: Node, pos: Vector3, width: float, yaw: float) -> void:
	var root = _group("WindowBay", parent)
	root.position = pos
	root.rotation.y = yaw
	_box(root, Vector3(width, 0.64, 0.23), Vector3(0, 0.32, 0), "ivory", true)
	_box(root, Vector3(width, 0.43, 0.24), Vector3(0, 3.545, 0), "navy", true)
	_box(root, Vector3(width - 0.1, 2.7, 0.045), Vector3(0, 1.98, 0), "glass", true)
	for frame_x in [-width / 2.0 + 0.04, width / 2.0 - 0.04]:
		_box(root, Vector3(0.085, 2.75, 0.12), Vector3(frame_x, 1.98, 0), "metal")
	_box(root, Vector3(width, 0.085, 0.34), Vector3(0, 0.68, 0), "wood")
	_box(root, Vector3(width, 0.045, 0.1), Vector3(0, 2.7, 0), "metal")


func _make_desk(parent: Node, pos: Vector3, yaw: float, variant: int) -> void:
	var root = _group("DeveloperDesk", parent)
	root.position = pos
	root.rotation.y = yaw
	_box(root, Vector3(1.95, 0.09, 0.92), Vector3(0, 0.77, 0), "wood", true)
	for leg_x in [-0.82, 0.82]:
		_box(root, Vector3(0.06, 0.7, 0.72), Vector3(leg_x, 0.36, 0), "metal")
	_box(root, Vector3(0.33, 0.65, 0.72), Vector3(-0.68, 0.355, 0.02), "navy", true)
	for drawer_y in [0.31, 0.57]:
		_box(root, Vector3(0.16, 0.025, 0.027), Vector3(-0.68, drawer_y, 0.39), "metal")
	var monitor = _box(root, Vector3(0.82, 0.48, 0.065), Vector3(-0.1, 1.21, -0.22), "black")
	_mark_entity(monitor, "Tietokoneen näyttö", "Computer monitor", "Laajakuvanäyttö, jossa näkyy lähdekoodia.", "Widescreen monitor displaying source code.")
	_box(root, Vector3(0.76, 0.42, 0.012), Vector3(-0.1, 1.21, -0.179), "screen")
	_box(root, Vector3(0.06, 0.18, 0.06), Vector3(-0.1, 0.91, -0.22), "metal")
	_box(root, Vector3(0.29, 0.025, 0.2), Vector3(-0.1, 0.827, -0.2), "black")
	# Two tiny panes of source code, drawn as geometry, remain crisp up close.
	for line in range(7):
		var length_value = 0.18 + float((line * 7 + abs(variant)) % 5) * 0.055
		_box(root, Vector3(length_value, 0.012, 0.004), Vector3(-0.28 + float(line % 2) * 0.04, 1.35 - float(line) * 0.046, -0.17), "code" if line % 3 != 0 else "code_blue")
	var keyboard = _box(root, Vector3(0.49, 0.028, 0.18), Vector3(-0.12, 0.836, 0.16), "black")
	_mark_entity(keyboard, "Näppäimistö", "Keyboard", "Ohjelmoijan kompakti musta näppäimistö.", "Programmer's compact black keyboard.")
	for row in range(3):
		_box(root, Vector3(0.42, 0.006, 0.014), Vector3(-0.12, 0.855, 0.11 + float(row) * 0.05), "metal")
	var mouse = _box(root, Vector3(0.11, 0.035, 0.17), Vector3(0.3, 0.84, 0.16), "black")
	_mark_entity(mouse, "Hiiri", "Computer mouse", "Musta tietokonehiiri työpöydällä.", "Black computer mouse on the desk.")
	var mug = _cylinder(root, 0.075, 0.13, Vector3(0.7, 0.875, 0.23), "paper")
	_mark_entity(mug, "Kahvikuppi", "Coffee mug", "Keraaminen kahvikuppi työpöydällä.", "Ceramic coffee mug on the desk.")
	var notebook = _box(root, Vector3(0.25, 0.028, 0.34), Vector3(0.66, 0.83, -0.16), "teal")
	_mark_entity(notebook, "Muistikirja", "Notebook", "Sinivihreä paperinen muistikirja tehtävämuistiinpanoille.", "Teal paper notebook for task notes.")
	_box(root, Vector3(0.19, 0.012, 0.28), Vector3(0.66, 0.85, -0.16), "paper")
	_make_chair(root, Vector3(0, 0, 1.0))


func _make_chair(parent: Node, pos: Vector3) -> void:
	var root = _group("ErgonomicChair", parent)
	root.position = pos
	_box(root, Vector3(0.6, 0.12, 0.57), Vector3(0, 0.49, 0), "navy", true)
	_box(root, Vector3(0.58, 0.64, 0.1), Vector3(0, 0.84, 0.25), "teal", true)
	_cylinder(root, 0.06, 0.37, Vector3(0, 0.22, 0), "metal")
	_box(root, Vector3(0.73, 0.055, 0.075), Vector3(0, 0.055, 0), "black")
	_box(root, Vector3(0.075, 0.055, 0.73), Vector3(0, 0.055, 0), "black")
	for side in [-1, 1]:
		_box(root, Vector3(0.08, 0.045, 0.38), Vector3(float(side) * 0.35, 0.69, 0), "metal")


func _make_shelf(parent: Node, pos: Vector3, yaw: float) -> void:
	var root = _group("BooksAndEquipment", parent)
	root.position = pos
	root.rotation.y = yaw
	_box(root, Vector3(1.1, 1.3, 0.37), Vector3(0, 0.65, 0), "wood_dark", true)
	for shelf_y in [0.43, 0.88, 1.28]:
		_box(root, Vector3(0.99, 0.35, 0.025), Vector3(0, shelf_y - 0.16, 0.198), "navy")
		_box(root, Vector3(1.13, 0.045, 0.43), Vector3(0, shelf_y, 0.025), "wood")
	for book in range(7):
		var keys = ["teal", "paper", "orange", "mint"]
		_box(root, Vector3(0.075, 0.25 + float(book % 3) * 0.025, 0.23), Vector3(-0.4 + float(book) * 0.12, 0.59, 0.07), keys[book % 4])
	_box(root, Vector3(0.6, 0.21, 0.3), Vector3(0, 1.4, 0), "paper")
	_box(root, Vector3(0.47, 0.025, 0.22), Vector3(0, 1.515, 0), "navy")


func _make_plant(parent: Node, pos: Vector3, scale_value: float = 1.0) -> void:
	var root = _group("Plant", parent)
	root.position = pos
	root.scale = Vector3.ONE * scale_value
	_cylinder(root, 0.25, 0.43, Vector3(0, 0.215, 0), "pot", 1.22)
	_cylinder(root, 0.28, 0.025, Vector3(0, 0.428, 0), "soil")
	_cylinder(root, 0.045, 0.9, Vector3(0, 0.88, 0), "wood_dark", 0.6)
	for leaf_index in range(5):
		var angle = float(leaf_index) * TAU / 5.0
		_sphere(root, 0.31, Vector3(cos(angle) * 0.21, 1.06 + float(leaf_index % 2) * 0.2, sin(angle) * 0.21), Vector3(0.76, 1.18, 0.72), "leaf" if leaf_index % 2 == 0 else "leaf_light")


func _make_lounge(parent: Node, y: float, floor_index: int) -> void:
	var root = _group("SharedLounge", parent)
	# Keep the centre and both room door approaches completely unobstructed.
	var sofa = _box(root, Vector3(0.85, 0.43, 2.8), Vector3(-2.18, y + 0.25, 8.8), "teal", true)
	_mark_entity(sofa, "Taukotilan sohva", "Lounge sofa", "Kolmipaikkainen sinivihreä sohva taukotilassa.", "Three-seat teal sofa in the shared lounge.")
	_box(root, Vector3(0.22, 0.84, 2.8), Vector3(-2.57, y + 0.62, 8.8), "navy", true)
	for z in [7.9, 8.8, 9.7]:
		_box(root, Vector3(0.63, 0.17, 0.79), Vector3(-2.03, y + 0.54, z), "mint")
	var kitchen = _box(root, Vector3(0.82, 0.84, 2.6), Vector3(2.22, y + 0.42, 8.7), "ivory", true)
	_mark_entity(kitchen, "Keittiön kaapisto", "Kitchen cabinet", "Taukotilan kaapisto ja puinen keittiötaso.", "Break room storage cabinet and wooden kitchen counter.")
	_box(root, Vector3(0.95, 0.07, 2.72), Vector3(2.17, y + 0.885, 8.7), "wood")
	var coffee_machine = _box(root, Vector3(0.42, 0.48, 0.38), Vector3(2.12, y + 1.15, 8.2), "black")
	_mark_entity(coffee_machine, "Kahvinkeitin", "Coffee machine", "Taukotilan musta espressokone.", "Black espresso machine in the shared kitchen.")
	_box(root, Vector3(0.31, 0.24, 0.027), Vector3(1.9, y + 1.12, 8.2), "metal", false, Vector3(0, PI / 2.0, 0))
	var first_mug = _cylinder(root, 0.07, 0.12, Vector3(2.06, y + 0.98, 8.72), "paper")
	var second_mug = _cylinder(root, 0.07, 0.12, Vector3(2.06, y + 0.98, 9.01), "orange")
	_mark_entity(first_mug, "Kahvikuppi", "Coffee mug", "Valkoinen kahvikuppi taukotilan keittiössä.", "White coffee mug in the shared kitchen.")
	_mark_entity(second_mug, "Kahvikuppi", "Coffee mug", "Oranssi kahvikuppi taukotilan keittiössä.", "Orange coffee mug in the shared kitchen.")
	_make_plant(root, Vector3(2.25, y, 10.85), 0.85)
	var lounge_names_fi = ["", "KAHVI & KOODI", "IDEOITA YHDESSÄ", "HETKI TAUKOA"]
	var lounge_names_en = ["", "COFFEE & CODE", "IDEAS TOGETHER", "TAKE A BREATHER"]
	var lounge_index = 1 + posmod(floor_index - 1, 3)
	_sign(root, Vector3(0, y + 3.2, 11.8), lounge_names_fi[lounge_index], lounge_names_en[lounge_index], PI, 33, Color("25565b"), 0.01)


func _make_reception() -> void:
	var root = _group("Reception")
	root.set_meta("entity_position", Vector3(0, 0, 7.35))
	_box(root, Vector3(3.7, 1.08, 0.95), Vector3(0, 0.54, 7.35), "navy", true)
	_box(root, Vector3(3.94, 0.11, 1.1), Vector3(0, 1.135, 7.35), "wood", true)
	_box(root, Vector3(3.46, 0.59, 0.035), Vector3(0, 0.61, 7.84), "teal")
	_sign(root, Vector3(0, 0.64, 7.872), "TERVETULOA", "WELCOME", 0, 35, Color("e6eedd"), 0.01)
	_sign(root, Vector3(0, 1.015, 7.878), "KANBAN HOUSE", "KANBAN HOUSE", 0, 21, Color("b3d3c8"), 0.01)
	for x in [-0.98, 0.98]:
		var monitor = _box(root, Vector3(0.61, 0.37, 0.055), Vector3(x, 1.44, 7.14), "navy")
		_mark_entity(monitor, "Vastaanoton tietokone", "Reception computer", "Vastaanottovirkailijan tietokone ja näyttö.", "Receptionist's computer and monitor.")
		_box(root, Vector3(0.54, 0.31, 0.009), Vector3(x, 1.44, 7.109), "screen")
		_box(root, Vector3(0.05, 0.17, 0.05), Vector3(x, 1.25, 7.14), "metal")
		var keyboard = _box(root, Vector3(0.31, 0.025, 0.14), Vector3(x, 1.207, 6.99), "black")
		_mark_entity(keyboard, "Vastaanoton näppäimistö", "Reception keyboard", "Vastaanottovirkailijan kompakti näppäimistö.", "Receptionist's compact keyboard.")
		_box(root, Vector3(0.5, 0.09, 0.12), Vector3(x, 1.25, 7.73), "paper")
	reception_positions = [Vector3(-0.96, 0.055, 6.3), Vector3(0.96, 0.055, 6.3)]
	_make_plant(root, Vector3(-2.38, 0, 10.85), 1.1)
	_make_plant(root, Vector3(2.38, 0, 10.85), 1.1)
	# Welcome mat starts beyond the initial camera, leaving sightline to faces.
	_box(root, Vector3(3.45, 0.015, 1.5), Vector3(0, 0.027, 11.1), "navy")
	_sign(root, Vector3(-2.84, 2.17, 5.15), "01  VASTAANOTTO\n01–%02d  STUDIOT\n↑  PORTAAT" % floor_count, "01  RECEPTION\n01–%02d  STUDIOS\n↑  STAIRS" % floor_count, PI / 2.0, 27, Color("25565b"), 0.012)


func _make_stairs() -> void:
	var root = _group("WalkableSwitchbackStairs")
	root.position.z = stair_offset
	root.set_meta("entity_position", Vector3(0, 0, -12.7 + stair_offset))
	var total_height = float(floor_count) * FLOOR_HEIGHT - 0.2
	# Rear extension encloses a genuine stairwell, rather than stacked ramps.
	_box(root, Vector3(12.3, 0.26, 12.1), Vector3(0, -0.13, -18.0), "concrete", true)
	for x in [-6.12, 6.12]:
		_box(root, Vector3(0.24, total_height, 12.3), Vector3(x, total_height / 2.0, -18), "ivory", true)
	_box(root, Vector3(12.48, total_height, 0.24), Vector3(0, total_height / 2.0, -24.05), "navy", true)
	for floor_index in range(floor_count):
		var base_y = float(floor_index) * FLOOR_HEIGHT
		_box(root, Vector3(12.05, 0.2, 1.55), Vector3(0, base_y - 0.1, -12.625), "hall_floor", true)
		_box(root, Vector3(11.8, 0.045, 0.18), Vector3(0, base_y + 0.022, -12.14), "teal")
		# Guard the open centre at the front landing, keeping flight ends open.
		_railing(root, Vector3(-0.98, base_y, -13.33), Vector3(0.98, base_y, -13.33))
		_sign(root, Vector3(-5.95, base_y + 2.9, -13.0), "%d" % (floor_index + 1), "%d" % (floor_index + 1), PI / 2.0, 95, Color("277a7c"), 0.014)
		_lamp(root, Vector3(0, base_y + 3.62, -12.45), 3.0)
		if floor_index == floor_count - 1:
			# There is no fourth ascent: prevent walking from the last landing
			# onto an empty left flight while keeping the right descent open.
			_railing(root, Vector3(-5.1, base_y, -13.33), Vector3(-1.0, base_y, -13.33))
			continue
		_make_flight(root, -3.0, base_y, true)
		_make_flight(root, 3.0, base_y + 2.0, false)
		_box(root, Vector3(12.0, 0.22, 2.95), Vector3(0, base_y + 1.89, -22.61), "hall_floor", true)
		_railing(root, Vector3(-1.0, base_y + 2.0, -21.14), Vector3(1.0, base_y + 2.0, -21.14))
		_box(root, Vector3(4.5, 1.1, 0.1), Vector3(0, base_y + 3.14, -23.87), "teal")
		_sign(root, Vector3(0, base_y + 3.18, -23.8), "↑  %d. KERROS\nYHDESSÄ ETEENPÄIN" % (floor_index + 2), "↑  FLOOR %d\nBUILDING TOGETHER" % (floor_index + 2), 0, 27, Color("f0f0e3"), 0.009)
		_lamp(root, Vector3(0, base_y + 5.55, -22.4), 3.1)
	# Close the ground-floor gap under the upper right-hand ramp, whose
	# sloping underside is otherwise a tempting but impassable dead end.
	_box(root, Vector3(3.95, 2.25, 0.16), Vector3(3.0, 1.125, -13.55), "navy", true)
	_sign(root, Vector3(3.0, 1.2, -13.45), "← PORTAAT YLÖS", "← STAIRS UP", 0, 29, Color("b5d6c8"), 0.011)
	_box(root, Vector3(12.6, 0.24, 12.5), Vector3(0, total_height + 0.06, -18), "ivory", true)


func _make_flight(parent: Node, x: float, base_y: float, rearward: bool) -> void:
	var root = _group("StairFlight", parent)
	var slope = atan(STAIR_RISE / STAIR_RUN) * (1.0 if rearward else -1.0)
	var length_value = sqrt(STAIR_RUN * STAIR_RUN + STAIR_RISE * STAIR_RISE)
	# A smooth invisible collision ramp removes the need for custom player
	# step-up logic while the visible geometry has sixteen individual treads.
	var collider = StaticBody3D.new()
	collider.collision_layer = 1
	collider.collision_mask = 0
	collider.position = Vector3(x, base_y + 1.0 - 0.12 / cos(slope), (STAIR_START + STAIR_END) / 2.0)
	collider.rotation.x = slope
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(4.0, 0.24, length_value + 0.07)
	collision.shape = shape
	collider.add_child(collision)
	root.add_child(collider)
	for step_index in range(16):
		var offset = (float(step_index) + 0.5) * 0.5
		var step_z = STAIR_START - offset if rearward else STAIR_END + offset
		var top_y = base_y + float(step_index + 1) * 0.125
		_box(root, Vector3(3.97, 0.16, 0.51), Vector3(x, top_y - 0.08, step_z), "wood")
		var edge_z = step_z + 0.23 if rearward else step_z - 0.23
		_box(root, Vector3(3.98, 0.017, 0.045), Vector3(x, top_y + 0.006, edge_z), "orange")
	var start_z = STAIR_START if rearward else STAIR_END
	var end_z = STAIR_END if rearward else STAIR_START
	for rail_x in [x - 2.01, x + 2.01]:
		_railing(parent, Vector3(rail_x, base_y, start_z), Vector3(rail_x, base_y + 2.0, end_z))


func _railing(parent: Node, from: Vector3, to: Vector3) -> void:
	var midpoint = (from + to) / 2.0
	var delta = to - from
	var length_value = delta.length()
	var rail = _group("SafetyRail", parent)
	rail.position = midpoint + Vector3(0, 0.53, 0)
	# look_at aligns local -Z to the rail direction. A sloped collision panel
	# below the handrail keeps the player on the stair and landing surfaces.
	if abs(delta.normalized().dot(Vector3.UP)) < 0.99:
		rail.basis = Basis.looking_at(delta, Vector3.UP)
	_box(rail, Vector3(0.075, 0.98, length_value), Vector3.ZERO, "glass", true)
	_box(rail, Vector3(0.11, 0.08, length_value + 0.1), Vector3(0, 0.51, 0), "wood")
	var post_count = maxi(2, int(ceil(length_value / 1.4)) + 1)
	for post_index in range(post_count):
		var point = from.lerp(to, float(post_index) / float(post_count - 1))
		_box(parent, Vector3(0.07, 1.03, 0.07), point + Vector3(0, 0.515, 0), "metal")


func get_stair_route(floor_index: int) -> Array:
	## Feet positions along the safe centreline, from floor N to floor N+1.
	## Tests should add player floor clearance (e.g. 0.08m) to every Y value.
	if floor_index < 0 or floor_index >= floor_count - 1:
		return []
	var y = float(floor_index) * FLOOR_HEIGHT
	var route = [
		Vector3(0, y, -11.7), Vector3(-3, y, -12.65),
		Vector3(-3, y, -13.2), Vector3(-3, y + 1.0, -17.2),
		Vector3(-3, y + 2.0, -21.2), Vector3(-3, y + 2.0, -22.2),
		Vector3(3, y + 2.0, -22.2), Vector3(3, y + 2.0, -21.2),
		Vector3(3, y + 3.0, -17.2), Vector3(3, y + 4.0, -13.2), Vector3(3, y + 4.0, -12.7),
		Vector3(0, y + 4.0, -12.0), Vector3(0, y + 4.0, -10.7),
	]
	for index in range(route.size()):
		route[index].z += stair_offset
	return route


func _make_roof() -> void:
	var root = _group("RoofAndFacade")
	var height = float(floor_count) * FLOOR_HEIGHT
	_box(root, Vector3(30.9, 0.3, building_depth + 0.9), Vector3(0, height - 0.1, stair_offset / 2.0), "navy", true)
	var levels: Array = []
	for floor_index in range(floor_count):
		levels.append(float(floor_index) * FLOOR_HEIGHT)
	levels.append(height - 0.25)
	for y in levels:
		_box(root, Vector3(30.8, 0.2, 0.36), Vector3(0, y + 0.03, 12.19), "navy")
		for x in [-15.21, 15.21]:
			_box(root, Vector3(0.36, 0.2, building_depth + 0.8), Vector3(x, y + 0.03, stair_offset / 2.0), "navy")
	for x in [-15.18, 15.18]:
		for z in [-12.17 + stair_offset, 12.17]:
			_box(root, Vector3(0.4, height - 0.2, 0.4), Vector3(x, (height - 0.2) / 2.0, z), "navy")
	# Shallow portico shelters the open entrance without blocking the sky.
	_box(root, Vector3(6.4, 0.18, 2.6), Vector3(0, 3.45, 13.25), "navy")
	_box(root, Vector3(5.9, 0.035, 0.28), Vector3(0, 3.337, 14.25), "light")
	for x in [-2.8, 2.8]:
		_box(root, Vector3(0.16, 3.45, 0.16), Vector3(x, 1.725, 14.35), "metal", true)
	# Silhouetted services reinforce the building's office scale outdoors.
	for x in [-8.0, 6.0]:
		_box(root, Vector3(4.0, 1.2, 2.4), Vector3(x, height + 0.6, -4.0), "metal")
		for grille in range(6):
			_box(root, Vector3(3.8, 0.035, 0.04), Vector3(x, height + 0.16 + float(grille) * 0.17, -2.77), "black")


func _make_outdoors() -> void:
	var root = _group("Neighbourhood")
	_box(root, Vector3(180, 0.4, maxf(180, building_depth * 2 + 60)), Vector3(0, -0.27, stair_offset / 2.0), "grass", true)
	_box(root, Vector3(38, 0.07, 39), Vector3(0, -0.03, -4.5), "path")
	_box(root, Vector3(7.0, 0.06, 17), Vector3(0, -0.025, 20.0), "path")
	var road = _group("CampusRoad", root)
	road.position = Vector3(0, -0.026, 34)
	_box(road, Vector3(160, 0.04, 7.5), Vector3.ZERO, "road")
	for stripe in range(-13, 14):
		_box(road, Vector3(2.2, 0.008, 0.11), Vector3(float(stripe) * 5, 0.026, 0), "white")
	for x in [-9.0, 9.0]:
		_make_bench(root, Vector3(x, 0, 22.0), 0.0)
	for index in range(18):
		var side = -1.0 if index % 2 == 0 else 1.0
		var x = side * (22.0 + float(index % 3) * 5.0)
		var z = -24.0 + float(index / 2) * 7.0
		_make_tree(root, Vector3(x, 0, z), 1.0 + float(index % 4) * 0.15)
	for x in [-7.5, 7.5]:
		for z in [18.0, 26.0]:
			_make_tree(root, Vector3(x, 0, z), 0.76)
	# Deterministic distant blocks, with real visible window grids.
	for index in range(0 if campus_mode else 13):
		var angle = float(index) * TAU / 13.0
		var radius = 57.0 + float(index % 3) * 7.0
		var height = 9.0 + float((index * 7) % 8) * 2.0
		var pos = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var building = _group("Neighbour_%02d" % index, root)
		building.position = pos
		building.rotation.y = angle + PI / 2.0
		_box(building, Vector3(10, height, 8), Vector3(0, height / 2.0, 0), "city" if index % 2 == 0 else "city_blue", true)
		_box(building, Vector3(10.4, 0.3, 8.4), Vector3(0, height + 0.12, 0), "navy")
		for row in range(int(height / 3.0)):
			# Continuous bands give the skyline windows without hundreds of draws.
			_box(building, Vector3(8.9, 1.15, 0.025), Vector3(0, 1.8 + float(row) * 3.0, 4.02), "screen")
		for column in [-3.0, -1.0, 1.0, 3.0]:
			_box(building, Vector3(0.15, height - 0.5, 0.04), Vector3(column, height / 2.0, 4.04), "city")
	# Visible boundary hedges also stop the player from leaving the ground.
	for boundary_x in ([] if campus_mode else [-84.0, 84.0]):
		_box(root, Vector3(1.5, 2.2, 169), Vector3(boundary_x, 1.1, 0), "leaf", true)
	for boundary_z in ([] if campus_mode else [-84.0, 84.0]):
		_box(root, Vector3(169, 2.2, 1.5), Vector3(0, 1.1, boundary_z), "leaf", true)


func _make_tree(parent: Node, pos: Vector3, scale_value: float) -> void:
	var root = _group("ParkTree", parent)
	root.position = pos
	root.scale = Vector3.ONE * scale_value
	_cylinder(root, 0.24, 3.4, Vector3(0, 1.7, 0), "wood_dark", 0.65)
	_sphere(root, 1.7, Vector3(0, 3.7, 0), Vector3(1.0, 1.2, 1.0), "leaf")
	_sphere(root, 1.1, Vector3(0.75, 3.8, 0.2), Vector3.ONE, "leaf_light")
	_sphere(root, 1.0, Vector3(-0.65, 3.35, -0.45), Vector3.ONE, "leaf_light")


func _make_bench(parent: Node, pos: Vector3, yaw: float) -> void:
	var root = _group("ParkBench", parent)
	root.position = pos
	root.rotation.y = yaw
	for z in [-0.22, 0.0, 0.22]:
		_box(root, Vector3(2.4, 0.075, 0.18), Vector3(0, 0.49, z), "wood", true)
	for x in [-0.92, 0.92]:
		_box(root, Vector3(0.09, 0.45, 0.48), Vector3(x, 0.225, 0), "metal")
	for y in [0.74, 0.96]:
		_box(root, Vector3(2.4, 0.17, 0.075), Vector3(0, y, -0.29), "wood")
