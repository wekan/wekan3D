extends CharacterBody3D
## Accessible first-person walking: arrows alone move AND turn, mouse is optional.
var camera: Camera3D
var controls_enabled = true
var using_controller = false
var pitch = 0.0
var test_move = Vector2.ZERO
var test_turn = 0.0
const WALK_SPEED = 4.3
const RUN_SPEED = 7.0
const TURN_SPEED = 1.9

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(48)
	floor_constant_speed = true
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	var shape = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.89
	add_child(shape)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position.y = 1.65
	camera.fov = 76
	camera.near = 0.06
	camera.far = 160
	camera.current = true
	add_child(camera)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton or abs(event.axis_value) > 0.25:
			using_controller = true
	elif event is InputEventMouseMotion:
		if event.relative.length() > 1:
			using_controller = false
		if controls_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			rotate_y(-event.relative.x * 0.003)
			pitch = clamp(pitch - event.relative.y * 0.003, -1.25, 1.25)
			camera.rotation.x = pitch
	elif event is InputEventKey:
		using_controller = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if controls_enabled and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var motion = Vector2.ZERO
	var turning = 0.0
	if controls_enabled:
		motion = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		turning = Input.get_axis("turn_left", "turn_right")
		var look = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		turning += look.x
		pitch = clamp(pitch - look.y * delta * TURN_SPEED, -1.25, 1.25)
		camera.rotation.x = pitch
	motion += test_move
	turning += test_turn
	rotate_y(-turning * TURN_SPEED * delta)
	var direction = transform.basis * Vector3(motion.x, 0, motion.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed = RUN_SPEED if controls_enabled and Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 24)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 24)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.1
	move_and_slide()
	if global_position.y < -8:
		global_position = Vector3(0,0.2,11)
		velocity = Vector3.ZERO

func set_enabled(value: bool) -> void:
	controls_enabled = value
	if not value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		velocity.x = 0
		velocity.z = 0

func point_ray(screen_position: Vector2, distance: float = 5.8) -> Dictionary:
	var origin = camera.project_ray_origin(screen_position)
	var end = origin + camera.project_ray_normal(screen_position) * distance
	var query = PhysicsRayQueryParameters3D.create(origin,end,23)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

static func configure_inputs() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A])
	_bind_keys("move_right", [KEY_D])
	_bind_keys("turn_left", [KEY_LEFT])
	_bind_keys("turn_right", [KEY_RIGHT])
	_bind_keys("look_up", [KEY_PAGEUP])
	_bind_keys("look_down", [KEY_PAGEDOWN])
	_bind_keys("look_left", [])
	_bind_keys("look_right", [])
	_bind_keys("interact", [KEY_E, KEY_ENTER])
	_bind_keys("inventory", [KEY_I, KEY_TAB])
	_bind_keys("take_card", [KEY_P])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1)
	_bind_axis("move_forward", JOY_AXIS_LEFT_Y, -1)
	_bind_axis("move_back", JOY_AXIS_LEFT_Y, 1)
	_bind_axis("look_left", JOY_AXIS_RIGHT_X, -1)
	_bind_axis("look_right", JOY_AXIS_RIGHT_X, 1)
	_bind_axis("look_up", JOY_AXIS_RIGHT_Y, -1)
	_bind_axis("look_down", JOY_AXIS_RIGHT_Y, 1)
	_bind_button("move_forward", JOY_BUTTON_DPAD_UP)
	_bind_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_bind_button("turn_left", JOY_BUTTON_DPAD_LEFT)
	_bind_button("turn_right", JOY_BUTTON_DPAD_RIGHT)
	_bind_button("interact", JOY_BUTTON_A)
	_bind_button("take_card", JOY_BUTTON_X)
	_bind_button("inventory", JOY_BUTTON_Y)
	_bind_button("sprint", JOY_BUTTON_LEFT_STICK)

static func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action,0.2)
	for key in keys:
		var event = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action,event)

static func _bind_button(action: String, button: int) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action,event)

static func _bind_axis(action: String, axis: int, value: float) -> void:
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	InputMap.action_add_event(action,event)
