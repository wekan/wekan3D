extends RefCounted
## Editable props built only from procedural meshes. +Z is forward, units metres.
## Large objects block world motion (layer 1) and all objects can be targeted on
## layer 16. Small tabletop items do not become invisible walking obstacles.

const TEMPLATES = ["desk", "chair", "monitor", "plant", "sofa", "bookshelf", "tree", "car", "bench", "bicycle", "moped", "motorcycle", "rollator", "cat", "dog", "cow", "horse", "chicken", "newspaper", "coffee_cup", "plate", "spoon", "drinking_glass", "book", "road", "flower"]
const SMALL_ITEMS = ["monitor", "newspaper", "coffee_cup", "plate", "spoon", "drinking_glass", "book"]
const TEMPLATE_NAMES = {
	"desk": {"fi": "Työpöytä", "en": "Desk"}, "chair": {"fi": "Työtuoli", "en": "Office chair"},
	"monitor": {"fi": "Näyttö", "en": "Monitor"}, "plant": {"fi": "Ruukkukasvi", "en": "Potted plant"},
	"sofa": {"fi": "Sohva", "en": "Sofa"}, "bookshelf": {"fi": "Kirjahylly", "en": "Bookshelf"},
	"tree": {"fi": "Puu", "en": "Tree"}, "car": {"fi": "Auto", "en": "Car"},
	"bench": {"fi": "Penkki", "en": "Bench"}, "bicycle": {"fi": "Polkupyörä", "en": "Bicycle"},
	"moped": {"fi": "Mopo", "en": "Moped"}, "motorcycle": {"fi": "Moottoripyörä", "en": "Motorcycle"},
	"rollator": {"fi": "Rollaattori", "en": "Rollator"}, "cat": {"fi": "Kissa", "en": "Cat"},
	"dog": {"fi": "Koira", "en": "Dog"}, "cow": {"fi": "Lehmä", "en": "Cow"},
	"horse": {"fi": "Hevonen", "en": "Horse"}, "chicken": {"fi": "Kana", "en": "Chicken"},
	"newspaper": {"fi": "Sanomalehti", "en": "Newspaper"}, "coffee_cup": {"fi": "Kahvikuppi", "en": "Coffee cup"},
	"plate": {"fi": "Lautanen", "en": "Plate"}, "spoon": {"fi": "Lusikka", "en": "Spoon"},
	"drinking_glass": {"fi": "Juomalasi", "en": "Drinking glass"}, "book": {"fi": "Kirja", "en": "Book"},
	"road": {"fi": "Tie", "en": "Road"}, "flower": {"fi": "Kukka", "en": "Flower"}
}

var _root: Node3D
var _entity_id: String = ""
var _materials: Dictionary = {}


static func get_template_names() -> Dictionary:
	return TEMPLATE_NAMES.duplicate(true)


func create(spec: Dictionary) -> Node3D:
	if _materials.is_empty():
		_make_materials()
	var template = str(spec.get("template", "desk"))
	if template not in TEMPLATES:
		template = "desk"
	_entity_id = str(spec.get("entity_id", spec.get("id", "")))
	_root = Node3D.new()
	_root.name = "Prop_" + template + "_" + _entity_id.validate_node_name()
	_root.set_meta("entity_id", _entity_id)
	_root.set_meta("entity_node", _root)
	_root.set_meta("template", template)
	_root.set_meta("kind", str(spec.get("kind", "animal" if template in ["cat", "dog", "cow", "horse", "chicken"] else "furniture")))
	_root.set_meta("display_name", spec.get("name", TEMPLATE_NAMES[template]))
	_root.set_meta("organization_id", spec.get("organization_id", ""))
	_root.set_meta("room_id", spec.get("room_id", ""))
	_root.position = _position(spec.get("position", Vector3.ZERO))
	_root.rotation.y = float(spec.get("yaw", 0.0))
	match template:
		"desk": _desk()
		"chair": _chair()
		"monitor": _monitor()
		"plant": _plant()
		"sofa": _sofa()
		"bookshelf": _bookshelf()
		"tree": _tree()
		"car": _car()
		"bench": _bench()
		"bicycle": _bicycle()
		"moped": _moped()
		"motorcycle": _motorcycle()
		"rollator": _rollator()
		"cat", "dog": _pet(template)
		"cow": _cow()
		"horse": _horse()
		"chicken": _chicken()
		"newspaper": _newspaper()
		"coffee_cup": _coffee_cup()
		"plate": _plate()
		"spoon": _spoon()
		"drinking_glass": _drinking_glass()
		"book": _book()
		"road": _road()
		"flower": _flower()
	apply_appearance(_root, spec.get("appearance", {}))
	return _root


