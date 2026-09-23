extends VBoxContainer
## Destination controls for relocating an entire pocketed floor or workspace.
signal placed(item_id: String)

var item: Dictionary = {}
var organization_picker: OptionButton
var floor_picker: OptionButton
var place_button: Button
var status_label: Label
var organization_ids: Array = []

func setup(pocket_item: Dictionary) -> void:
	item = pocket_item
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading = Label.new()
	heading.text = _t("Sijoita kokonaisuus toiseen paikkaan", "Place this item in a new location")
	heading.add_theme_font_size_override("font_size", 19)
	add_child(heading)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	organization_picker = OptionButton.new()
	organization_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	organization_picker.custom_minimum_size = Vector2(230, 42)
	organization_picker.clip_text = true
	organization_picker.set_meta("focus_id", "spatial_destination_organization")
	row.add_child(organization_picker)
	floor_picker = OptionButton.new()
	floor_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floor_picker.custom_minimum_size = Vector2(230, 42)
	floor_picker.clip_text = true
	floor_picker.set_meta("focus_id", "spatial_destination_floor")
	row.add_child(floor_picker)
	place_button = Button.new()
	place_button.text = _t("Sijoita tähän", "Place here")
	place_button.custom_minimum_size = Vector2(150, 42)
	place_button.set_meta("focus_id", "spatial_destination_place")
	place_button.pressed.connect(_place)
	row.add_child(place_button)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.modulate = Color("a4c3c9")
	add_child(status_label)
	for organization_id in GameState.organizations:
		var organization: Dictionary = GameState.organizations[organization_id]
		if organization.get("deleted", false) or organization.get("in_pocket", false): continue
		organization_ids.append(str(organization_id))
		organization_picker.add_item(GameState.localize(organization.name))
	organization_picker.item_selected.connect(func(_index): _populate_floors())
	_populate_floors()

func _populate_floors() -> void:
	floor_picker.clear()
	if organization_ids.is_empty():
		place_button.disabled = true
		status_label.text = _t("Kohteeksi tarvitaan paikalleen sijoitettu rakennus.", "A placed building is needed as the destination.")
		return
	var organization_id: String = str(organization_ids[organization_picker.selected])
	if item.get("kind", "") == "floor":
		floor_picker.add_item(_t("Ylimmäksi kerrokseksi", "As the top floor"))
		floor_picker.set_item_metadata(0, {"id": "", "number": -1})
	var candidates: Array = []
	var all_floors = GameState.get("floors")
	if all_floors is Dictionary:
		for floor_record in all_floors.values():
			if str(floor_record.get("organization_id", "")) != organization_id: continue
			if floor_record.get("deleted", false) or floor_record.get("in_pocket", false): continue
			candidates.append(floor_record)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.number) < int(b.number))
	for floor_record in candidates:
		var prefix: String = _t("Ennen kerrosta ", "Before floor ") if item.get("kind", "") == "floor" else _t("Kerros ", "Floor ")
		floor_picker.add_item(prefix + str(floor_record.number) + " · " + GameState.localize(floor_record.get("name", "")))
		floor_picker.set_item_metadata(floor_picker.item_count - 1, {"id": str(floor_record.id), "number": int(floor_record.number)})
	place_button.disabled = floor_picker.item_count == 0
	status_label.text = _t("Kaikki sisältö siirtyy mukana. Kerroksen lisääminen siirtää ylempiä kerroksia ylöspäin.", "All contents move together. Inserting a floor shifts the floors above it upwards.") if item.get("kind", "") == "floor" else _t("Työtila tauluineen, ihmisineen ja esineineen siirtyy valittuun kerrokseen.", "The workspace, boards, people and objects move to the selected floor.")

func _place() -> void:
	if place_button.disabled or organization_picker.selected < 0 or floor_picker.selected < 0: return
	var organization_id: String = str(organization_ids[organization_picker.selected])
	var floor_data: Dictionary = floor_picker.get_item_metadata(floor_picker.selected)
	var organization: Dictionary = GameState.organizations[organization_id]
	var value = organization.get("position", {"x": 0.0, "y": 0.0, "z": 0.0})
	var position = value if value is Vector3 else Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
	position.y += maxf(0.0, float(floor_data.number - 1) * 4.0)
	var success: bool = bool(GameState.call("place_spatial_item", str(item.id), "", position, organization_id, str(floor_data.id), int(floor_data.number)))
	if success:
		placed.emit(str(item.id))
	else:
		status_label.modulate = Color("ffc2a8")
		status_label.text = _t("Sijoitus ei onnistunut. Tarkista, että kohderakennus ja kerros ovat käytettävissä.", "Placement failed. Check that the destination building and floor are available.")

func _t(fi: String, en: String) -> String:
	return fi if GameState.language == "fi" else en
