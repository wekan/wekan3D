extends SceneTree
## redot --headless --path . --script res://tests/person_profiles_test.gd
const Profiles = preload("res://scripts/actors/person_profiles.gd")
const Catalog = preload("res://scripts/core/catalog.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("_run")


func _run() -> void:
	var catalog = Catalog.new()
	var titles: Dictionary = {}
	var answers: Dictionary = {}
	for topic in range(catalog.count()):
		for variant in range(2):
			var spec = {"name": "Test Person " + str(variant), "room_id": "topic_room_" + str(topic), "topic": topic, "role_variant": variant, "female": variant == 0}
			var profile = Profiles.make_profile(spec)
			_check_profile(profile, "topic %d variant %d" % [topic, variant])
			titles[profile.title.en] = true
			answers[profile.qa[1].answer.en] = true
			var all_fi = ""
			var all_en = ""
			for pair in profile.qa:
				all_fi += pair.question.fi + " " + pair.answer.fi + " "
				all_en += pair.question.en + " " + pair.answer.en + " "
			for part in catalog.topic(topic).parts:
				_expect(str(part.name.fi) in all_fi and str(part.name.en) in all_en, "QA covers concrete work package " + str(part.name.en))
				_expect(str(part.accept.fi) in all_fi and str(part.accept.en) in all_en, "QA covers actual acceptance criterion " + str(part.accept.en))
			_expect(JSON.stringify(Profiles.make_profile(spec)) == JSON.stringify(profile), "profiles deterministic for stable identity")
			spec.female = not spec.female
			_expect(JSON.stringify(Profiles.make_profile(spec)) == JSON.stringify(profile), "expert roles independent of gender")
	_expect(titles.size() >= 100, "broad variety of topic-specific professional titles")
	_expect(answers.size() >= 60, "answers differ between concrete topic work packages")
	var initial_titles: Dictionary = {}
	for room_index in range(16):
		for colleague in range(2):
			var person = Profiles.make_profile({"name": "Colleague %d" % (room_index * 2 + colleague), "room_id": "room_%d" % room_index, "topic": room_index * 4, "role_variant": colleague})
			_check_profile(person, "initial colleague")
			initial_titles[person.title.en] = true
	_expect(initial_titles.size() >= 24, "initial building has varied worker titles")
	var reception_titles: Dictionary = {}
	for index in range(2):
		var receptionist = Profiles.make_profile({"name": "Aino" if index == 0 else "Maya", "entity_id": "person_reception_" + str(index), "receptionist": true, "female": true})
		_check_profile(receptionist, "receptionist")
		reception_titles[receptionist.title.en] = true
		var reception_text = JSON.stringify(receptionist.qa)
		_expect("stairs" in reception_text and "controller" in reception_text and "pocket" in reception_text, "reception answers cover directions, carrying and controls")
	_expect(reception_titles.size() == 2, "two receptionists have distinct professional roles")
	await _check_npc_profile_updates()
	print("Person profiles: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check_profile(profile: Dictionary, label: String) -> void:
	for field in ["title", "team_role", "expertise"]:
		_expect(profile.get(field) is Dictionary, label + " bilingual " + field)
		for language in ["fi", "en"]:
			_expect(profile[field].get(language) is String and not str(profile[field][language]).strip_edges().is_empty(), label + " nonempty " + field + " " + language)
	_expect(profile.get("qa") is Array and profile.qa.size() >= 4, label + " at least four Q&A pairs")
	var identifiers: Dictionary = {}
	for pair in profile.qa:
		_expect(not str(pair.get("id", "")).is_empty() and not identifiers.has(pair.id), label + " stable unique pair ID")
		identifiers[pair.id] = true
		for field in ["question", "answer"]:
			for language in ["fi", "en"]:
				_expect(pair.get(field, {}).get(language) is String and str(pair[field][language]).length() >= 10, label + " meaningful " + field + " " + language)


func _check_npc_profile_updates() -> void:
	var state = root.get_node_or_null("GameState")
	_expect(state != null, "GameState available for NPC profile integration")
	if state == null:
		return
	var previous_language = state.language
	var scene = Node3D.new()
	root.add_child(scene)
	var player = Node3D.new()
	scene.add_child(player)
	player.position = Vector3(30, 0, 30)
	var script = load("res://scripts/actors/office_npc.gd")
	var npc = script.new()
	scene.add_child(npc)
	var spec = {"entity_id": "profile_test_person", "name": "Test Colleague", "room_id": "profile_test_room", "topic": 2, "position": Vector3(-9, 0, -6)}
	state.entities[spec.entity_id] = {"id": spec.entity_id, "name": {"fi": "Testikollega", "en": "Test Colleague"}, "profile": Profiles.make_profile(spec)}
	npc.setup(spec, player)
	var information = npc.interact()
	_expect(information.profile.qa.size() >= 4 and information.qa == information.profile.qa, "interaction exposes profile and direct Q&A payload")
	_expect(information.title == state.entities[spec.entity_id].profile.title, "interaction uses persisted title")
	state.entities[spec.entity_id].profile.title = {"fi": "Päivitetty titteli", "en": "Updated title"}
	state.language = "fi"
	state.entities_changed.emit()
	_expect("Päivitetty titteli" in npc._name_label.text, "edited Finnish title appears on NPC nameplate")
	state.language = "en"
	state.language_changed.emit()
	_expect("Updated title" in npc._name_label.text and "Test Colleague" in npc._name_label.text, "English nameplate follows live language change")
	_expect(npc.interact().profile.title.en == "Updated title", "subsequent dialogue reads edited profile")
	state.entities.erase(spec.entity_id)
	state.language = previous_language
	scene.queue_free()
	await process_frame


func _expect(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Person profile test failed: " + label)
