extends Control
## A one-shot, high-contrast rendering of the real board model.
## Grid geometry is shared with Board3D so picking matches the visible cards.

const CANVAS_SIZE = Vector2(1280.0, 736.0)
const OUTER_MARGIN = 24.0
const COLUMN_GAP = 14.0
const COLUMN_WIDTH = (1280.0 - OUTER_MARGIN * 2.0 - COLUMN_GAP * 3.0) / 4.0
const COLUMN_TOP = 152.0
const COLUMN_BOTTOM = 704.0
const CARD_TOP = 196.0
const CARD_HEIGHT = 110.0
const CARD_GAP = 10.0
const VISIBLE_ROWS = 4

const INK = Color("203748")
const PAPER = Color("eef2ef")
const MUTED = Color("526978")
const ACCENTS = [Color("438a97"), Color("c59535"), Color("7276af"), Color("40896e")]

var board_title = ""
var lane_title = ""
var list_titles: Array = []
var column_cards: Array = [[], [], [], []]
var column_counts: Array = [0, 0, 0, 0]
var lane_count = 1
var list_count = 4
var total_lists = 4
var total_cards = 16
var empty_slot = false
var language = "fi"
var _font: Font
var _card_style: StyleBoxFlat
var _column_style: StyleBoxFlat


static func column_rect(column: int) -> Rect2:
	return Rect2(OUTER_MARGIN + column * (COLUMN_WIDTH + COLUMN_GAP), COLUMN_TOP, COLUMN_WIDTH, COLUMN_BOTTOM - COLUMN_TOP)


static func card_rect(column: int, row: int) -> Rect2:
	var column_box = column_rect(column)
	return Rect2(column_box.position.x + 6.0, CARD_TOP + row * (CARD_HEIGHT + CARD_GAP), COLUMN_WIDTH - 12.0, CARD_HEIGHT)


static func calendar_rect() -> Rect2:
	return Rect2(1034, 46, 220, 42)


func _ready() -> void:
	size = CANVAS_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_card_style = _style(Color("ffffff"), 7, Color("c8d3d4"))
	_card_style.shadow_color = Color(0.08, 0.18, 0.23, 0.13)
	_card_style.shadow_size = 2
	_card_style.shadow_offset = Vector2(0, 2)
	_column_style = _style(Color("e0e7e4"), 9)


