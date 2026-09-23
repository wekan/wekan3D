extends VBoxContainer
## An in-world video call, rendered live from the selected colleague's real room.
signal closed
var person_id = ""
var person: Node3D
var video: SubViewport
var video_camera: Camera3D
var person_label: Label
var room_label: Label
var speech_label: Label
var buttons: Array = []
var answer_index = 0
var question_id = ""
var questions_box: VBoxContainer
var profile_label: Label
var hangup: Button
var _bubble_was_visible = true

func setup(entity_id: String, npc: Node3D) -> void:
	person_id = entity_id
	person = npc
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	var heading = HBoxContainer.new()
	add_child(heading)
	person_label = Label.new()
	person_label.add_theme_font_size_override("font_size",24)
	person_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(person_label)
	room_label = Label.new()
	room_label.add_theme_color_override("font_color",Color("83d9c7"))
	heading.add_child(room_label)
	var tablet = PanelContainer.new()
	var bezel = StyleBoxFlat.new()
	bezel.bg_color = Color("11181e")
	bezel.border_color = Color("6b7d87")
	bezel.set_border_width_all(3)
	bezel.set_corner_radius_all(30)
	bezel.content_margin_left = 30
	bezel.content_margin_right = 30
	bezel.content_margin_top = 24
	bezel.content_margin_bottom = 22
	tablet.add_theme_stylebox_override("panel",bezel)
	tablet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tablet)
	var screen = HBoxContainer.new()
	screen.add_theme_constant_override("separation",20)
	tablet.add_child(screen)
	var camera_stack = VBoxContainer.new()
	camera_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.add_child(camera_stack)
	var camera_dot = Label.new()
	camera_dot.text = "●"
	camera_dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_dot.add_theme_color_override("font_color",Color("5bc5b5"))
	camera_stack.add_child(camera_dot)
	video = SubViewport.new()
	video.name = "RemoteVideo"
	video.size = Vector2i(800,620)
	video.world_3d = get_viewport().world_3d
	video.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	video.msaa_3d = Viewport.MSAA_2X
	add_child(video)
	video_camera = Camera3D.new()
	video_camera.fov = 43
	video_camera.near = 0.08
	video_camera.far = 60
	video.add_child(video_camera)
	video_camera.current = true
	var picture = TextureRect.new()
	picture.name = "LiveColleague"
	picture.texture = video.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(430,350)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	camera_stack.add_child(picture)
	var side = VBoxContainer.new()
	side.custom_minimum_size.x = 320
	side.add_theme_constant_override("separation",14)
	screen.add_child(side)
	var live = Label.new()
	live.text = "● " + _t("ETÄYHTEYS", "REMOTE CALL")
	live.add_theme_color_override("font_color",Color("80e1be"))
	side.add_child(live)
	speech_label = Label.new()
	speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech_label.add_theme_font_size_override("font_size",20)
	side.add_child(speech_label)
	profile_label = Label.new()
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_label.add_theme_color_override("font_color",Color("91c9c7"))
	profile_label.add_theme_font_size_override("font_size",15)
	side.add_child(profile_label)
	var questions_scroll = ScrollContainer.new()
	questions_scroll.custom_minimum_size = Vector2(320,220)
	questions_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	questions_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(questions_scroll)
	questions_box = VBoxContainer.new()
	questions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	questions_box.add_theme_constant_override("separation",8)
	questions_scroll.add_child(questions_box)
	var end_call = Button.new()
	hangup = end_call
	end_call.text = _t("Lopeta etäyhteys", "End call")
	end_call.pressed.connect(func(): closed.emit())
	add_child(end_call)
	if person.get("_bubble_root") != null:
		_bubble_was_visible = person._bubble_root.visible
		person._bubble_root.visible = false
	GameState.language_changed.connect(_refresh)
	GameState.entities_changed.connect(_refresh)
	_refresh()
	_process(0)
	if not buttons.is_empty(): buttons[0].grab_focus()

func _refresh() -> void:
	if person_label == null:
		return
	var data = GameState.entities.get(person_id,{})
	person_label.text = GameState.localize(data.get("name",person_id))
	room_label.text = GameState.room_name(str(data.get("room_id",""))) + " · " + _t("kerros ","floor ") + str(data.get("floor",1))
	var profile = GameState.get_person_profile(person_id)
	profile_label.text = str(profile.get("title",""))+"\n"+str(profile.get("team_role",""))+"\n"+str(profile.get("expertise",""))
	speech_label.text = _t("Hei! Mukava nähdä. Mistä jutellaan?", "Hi! Good to see you. What would you like to discuss?")
	for child in questions_box.get_children():
		questions_box.remove_child(child)
		child.queue_free()
	buttons.clear()
	for pair in profile.get("qa",[]):
		if str(pair.get("question","")).is_empty(): continue
		if str(pair.get("id","")) == question_id: speech_label.text = str(pair.answer)
		var button = Button.new()
		button.text = str(pair.question)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func(): question_id = str(pair.id); speech_label.text = str(pair.answer))
		questions_box.add_child(button)
		buttons.append(button)
	hangup.text = _t("Lopeta etäyhteys", "End call")

func _process(_delta: float) -> void:
	if not is_instance_valid(person) or not is_instance_valid(video_camera) or not person.is_inside_tree() or not video_camera.is_inside_tree():
		return
	var outward = person.global_basis.z.normalized()
	video_camera.global_position = person.global_position + outward*2.45 + Vector3(0,1.52,0)
	video_camera.look_at(person.global_position + Vector3(0,1.12,0),Vector3.UP)
	if person.get("_bubble_root") != null: person._bubble_root.visible = false

func _exit_tree() -> void:
	if is_instance_valid(person) and person.get("_bubble_root") != null:
		person._bubble_root.visible = _bubble_was_visible

func _t(fi: String, en: String) -> String:
	return fi if GameState.language == "fi" else en
