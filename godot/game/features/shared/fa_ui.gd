extends RefCounted
## 제품 화면이 함께 쓰는 캔디 팝 구성요소: 그림 판 버튼, 안내 글, 카드 아이콘, 팝업 틀, 코인 칩, 흰 판, 배지, 원형 메뉴 버튼.
## 판은 스킨 테마(theme.tres)와 제품 그림(FaArt)이 그리고, 글자는 제품 서체(FaFonts)다. 버튼 효과음은 공통 ui_sfx가 붙인다.

const PopupBase := preload("res://addons/seorilabs_game/ui_kit/popup_base.tscn")
const CurrencyChip := preload("res://addons/seorilabs_game/ui_kit/currency_chip.tscn")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")

const ICON_DIR := "res://game/assets/icons/"
const BUTTON_HEIGHT := 54.0
## 팝업 버튼 안에서 글자와 아이콘이 쓸 수 있는 폭(창의 폭에서 틀과 버튼의 안쪽 여백을 뺀 값), 둘 사이 간격, 아래 옆면의 높이.
const BUTTON_TEXT_ROOM := 234.0
const BUTTON_ICON_GAP := 8
const BUTTON_LIP := 6.0
const BUTTON_FONT_SIZES: Array[int] = [20, 18, 16]
const BUTTON_SECOND_LINE := 14.0
const PRIMARY_SHADE := Color("b85a00")
## 되돌릴 수 없는 행동(데이터 초기화): 빨간 주 버튼의 그림자, 경고 글과 설정 줄의 글자.
const DANGER_SHADE := Color("9e1f30")
const DANGER_INK := Color("d6283f")
## 스킨의 주 버튼 판과 같은 9분할 여백과 안쪽 여백(skin.json의 button_primary).
const PRIMARY_MARGINS := [26, 26, 26, 32]
const PRIMARY_CONTENT := [20, 9, 20, 13]
const POPUP_WIDTH := 318.0
const DIM := Color(0.09, 0.07, 0.3, 0.62)
const RED := Color("ff4b5c")
## 코인 칩: 판 그림은 사방에 1의 빈 테두리가 있어 보이는 높이는 32다.
const CHIP_HEIGHT := 34.0
## 흰 판(ui_panel): 9분할 여백과 안쪽 여백.
const PANEL_MARGINS := [24, 24, 24, 30]
## 둥근 메뉴 버튼(홈 아래 줄)의 원판 크기와 이름 글자 크기.
const ROUND_SIZE := 60.0
## 큰 글자 설정에서 글을 키우는 양. 공통 기반의 배율(+3)과 같고 bootstrap이 설정을 적용할 때 정한다.
const LARGE_TEXT_BONUS := 3

static var text_bonus: int = 0


## 큰 글자 설정을 따르는 글자 크기.
static func sized(value: int) -> int:
	return value + text_bonus


