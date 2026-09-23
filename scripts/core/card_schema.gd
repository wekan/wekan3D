extends RefCounted
## Declarative adaptation of the supplied WeKan schemas. No JavaScript is run.
## Human text uses language overlays; identity and typed values remain shared.

const CATALOG_PATH = "res://data/card_fields.json"
static var _catalog: Dictionary = {}


static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary:
			_catalog = parsed
	return _catalog


static func schema(schema_name: String = "cards") -> Dictionary:
	return catalog().get("schemas", {}).get(schema_name, {}).duplicate(true)


static func fields(schema_name: String = "cards") -> Array:
	return schema(schema_name).get("fields", [])


static func descriptor(path: String, schema_name: String = "cards") -> Dictionary:
	return _find_descriptor(fields(schema_name), path)


static func _find_descriptor(descriptors: Array, path: String) -> Dictionary:
	for item in descriptors:
		if str(item.get("path", "")) == path:
			return item.duplicate(true)
		var nested = _find_descriptor(item.get("children", []), path)
		if not nested.is_empty():
			return nested
		if item.has("items"):
			nested = _find_descriptor([item["items"]], path)
			if not nested.is_empty():
				return nested
	return {}


static func localized_paths(schema_name: String = "cards") -> Array:
	var result: Array = []
	_collect_localized(fields(schema_name), result)
	return result


static func _collect_localized(descriptors: Array, result: Array) -> void:
	for item in descriptors:
		if item.get("localized", false):
			result.append(item["path"])
		_collect_localized(item.get("children", []), result)
		if item.has("items"):
			_collect_localized([item["items"]], result)


static func default_details(lines_by_language: Dictionary) -> Dictionary:
	var full = _default_object(fields())
	var now = Time.get_datetime_string_from_system(true) + "Z"
	for key in ["createdAt", "modifiedAt", "dateLastActivity"]:
		full[key] = now
	var shared: Dictionary = {}
	var localized: Dictionary = {"fi": {}, "en": {}}
	for locale in ["fi", "en"]:
		var lines: Array = lines_by_language.get(locale, [])
		full["title"] = str(lines[0]) if not lines.is_empty() else ""
		var description_lines: Array = []
		for index in range(1, mini(4, lines.size())):
			description_lines.append(str(lines[index]))
		full["description"] = "\n".join(description_lines)
		var result = split(full, locale, localized)
		shared = result["details"]
		localized = result["localized_details"]
	return {"details": shared, "localized_details": localized}


