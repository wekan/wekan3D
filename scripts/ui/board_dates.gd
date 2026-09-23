extends RefCounted
## Shared, read-only date facts for Calendar, Gantt and Reports.
const SCHEDULE_FIELDS = ["receivedAt", "startAt", "dueAt", "endAt"]
const DATE_FIELDS = {
	"receivedAt": {"fi":"Vastaanotettu", "en":"Received", "color":"719ddd"},
	"startAt": {"fi":"Aloitus", "en":"Start", "color":"54bea2"},
	"dueAt": {"fi":"Määräaika", "en":"Due", "color":"e8b467"},
	"endAt": {"fi":"Päättyminen", "en":"End", "color":"ba94d6"},
	"createdAt": {"fi":"Luotu", "en":"Created", "color":"91a8b7"},
	"modifiedAt": {"fi":"Muokattu", "en":"Modified", "color":"91a8b7"},
	"dateLastActivity": {"fi":"Viimeisin tapahtuma", "en":"Last activity", "color":"91a8b7"},
	"archivedAt": {"fi":"Arkistoitu", "en":"Archived", "color":"a69a8b"},
	"deletedAt": {"fi":"Poistettu", "en":"Deleted", "color":"db8181"},
	"vote.end": {"fi":"Äänestys päättyy", "en":"Voting ends", "color":"d693bc"},
	"poker.end": {"fi":"Pokeri päättyy", "en":"Poker ends", "color":"bd99db"},
}
const MONTHS = {
	"fi":["Tammikuu","Helmikuu","Maaliskuu","Huhtikuu","Toukokuu","Kesäkuu","Heinäkuu","Elokuu","Syyskuu","Lokakuu","Marraskuu","Joulukuu"],
	"en":["January","February","March","April","May","June","July","August","September","October","November","December"],
}

static func parse_date(value) -> Dictionary:
	if not value is String or value.length() < 10:
		return {}
	var text = value.left(10)
	if text[4] != "-" or text[7] != "-":
		return {}
	var parts = text.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	var year = int(parts[0]); var month = int(parts[1]); var day = int(parts[2])
	if year < 1 or year > 9999 or month < 1 or month > 12 or day < 1 or day > days_in_month(year, month):
		return {}
	return {"year":year,"month":month,"day":day,"key":"%04d-%02d-%02d" % [year,month,day],"number":day_number(year,month,day)}

static func days_in_month(year: int, month: int) -> int:
	if month < 1 or month > 12:
		return 0
	var leap = year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
	return [31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31][month-1]

static func day_number(year: int, month: int, day: int) -> int:
	return int(floor(float(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":12,"minute":0,"second":0})) / 86400.0))

static func date_from_day(number: int) -> Dictionary:
	var result = Time.get_datetime_dict_from_unix_time(number * 86400)
	result["key"] = "%04d-%02d-%02d" % [result.year,result.month,result.day]
	result["number"] = number
	return result

static func month_grid(year: int, month: int) -> Array:
	var first = day_number(year,month,1)
	var first_date = date_from_day(first)
	var start = first - (int(first_date.weekday) + 6) % 7
	var result: Array = []
	for offset in range(42):
		result.append(date_from_day(start+offset))
	return result

static func shift_month(year: int, month: int, delta: int) -> Vector2i:
	var absolute = clampi(year * 12 + month - 1 + delta, 12, 9999*12+11)
	return Vector2i(int(floor(float(absolute)/12.0)),absolute%12+1)

static func today() -> Dictionary:
	var now = Time.get_date_dict_from_system(true)
	return parse_date("%04d-%02d-%02d" % [now.year,now.month,now.day])

static func month_title(year: int, month: int, locale: String) -> String:
	return "%s %d" % [MONTHS.get(locale,MONTHS.en)[month-1],year]

static func snapshot(state: Node, board_id: String) -> Dictionary:
	var result = {"board_id":board_id,"title":"","cards":[],"lanes":[],"lists":[],"total_cards":0,"scheduled":0,"past_due":0,"undated":[]}
	if not state.boards.has(board_id):
		return result
	var board: Dictionary = state.boards[board_id]
	result.title = state.localize(board.get("title",""))
	var lanes: Array = board.get("swimlanes",[{"id":"","title":state.tr_key("swimlane"),"lists":board.get("lists",[]),"cards":board.get("cards",[])}])
	var seen: Dictionary = {}
	var current_day = today().number
	for lane_index in range(lanes.size()):
		var lane: Dictionary = lanes[lane_index]
		var lane_name = state.localize(lane.get("title",""))
		var lane_row = {"index":lane_index,"title":lane_name,"count":0}
		var names: Array = lane.get("lists",[])
		var columns: Array = lane.get("cards",[])
		for column in range(names.size()):
			var list_name = state.localize(names[column])
			var list_row = {"lane":lane_index,"index":column,"lane_title":lane_name,"title":list_name,"count":0}
			var ids: Array = columns[column] if column < columns.size() else []
			for value in ids:
				var id = str(value)
				if seen.has(id) or not state.cards.has(id):
					continue
				seen[id] = true
				var document: Dictionary = state.get_card_details(id)
				var dates: Dictionary = {}
				for field in DATE_FIELDS:
					var parsed = parse_date(_read(document,field))
					if not parsed.is_empty():
						dates[field] = parsed
				var title = str(document.get("title",""))
				if title.is_empty():
					title = id
				var record = {"card_id":id,"title":title,"dates":dates,"lane":lane_index,"list":column,"lane_title":lane_name,"list_title":list_name}
				result.cards.append(record)
				lane_row.count += 1; list_row.count += 1
				var scheduled = false
				for field in SCHEDULE_FIELDS:
					scheduled = scheduled or dates.has(field)
				if scheduled:
					result.scheduled += 1
				else:
					result.undated.append(record)
				if dates.has("dueAt") and int(dates.dueAt.number) < current_day:
					result.past_due += 1
			result.lists.append(list_row)
		result.lanes.append(lane_row)
	result.total_cards = result.cards.size()
	return result

static func events(snapshot_data: Dictionary, selected_fields: Array = SCHEDULE_FIELDS) -> Dictionary:
	var by_day: Dictionary = {}
	var undated: Array = []
	for card in snapshot_data.get("cards",[]):
		var has_date = false
		for field in selected_fields:
			if not card.dates.has(field):
				continue
			has_date = true
			var date: Dictionary = card.dates[field]
			if not by_day.has(date.key):
				by_day[date.key] = []
			by_day[date.key].append({"card_id":card.card_id,"title":card.title,"field":field,"date":date.key,"lane_title":card.lane_title,"list_title":card.list_title})
		if not has_date:
			undated.append(card)
	return {"by_day":by_day,"undated":undated}

static func gantt_interval(card: Dictionary) -> Dictionary:
	var dates: Dictionary = card.get("dates",{})
	var markers: Array = []
	for field in SCHEDULE_FIELDS:
		if dates.has(field):
			markers.append({"field":field,"number":dates[field].number,"date":dates[field].key})
	var result = {"markers":markers,"has_bar":false,"reversed":false}
	if dates.has("startAt") and (dates.has("endAt") or dates.has("dueAt")):
		var end_field = "endAt" if dates.has("endAt") else "dueAt"
		result["start"] = int(dates.startAt.number)
		result["end"] = int(dates[end_field].number)
		result["end_field"] = end_field
		result["has_bar"] = true
		result["reversed"] = result.end < result.start
	return result

static func _read(document: Dictionary, path: String):
	var value = document
	for key in path.split("."):
		if not value is Dictionary or not value.has(key):
			return null
		value = value[key]
	return value
