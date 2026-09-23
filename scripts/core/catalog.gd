extends RefCounted
## Deterministic bilingual board content. No network or external assets required.
const TOPIC_PATH = "res://scripts/core/topics.json"
const CATALOG_VERSION = 1
const PEOPLE = ["Aino", "Oskari", "Mila", "Elias", "Sofia", "Noah", "Emma", "Leo"]
const LISTS = [
	{"fi": "Ideat", "en": "Ideas"},
	{"fi": "Valmiina", "en": "Ready"},
	{"fi": "Työn alla", "en": "In progress"},
	{"fi": "Valmis", "en": "Done"}
]
var topics: Array = []

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TOPIC_PATH))
	if parsed is Array:
		topics = parsed
	else:
		push_error("Kanban topic catalog is missing or invalid: " + TOPIC_PATH)

func count() -> int:
	return topics.size()

func topic(index: int) -> Dictionary:
	if topics.is_empty():
		return {}
	return topics[posmod(index, topics.size())]

func make_board(board_id: String, room_id: String, topic_index: int) -> Dictionary:
	var subject = topic(topic_index)
	return {
		"id": board_id, "room_id": room_id, "topic": posmod(topic_index, maxi(1, count())),
		"title": subject.get("title", {"fi": "Taulu", "en": "Board"}).duplicate(true),
		"lists": LISTS.duplicate(true), "cards": [[], [], [], []]
	}

func make_cards(board_id: String, topic_index: int) -> Array:
	var subject = topic(topic_index)
	var result: Array = []
	if subject.is_empty():
		return result
	for phase in range(4):
		for component in range(4):
			var part = subject.parts[component]
			var owner = PEOPLE[posmod(topic_index + component, PEOPLE.size())]
			var lines = {"fi": [], "en": []}
			for lang in ["fi", "en"]:
				var name_text: String = part.name[lang]
				var work_text: String = part.work[lang]
				var accepted: String = part.accept[lang]
				var phase_fi = ["Suunnitelma", "Toteutus", "Testaus", "Hyväksyntä"]
				var phase_en = ["Plan", "Build", "Test", "Accept"]
				var heading = phase_fi[phase] if lang == "fi" else phase_en[phase]
				var action: String
				var outcome: String
				match phase:
					0:
						action = work_text.capitalize()
						outcome = ("Raja: " if lang == "fi" else "Goal: ") + accepted
					1:
						action = work_text.capitalize()
						outcome = ("Ehto: " if lang == "fi" else "Pass: ") + accepted
					2:
						action = ("Tarkista: " if lang == "fi" else "Verify: ") + accepted
						outcome = "Kirjaa mittaus ja havainto" if lang == "fi" else "Record result and observation"
					_:
						action = ("Todettu: " if lang == "fi" else "Verified: ") + accepted
						outcome = "Päätös: hyväksytty jatkoon" if lang == "fi" else "Decision: approved to proceed"
				lines[lang] = [heading + ": " + name_text, action, ("Vastuu: " if lang == "fi" else "Owner: ") + owner, outcome]
			result.append({
				"id": board_id + "_card_%02d" % (phase * 4 + component),
				"topic": posmod(topic_index, maxi(1, count())),
				"lines": lines
			})
	return result