static func _default_object(descriptors: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in descriptors:
		var name = _field_name(item)
		if item.get("has_default", false) and not item.has("default_expression"):
			result[name] = _copy(item.get("default"))
		else:
			match str(item.get("type", "any")):
				"string", "mixed": result[name] = ""
				"number": result[name] = 0
				"boolean": result[name] = false
				"array": result[name] = []
				"object": result[name] = _default_object(item.get("children", []))
				_: result[name] = null
	return result


static func compose(details: Dictionary, localized_details: Dictionary, language: String, schema_name: String = "cards") -> Dictionary:
	var overlay: Dictionary = localized_details.get(language, {})
	return _compose_value(details, overlay, {"type": "object", "children": fields(schema_name)})


static func _compose_value(shared, overlay, item: Dictionary):
	if item.get("localized", false) and overlay is String and (shared == null or shared is String):
		return overlay
	if shared is Dictionary:
		var result = shared.duplicate(true)
		var patch: Dictionary = overlay if overlay is Dictionary else {}
		for child in item.get("children", []):
			var key = _field_name(child)
			if result.has(key) or patch.has(key):
				result[key] = _compose_value(result.get(key), patch.get(key), child)
		return result
	if shared is Array:
		var result: Array = []
		var patches: Array = overlay if overlay is Array else []
		var element: Dictionary = item.get("items", {})
		for index in range(shared.size()):
			var patch = patches[index] if index < patches.size() else null
			if shared[index] is Dictionary and shared[index].has("_id"):
				patch = null
				for candidate in patches:
					if candidate is Dictionary and candidate.get("__item_id", "") == shared[index]["_id"]:
						patch = candidate
						break
			result.append(_compose_value(shared[index], patch, element))
		return result
	# A missing localized leaf can still be materialized from its overlay.
	if shared == null and item.get("localized", false) and overlay is String:
		return overlay
	return _copy(shared)


static func split(document: Dictionary, language: String, previous_localized: Dictionary = {}, schema_name: String = "cards") -> Dictionary:
	var separated = _split_value(document, {"type": "object", "children": fields(schema_name)})
	var localized = previous_localized.duplicate(true)
	if not localized.has("fi"):
		localized["fi"] = {}
	if not localized.has("en"):
		localized["en"] = {}
	localized[language] = separated["localized"]
	return {"details": separated["shared"], "localized_details": localized}


static func _split_value(value, item: Dictionary) -> Dictionary:
	if item.get("localized", false) and value is String:
		return {"shared": null, "localized": value, "has_shared": false, "has_localized": true}
	if value is Dictionary:
		var shared = value.duplicate(true)
		var localized: Dictionary = {}
		for child in item.get("children", []):
			var key = _field_name(child)
			if not value.has(key):
				continue
			var part = _split_value(value[key], child)
			if part["has_shared"]:
				shared[key] = part["shared"]
			else:
				shared.erase(key)
			if part["has_localized"]:
				localized[key] = part["localized"]
		if not localized.is_empty() and value.has("_id"):
			localized["__item_id"] = value["_id"]
		return {"shared": shared, "localized": localized, "has_shared": true, "has_localized": not localized.is_empty()}
	if value is Array:
		var shared: Array = []
		var localized: Array = []
		var has_localized = false
		for entry in value:
			var part = _split_value(entry, item.get("items", {}))
			shared.append(part["shared"])
			localized.append(part["localized"] if part["has_localized"] else null)
			has_localized = has_localized or part["has_localized"]
		return {"shared": shared, "localized": localized, "has_shared": true, "has_localized": has_localized}
	return {"shared": _copy(value), "localized": null, "has_shared": true, "has_localized": false}


static func validate(document: Dictionary, schema_name: String = "cards") -> Array:
	var errors: Array = []
	_validate_object(document, fields(schema_name), "", errors)
	return errors


static func _validate_object(document: Dictionary, descriptors: Array, prefix: String, errors: Array) -> void:
	for item in descriptors:
		var key = _field_name(item)
		var path = prefix + key
		if not document.has(key):
			if not item.get("optional", false) and not item.get("readonly", false) and not item.get("has_default", false):
				errors.append(path + ": required field is missing")
			continue
		_validate_value(document[key], item, path, errors)


static func _validate_value(value, item: Dictionary, path: String, errors: Array) -> void:
	if value == null:
		if not item.get("optional", false) and not item.get("readonly", false) and not (item.get("has_default", false) and item.get("default") == null):
			errors.append(path + ": null is not allowed")
		return
	var kind = str(item.get("type", "any"))
	var valid = true
	match kind:
		"string": valid = value is String
		"boolean": valid = value is bool
		"number": valid = (value is int or value is float) and is_finite(float(value))
		"date": valid = value is String and (str(value).is_empty() and item.get("optional", false) or _is_iso_date(str(value)))
		"array": valid = value is Array
		"object": valid = value is Dictionary
		"mixed":
			valid = value is String or value is bool or value is int or value is float or value is Array
			if value is Array:
				for entry in value:
					valid = valid and entry is String
	if not valid:
		errors.append(path + ": expected " + kind)
		return
	var allowed: Array = item.get("allowed_values", [])
	if not allowed.is_empty() and value not in allowed:
		errors.append(path + ": value is not in allowed values")
	if value is String:
		if item.has("max") and item["max"] != null and value.length() > int(item["max"]):
			errors.append(path + ": text is too long")
		if item.has("min") and item["min"] != null and value.length() < int(item["min"]):
			errors.append(path + ": text is too short")
		if item.has("pattern"):
			var expression = RegEx.new()
			if expression.compile(str(item["pattern"])) == OK and expression.search(value) == null:
				errors.append(path + ": text does not match the required pattern")
	if value is Dictionary:
		_validate_object(value, item.get("children", []), path + ".", errors)
	if value is Array:
		if item.has("maxCount") and item["maxCount"] != null and value.size() > int(item["maxCount"]):
			errors.append(path + ": too many entries")
		if item.has("minCount") and item["minCount"] != null and value.size() < int(item["minCount"]):
			errors.append(path + ": too few entries")
		if item.has("items"):
			for index in range(value.size()):
				_validate_value(value[index], item["items"], "%s[%d]" % [path, index], errors)


static func _is_iso_date(value: String) -> bool:
	var expression = RegEx.new()
	expression.compile("^([0-9]{4})-([0-9]{2})-([0-9]{2})(?:T([0-9]{2}):([0-9]{2})(?::([0-9]{2})(?:\\.[0-9]+)?)?(?:Z|[+-][0-9]{2}:[0-9]{2})?)?$")
	var found = expression.search(value)
	if found == null:
		return false
	var year = int(found.get_string(1))
	var month = int(found.get_string(2))
	var day = int(found.get_string(3))
	if month < 1 or month > 12 or year < 1:
		return false
	var month_days = [31, 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if day < 1 or day > month_days[month - 1]:
		return false
	if not found.get_string(4).is_empty():
		return int(found.get_string(4)) < 24 and int(found.get_string(5)) < 60 and int(found.get_string(6)) < 60
	return true


static func _field_name(item: Dictionary) -> String:
	var parts = str(item.get("path", item.get("key", ""))).split(".")
	return parts[parts.size() - 1]


static func _copy(value):
	return value.duplicate(true) if value is Dictionary or value is Array else value