func set_data(data: Dictionary) -> void:
	board_title = str(data.get("title", ""))
	lane_title = str(data.get("lane", ""))
	list_titles = data.get("lists", [])
	column_cards = data.get("cards", [[], [], [], []])
	column_counts = data.get("counts", [0, 0, 0, 0])
	lane_count = int(data.get("lane_count", 1))
	list_count = int(data.get("list_count", list_titles.size()))
	total_lists = int(data.get("total_lists", list_count))
	total_cards = int(data.get("total_cards", 0))
	empty_slot = bool(data.get("empty_slot", false))
	language = str(data.get("language", "fi"))
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), PAPER)
	draw_rect(Rect2(0, 0, CANVAS_SIZE.x, 103), INK)
	draw_rect(Rect2(0, 101, CANVAS_SIZE.x, 4), Color("42ae9a"))
	var eyebrow = "KANBAN  /  TYÖNKULKU" if language == "fi" else "KANBAN  /  WORKFLOW"
	_draw_text(eyebrow, Vector2(28, 28), 880, 14, Color("a9ceca"))
	var total_label = "%d KORTTIA" % total_cards if language == "fi" else "%d CARDS" % total_cards
	_draw_text(total_label, Vector2(1044, 28), 208, 14, Color("a9ceca"), HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_text(board_title, Vector2(26, 79), 980 if not empty_slot else 1228, 37, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 24)
	if not empty_slot:
		var calendar = calendar_rect()
		draw_style_box(_style(Color("355866"), 7), calendar)
		draw_rect(Rect2(calendar.position + Vector2(13, 12), Vector2(20, 19)), Color("b0d9d0"), false, 2)
		draw_line(calendar.position + Vector2(13, 18), calendar.position + Vector2(33, 18), Color("b0d9d0"), 2)
		_draw_text("Kalenteri" if language == "fi" else "Calendar", calendar.position + Vector2(46, 28), 158, 19, Color("ecf8f3"))
	draw_circle(Vector2(35, 130), 5.5, Color("208570"))
	var lane_label = lane_title
	if lane_count == 0:
		lane_label = "Ei uimaratoja" if language == "fi" else "No swimlanes"
	_draw_text(lane_label, Vector2(50, 137), 730, 21, INK)
	var board_hint = "Uimarata %d/%d · Listat %d/%d" % [mini(lane_count, 1), lane_count, mini(list_count, 4), list_count] if language == "fi" else "Lane %d/%d · Lists %d/%d" % [mini(lane_count, 1), lane_count, mini(list_count, 4), list_count]
	_draw_text(board_hint, Vector2(794, 135), 460, 15, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	for column in range(mini(4, list_titles.size())):
		_draw_column(column)
	if list_titles.is_empty():
		var empty_title = "Tälle taululle mahtuu uusia ideoita." if language == "fi" else "There is room here for new ideas."
		var empty_hint = "Avaa taulu: lisää uimarata, lista ja kortit." if language == "fi" else "Open the board to add a swimlane, list and cards."
		if empty_slot:
			empty_title = "+  Tuo taulu tähän taskusta" if language == "fi" else "+  Place a board from your pocket"
			empty_hint = "Taulu sisältöineen siirtyy tähän huoneeseen." if language == "fi" else "The board and all of its contents move to this room."
		_draw_text(empty_title, Vector2(75, 360), 1130, 32, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_draw_text(empty_hint, Vector2(75, 411), 1130, 24, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var hint = "E / A  •  Avaa ja muokkaa taulua     |     Vedä kortti taululle tai taskuun" if language == "fi" else "E / A  •  Open and edit board     |     Drag a card to a board or your pocket"
	if lane_count > 1 or list_count > 4:
		hint = "E / A  •  Näytä kaikki: %d uimarataa, %d listaa     |     Avaa ja muokkaa" % [lane_count, total_lists] if language == "fi" else "E / A  •  View all: %d swimlanes, %d lists     |     Open and edit" % [lane_count, total_lists]
	if empty_slot:
		hint = "I / Y  •  Avaa tasku ja valitse taulu sijoitettavaksi" if language == "fi" else "I / Y  •  Open pocket and choose a board to place"
	_draw_text(hint, Vector2(26, 727), 1228, 16, MUTED)


func _draw_column(column: int) -> void:
	var box = column_rect(column)
	draw_style_box(_column_style, box)
	draw_circle(Vector2(box.position.x + 15, 176), 5, ACCENTS[column])
	var title = str(list_titles[column]) if column < list_titles.size() else ""
	_draw_text(title, Vector2(box.position.x + 28, 183), box.size.x - 79, 21, INK, HORIZONTAL_ALIGNMENT_LEFT, 16)
	_draw_text(str(column_counts[column]), Vector2(box.end.x - 45, 182), 31, 17, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	var cards: Array = column_cards[column] if column < column_cards.size() else []
	for row in range(VISIBLE_ROWS):
		var rect = card_rect(column, row)
		if row < cards.size():
			_draw_card(rect, cards[row], ACCENTS[column])
		else:
			# An understated, visibly empty drop target also works for an empty list.
			draw_style_box(_style(Color(0.91, 0.94, 0.92, 0.8), 7, Color("ccd9d4")), rect)
			if row == 0:
				var empty_text = "Pudota kortti tähän" if language == "fi" else "Drop a card here"
				_draw_text(empty_text, rect.position + Vector2(15, 60), rect.size.x - 30, 18, MUTED)
	var hidden = maxi(0, int(column_counts[column]) - VISIBLE_ROWS)
	var footer = ""
	if hidden > 0:
		footer = "+%d lisää · avaa taulu" % hidden if language == "fi" else "+%d more · open board" % hidden
	else:
		footer = "Vedä ja pudota" if language == "fi" else "Drag & drop"
	_draw_text(footer, Vector2(box.position.x + 12, 694), box.size.x - 24, 15, MUTED)


func _draw_card(rect: Rect2, lines: Array, accent: Color) -> void:
	draw_style_box(_card_style, rect)
	draw_rect(Rect2(rect.position + Vector2(0, 8), Vector2(3, rect.size.y - 16)), accent)
	for line_index in range(4):
		var line = str(lines[line_index]) if line_index < lines.size() else ""
		var color = INK if line_index == 0 else Color("3b5261")
		_draw_text(line, rect.position + Vector2(14, 25 + line_index * 24), rect.size.x - 27, 19 if line_index == 0 else 18, color, HORIZONTAL_ALIGNMENT_LEFT, 14)


func _draw_text(value: String, baseline: Vector2, width: float, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, minimum_size: int = 14) -> void:
	var fitted = font_size
	while fitted > minimum_size and _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		fitted -= 1
	var text = value
	if _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
		while text.length() > 0 and _font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > width:
			text = text.left(text.length() - 1)
		text += "…"
	draw_string(_font, baseline, text, alignment, width, fitted, color)


func _style(background: Color, radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	if border.a > 0.0:
		style.set_border_width_all(1)
		style.border_color = border
	return style
