extends VBoxContainer
## Building/floor/workspace and physical-object editing using authoritative state.
signal changed
signal closed
signal person_selected(entity_id: String)

const FALLBACK_TEMPLATES = {
	"desk":["Työpöytä","Desk"],"chair":["Tuoli","Chair"],"monitor":["Näyttö","Monitor"],"plant":["Kasvi","Plant"],"sofa":["Sohva","Sofa"],"bookshelf":["Kirjahylly","Bookshelf"],
	"tree":["Puu","Tree"],"car":["Auto","Car"],"bench":["Penkki","Bench"],"bicycle":["Polkupyörä","Bicycle"],"moped":["Mopo","Moped"],"motorcycle":["Moottoripyörä","Motorcycle"],"rollator":["Rollaattori","Rollator"],
	"cat":["Kissa","Cat"],"dog":["Koira","Dog"],"cow":["Lehmä","Cow"],"horse":["Hevonen","Horse"],"chicken":["Kana","Chicken"],
	"newspaper":["Sanomalehti","Newspaper"],"coffee_cup":["Kahvikuppi","Coffee cup"],"plate":["Lautanen","Plate"],"spoon":["Lusikka","Spoon"],"drinking_glass":["Juomalasi","Drinking glass"],"book":["Kirja","Book"],"flower":["Kukka","Flower"],"road":["Tie","Road"],
}
var context: Dictionary = {}
var organization_id = ""
var floor_id = ""
var room_id = ""
var entity_id = ""
var organization_picker: OptionButton
var floor_picker: OptionButton
var room_picker: OptionButton
var floor_name: LineEdit
var room_name: LineEdit
var entity_name: LineEdit
var object_name: LineEdit
var template_picker: OptionButton
var object_list: ItemList
var object_filter: LineEdit
var status_label: Label
var location_label: Label
var person_button: Button
var appearance_color: ColorPickerButton
var scale_controls: Dictionary = {}
var confirmation: ConfirmationDialog
var pending_delete: Dictionary = {}
var last_created_id = ""
var last_pocket_id = ""
var _state: Node
var _refresh_queued = false
var _appearance_entity_id = ""
var _appearance_dirty = false
var _color_changed = false
var _syncing_appearance = false
var _action_buttons: Dictionary = {}
var _labels: Dictionary = {}
var _templates: Dictionary = FALLBACK_TEMPLATES.duplicate(true)

func setup(options: Dictionary) -> void:
	context = options.duplicate(true)
	_state = get_node("/root/GameState")
	organization_id = str(context.get("organization_id",""))
	floor_id = str(context.get("floor_id",""))
	room_id = str(context.get("room_id",""))
	entity_id = str(context.get("entity_id",""))
	_load_templates()
	_resolve_context()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",12)
	_build()
	for signal_name in ["layout_changed","entities_changed","organizations_changed","cards_changed","language_changed"]:
		if _state.has_signal(signal_name):_state.connect(signal_name,_queue_refresh)
	refresh()

func _load_templates() -> void:
	var path = "res://scripts/world/prop_factory.gd"
	if not ResourceLoader.exists(path):return
	var factory = load(path)
	if factory == null:return
	var names = factory.get_template_names() if factory.has_method("get_template_names") else {}
	if names is Dictionary and not names.is_empty():
		_templates.clear()
		for key in names:
			_templates[key] = [names[key].get("fi",key),names[key].get("en",key)]

func _location_is_pocketed() -> bool:
	var floors = _state.get("floors")
	var floor: Dictionary = floors.get(floor_id,{}) if floors is Dictionary else {}
	return _state.organizations.get(organization_id,{}).get("in_pocket",false) or floor.get("in_pocket",false) or _state.rooms.get(room_id,{}).get("in_pocket",false)

func _resolve_context() -> void:
	if not entity_id.is_empty() and _state.entities.has(entity_id):
		var entity: Dictionary = _state.entities[entity_id]
		room_id = str(entity.get("room_id",room_id))
		organization_id = str(entity.get("organization_id",organization_id))
	if not room_id.is_empty() and _state.rooms.has(room_id):
		var room: Dictionary = _state.rooms[room_id]
		floor_id = str(room.get("floor_id",floor_id))
		organization_id = str(room.get("organization_id",organization_id))
	var floors = _state.get("floors")
	if floors is Dictionary and floors.has(floor_id):organization_id = str(floors[floor_id].get("organization_id",organization_id))