static func apply_appearance(root: Node3D, appearance: Dictionary) -> void:
	if root == null:
		return
	if not root.has_meta("default_scale"):
		root.set_meta("default_scale", root.scale)
	var base: Vector3 = root.get_meta("default_scale")
	var value = appearance.get("scale", {})
	if value is Dictionary:
		root.scale = Vector3(base.x * float(value.get("x", 1.0)), base.y * float(value.get("y", 1.0)), base.z * float(value.get("z", 1.0)))
	var html = str(appearance.get("color", ""))
	if html.is_empty():
		return
	var tint = Color.from_string(html, Color.WHITE)
	for child in root.get_children():
		_apply_tint(child, tint)


static func _apply_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var original = node.get_meta("appearance_original_material", node.material_override)
		if not node.has_meta("appearance_original_material"):
			node.set_meta("appearance_original_material", original)
		if original is StandardMaterial3D:
			var material: StandardMaterial3D = original.duplicate()
			material.albedo_color = material.albedo_color.lerp(tint, 0.72)
			node.material_override = material
	for child in node.get_children():
		_apply_tint(child, tint)


func _position(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _make_materials() -> void:
	var colors = {
		"wood": "b9804e", "wood_dark": "674a37", "teal": "277a7c", "navy": "182f40", "mint": "86bbb0",
		"metal": "70858a", "black": "17252b", "paper": "eee9d9", "white": "f2f0e7", "leaf": "468061",
		"leaf_light": "71a578", "pot": "b46e51", "soil": "413d34", "orange": "dca354", "red": "bb5049",
		"brown": "956042", "pink": "d6a4a0", "yellow": "e8bf5c", "coffee": "51342a", "screen": "174e62"
	}
	for key in colors:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(colors[key])
		material.roughness = 0.88
		if key == "metal":
			material.metallic = 0.55
			material.roughness = 0.32
		if key == "screen":
			material.emission_enabled = true
			material.emission = Color(colors[key])
			material.emission_energy_multiplier = 0.45
		_materials[key] = material
	for key in ["glass", "water"]:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.63, 0.83, 0.87, 0.24 if key == "glass" else 0.45)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.12
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[key] = material


func _mesh(geometry: Mesh, position: Vector3, material: String, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = geometry
	mesh.position = position
	mesh.scale = scale_value
	mesh.rotation = rotation_value
	mesh.material_override = _materials[material]
	if material in ["glass", "water"]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mesh)
	return mesh