## 그림 판 버튼. 글자와 아이콘은 한 줄로 묶어 가운데에 두고, 주 버튼은 흰 글자에 짙은 주황 그림자다.
## 글자가 room을 넘치면 한 단계 줄이고, 그래도 넘치면 두 줄로 나누며 버튼이 높아진다(meta "needed"). primary는 한 화면에 하나만 준다.
static func button(button_name: String, text: String, primary: bool, action: Callable, icon: Texture2D = null,
		icon_size: Vector2 = Vector2.ZERO, room: float = BUTTON_TEXT_ROOM, sizes: Array[int] = BUTTON_FONT_SIZES,
		height: float = BUTTON_HEIGHT) -> Button:
	var node := Button.new()
	node.name = button_name
	node.set_meta("label", text)
	node.set_meta("needed", height)
	node.custom_minimum_size.y = height
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.focus_mode = Control.FOCUS_NONE
	if primary:
		node.theme_type_variation = &"PrimaryButton"
		node.set_meta("ui_sfx_kind", "confirm")
	node.pressed.connect(action)
	node.button_down.connect(Juice.press_punch.bind(node, 0.96, 0.1))
	if text.is_empty() and icon == null:
		return node
	var row := HBoxContainer.new()
	row.name = "row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BUTTON_ICON_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -BUTTON_LIP
	node.add_child(row)
	var left: float = room
	if icon != null:
		var picture: TextureRect = Art.picture(icon, icon_size)
		picture.name = "icon"
		picture.custom_minimum_size = picture.size
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
		left -= picture.size.x + BUTTON_ICON_GAP
	if text.is_empty():
		return node
	var font: Font = Fonts.display(700)
	var label: Label = Fonts.text(text, font, sizes[0], Color.WHITE if primary else Fonts.INK)
	label.name = "label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if primary:
		Fonts.shade(label, PRIMARY_SHADE)
	for font_size: int in sizes:
		label.add_theme_font_size_override("font_size", font_size)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= left:
			row.add_child(label)
			return node
	# 가장 작은 글자로도 한 줄에 안 들어가면 두 줄로 나눈다(한국어는 낱말 단위로).
	label.text = Fonts.keep_words(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = left
	label.add_theme_constant_override("line_spacing", -2)
	node.set_meta("needed", height + BUTTON_SECOND_LINE)
	node.custom_minimum_size.y = height + BUTTON_SECOND_LINE
	row.add_child(label)
	return node


## 버튼의 글자를 바꾼다(크기 맞춤은 다시 하지 않는다).
static func set_button_text(node: Button, text: String) -> void:
	node.set_meta("label", text)
	var label: Label = node.find_child("label", true, false) as Label
	if label != null:
		label.text = text


## 주 버튼을 되돌릴 수 없는 행동의 빨간 판으로 바꾼다(모양과 눌림은 주 버튼과 같다). 누른 뒤 막아 둔 동안에도 눌린 빨간 판이다.
static func danger(node: Button) -> void:
	node.set_meta("danger", true)
	for pair: Array in [["normal", "button_danger_normal"], ["hover", "button_danger_normal"], ["pressed", "button_danger_pressed"], ["disabled", "button_danger_pressed"]]:
		node.add_theme_stylebox_override(pair[0], Art.box(Art.outgame(pair[1]), PRIMARY_MARGINS, PRIMARY_CONTENT))
	var label: Label = node.find_child("label", true, false) as Label
	if label != null:
		Fonts.shade(label, DANGER_SHADE)


## 보상형 광고 버튼: 무엇을 얻는지와 광고 시청을 함께 적고 초록 재생 꼬리표를 붙인다.
static func ad_button(button_name: String, text: String, primary: bool, action: Callable) -> Button:
	return button(button_name, text, primary, action, Art.play("icon_ad"))


## 살 수 없는 가격: 보조 버튼의 비활성 판에 빨간 글자. 눌러서 모자란 수를 알 수 있게 버튼은 살려 둔다.
## theme_owner는 테마의 비활성 판을 읽을 컨트롤이다(트리 안의 화면).
static func mark_unaffordable(node: Button, theme_owner: Control) -> void:
	node.theme_type_variation = &""
	node.set_meta("unaffordable", true)
	node.set_meta("ui_sfx_kind", "error")
	var plate: StyleBox = theme_owner.get_theme_stylebox("disabled", "Button")
	for style: String in ["normal", "hover", "pressed"]:
		node.add_theme_stylebox_override(style, plate)
	var label: Label = node.find_child("label", true, false) as Label
	if label != null:
		label.add_theme_color_override("font_color", RED)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


## 판 위의 안내 글(본문 서체, 남보라). 한국어는 낱말 단위로만 줄을 바꾼다.
static func note(text: String, font_size: int = 15, color: Color = Fonts.INK) -> Label:
	var label: Label = Fonts.text(Fonts.keep_words(text), Fonts.body(), sized(font_size), color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## 제목 서체의 글(굵은 둥근 글자).
static func heading(text: String, font_size: int, color: Color = Fonts.INK) -> Label:
	var label: Label = Fonts.text(text, Fonts.display(700), sized(font_size), color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## 카드 그림(192px PNG). 줄여 그리므로 밉맵을 쓴다.
static func card_icon(icon_key: String, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(ICON_DIR + icon_key + ".png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## 팝업의 틀(공통 popup_base): 제목, 닫기(closable일 때만), 어두운 배경. 내용은 add_content로 넣는다.
## screen_width는 팝업을 띄울 화면의 폭이다. 화면이 좁으면 양옆을 12씩 남긴다.
static func popup(title: String, closable: bool, screen_width: float) -> Control:
	var node: Control = PopupBase.instantiate()
	node.dismiss_on_dim = closable
	node.set_title(title)
	(node.get_node("Dim") as ColorRect).color = DIM
	var frame: Control = node.get_node("Center/Frame")
	frame.custom_minimum_size.x = minf(POPUP_WIDTH, screen_width - 24.0)
	(node.get_node("Center/Frame/Body/Actions") as Control).visible = false
	var close: Button = node.get_node("Center/Frame/Body/Header/Close")
	close.visible = closable
	close.focus_mode = Control.FOCUS_NONE
	icon_only(close, Art.outgame("icon_close"))
	var heading_label: Label = node.get_node("Center/Frame/Body/Header/Title")
	heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if closable else HORIZONTAL_ALIGNMENT_CENTER
	return node


## 글자 버튼을 가운데 아이콘만 있는 버튼으로 바꾼다(머리 줄의 뒤로, 닫기).
static func icon_only(node: Button, icon: Texture2D) -> void:
	node.text = ""
	node.icon = icon
	node.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.expand_icon = false
	node.add_theme_color_override("icon_normal_color", Color.WHITE)
	node.add_theme_color_override("icon_pressed_color", Color(0.85, 0.86, 0.95))


## 코인 칩: 짙은 반투명 알약에 코인, 숫자, 초록 더하기(show_add일 때만). 더하기는 add_pressed로 알린다.
static func coin_chip(chip_name: String, show_add: bool) -> PanelContainer:
	var chip: PanelContainer = CurrencyChip.instantiate()
	chip.name = chip_name
	chip.show_add = show_add
	chip.add_theme_stylebox_override("panel", Art.box(Art.skin("ui_chip"), [22, 14, 22, 14], [0, 0, 5, 0]))
	chip.custom_minimum_size.y = CHIP_HEIGHT
	chip.set_icon(Art.skin("icon_coin"))
	var row: HBoxContainer = chip.get_node("Row")
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip_icon: TextureRect = chip.get_node("Row/Icon")
	chip_icon.custom_minimum_size = Vector2(28, 28)
	chip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value: Label = chip.get_node("Row/Value")
	value.add_theme_font_override("font", Fonts.display(600))
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_constant_override("outline_size", 0)
	var add: Button = chip.get_node("Row/Add")
	add.text = ""
	add.custom_minimum_size = Vector2(22, 24)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plus: StyleBoxTexture = Art.box(Art.play("plus_button"), [0, 0, 0, 0], [0, 0, 0, 0])
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add.add_theme_stylebox_override(style, plus)
	return chip


## 흰 판(스킨 ui_panel): 연보라 옆면이 있는 카드 모양 판. 안쪽 여백은 content(좌, 상, 우, 하)다.
static func panel(content: Array = [16, 14, 16, 18]) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", Art.box(Art.skin("ui_panel"), PANEL_MARGINS, content))
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	return node


## 빨간 동그라미 배지. 글자가 비면 점만 보인다.
static func badge(text: String = "") -> Control:
	var node: TextureRect = Art.picture(Art.play("badge"), Vector2(22, 22) if not text.is_empty() else Vector2(16, 16))
	node.name = "badge"
	if not text.is_empty():
		var label: Label = Fonts.text(text, Fonts.display(700), 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_top = -1
		node.add_child(label)
	return node


## 사각 HUD 버튼(흰 판에 남보라 옆면, 가운데 그림). 누르는 영역은 48×48이다.
static func hud_button(button_name: String, glyph: Texture2D, action: Callable) -> TextureButton:
	var node := TextureButton.new()
	node.name = button_name
	node.custom_minimum_size = Vector2(48, 48)
	node.focus_mode = Control.FOCUS_NONE
	var plate: NinePatchRect = Art.plate(Art.play("hud_button"), [16, 16, 16, 20])
	plate.name = "plate"
	plate.size = Vector2(44, 48)
	plate.position = Vector2(2, 0)
	plate.pivot_offset = Vector2(22, 22)
	node.add_child(plate)
	var picture: TextureRect = Art.picture(glyph, Vector2(24, 24))
	picture.position = Vector2(10, 10)
	plate.add_child(picture)
	node.button_down.connect(func() -> void: Juice.press_punch(plate, 0.92, 0.1))
	node.pressed.connect(action)
	return node


## 둥근 메뉴 버튼(홈 아래 줄): 색 원판 그림과 그 아래 이름. 배지는 원판 오른쪽 위에 붙인다.
static func round_button(button_name: String, disc: Texture2D, caption: String, action: Callable) -> TextureButton:
	var node := TextureButton.new()
	node.name = button_name
	node.custom_minimum_size = Vector2(84, ROUND_SIZE + 30)
	node.focus_mode = Control.FOCUS_NONE
	var art: TextureRect = Art.picture(disc, Vector2(ROUND_SIZE, ROUND_SIZE * 60.0 / 58.0))
	art.name = "disc"
	art.position = Vector2((84 - ROUND_SIZE) / 2.0, 0)
	art.pivot_offset = art.size / 2.0
	node.add_child(art)
	var label: Label = Fonts.text(caption, Fonts.display(700), 14)
	label.name = "caption"
	Fonts.shade(label)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-8, ROUND_SIZE + 6)
	label.size = Vector2(100, 22)
	node.add_child(label)
	node.button_down.connect(func() -> void: Juice.press_punch(art, 0.92, 0.1))
	node.pressed.connect(action)
	return node