func _build() -> void:
	var header = HBoxContainer.new();add_child(header)
	var title = _label("title","Rakennukset ja esineet","Buildings and objects",23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL;header.add_child(title)
	header.add_child(_button("close","Sulje","Close",func():closed.emit()))
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true;add_child(scroll)
	var body = HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",24);scroll.add_child(body)
	var hierarchy = VBoxContainer.new()
	hierarchy.custom_minimum_size.x = 325
	hierarchy.add_theme_constant_override("separation",9);body.add_child(hierarchy)
	hierarchy.add_child(_label("building","Rakennus","Building",18))
	organization_picker = _picker();hierarchy.add_child(organization_picker)
	organization_picker.item_selected.connect(_select_organization)
	hierarchy.add_child(_button("pocket_building","Rakennus taskuun","Pocket building",_pocket_building))
	hierarchy.add_child(HSeparator.new())
	hierarchy.add_child(_label("floor","Kerros","Floor",18))
	floor_picker = _picker();hierarchy.add_child(floor_picker)
	floor_picker.item_selected.connect(_select_floor)
	floor_name = _text_input("floor_name","Kerroksen nimi","Floor name");hierarchy.add_child(floor_name)
	var floor_actions = HBoxContainer.new();hierarchy.add_child(floor_actions)
	floor_actions.add_child(_button("add_floor","Lisää","Add",_add_floor))
	floor_actions.add_child(_button("rename_floor","Nimeä","Rename",_rename_floor))
	floor_actions.add_child(_button("pocket_floor","Taskuun","Pocket",_pocket_floor))
	floor_actions.add_child(_button("delete_floor","Poista","Delete",func():_request_delete("floor",floor_id)))
	hierarchy.add_child(HSeparator.new())
	hierarchy.add_child(_label("room","Työtila","Workspace",18))
	room_picker = _picker();hierarchy.add_child(room_picker)
	room_picker.item_selected.connect(_select_room)
	room_name = _text_input("room_name","Työtilan nimi","Workspace name");hierarchy.add_child(room_name)
	var room_actions = HBoxContainer.new();hierarchy.add_child(room_actions)
	room_actions.add_child(_button("add_room","Lisää","Add",_add_room))
	room_actions.add_child(_button("rename_room","Nimeä","Rename",_rename_room))
	room_actions.add_child(_button("pocket_room","Taskuun","Pocket",_pocket_room))
	room_actions.add_child(_button("delete_room","Poista","Delete",func():_request_delete("room",room_id)))
	var structural_note = _label("structural_note","Kerroksen tai työtilan poistaminen siirtää sen taulut ja esineet taskuun.","Deleting a floor or workspace moves its boards and objects into the pocket.",13)
	structural_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	structural_note.modulate = Color("a2bec8");hierarchy.add_child(structural_note)
	var objects = VBoxContainer.new()
	objects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objects.add_theme_constant_override("separation",9);body.add_child(objects)
	objects.add_child(_label("objects","Valitun paikan esineet","Objects at the selected location",18))
	object_filter = _text_input("filter","Etsi esinettä…","Find an object…")
	object_filter.clear_button_enabled = true
	object_filter.text_changed.connect(func(_value):_refresh_objects())
	objects.add_child(object_filter)
	object_list = ItemList.new()
	object_list.custom_minimum_size.y = 215
	object_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_list.max_columns = 1
	object_list.fixed_icon_size = Vector2i(18,18)
	object_list.item_selected.connect(_select_entity)
	object_list.item_activated.connect(func(_index):_open_person())
	objects.add_child(object_list)
	objects.add_child(_label("selected","Valittu esine","Selected object",16))
	entity_name = _text_input("entity_name","Esineen nimi","Object name");objects.add_child(entity_name)
	var entity_actions = HBoxContainer.new();objects.add_child(entity_actions)
	entity_actions.add_child(_button("rename_entity","Nimeä uudelleen","Rename",_rename_entity))
	entity_actions.add_child(_button("pocket_entity","Taskuun","Pocket",_pocket_entity))
	entity_actions.add_child(_button("delete_entity","Poista","Delete",func():_request_delete("entity",entity_id)))
	person_button = _button("person","Henkilön tiedot ja tiimi","Person details and team",_open_person)
	entity_actions.add_child(person_button)
	objects.add_child(_label("appearance","Väri ja koko","Color and size",16))
	var appearance_row = HBoxContainer.new();appearance_row.add_theme_constant_override("separation",9);objects.add_child(appearance_row)
	appearance_color = ColorPickerButton.new();appearance_color.custom_minimum_size = Vector2(55,39)
	appearance_color.get_picker().picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	appearance_color.get_picker().can_add_swatches = true
	appearance_color.color_changed.connect(func(_color):
		if not _syncing_appearance:_appearance_dirty = true;_color_changed = true
	)
	appearance_color.set_meta("spatial_field","color");appearance_row.add_child(appearance_color)
	for axis in ["x","y","z"]:
		var dimensions = VBoxContainer.new();dimensions.add_theme_constant_override("separation",2)
		var labels = {"x":["Leveys X ×","Width X ×"],"y":["Korkeus Y ×","Height Y ×"],"z":["Syvyys Z ×","Depth Z ×"]}[axis]
		dimensions.add_child(_label("scale_"+axis,labels[0],labels[1],12))
		var spin = SpinBox.new();spin.min_value = 0.1;spin.max_value = 20.0;spin.step = 0.1;spin.value = 1.0
		spin.custom_minimum_size = Vector2(96,35);spin.set_meta("spatial_field","scale_"+axis)
		spin.value_changed.connect(func(_value):
			if not _syncing_appearance:_appearance_dirty = true
		)
		scale_controls[axis] = spin;dimensions.add_child(spin);appearance_row.add_child(dimensions)
	appearance_row.add_child(_button("apply_appearance","Käytä","Apply",_apply_appearance))
	objects.add_child(HSeparator.new())
	objects.add_child(_label("add_object","Lisää esine","Add an object",18))
	var new_object_row = HBoxContainer.new();objects.add_child(new_object_row)
	template_picker = _picker();template_picker.custom_minimum_size.x = 175
	new_object_row.add_child(template_picker)
	object_name = _text_input("object_name","Uuden esineen nimi","New object name")
	object_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL;new_object_row.add_child(object_name)
	new_object_row.add_child(_button("create_object","Lisää","Add",_create_object))
	location_label = Label.new()
	location_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	location_label.modulate = Color("9cbbc6")
	location_label.add_theme_font_size_override("font_size",13);objects.add_child(location_label)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size",15)
	status_label.modulate = Color("8bd2b9");add_child(status_label)
	confirmation = ConfirmationDialog.new()
	confirmation.confirmed.connect(_confirm_delete)
	confirmation.canceled.connect(func():pending_delete.clear())
	add_child(confirmation)

func refresh() -> void:
	_refresh_queued = false
	if not is_inside_tree() or _state == null:return
	_relabel()
	_fill_picker(organization_picker,_active_organizations(),organization_id)
	organization_id = _selected_id(organization_picker)
	_fill_picker(floor_picker,_active_floors(),floor_id)
	floor_id = _selected_id(floor_picker)
	var room_options = [{"id":"","name":{"fi":"Ulkotila","en":"Outdoors"}}]
	room_options.append_array(_active_rooms())
	_fill_picker(room_picker,room_options,room_id)
	room_id = _selected_id(room_picker)
	if not floor_name.has_focus():floor_name.text = _record_name("floors",floor_id)
	if not room_name.has_focus():room_name.text = _record_name("rooms",room_id)
	var old_template = _selected_id(template_picker)
	template_picker.clear()
	for key in _templates:
		var names = _templates[key]
		template_picker.add_item(_t(names[0],names[1]))
		template_picker.set_item_metadata(template_picker.item_count-1,key)
		if key == old_template:template_picker.select(template_picker.item_count-1)
	_refresh_objects()
	var org_valid = _state.organizations.has(organization_id)
	_action_buttons.pocket_building.disabled = not org_valid or bool(_state.organizations.get(organization_id,{}).get("in_pocket",false))
	_action_buttons.add_floor.disabled = not org_valid
	for key in ["rename_floor","delete_floor","pocket_floor","add_room"]:_action_buttons[key].disabled = floor_id.is_empty()
	for key in ["rename_room","delete_room","pocket_room"]:_action_buttons[key].disabled = room_id.is_empty()
	_action_buttons.create_object.disabled = not org_valid
	location_label.text = _t("Sijoituspaikka: nykyinen sijaintisi.","Placement: your current position.") if _uses_player_position() else _t("Sijoituspaikka: valittu työtila tai rakennuksen ulkotila. Voit siirtää esineen taskun kautta.","Placement: the selected workspace or the building's outdoor area. Use the pocket to move the object afterward.")

func _active_organizations() -> Array:
	var result: Array = []
	for record in _state.organizations.values():
		if not record.get("deleted",false):result.append(record)
	return result
func _active_floors() -> Array:
	var result: Array = []
	var floors = _state.get("floors")
	if not floors is Dictionary:return result
	for record in floors.values():
		if record.get("organization_id","") == organization_id and not record.get("deleted",false):result.append(record)
	result.sort_custom(func(a,b):return int(a.get("number",0)) < int(b.get("number",0)))
	return result
func _active_rooms() -> Array:
	var result: Array = []
	for record in _state.rooms.values():
		if record.get("floor_id","") == floor_id and record.get("organization_id","") == organization_id and not record.get("deleted",false):result.append(record)
	result.sort_custom(func(a,b):return int(a.get("slot_index",0)) < int(b.get("slot_index",0)))
	return result

func _refresh_objects() -> void:
	if object_list == null:return
	object_list.clear()
	var filter = object_filter.text.strip_edges().to_lower()
	for id in _state.entities:
		var record: Dictionary = _state.entities[id]
		if record.get("deleted",false) or record.get("organization_id","") != organization_id or str(record.get("room_id","")) != room_id:continue
		if _is_pocketed(id) and id != entity_id and not _location_is_pocketed():continue
		var name = _state.localize(record.get("name",id))
		var type_text = _template_label(str(record.get("template",record.get("kind",""))))
		if not filter.is_empty() and not (name+" "+type_text).to_lower().contains(filter):continue
		var label = name + "  ·  " + type_text
		if _is_pocketed(id):label += _t(" (taskussa)"," (in pocket)")
		object_list.add_item(label)
		var index = object_list.item_count-1
		object_list.set_item_metadata(index,id)
		object_list.set_item_tooltip(index,label)
		if id == entity_id:object_list.select(index)
	if not _state.entities.has(entity_id) or _state.entities.get(entity_id,{}).get("deleted",false):entity_id = ""
	_sync_entity_actions()

func _sync_entity_actions() -> void:
	var valid = _state.entities.has(entity_id) and not _state.entities.get(entity_id,{}).get("deleted",false)
	if not entity_name.has_focus():entity_name.text = _record_name("entities",entity_id) if valid else ""
	for key in ["rename_entity","delete_entity"]:_action_buttons[key].disabled = not valid
	_action_buttons.pocket_entity.disabled = not valid or _is_pocketed(entity_id)
	person_button.visible = valid and _state.entities.get(entity_id,{}).get("kind","") == "person"
	_action_buttons.apply_appearance.disabled = not valid
	appearance_color.disabled = not valid
	if entity_id != _appearance_entity_id:
		_appearance_entity_id = entity_id;_appearance_dirty = false;_color_changed = false
	if not _appearance_dirty:
		_syncing_appearance = true
		var appearance: Dictionary = _state.entities.get(entity_id,{}).get("appearance",{})
		appearance_color.color = Color.from_string(str(appearance.get("color","#ffffff")),Color.WHITE)
		var scale_value = _vector(appearance.get("scale",Vector3.ONE))
		var values = {"x":scale_value.x,"y":scale_value.y,"z":scale_value.z}
		for axis in scale_controls:scale_controls[axis].value = values[axis]
		_syncing_appearance = false
	for control in scale_controls.values():control.editable = valid

func _select_organization(index: int) -> void:
	organization_id = str(organization_picker.get_item_metadata(index));floor_id = "";room_id = "";entity_id = ""
	refresh()
func _select_floor(index: int) -> void:
	floor_id = str(floor_picker.get_item_metadata(index));entity_id = ""
	var rooms = _active_rooms();room_id = str(rooms[0].id) if not rooms.is_empty() else ""
	refresh()
func _select_room(index: int) -> void:
	room_id = str(room_picker.get_item_metadata(index));entity_id = "";refresh()
func _select_entity(index: int) -> void:
	entity_id = str(object_list.get_item_metadata(index));_sync_entity_actions()

func _add_floor() -> void:
	var title = _name_or_default(floor_name.text,"Uusi kerros","New floor")
	var result = _call("add_floor",[organization_id,title])
	if result is String and not result.is_empty():floor_id = result;room_id = "";last_created_id = result
	_finish(result,_t("Kerros lisätty.","Floor added."))
func _rename_floor() -> void:
	_finish(_call("rename_floor",[floor_id,floor_name.text]),_t("Kerroksen nimi tallennettu.","Floor name saved."))
func _add_room() -> void:
	var result = _call("add_room",[floor_id,_name_or_default(room_name.text,"Uusi työtila","New workspace")])
	if result is String and not result.is_empty():room_id = result;last_created_id = result
	_finish(result,_t("Työtila lisätty.","Workspace added."))
func _rename_room() -> void:
	_finish(_call("rename_room",[room_id,room_name.text]),_t("Työtilan nimi tallennettu.","Workspace name saved."))
func _create_object() -> void:
	var template = _selected_id(template_picker)
	var name = object_name.text.strip_edges()
	if name.is_empty():name = _template_label(template)
	var result = _call("create_object",[template,name,room_id,_placement_position(),organization_id])
	if result is String and not result.is_empty():entity_id = result;last_created_id = result;object_name.clear()
	_finish(result,_t("Esine lisätty.","Object added."))
func _rename_entity() -> void:
	_finish(_call("rename_entity",[entity_id,entity_name.text]),_t("Esineen nimi tallennettu.","Object name saved."))
func _apply_appearance() -> void:
	var new_scale = Vector3(scale_controls.x.value,scale_controls.y.value,scale_controls.z.value)
	var html_color = "#"+appearance_color.color.to_html(true) if _color_changed else ""
	var result = _call("edit_entity_appearance",[entity_id,html_color,new_scale])
	if result:_appearance_dirty = false;_color_changed = false
	_finish(result,_t("Väri ja koko tallennettu.","Color and size saved."))
func _pocket_entity() -> void:
	var result = _call("pocket_entity",[entity_id])
	if result is String and not result.is_empty():last_pocket_id = result;entity_id = ""
	_finish(result,_t("Esine siirretty taskuun.","Object moved into the pocket."))
func _pocket_building() -> void:
	var result = _call("pocket_building",[organization_id])
	if result is String and not result.is_empty():last_pocket_id = result
	_finish(result,_t("Rakennus sisältöineen siirretty taskuun.","Building and contents moved into the pocket."))
func _pocket_floor() -> void:
	var result = _call("pocket_floor",[floor_id])
	if result is String and not result.is_empty():last_pocket_id = result;floor_id = "";room_id = "";entity_id = ""
	_finish(result,_t("Kerros sisältöineen siirretty taskuun.","Floor and contents moved into the pocket."))
func _pocket_room() -> void:
	var result = _call("pocket_room",[room_id])
	if result is String and not result.is_empty():last_pocket_id = result;room_id = "";entity_id = ""
	_finish(result,_t("Työtila sisältöineen siirretty taskuun.","Workspace and contents moved into the pocket."))

func _request_delete(kind: String,id: String) -> void:
	if id.is_empty():return
	pending_delete = {"kind":kind,"id":id}
	confirmation.title = _t("Vahvista poistaminen","Confirm deletion")
	confirmation.dialog_text = _t("Poistetaanko valittu kerros tai työtila? Sen taulut ja esineet siirtyvät taskuun.","Delete the selected floor or workspace? Its boards and objects will move into the pocket.") if kind in ["floor","room"] else _t("Poistetaanko valittu esine?","Delete the selected object?")
	confirmation.ok_button_text = _t("Poista","Delete")
	confirmation.cancel_button_text = _t("Peruuta","Cancel")
	confirmation.popup_centered(Vector2i(520,170))
func _confirm_delete() -> void:
	if pending_delete.is_empty():return
	var request = pending_delete.duplicate();pending_delete.clear();confirmation.hide()
	var method = {"floor":"delete_floor","room":"delete_room","entity":"delete_entity"}.get(request.kind,"")
	var result = _call(method,[request.id])
	if result:
		if request.kind == "floor":floor_id = "";room_id = "";entity_id = ""
		elif request.kind == "room":room_id = "";entity_id = ""
		else:entity_id = ""
	_finish(result,_t("Poistettu.","Deleted."))

func _open_person() -> void:
	if _state.entities.get(entity_id,{}).get("kind","") == "person":person_selected.emit(entity_id)
func _placement_position() -> Vector3:
	if _uses_player_position():return _vector(context.player_position)
	if not room_id.is_empty() and _state.rooms.has(room_id):return _vector(_state.rooms[room_id].get("position",Vector3.ZERO))
	return _vector(_state.organizations.get(organization_id,{}).get("position",Vector3.ZERO))+Vector3(0,0,18)
func _uses_player_position() -> bool:
	return context.has("player_position") and str(context.get("room_id","")) == room_id and str(context.get("organization_id",organization_id)) == organization_id
func _vector(value) -> Vector3:
	if value is Vector3:return value
	if value is Dictionary:return Vector3(float(value.get("x",0)),float(value.get("y",0)),float(value.get("z",0)))
	return Vector3.ZERO
func _is_pocketed(id: String) -> bool:
	if id.is_empty():return false
	return bool(_state.call("entity_is_pocketed",id)) if _state.has_method("entity_is_pocketed") else bool(_state.entities.get(id,{}).get("in_pocket",false))
func _call(method: String,args: Array):
	if not _state.has_method(method):
		status_label.text = _t("Toiminto ei ole käytettävissä: ","Action unavailable: ")+method
		return false
	return _state.callv(method,args)
func _finish(result,success_message: String) -> void:
	var ok = result == true if result is bool else result is String and not result.is_empty()
	status_label.modulate = Color("8bd2b9") if ok else Color("e6a29f")
	status_label.text = success_message if ok else str(_state.get("last_error"))
	if not ok and status_label.text.is_empty():status_label.text = _t("Muutosta ei voitu tallentaa.","Could not save the change.")
	if ok:changed.emit()
	refresh()
func _queue_refresh() -> void:
	if not _refresh_queued:_refresh_queued = true;call_deferred("refresh")
func _fill_picker(picker: OptionButton,records: Array,selected: String) -> void:
	picker.clear()
	for record in records:
		var name = _state.localize(record.get("name",record.get("id","")))
		if record.get("in_pocket",false):name += _t(" (taskussa)"," (in pocket)")
		picker.add_item(name)
		picker.set_item_metadata(picker.item_count-1,str(record.get("id","")))
		if str(record.get("id","")) == selected:picker.select(picker.item_count-1)
	picker.disabled = picker.item_count == 0
func _selected_id(picker: OptionButton) -> String:
	return str(picker.get_item_metadata(picker.selected)) if picker.selected >= 0 and picker.selected < picker.item_count else ""
func _record_name(collection: String,id: String) -> String:
	var records = _state.get(collection)
	return _state.localize(records[id].get("name",id)) if records is Dictionary and records.has(id) else ""
func _template_label(key: String) -> String:
	if key == "person":return _t("Henkilö","Person")
	return _t(_templates[key][0],_templates[key][1]) if _templates.has(key) else key
func _name_or_default(value: String,fi: String,en: String) -> String:
	return value.strip_edges() if not value.strip_edges().is_empty() else _t(fi,en)
func _picker() -> OptionButton:
	var picker = OptionButton.new();picker.custom_minimum_size.y = 39
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return picker
func _text_input(key: String,fi: String,en: String) -> LineEdit:
	var field = LineEdit.new();field.custom_minimum_size.y = 39
	field.placeholder_text = _t(fi,en);field.set_meta("i18n",[fi,en]);field.set_meta("spatial_field",key)
	_labels[key] = field;return field
func _label(key: String,fi: String,en: String,font_size: int) -> Label:
	var label = Label.new();label.text = _t(fi,en);label.set_meta("i18n",[fi,en])
	label.add_theme_font_size_override("font_size",font_size);_labels[key] = label;return label
func _button(key: String,fi: String,en: String,callback: Callable) -> Button:
	var button = Button.new();button.text = _t(fi,en);button.custom_minimum_size.y = 36
	button.set_meta("i18n",[fi,en]);button.pressed.connect(callback)
	_action_buttons[key] = button;return button
func _relabel() -> void:
	for control in _labels.values():
		var text = control.get_meta("i18n")
		if control is LineEdit:control.placeholder_text = _t(text[0],text[1])
		else:control.text = _t(text[0],text[1])
	for button in _action_buttons.values():
		var text = button.get_meta("i18n");button.text = _t(text[0],text[1])
func _t(fi: String,en: String) -> String:
	return fi if _state.language == "fi" else en
