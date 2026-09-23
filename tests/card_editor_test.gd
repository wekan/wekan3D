extends SceneTree
## redot --headless --path . --script res://tests/card_editor_test.gd
## Optional screenshots: run with display and -- --capture=/absolute/directory

var state
var schema
var editor_script
var editor
var shell: VBoxContainer
var failures: Array = []
var save_count = 0
var capture_directory = ""
var card_id = ""


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
	state.ensure_board("editor_board", "editor_room", 0)
	card_id = state.boards["editor_board"].cards[0][0]
	schema = load("res://scripts/core/card_schema.gd")
	editor_script = load("res://scripts/ui/card_editor.gd")
	if schema == null or editor_script == null:
		push_error("Card editor dependencies did not compile")
		quit(1)
		return
	_make_shell()
	await _open_editor()
	var original_en = state.get_card_details(card_id, "en").duplicate(true)
	_check(editor.field_controls.size() == schema.fields().size(), "Every card schema field has a visible editor or read-only control")
	_check(editor.tabs.get_tab_count() == 7, "Card editor has all seven sections")
	_check(editor.related_controls.size() == 6, "All six related-record categories are editable")
	_check(not editor.field_controls["_id"].editable, "Card ID is read only")
	_check(not editor.field_controls["boardId"].editable, "Board placement is read only")
	_check(editor.field_controls["title"].get_global_rect().position.y > 150, "Title is initially visible at the top of the editor")
	_check(editor.collect_changes().get("values", {}) == {}, "Opening a card produces no changes")
	editor.set_field_value("title", "Moottorimoduulin turvallinen asennus")
	editor.set_field_value("description", "Tarkista osat ja työkalut ennen kokoamista.\nAsenna moottori telineeseen ja varmista kiinnitykset.\nKirjaa testitulokset ja sovi vertaisarviointi.")
	editor.set_field_value("dueAt", "2026-10-21T14:30:00Z")
	editor.set_field_value("spentTime", 2.5)
	editor.set_field_value("dueComplete", true)
	editor.set_field_value("priority", "high")
	editor.set_field_value("members", ["aino", "mikael"])
	editor.set_field_value("customFields", [{"_id": "budget", "value": 1250.5}])
	editor.set_field_value("related.checklists", [{"_id": "review-checklist", "title": "Tarkastus", "sort": 0}])
	editor.set_field_value("related.checklistItems", [{"_id": "review-item", "checklistId": "review-checklist", "title": "Kiinnitykset tarkistettu", "isFinished": true, "sort": 0}])
	await _settle()
	await _capture("card-editor-main-fi.png")
	editor.tabs.current_tab = 3
	await _settle()
	await _capture("card-editor-checklists-fi.png")
	editor._save()
	_check(save_count == 1, "Valid full-field edit emits saved")
	_check(not editor.status_label.visible, "Valid edit has no error")
	if save_count != 1:
		push_error("Card editor save failed: " + editor.status_label.text)
		quit(1)
		return
	var fi = state.get_card_details(card_id, "fi")
	_check(fi.title == "Moottorimoduulin turvallinen asennus", "Finnish title saved")
	_check(fi.description.contains("Asenna moottori"), "Multiline description saved")
	_check(fi.dueAt == "2026-10-21T14:30:00Z" and fi.spentTime == 2.5 and fi.dueComplete, "Date, number and Boolean values preserve their types")
	_check(fi.priority == "high", "Priority selection saves its canonical value")
	_check(fi.members == ["aino", "mikael"], "People references persist")
	_check(fi.customFields[0].value == 1250.5, "Structured custom field persists")
	_check(state.cards[card_id].related.checklistItems[0].isFinished, "Related checklist item persists")
	_check(state.get_card_details(card_id, "en").title == original_en.title, "Finnish edit preserves the English title")
	state.set_language("en")
	await _open_editor()
	var expected_fi_title = state.get_card_details(card_id, "fi").title
	editor.set_field_value("title", "Safe motor module installation")
	editor.set_field_value("description", "Check the parts and tools before assembly.\nInstall the motor and verify all mountings.\nRecord test results and request a peer review.")
	editor.field_controls["members"].text = "[broken"
	editor._save()
	_check(save_count == 1 and editor.status_label.visible, "Malformed JSON blocks saving and shows an error")
	_check(state.get_card_details(card_id, "en").title == original_en.title, "Failed validation leaves state unchanged")
	editor.set_field_value("members", ["aino"])
	editor.set_field_value("dueAt", "2026-02-30")
	editor._save()
	_check(save_count == 1 and editor.status_label.text.contains("ISO"), "Impossible dates block saving")
	editor.set_field_value("dueAt", "2026-10-22")
	editor.field_controls["spentTime"].text = "not-a-number"
	editor._save()
	_check(save_count == 1 and editor.status_label.text.contains("number"), "Invalid numeric data blocks saving")
	editor.set_field_value("spentTime", 3.75)
	editor.field_controls["_id"].text = "should-never-change"
	var english_checklists = state.get_card_details(card_id, "en").related.checklists.duplicate(true)
	english_checklists[0]["title"] = "Verification"
	editor.set_field_value("related.checklists", english_checklists)
	editor.set_field_value("related.cardComments", [{"_id": "comment-review", "text": "Ready for peer review", "userId": "aino"}])
	editor.filter_input.text = ""
	editor._filter_fields("")
	editor.tabs.current_tab = 0
	editor.status_label.visible = false
	await _settle()
	await _capture("card-editor-main-en.png")
	editor._save()
	_check(save_count == 2, "Corrected English edit saves")
	if save_count != 2:
		push_error("Card editor English save failed: " + editor.status_label.text)
		quit(1)
		return
	_check(state.get_card_details(card_id, "fi").title == expected_fi_title, "English edit preserves Finnish title")
	_check(state.get_card_details(card_id, "en").title == "Safe motor module installation", "English title saved")
	_check(state.get_card_details(card_id, "en")._id == card_id, "System ID cannot be changed by the editor")
	_check(state.get_card_details(card_id, "en").related.cardComments[0].text == "Ready for peer review", "Related comment text saved")
	_check(state.get_card_details(card_id, "fi").related.checklists[0].title == "Tarkastus", "English checklist edit preserves the Finnish checklist title")
	_check(state.get_card_details(card_id, "en").related.checklists[0].title == "Verification", "Related checklist text saves in the selected language")
	_check(state.validate_state().is_empty(), "Field editing preserves all card ownership invariants")
	await _open_editor()
	editor.filter_input.text = "customFields"
	editor._filter_fields("customFields")
	await _settle()
	_check(editor.tabs.current_tab == 6, "Field search switches to matching section")
	await _capture("card-editor-custom-fields-en.png")
	if failures.is_empty():
		print("PASS: full card schema controls, typed fields, JSON validation, dates, related records, localization, read-only IDs, field search")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


func _make_shell() -> void:
	root.size = Vector2i(1440, 900)
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
	shell.add_theme_constant_override("separation", 16)
	margin.add_child(shell)
	var ui_script = load("res://scripts/ui/game_ui.gd")
	var ui = ui_script.new()
	shell.theme = ui._make_theme()
	ui.free()
	var title = Label.new()
	title.text = "KANBAN OFFICE  /  " + ("Kortin tiedot" if state.language == "fi" else "Card details")
	title.add_theme_font_size_override("font_size", 29)
	shell.add_child(title)


func _open_editor() -> void:
	shell.get_child(0).text = "KANBAN OFFICE  /  " + ("Kortin tiedot" if state.language == "fi" else "Card details")
	if is_instance_valid(editor):
		shell.remove_child(editor)
		editor.queue_free()
	editor = editor_script.new()
	shell.add_child(editor)
	editor.saved.connect(func(): save_count += 1)
	editor.setup(card_id)
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
