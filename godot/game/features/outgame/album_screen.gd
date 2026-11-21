extends VBoxContainer
## 도감(SCR-009). 위에 모은 범주 수와 전체 수, 다음 달성 보상까지 남은 수. 대분류별 묶음 아래 범주 칸이 4열로 놓인다.
## 모은 범주는 대표 아이콘과 이름, 못 모은 범주는 물음표 칸이다. 범주를 누르면 본 카드가 채워진 상세가 열린다(못 본 카드는 윤곽만).
## 목록은 칸 위를 밀어도 스크롤된다(칸은 입력을 목록에 넘긴다).

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const COLUMNS := 4
const GAP := 8
const CELL_HEIGHT := 92.0
const ICON := 40.0
const MUTED := Color("8a8db5")
## 대분류 이름(콘텐츠의 domain).
const DOMAINS := {
	"animal": ["Animals", "동물"], "food": ["Food", "음식"], "object": ["Things", "물건"], "fun": ["Fun", "놀이"],
	"sky": ["Sky & Weather", "하늘과 날씨"], "symbol": ["Signs", "기호"], "transport": ["Transport", "탈것"],
	"wear": ["Clothes", "입을 것"], "place": ["Places", "장소"], "tech": ["Tech", "기술"], "people": ["People", "사람"],
	"color": ["Colors", "색"], "home": ["Home", "집"], "sport": ["Sports", "운동"], "plant": ["Plants", "식물"], "music": ["Music", "음악"],
}

var host: Control
## 지금 띄운 상세 팝업(없으면 null).
var detail: Control

var _session: RefCounted
var scroll: ScrollContainer


func _ready() -> void:
	name = "album_screen"
	_session = host.session
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	add_child(_summary())
	scroll = ScrollContainer.new()
	scroll.name = "album_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var box := VBoxContainer.new()
	box.name = "groups"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(box)
	var player: RefCounted = _session.player
	if player.album_count() == 0:
		box.add_child(_empty())
	for domain: String in _domains():
		box.add_child(_domain_heading(domain))
		var grid := GridContainer.new()
		grid.name = "grid_" + domain
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", GAP)
		grid.add_theme_constant_override("v_separation", GAP)
		grid.mouse_filter = Control.MOUSE_FILTER_PASS
		box.add_child(grid)
		for category: String in _categories_of(domain):
			grid.add_child(_cell(category))


func _t(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


## 대분류(콘텐츠 순서).
func _domains() -> Array[String]:
	var found: Array[String] = []
	for category: String in _session.catalog.category_ids():
		var domain: String = _session.catalog.category_domain(category)
		if not found.has(domain):
			found.append(domain)
	return found


func _categories_of(domain: String) -> Array[String]:
	var found: Array[String] = []
	for category: String in _session.catalog.category_ids():
		if _session.catalog.category_domain(category) == domain:
			found.append(category)
	return found


func _summary() -> Control:
	var player: RefCounted = _session.player
	var total: int = _session.catalog.category_ids().size()
	var count: int = player.album_count()
	var card: PanelContainer = Ui.panel([14, 10, 14, 16])
	card.name = "album_summary"
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var line: Label = Ui.heading(_t("%d / %d categories", "모은 범주 %d / %d") % [count, total], 20)
	line.name = "album_count"
	box.add_child(line)
	var next: String
	if count >= total:
		next = _t("You collected every category!", "모든 범주를 모았어요!")
	else:
		var left: int = Economy.ALBUM_MILESTONE_STEP - count % Economy.ALBUM_MILESTONE_STEP
		next = _t("%d more for %d coins", "%d개 더 모으면 코인 %d") % [left, Economy.ALBUM_MILESTONE_REWARD]
	var hint: Label = Ui.note(next, 13, MUTED)
	hint.name = "album_next"
	box.add_child(hint)
	return card


func _empty() -> Control:
	var box := VBoxContainer.new()
	box.name = "album_empty"
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 8)
	box.add_child(Ui.note(_t("No categories collected yet", "아직 모은 범주가 없어요"), 15))
	var stage: int = _session.player.stage()
	box.add_child(Ui.button("album_start", _t("Play Stage %d", "스테이지 %d 시작") % stage, true, func() -> void: host._open("play")))
	return box


