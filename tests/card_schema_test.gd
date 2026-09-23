extends SceneTree
const CardSchema = preload("res://scripts/core/card_schema.gd")
var checks = 0
var failures = 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var initial = CardSchema.default_details({"fi":["Runko","Suunnittele","Rakenna","Testaa"],"en":["Chassis","Plan","Build","Test"]})
	_expect(CardSchema.fields().size() == 56,"all card roots, watcher mixin, implicit id, priority")
	var doc = CardSchema.compose(initial.details,initial.localized_details,"fi")
	_expect(doc.title == "Runko" and doc.description == "Suunnittele\nRakenna\nTestaa","preview lines initialize full text")
	_expect(not initial.details.has("title") and not initial.details.has("description"),"human text excluded from shared details")
	_expect(CardSchema.validate(doc).is_empty(),"default complete document valid")
	_expect(CardSchema.descriptor("poker.one.$").type == "string","nested poker voters descriptor")
	_expect(CardSchema.descriptor("customFields.$.value").type == "mixed","custom field union descriptor")
	_expect(CardSchema.descriptor("stickers.$.highlight").allowed_values == ["underline","round"],"exact nested enum preserved")
	_expect(CardSchema.descriptor("poker.question").type == "boolean","source poker question type retained")
	_expect(CardSchema.descriptor("watchers").source == "watchable.js","schema mixin coverage")
	doc.locations = [{"_id":"home","name":"Koti","address":"Kotitie","latitude":60.1,"longitude":24.2},{"_id":"office","name":"Toimisto","address":"Toimistotie","latitude":61.0,"longitude":25.0}]
	doc.customFields = [{"_id":"memo","value":"Suomenkielinen"}]
	doc.vote.question = "Julkaistaanko?"
	doc.vote.positive = ["user_shared"]
	var saved = CardSchema.split(doc,"fi",initial.localized_details)
	_expect(saved.details.locations[0]._id == "home" and not saved.details.locations[0].has("name"),"nested ids shared and names localized")
	_expect(saved.details.locations[0].latitude == 60.1,"coordinates shared")
	_expect(saved.details.vote.positive == ["user_shared"] and not saved.details.vote.has("question"),"vote user IDs shared, question localized")
	var english = CardSchema.compose(saved.details,saved.localized_details,"en")
	english.locations[0].name = "Home"
	english.locations[0].address = "Home road"
	english.locations[1].name = "Office"
	english.locations[1].address = "Office road"
	english.customFields[0].value = "English value"
	var bilingual = CardSchema.split(english,"en",saved.localized_details)
	bilingual.details.locations.reverse()
	var fi = CardSchema.compose(bilingual.details,bilingual.localized_details,"fi")
	var en = CardSchema.compose(bilingual.details,bilingual.localized_details,"en")
	_expect(fi.locations[0].name == "Toimisto" and en.locations[0].name == "Office","localized array overlays follow stable IDs after reorder")
	_expect(fi.title == "Runko" and en.title == "Chassis","independent top-level languages")
	en.customFields[0].value = 42
	var numeric = CardSchema.split(en,"en",bilingual.localized_details)
	_expect(CardSchema.compose(numeric.details,numeric.localized_details,"fi").customFields[0].value == 42,"numeric custom field changes are shared")
	var invalid = doc.duplicate(true)
	invalid.poker.one = [7]
	_expect(not CardSchema.validate(invalid).is_empty(),"nested voter identifiers must be strings")
	invalid = doc.duplicate(true)
	invalid.dueAt = "2026-02-30"
	_expect(not CardSchema.validate(invalid).is_empty(),"invalid calendar date rejected")
	invalid.dueAt = "2028-02-29T12:30:00Z"
	_expect(CardSchema.validate(invalid).is_empty(),"valid leap date accepted")
	invalid.priority = "unknown"
	_expect(not CardSchema.validate(invalid).is_empty(),"priority enum enforced")
	var reaction = {"reactions":[{"reactionCodepoint":"&#128077;","userIds":["u"]}]}
	_expect(CardSchema.validate(reaction,"cardCommentReactions").is_empty(),"reaction schema supports entity validation")
	reaction.reactions[0].reactionCodepoint = "<script>"
	_expect(not CardSchema.validate(reaction,"cardCommentReactions").is_empty(),"reaction code custom rule enforced")
	_expect(not CardSchema.schema("attachments").schema_declared and not CardSchema.schema("activities").schema_declared,"schema-less source distinction retained")
	var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/wekan_schema.json"))
	for collection in raw.collections:
		if collection.name == "cards":
			for path in collection.fields:
				_expect(not CardSchema.descriptor(path).is_empty(),"source coverage: "+path)
	print("Card schema: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func _expect(condition: bool,label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