func _box(size: Vector3, position: Vector3, material: String, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return _mesh(shape, position, material, Vector3.ONE, rotation_value)


func _sphere(radius: float, position: Vector3, material: String, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 12
	shape.rings = 6
	return _mesh(shape, position, material, scale_value)


func _cylinder(radius: float, height: float, position: Vector3, material: String, rotation_value: Vector3 = Vector3.ZERO, top_ratio: float = 1.0) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius * top_ratio
	shape.height = height
	shape.radial_segments = 12
	return _mesh(shape, position, material, Vector3.ONE, rotation_value)


func _rod(start: Vector3, finish: Vector3, radius: float, material: String) -> void:
	var direction = finish - start
	if direction.length() < 0.001:
		return
	var mesh = _cylinder(radius, direction.length(), (start + finish) * 0.5, material)
	mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _ring(radius: float, thickness: float, position: Vector3, material: String, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var shape = TorusMesh.new()
	shape.inner_radius = maxf(0.005, radius - thickness)
	shape.outer_radius = radius + thickness
	shape.rings = 16
	shape.ring_segments = 8
	_mesh(shape, position, material, Vector3.ONE, rotation_value)


func _target(size: Vector3, center: Vector3, solid: bool = true) -> void:
	var body = StaticBody3D.new()
	body.name = "ObjectTarget"
	body.collision_layer = 17 if solid else 16
	body.collision_mask = 0
	body.set_meta("entity_id", _entity_id)
	body.set_meta("entity_node", _root)
	body.set_meta("room_id", _root.get_meta("room_id", ""))
	body.set_meta("organization_id", _root.get_meta("organization_id", ""))
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	collider.position = center
	body.add_child(collider)
	_root.add_child(body)


func _desk() -> void:
	_box(Vector3(1.8, 0.09, 0.85), Vector3(0, 0.765, 0), "wood")
	for x in [-0.75, 0.75]:
		for z in [-0.31, 0.31]:
			_box(Vector3(0.055, 0.72, 0.055), Vector3(x, 0.36, z), "metal")
	_box(Vector3(0.36, 0.58, 0.66), Vector3(-0.57, 0.43, 0), "navy")
	for y in [0.27, 0.48, 0.65]:
		_box(Vector3(0.20, 0.024, 0.033), Vector3(-0.57, y, 0.34), "metal")
	_target(Vector3(1.8, 0.81, 0.85), Vector3(0, 0.405, 0))


func _chair() -> void:
	_box(Vector3(0.58, 0.11, 0.56), Vector3(0, 0.48, 0), "navy")
	_box(Vector3(0.57, 0.63, 0.09), Vector3(0, 0.83, -0.25), "teal", Vector3(-0.12, 0, 0))
	_cylinder(0.055, 0.4, Vector3(0, 0.24, 0), "metal")
	for angle in range(5):
		var end = Vector3(sin(angle * TAU / 5.0), 0, cos(angle * TAU / 5.0)) * 0.34
		_rod(Vector3(0, 0.08, 0), end + Vector3.UP * 0.08, 0.023, "metal")
		_sphere(0.052, end + Vector3.UP * 0.05, "black")
	for x in [-0.34, 0.34]:
		_rod(Vector3(x, 0.48, -0.07), Vector3(x, 0.72, -0.07), 0.025, "metal")
		_box(Vector3(0.075, 0.045, 0.35), Vector3(x, 0.74, -0.01), "black")
	_target(Vector3(0.76, 1.18, 0.73), Vector3(0, 0.59, 0))


func _monitor() -> void:
	_box(Vector3(0.29, 0.025, 0.23), Vector3(0, 0.013, 0), "black")
	_box(Vector3(0.055, 0.25, 0.055), Vector3(0, 0.145, -0.045), "metal")
	_box(Vector3(0.74, 0.44, 0.055), Vector3(0, 0.43, -0.045), "black")
	_box(Vector3(0.68, 0.38, 0.009), Vector3(0, 0.43, -0.012), "screen")
	for line in range(6):
		_box(Vector3(0.15 + (line % 3) * 0.065, 0.012, 0.004), Vector3(-0.18 + (line % 2) * 0.04, 0.56 - line * 0.051, -0.005), "mint")
	_target(Vector3(0.76, 0.66, 0.25), Vector3(0, 0.33, -0.015), false)


func _plant() -> void:
	_cylinder(0.15, 0.31, Vector3(0, 0.155, 0), "pot", Vector3.ZERO, 1.3)
	_cylinder(0.18, 0.014, Vector3(0, 0.31, 0), "soil")
	for index in range(7):
		var angle = index * TAU / 7.0
		var end = Vector3(sin(angle) * 0.25, 0.64 + float(index % 3) * 0.13, cos(angle) * 0.25)
		_rod(Vector3(0, 0.29, 0), end, 0.012, "leaf")
		_sphere(0.16, end, "leaf_light" if index % 2 == 0 else "leaf", Vector3(0.63, 0.27, 1.25))
	_target(Vector3(0.66, 0.93, 0.66), Vector3(0, 0.465, 0))


func _sofa() -> void:
	_box(Vector3(2.1, 0.3, 0.83), Vector3(0, 0.35, 0), "navy")
	_box(Vector3(2.1, 0.66, 0.2), Vector3(0, 0.67, -0.33), "teal")
	for x in [-0.64, 0.0, 0.64]:
		_box(Vector3(0.60, 0.15, 0.66), Vector3(x, 0.54, 0.03), "mint")
	for x in [-1.05, 1.05]:
		_box(Vector3(0.17, 0.50, 0.9), Vector3(x, 0.52, 0), "teal")
	for x in [-0.87, 0.87]:
		for z in [-0.29, 0.29]:
			_box(Vector3(0.09, 0.2, 0.09), Vector3(x, 0.1, z), "wood_dark")
	_target(Vector3(2.28, 1.0, 0.92), Vector3(0, 0.5, 0))


func _bookshelf() -> void:
	_box(Vector3(1.22, 1.88, 0.06), Vector3(0, 0.94, -0.17), "wood_dark")
	for x in [-0.60, 0.60]:
		_box(Vector3(0.055, 1.9, 0.41), Vector3(x, 0.95, 0), "wood")
	for shelf in range(5):
		var y = 0.06 + shelf * 0.45
		_box(Vector3(1.24, 0.05, 0.42), Vector3(0, y, 0), "wood")
		if shelf == 4: continue
		for index in range(8):
			var height = 0.25 + float(index % 3) * 0.035
			_box(Vector3(0.09, height, 0.27), Vector3(-0.47 + index * 0.123, y + height * 0.5 + 0.028, 0.03), ["teal", "paper", "red", "navy"][index % 4])
	_target(Vector3(1.26, 1.92, 0.44), Vector3(0, 0.96, 0))


func _tree() -> void:
	_cylinder(0.19, 2.3, Vector3(0, 1.15, 0), "wood_dark", Vector3.ZERO, 0.62)
	for index in range(5):
		var angle = index * TAU / 5.0
		var end = Vector3(sin(angle) * 0.73, 2.25 + (index % 2) * 0.43, cos(angle) * 0.73)
		_rod(Vector3(0, 1.3, 0), end, 0.06, "wood_dark")
		_sphere(0.77, end, "leaf_light" if index % 2 == 0 else "leaf", Vector3(1.0, 1.0, 1.0))
	_sphere(0.86, Vector3(0, 2.94, 0), "leaf")
	_target(Vector3(0.40, 2.3, 0.40), Vector3(0, 1.15, 0))
	_target(Vector3(2.75, 2.1, 2.75), Vector3(0, 2.65, 0), false)


func _wheel(center: Vector3, radius: float, thick: bool = false) -> void:
	_ring(radius, 0.065 if thick else 0.028, center, "black", Vector3(0, 0, PI / 2.0))
	_ring(radius - 0.035, 0.015, center, "metal", Vector3(0, 0, PI / 2.0))
	_cylinder(0.055, 0.18 if thick else 0.09, center, "metal", Vector3(0, 0, PI / 2.0))
	for index in range(6):
		var angle = index * TAU / 6.0
		_rod(center, center + Vector3(0, sin(angle), cos(angle)) * (radius - 0.03), 0.009, "metal")


func _car() -> void:
	_box(Vector3(1.75, 0.42, 3.8), Vector3(0, 0.57, 0), "teal")
	_box(Vector3(1.54, 0.56, 1.82), Vector3(0, 1.06, -0.18), "teal")
	_box(Vector3(1.41, 0.42, 0.025), Vector3(0, 1.09, 0.75), "glass", Vector3(-0.24, 0, 0))
	_box(Vector3(1.41, 0.40, 0.025), Vector3(0, 1.08, -1.11), "glass", Vector3(0.22, 0, 0))
	for side in [-1.0, 1.0]:
		for z in [-0.67, 0.29]:
			_box(Vector3(0.025, 0.36, 0.77), Vector3(side * 0.783, 1.09, z), "glass")
		for z in [-1.19, 1.19]:
			_wheel(Vector3(side * 0.88, 0.36, z), 0.31, true)
		_box(Vector3(0.12, 0.16, 0.24), Vector3(side * 0.94, 0.96, 0.50), "teal")
		_box(Vector3(0.41, 0.16, 0.05), Vector3(side * 0.53, 0.70, 1.93), "white")
		_box(Vector3(0.34, 0.15, 0.045), Vector3(side * 0.57, 0.69, -1.93), "red")
	_box(Vector3(1.64, 0.12, 0.10), Vector3(0, 0.41, 1.93), "metal")
	_box(Vector3(0.45, 0.14, 0.015), Vector3(0, 0.57, 1.964), "paper")
	_target(Vector3(1.96, 1.4, 3.96), Vector3(0, 0.70, 0))


func _bench() -> void:
	for z in [-0.22, -0.11, 0.0, 0.11, 0.22]:
		_box(Vector3(1.8, 0.045, 0.087), Vector3(0, 0.49, z), "wood")
	for y in [0.66, 0.80, 0.94]:
		_box(Vector3(1.8, 0.10, 0.045), Vector3(0, y, -0.26), "wood")
	for x in [-0.68, 0.68]:
		_rod(Vector3(x, 0.04, -0.2), Vector3(x, 0.98, -0.27), 0.032, "metal")
		_rod(Vector3(x, 0.04, 0.2), Vector3(x, 0.47, 0.14), 0.032, "metal")
		_rod(Vector3(x, 0.47, -0.25), Vector3(x, 0.47, 0.25), 0.032, "metal")
	_target(Vector3(1.85, 1.0, 0.62), Vector3(0, 0.5, 0))


func _bicycle() -> void:
	var rear = Vector3(0, 0.36, -0.69)
	var front = Vector3(0, 0.36, 0.69)
	var crank = Vector3(0, 0.38, -0.02)
	var seat = Vector3(0, 0.92, -0.24)
	var neck = Vector3(0, 0.91, 0.40)
	_wheel(rear, 0.34)
	_wheel(front, 0.34)
	for edge in [[rear, seat], [seat, crank], [crank, rear], [seat, neck], [neck, crank], [neck, front]]:
		_rod(edge[0], edge[1], 0.025, "teal")
	_rod(seat, seat + Vector3.UP * 0.12, 0.02, "metal")
	_box(Vector3(0.24, 0.065, 0.27), seat + Vector3.UP * 0.15, "black")
	_rod(neck, Vector3(0, 1.1, 0.48), 0.025, "metal")
	_rod(Vector3(-0.30, 1.1, 0.48), Vector3(0.30, 1.1, 0.48), 0.023, "metal")
	for side in [-1.0, 1.0]:
		_box(Vector3(0.15, 0.042, 0.09), crank + Vector3(side * 0.15, side * 0.09, 0), "black")
		_rod(crank, crank + Vector3(side * 0.15, side * 0.09, 0), 0.017, "metal")
	_ring(0.10, 0.012, crank, "metal", Vector3(0, 0, PI / 2.0))
	_target(Vector3(0.67, 1.16, 2.12), Vector3(0, 0.58, 0))


func _moped() -> void:
	for z in [-0.59, 0.61]: _wheel(Vector3(0, 0.26, z), 0.23, true)
	_box(Vector3(0.39, 0.20, 0.99), Vector3(0, 0.42, -0.07), "mint")
	_box(Vector3(0.40, 0.31, 0.63), Vector3(0, 0.58, -0.27), "teal")
	_box(Vector3(0.42, 0.10, 0.65), Vector3(0, 0.80, -0.24), "black")
	_box(Vector3(0.43, 0.54, 0.12), Vector3(0, 0.65, 0.43), "teal", Vector3(0.14, 0, 0))
	_rod(Vector3(0, 0.27, 0.61), Vector3(0, 1.0, 0.47), 0.05, "metal")
	_rod(Vector3(-0.28, 1.03, 0.47), Vector3(0.28, 1.03, 0.47), 0.025, "black")
	_sphere(0.105, Vector3(0, 0.95, 0.55), "white", Vector3(1, 0.75, 0.5))
	_box(Vector3(0.58, 0.04, 0.35), Vector3(0, 0.40, 0.2), "black")
	_target(Vector3(0.64, 1.12, 1.79), Vector3(0, 0.56, 0))


func _motorcycle() -> void:
	for z in [-0.73, 0.75]: _wheel(Vector3(0, 0.36, z), 0.32, true)
	_rod(Vector3(0, 0.39, -0.7), Vector3(0, 0.70, 0.22), 0.065, "metal")
	_rod(Vector3(0, 0.36, 0.75), Vector3(0, 1.03, 0.43), 0.055, "metal")
	_box(Vector3(0.40, 0.35, 0.41), Vector3(0, 0.52, 0.02), "metal")
	for y in [0.41, 0.48, 0.55, 0.62]:
		_box(Vector3(0.47, 0.025, 0.40), Vector3(0, y, 0.02), "black")
	_sphere(0.28, Vector3(0, 0.81, 0.14), "red", Vector3(0.85, 0.61, 1.27))
	_box(Vector3(0.38, 0.10, 0.62), Vector3(0, 0.79, -0.43), "black")
	_rod(Vector3(-0.36, 1.09, 0.43), Vector3(0.36, 1.09, 0.43), 0.027, "metal")
	_cylinder(0.105, 0.10, Vector3(0, 1.0, 0.54), "white", Vector3(PI / 2.0, 0, 0))
	_rod(Vector3(0.25, 0.43, 0.1), Vector3(0.25, 0.33, -0.77), 0.05, "metal")
	_target(Vector3(0.80, 1.19, 2.22), Vector3(0, 0.595, 0))


func _rollator() -> void:
	for side in [-1.0, 1.0]:
		for z in [-0.28, 0.28]:
			_wheel(Vector3(side * 0.31, 0.10, z), 0.075, true)
		_rod(Vector3(side * 0.31, 0.14, -0.28), Vector3(side * 0.29, 0.92, -0.15), 0.022, "red")
		_rod(Vector3(side * 0.31, 0.14, 0.28), Vector3(side * 0.29, 0.70, -0.05), 0.022, "red")
		_rod(Vector3(side * 0.29, 0.91, -0.15), Vector3(side * 0.29, 0.91, -0.34), 0.035, "black")
		_rod(Vector3(side * 0.29, 0.84, -0.20), Vector3(side * 0.29, 0.84, -0.33), 0.018, "metal")
	_box(Vector3(0.55, 0.055, 0.32), Vector3(0, 0.59, 0.015), "black")
	_box(Vector3(0.44, 0.22, 0.26), Vector3(0, 0.40, 0.14), "navy")
	_rod(Vector3(-0.29, 0.74, 0.08), Vector3(0.29, 0.74, 0.08), 0.028, "black")
	_target(Vector3(0.78, 0.98, 0.80), Vector3(0, 0.49, 0))


func _pet(template: String) -> void:
	var cat = template == "cat"
	var coat = "orange" if cat else "brown"
	_sphere(0.27, Vector3(0, 0.34, 0), coat, Vector3(0.59, 0.64, 1.25))
	for x in [-0.10, 0.10]:
		for z in [-0.22, 0.20]:
			_cylinder(0.038 if cat else 0.045, 0.27, Vector3(x, 0.155, z), coat)
	_sphere(0.16 if cat else 0.19, Vector3(0, 0.45, 0.32), coat)
	_sphere(0.09, Vector3(0, 0.405, 0.46), "paper" if cat else "brown", Vector3(1.0, 0.65, 0.8 if cat else 1.2))
	_sphere(0.035, Vector3(0, 0.435, 0.50 if cat else 0.57), "pink" if cat else "black")
	for side in [-1.0, 1.0]:
		_sphere(0.019, Vector3(side * 0.080, 0.49, 0.446), "black")
		if cat:
			_cylinder(0.08, 0.17, Vector3(side * 0.10, 0.59, 0.31), coat, Vector3(0, 0, side * 0.2), 0.0)
			for y in [0.40, 0.425]:
				_rod(Vector3(side * 0.035, y, 0.47), Vector3(side * 0.20, y + 0.018, 0.47), 0.003, "paper")
		else:
			_sphere(0.09, Vector3(side * 0.16, 0.40, 0.29), "wood_dark", Vector3(0.55, 1.65, 0.85))
	_rod(Vector3(0, 0.36, -0.3), Vector3(0.04, 0.61 if cat else 0.48, -0.55), 0.033, coat)
	if cat: _rod(Vector3(0.04, 0.61, -0.55), Vector3(0.12, 0.71, -0.60), 0.028, coat)
	_target(Vector3(0.44, 0.75, 1.25), Vector3(0, 0.375, -0.02))


func _cow() -> void:
	_sphere(0.65, Vector3(0, 1.01, 0), "white", Vector3(0.8, 0.69, 1.45))
	for x in [-0.32, 0.32]:
		for z in [-0.56, 0.55]:
			_cylinder(0.078, 0.78, Vector3(x, 0.43, z), "white")
			_cylinder(0.085, 0.12, Vector3(x, 0.07, z), "black")
	_sphere(0.29, Vector3(0, 1.15, 0.94), "white", Vector3(0.84, 1.0, 1.05))
	_sphere(0.22, Vector3(0, 1.0, 1.19), "pink", Vector3(1.0, 0.67, 0.8))
	for side in [-1.0, 1.0]:
		_sphere(0.022, Vector3(side * 0.17, 1.20, 1.12), "black")
		_sphere(0.10, Vector3(side * 0.30, 1.27, 0.94), "white", Vector3(1.4, 0.4, 0.67))
		_cylinder(0.046, 0.20, Vector3(side * 0.17, 1.45, 0.94), "paper", Vector3(0, 0, -side * 0.35), 0.0)
		_sphere(0.27, Vector3(side * 0.48, 1.07, -0.16), "black", Vector3(0.16, 0.68, 1.05))
		_sphere(0.17, Vector3(side * 0.40, 1.21, 0.35), "black", Vector3(0.3, 0.55, 1.0))
	_rod(Vector3(0, 1.1, -0.91), Vector3(0.04, 0.48, -1.11), 0.025, "white")
	_sphere(0.075, Vector3(0.04, 0.44, -1.11), "black", Vector3(0.65, 1.6, 0.65))
	_target(Vector3(1.03, 1.57, 2.48), Vector3(0, 0.785, 0.08))


func _horse() -> void:
	_sphere(0.62, Vector3(0, 1.19, 0), "brown", Vector3(0.71, 0.73, 1.44))
	for x in [-0.29, 0.29]:
		for z in [-0.56, 0.52]:
			_rod(Vector3(x, 0.13, z), Vector3(x, 1.03, z - 0.06), 0.067, "brown")
			_cylinder(0.077, 0.13, Vector3(x, 0.07, z), "black")
	_rod(Vector3(0, 1.18, 0.59), Vector3(0, 1.82, 0.91), 0.19, "brown")
	_sphere(0.26, Vector3(0, 1.86, 1.04), "brown", Vector3(0.78, 0.83, 1.53))
	for side in [-1.0, 1.0]:
		_sphere(0.022, Vector3(side * 0.18, 1.92, 1.13), "black")
		_cylinder(0.052, 0.24, Vector3(side * 0.105, 2.12, 0.91), "brown", Vector3(0.17, 0, side * 0.1), 0.0)
	for index in range(5):
		var y = 1.39 + index * 0.10
		_rod(Vector3(0, y, 0.55 + index * 0.05), Vector3(0, y - 0.12, 0.42 + index * 0.06), 0.06, "black")
	_rod(Vector3(0, 1.37, -0.80), Vector3(0.04, 0.56, -1.13), 0.09, "wood_dark")
	_target(Vector3(0.95, 2.26, 2.67), Vector3(0, 1.13, 0.13))


func _chicken() -> void:
	_sphere(0.25, Vector3(0, 0.34, 0), "white", Vector3(0.83, 1.0, 1.12))
	_sphere(0.135, Vector3(0, 0.62, 0.15), "white")
	_cylinder(0.055, 0.12, Vector3(0, 0.60, 0.31), "yellow", Vector3(PI / 2.0, 0, 0), 0.0)
	for index in range(3):
		_sphere(0.048, Vector3(0, 0.765, 0.085 + index * 0.054), "red", Vector3(0.45, 1.0, 1.0))
	_sphere(0.05, Vector3(0, 0.52, 0.255), "red", Vector3(0.6, 1.4, 0.6))
	for side in [-1.0, 1.0]:
		_sphere(0.013, Vector3(side * 0.093, 0.65, 0.234), "black")
		_rod(Vector3(side * 0.08, 0.035, 0.02), Vector3(side * 0.08, 0.22, 0.02), 0.018, "yellow")
		for toe in [-1.0, 0.0, 1.0]:
			_rod(Vector3(side * 0.08, 0.032, 0.02), Vector3(side * 0.08 + toe * 0.04, 0.024, 0.12), 0.011, "yellow")
		_sphere(0.16, Vector3(side * 0.18, 0.36, -0.035), "paper", Vector3(0.22, 0.79, 1.2))
	for index in range(3):
		_sphere(0.18, Vector3((index - 1) * 0.07, 0.46, -0.25), "white", Vector3(0.35, 1.1, 0.55))
	_target(Vector3(0.48, 0.82, 0.74), Vector3(0, 0.41, 0.03))


func _newspaper() -> void:
	_box(Vector3(0.43, 0.008, 0.32), Vector3(0, 0.006, 0), "paper")
	_box(Vector3(0.35, 0.003, 0.032), Vector3(0, 0.013, -0.105), "black")
	_box(Vector3(0.10, 0.003, 0.075), Vector3(-0.12, 0.014, -0.025), "metal")
	for column in range(3):
		for line in range(7):
			_box(Vector3(0.095 - float(line % 3) * 0.007, 0.003, 0.004), Vector3(-0.13 + column * 0.13, 0.014, 0.032 + line * 0.015), "black")
	_target(Vector3(0.45, 0.035, 0.34), Vector3(0, 0.018, 0), false)


func _coffee_cup() -> void:
	_cylinder(0.062, 0.145, Vector3(0, 0.077, 0), "white", Vector3.ZERO, 1.08)
	_cylinder(0.057, 0.005, Vector3(0, 0.15, 0), "coffee")
	_ring(0.064, 0.005, Vector3(0, 0.153, 0), "white")
	_ring(0.038, 0.010, Vector3(0.073, 0.083, 0), "white", Vector3(0, 0, PI / 2.0))
	_target(Vector3(0.24, 0.18, 0.15), Vector3(0.025, 0.09, 0), false)


func _plate() -> void:
	_cylinder(0.15, 0.014, Vector3(0, 0.015, 0), "white")
	_ring(0.135, 0.011, Vector3(0, 0.027, 0), "white")
	_cylinder(0.12, 0.004, Vector3(0, 0.024, 0), "paper")
	_target(Vector3(0.33, 0.052, 0.33), Vector3(0, 0.027, 0), false)


func _spoon() -> void:
	_box(Vector3(0.018, 0.007, 0.17), Vector3(0, 0.009, -0.025), "metal")
	_sphere(0.040, Vector3(0, 0.012, 0.086), "metal", Vector3(0.67, 0.13, 1.1))
	_target(Vector3(0.070, 0.036, 0.26), Vector3(0, 0.019, 0.015), false)


func _drinking_glass() -> void:
	_cylinder(0.063, 0.23, Vector3(0, 0.12, 0), "glass", Vector3.ZERO, 1.05)
	_cylinder(0.057, 0.15, Vector3(0, 0.080, 0), "water")
	_ring(0.064, 0.004, Vector3(0, 0.237, 0), "glass")
	_cylinder(0.062, 0.01, Vector3(0, 0.01, 0), "glass")
	_target(Vector3(0.15, 0.25, 0.15), Vector3(0, 0.125, 0), false)


func _book() -> void:
	_box(Vector3(0.19, 0.044, 0.27), Vector3(0, 0.025, 0), "teal")
	_box(Vector3(0.173, 0.029, 0.256), Vector3(0.004, 0.027, 0.002), "paper")
	_box(Vector3(0.19, 0.005, 0.27), Vector3(0, 0.050, 0), "teal")
	_box(Vector3(0.12, 0.003, 0.014), Vector3(0, 0.054, -0.045), "paper")
	_box(Vector3(0.085, 0.003, 0.008), Vector3(0, 0.054, -0.015), "mint")
	_target(Vector3(0.21, 0.065, 0.29), Vector3(0, 0.033, 0), false)


func _road() -> void:
	_box(Vector3(4.8, 0.05, 1.45), Vector3(0, 0.025, 0), "black")
	for x in [-1.6, 0.0, 1.6]:
		_box(Vector3(0.62, 0.012, 0.06), Vector3(x, 0.057, 0), "paper")
	_target(Vector3(4.8, 0.08, 1.45), Vector3(0, 0.04, 0), false)


func _flower() -> void:
	_cylinder(0.065, 0.17, Vector3(0, 0.085, 0), "pot", Vector3.ZERO, 1.25)
	_rod(Vector3(0, 0.16, 0), Vector3(0, 0.57, 0), 0.018, "leaf")
	for index in range(6):
		var angle = float(index) * TAU / 6.0
		_sphere(0.105, Vector3(sin(angle) * 0.11, 0.57, cos(angle) * 0.11), "pink", Vector3(1.0, 0.32, 1.0))
	_sphere(0.055, Vector3(0, 0.57, 0), "yellow")
	_target(Vector3(0.34, 0.7, 0.34), Vector3(0, 0.35, 0), false)