func _domain_heading(domain: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var names: Array = DOMAINS.get(domain, [domain, domain])
	var title: Label = Fonts.text(names[1] if host.language() == "ko" else names[0], Fonts.display(700), Ui.sized(16), Fonts.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var owned: int = 0
	var categories: Array[String] = _categories_of(domain)
	var collected: Array[String] = _session.player.album_categories()
	for category: String in categories:
		if collected.has(category):
			owned += 1
	row.add_child(Fonts.text("%d / %d" % [owned, categories.size()], Fonts.display(600), Ui.sized(13), MUTED))
	return row


## 범주 칸. 모은 범주는 판 그림에 대표 카드와 이름, 못 모은 범주는 물음표다.
func _cell(category: String) -> Control:
	var collected: bool = _session.player.album_categories().has(category)
	var cell := Button.new()
	cell.name = "category_" + category
	cell.focus_mode = Control.FOCUS_NONE
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.custom_minimum_size = Vector2(0, CELL_HEIGHT)
	cell.set_meta("collected", collected)
	var art: Texture2D = Art.play("card_face") if collected else Art.outgame("day_dim")
	var plate: StyleBoxTexture = Art.box(art, [20, 20, 20, 29] if collected else [12, 12, 12, 12], [4, 4, 4, 12])
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		cell.add_theme_stylebox_override(style, plate)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 3
	column.offset_right = -3
	column.offset_bottom = -9 if collected else 0
	cell.add_child(column)
	if collected:
		var seen: Array[String] = _session.player.album_items(category)
		var face: String = seen[0] if not seen.is_empty() else _session.catalog.category_members(category)[0]
		var icon: TextureRect = Ui.card_icon(_session.catalog.item_icon(face), ICON)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var label: Label = Fonts.text(_session.catalog.category_name(category, host.language()), Fonts.label(host.language()), 12, Fonts.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.add_theme_constant_override("line_spacing", -3)
		column.add_child(label)
		cell.pressed.connect(open_detail.bind(category))
	else:
		var mark: Label = Fonts.text("?", Fonts.display(700), 26, Color("b4b9d8"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(mark)
		cell.pressed.connect(func() -> void: host.show_toast(_t("Solve a board with this category to collect it", "이 범주를 판에서 묶으면 모여요")))
	cell.button_down.connect(Juice.press_punch.bind(cell, 0.95, 0.1))
	return cell


## 범주 상세 팝업: 그 범주의 카드 가운데 본 카드는 채우고, 못 본 카드는 윤곽만 그린다.
func open_detail(category: String) -> void:
	var catalog: RefCounted = _session.catalog
	var seen: Array[String] = _session.player.album_items(category)
	var members: PackedStringArray = catalog.category_members(category)
	var popup: Control = Ui.popup(catalog.category_name(category, host.language()), true, host.size.x)
	popup.name = "album_detail"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	popup.add_content(box)
	var found: int = 0
	for item: String in members:
		if seen.has(item):
			found += 1
	var line: Label = Ui.note(_t("Cards seen %d / %d", "본 카드 %d / %d") % [found, members.size()], 14)
	line.name = "seen_count"
	box.add_child(line)
	var grid := GridContainer.new()
	grid.name = "cards"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for item: String in members:
		grid.add_child(_detail_card(item, seen.has(item)))
	detail = popup
	host.show_popup(popup)
	popup.closed.connect(func() -> void:
		if detail == popup:
			detail = null)


func _detail_card(item: String, seen: bool) -> Control:
	var cell := PanelContainer.new()
	cell.name = "card_" + item
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.custom_minimum_size = Vector2(62, 80)
	cell.set_meta("seen", seen)
	var art: Texture2D = Art.play("card_face") if seen else Art.outgame("card_outline")
	cell.add_theme_stylebox_override("panel", Art.box(art, [20, 20, 20, 29] if seen else [16, 16, 16, 16], [3, 6, 3, 13] if seen else [3, 6, 3, 6]))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 2)
	cell.add_child(column)
	if seen:
		var icon: TextureRect = Ui.card_icon(_session.catalog.item_icon(item), 34.0)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
		var label: Label = Fonts.text(_session.catalog.item_name(item, host.language()), Fonts.label(host.language()), 11, Fonts.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.max_lines_visible = 2
		label.add_theme_constant_override("line_spacing", -3)
		column.add_child(label)
	return cell
