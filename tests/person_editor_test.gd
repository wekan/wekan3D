extends SceneTree
## redot --headless --path . --script res://tests/person_editor_test.gd
## Optional displayed screenshots: -- --capture=/absolute/directory

var state
var editor_script
var editor
var shell: VBoxContainer
var entity_id = ""
var capture_directory = ""
var failures: Array = []
var saved_count = 0
var deleted_count = 0
var cancelled_count = 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_directory = argument.trim_prefix("--capture=")
	call_deferred("_run")


func _run() -> void:
	state = root.get_node("GameState")
	state.autosave_enabled = false
	state.reset_game()
	state.set_language("fi")
	state.register_room({"id": "person_editor_room", "number": "101", "floor": 0, "center": Vector3(-9, 0, -6.5), "name": {"fi": "Robotiikkastudio", "en": "Robotics studio"}})
	entity_id = state.create_person("person_editor_room", "Aino Virtanen", true)
	_check(not entity_id.is_empty(), "Person fixture created")
	state.edit_person_profile(entity_id, {"qa": [
		{"question": "Mitä tiimi rakentaa?", "answer": "Kokoamme robottia toimiston kanban-taulujen avulla."},
		{"question": "Missä voin pitää tauon?", "answer": "Yläkerrassa on kahvipiste ja mukava sohva."},
	]}, "fi")
	var initial = state.get_person_profile(entity_id, "fi")
	var first_id = initial.qa[0].id
	var removed_id = initial.qa[1].id
	state.edit_person_profile(entity_id, {"name": "Aino Virtanen", "title": "Robotics developer", "team_role": "Quality lead", "expertise": "Robotics, programming and testing", "qa": [
		{"id": first_id, "question": "What is the team building?", "answer": "We are assembling a robot with the office kanban boards."},
		{"id": removed_id, "question": "Where can I take a break?", "answer": "There is a coffee point and a comfortable sofa upstairs."},
	]}, "en")
	editor_script = load("res://scripts/ui/person_editor.gd")
	_make_shell()
	await _open_editor()
	_check(editor.qa_rows.size() == 2, "Existing questions populate individual editors")
	_check(editor.fields.size() == 4, "Name, job title, team role and expertise are editable")
	editor.fields.name.text = "Aino Lehtinen"
	editor.fields.title.text = "Robotiikan ohjelmistokehittäjä"
	editor.fields.team_role.text = "Testausvastaava"
	editor.fields.expertise.text = "Robotiikka, testiautomaatio ja ohjelmistojen laadunvarmistus."
	editor.qa_rows[0].question.text = "Miten robotti testataan?"
	editor.qa_rows[0].answer.text = "Aloitamme antureista ja moottoreista.\nKirjaamme testitulokset taululle ennen vertaisarviointia."
	editor.add_button.pressed.emit()
	await _settle()
	_check(editor.qa_rows.size() == 3, "Add question button creates a blank pair")
	var new_row = editor.qa_rows[2]
	new_row.question.text = "Miten liityn katselmointiin?"
	new_row.answer.text = "Avaa huoneen kanban-taulu ja valitse katselmoitava kortti."
	new_row.up.pressed.emit()
	new_row.up.pressed.emit()
	_check(editor.qa_rows[0].key == new_row.key, "Move-up buttons reorder the same question record")
	var old_second = editor.qa_rows[2]
	old_second.remove.pressed.emit()
	_check(editor.qa_rows.size() == 2, "Remove pair button removes a question row")
	editor.qa_scroll.scroll_vertical = 0
	await _settle()
	await _capture("person-editor-fi.png")
	editor.save_button.pressed.emit()
	if not _require(saved_count == 1, "Finnish profile save failed: " + editor.status_label.text):
		return
	var fi = state.get_person_profile(entity_id, "fi")
	var en = state.get_person_profile(entity_id, "en")
	_check(fi.name == "Aino Lehtinen" and en.name == "Aino Virtanen", "Person rename preserves the other language")
	_check(fi.title == "Robotiikan ohjelmistokehittäjä" and en.title == "Robotics developer", "Job title is localized independently")
	_check(fi.qa.size() == 2 and fi.qa[1].id == first_id, "Reorder preserves the existing stable question ID")
	_check(en.qa[1].question == "What is the team building?", "Reordered question retains its English translation")
	_check(en.qa[0].question.is_empty() and en.qa[0].answer.is_empty(), "New Finnish question does not overwrite or invent English text")
	_check(not str(fi.qa).contains(removed_id) and not str(en.qa).contains(removed_id), "Removing a pair removes both language versions")
	state.set_language("en")
	await _open_editor()
	_check(editor.qa_rows[0].question.text.is_empty(), "Missing translation appears as a blank existing pair")
	editor.fields.name.text = "Aino Lehtinen"
	editor.fields.title.text = "Senior robotics developer"
	editor.fields.team_role.text = "Test coordinator"
	editor.fields.expertise.text = "Robotics, automated testing and software quality."
	editor.qa_rows[1].question.text = "How is the robot tested?"
	editor.qa_rows[1].answer.text = "We start with sensors and motors, record results, and ask for a peer review."
	editor.add_button.pressed.emit()
	await _settle()
	editor.save_button.pressed.emit()
	_check(saved_count == 1 and editor.status_label.visible, "A new blank question cannot be saved")
	_check(state.get_person_profile(entity_id, "en").title == "Robotics developer", "Invalid question leaves the profile unchanged")
	editor.qa_rows[2].remove.pressed.emit()
	editor.status_label.visible = false
	editor.qa_scroll.scroll_vertical = 0
	await _settle()
	await _capture("person-editor-en.png")
	editor.save_button.pressed.emit()
	if not _require(saved_count == 2, "English profile save failed: " + editor.status_label.text):
		return
	fi = state.get_person_profile(entity_id, "fi")
	en = state.get_person_profile(entity_id, "en")
	_check(fi.qa[1].question == "Miten robotti testataan?" and en.qa[1].question == "How is the robot tested?", "Editing English question text preserves Finnish text by stable ID")
	_check(fi.title == "Robotiikan ohjelmistokehittäjä" and en.title == "Senior robotics developer", "English title edit preserves Finnish title")
	_check(en.qa[0].question.is_empty(), "Unchanged untranslated existing pair permits profile edits")
	await _open_editor()
	editor.fields.name.text = ""
	editor.save_button.pressed.emit()
	_check(saved_count == 2 and editor.status_label.text.contains("name"), "Empty person name is rejected")
	editor.fields.name.text = en.name
	editor.cancelled.emit()
	_check(cancelled_count == 1 and not state.entities[entity_id].deleted, "Cancel emits without deleting the person")
	editor.status_label.visible = false
	editor.delete_button.pressed.emit()
	await _settle()
	_check(editor.delete_dialog.visible and not state.entities[entity_id].deleted, "Delete opens confirmation before changing state")
	editor.delete_dialog.get_cancel_button().pressed.emit()
	await _settle()
	_check(not state.entities[entity_id].deleted and deleted_count == 0, "Cancelling deletion retains the person")
	editor.delete_button.pressed.emit()
	await _settle()
	await _capture("person-editor-delete-confirmation-en.png")
	editor.delete_dialog.get_ok_button().pressed.emit()
	await _settle()
	_check(deleted_count == 1 and state.entities[entity_id].deleted, "Confirmed deletion marks the exact person deleted")
	_check(not state.edit_person_profile(entity_id, {"name": "Restored accidentally"}), "Deleted person cannot be accidentally edited back into the office")
	if failures.is_empty():
		print("PASS: person fields, add/remove/reorder questions, stable IDs, bilingual preservation, validation, confirmed deletion")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _make_shell() -> void:
	root.size = Vector2i(1440, 900)
	root.gui_embed_subwindows = true
	var background = ColorRect.new()
	background.color = Color("102431")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	root.add_child(margin)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 15)
	margin.add_child(shell)
	var ui = load("res://scripts/ui/game_ui.gd").new()
	shell.theme = ui._make_theme()
	ui.free()
	var title = Label.new()
	title.add_theme_font_size_override("font_size", 29)
	shell.add_child(title)


func _open_editor() -> void:
	shell.get_child(0).text = "KANBAN OFFICE  /  " + ("Henkilön tiedot" if state.language == "fi" else "Person profile")
	if is_instance_valid(editor):
		shell.remove_child(editor)
		editor.queue_free()
	editor = editor_script.new()
	shell.add_child(editor)
	editor.saved.connect(func(): saved_count += 1)
	editor.deleted.connect(func(): deleted_count += 1)
	editor.cancelled.connect(func(): cancelled_count += 1)
	editor.setup(entity_id)
	await _settle()


func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func _capture(filename: String) -> void:
	if capture_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(capture_directory.path_join(filename))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _require(condition: bool, message: String) -> bool:
	_check(condition, message)
	if not condition:
		push_error(message)
		quit(1)
	return condition
