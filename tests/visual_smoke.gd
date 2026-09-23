extends SceneTree
## Render actual project screenshots; never uses synthetic mockup images.
var game
var capture_dir = ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()
func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var state = root.get_node("GameState")
	state.autosave_enabled = false
	for npc in game.npcs:
		npc.set_physics_process(false)
	game.player.set_enabled(false)
	await _capture("01-reception.png")
	var room = game.world.rooms[0]
	game.player.global_position = room.center + Vector3(0,0.05,0)
	game.player.rotation.y = -PI/2
	await _capture("02-office.png")
	game.ui.open_board(game.world.board_specs[0].id)
	await _capture("03-board.png")
	game.ui.close_modal()
	game.ui.open_card_editor(str(state.cards.keys()[0]))
	await _capture("04-card-editor.png")
	game.ui.close_modal()
	for i in range(18): state.pocket_card(str(state.cards.keys()[i]))
	game.ui.open_pocket()
	await _capture("05-pocket.png")
	game.ui.close_modal()
	game.ui.open_search("näyttö")
	await _capture("06-search.png")
	game.ui.close_modal()
	game._open_remote_call(game.npcs[2].entity_id)
	await _capture("08-remote-tablet.png")
	game.ui.close_modal()
	game.player.global_position = Vector3(0,8.05,-12.5)
	game.player.rotation.y = 0
	await _capture("07-stairs.png")
	game.queue_free()
	await process_frame
	print("VISUAL SMOKE: completed")
	quit()
func _capture(filename: String) -> void:
	for i in range(8): await process_frame
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		var frame = root.get_texture().get_image()
		frame.save_png(capture_dir.path_join(filename))
		print("CAPTURE "+filename)
