extends VBoxContainer
## 코인 상점(SCR-010). 결제는 없다. 탭 둘: 부스터(힌트 100, 되돌리기 80, 칸 추가 150과 보유 수)와 꾸미기(카드 뒷면 4종, 배경 4종).
## 꾸미기는 가진 것은 사용 버튼, 쓰는 중인 것은 체크다. 코인이 모자라면 가격이 빨갛고 누르면 모자란 수를 알린다.
## 사고 고르는 규칙은 코어의 FaShop이 맡고, 이 화면은 결과를 연출한다(코인 칩 숫자, 반짝임, 소리, 진동).

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const Look := preload("res://game/features/shared/fa_look.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Sparkle := preload("res://addons/seorilabs_game/ui_kit/particles/sparkle.tscn")

const TAB_BOOSTERS := "boosters"
const TAB_DECOR := "decor"
const BOOSTER_ART := {Economy.BOOSTER_HINT: "gift_hint", Economy.BOOSTER_UNDO: "gift_undo", Economy.BOOSTER_SLOT: "gift_slot"}
const PRICE_ROOM := 70.0
const PREVIEW := Vector2(58, 78)
const MUTED := Color("8a8db5")

var host: Control
## 보이는 탭.
var tab: String = TAB_BOOSTERS

var _session: RefCounted
var _chip: PanelContainer
var _tabs: HBoxContainer
var _list: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	name = "shop_screen"
	_session = host.session
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	_tabs = HBoxContainer.new()
	_tabs.name = "tabs"
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("separation", 0)
	top.add_child(_tabs)
	_chip = Ui.coin_chip("shop_coins", false)
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_chip.set_value(_session.player.coins(), false)
	top.add_child(_chip)
	scroll = ScrollContainer.new()
	scroll.name = "shop_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	rebuild()


func _t(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


func rebuild() -> void:
	_build_tabs()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if tab == TAB_BOOSTERS:
		for booster: String in Economy.BOOSTERS:
			_list.add_child(_booster_row(booster))
		_list.add_child(Ui.note(_t("Coins come from boards, the daily challenge, check-ins and your album. Nothing here costs real money.",
			"코인은 판, 일일 도전, 출석, 도감에서 모아요. 상점에는 결제가 없어요."), 13, MUTED))
	else:
		_list.add_child(_section(Economy.THEME_CARD_BACK, _t("Card backs", "카드 뒷면")))
		_list.add_child(_section(Economy.THEME_BACKGROUND, _t("Backgrounds", "배경")))


func _build_tabs() -> void:
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var track := PanelContainer.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.add_theme_stylebox_override("panel", Art.box(Art.outgame("tab_track"), [22, 22, 22, 22], [4, 4, 4, 4]))
	_tabs.add_child(track)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	track.add_child(row)
	for pair: Array in [[TAB_BOOSTERS, _t("Boosters", "부스터")], [TAB_DECOR, _t("Decor", "꾸미기")]]:
		var on: bool = tab == pair[0]
		var button := Button.new()
		button.name = "tab_" + pair[0]
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		var style: StyleBox = Art.box(Art.outgame("tab_on"), [20, 20, 20, 24], [8, 4, 8, 8]) if on else StyleBoxEmpty.new()
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		var label: Label = Fonts.text(pair[1], Fonts.display(700), Ui.sized(16), Color.WHITE if on else Fonts.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_bottom = -4 if on else 0
		if on:
			Fonts.shade(label, Color(0.29, 0.18, 0.72, 0.5))
		button.add_child(label)
		button.set_meta("on", on)
		button.pressed.connect(func() -> void:
			if tab != pair[0]:
				tab = pair[0]
				rebuild())
		row.add_child(button)


# ---- 부스터 ----

func _booster_row(booster: String) -> Control:
	var names: Dictionary = {
		Economy.BOOSTER_HINT: [_t("Hint", "힌트"), _t("Shows two cards that belong together.", "같은 범주의 카드 두 장을 알려 줘요.")],
		Economy.BOOSTER_UNDO: [_t("Undo", "되돌리기"), _t("Takes back your last move to a holding slot.", "마지막으로 임시 칸에 옮긴 카드를 되돌려요.")],
		Economy.BOOSTER_SLOT: [_t("Extra slot", "칸 추가"), _t("Opens a third holding slot for one board.", "한 판 동안 임시 칸을 하나 더 열어요.")],
	}
	# 위 줄: 그림, 이름과 보유 수, 가격 버튼. 아래 줄: 설명(판의 폭 전체).
	var card: PanelContainer = Ui.panel([12, 10, 12, 16])
	card.name = "row_" + booster
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 10)
	column.add_child(row)
	var art: TextureRect = Art.picture(Art.play(BOOSTER_ART[booster]), Vector2(50, 52))
	art.name = "art"
	art.custom_minimum_size = Vector2(50, 52)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(Fonts.text(names[booster][0], Fonts.display(700), Ui.sized(18), Fonts.INK))
	var owned: Label = Fonts.text(_t("You have %d", "보유 %d개") % _session.player.booster(booster), Fonts.display(600), Ui.sized(13), Color("6a46e8"))
	owned.name = "owned_" + booster
	text.add_child(owned)
	row.add_child(_price_button("buy_" + booster, Economy.price(booster), _buy_booster.bind(booster)))
	var description: Label = Fonts.text(Fonts.keep_words(names[booster][1]), Fonts.body(500), Ui.sized(13), Color("5a5a88"))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	return card


func _buy_booster(booster: String) -> void:
	var result: Dictionary = _session.shop.buy_booster(_session.player, booster)
	if not result["ok"]:
		_tell_short(int(result["short"]))
		return
	_celebrate("row_" + booster)
	rebuild()


# ---- 꾸미기 ----

func _section(kind: String, title: String) -> Control:
	var box := VBoxContainer.new()
	box.name = "section_" + kind
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 8)
	var heading: Label = Fonts.text(title, Fonts.display(700), Ui.sized(17), Fonts.INK)
	box.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(grid)
	grid.add_child(_theme_tile(kind, ""))
	for theme: Dictionary in Economy.themes(kind):
		grid.add_child(_theme_tile(kind, theme["id"]))
	return box


func _theme_tile(kind: String, id: String) -> Control:
	var status: Dictionary = _session.shop.status(_session.player, id) if not id.is_empty() else {"owned": true, "selected": _session.player.selected_theme(kind).is_empty(), "price": 0, "short": 0}
	var card: PanelContainer = Ui.panel([10, 10, 10, 16])
	card.name = "tile_" + (id if not id.is_empty() else kind + "_default")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size.y = PREVIEW.y + 12
	box.add_child(holder)
	holder.add_child(_preview(kind, id))
	var name_label: Label = Fonts.text(Look.theme_name(kind, id, host.language()), Fonts.display(700), Ui.sized(14), Fonts.INK)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	var key: String = id if not id.is_empty() else kind + "_default"
	if status["selected"]:
		var using := HBoxContainer.new()
		using.name = "using_" + key
		using.alignment = BoxContainer.ALIGNMENT_CENTER
		using.mouse_filter = Control.MOUSE_FILTER_IGNORE
		using.custom_minimum_size.y = 44
		using.add_theme_constant_override("separation", 4)
		var tick: TextureRect = Art.picture(Art.play("tick"), Vector2(24, 26))
		tick.custom_minimum_size = Vector2(24, 26)
		tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		using.add_child(tick)
		using.add_child(Fonts.text(_t("In use", "사용 중"), Fonts.display(700), Ui.sized(15), Color("2f9a4c")))
		box.add_child(using)
	elif status["owned"]:
		box.add_child(Ui.button("use_" + key, _t("Use", "사용"), false, _use.bind(kind, id), null, Vector2.ZERO, 110.0, [17, 15], 48.0))
	else:
		box.add_child(_price_button("buy_" + id, int(status["price"]), _buy_theme.bind(id)))
	return card


## 미리 보기: 카드 뒷면은 그 테마의 뒤집힌 카드, 배경은 그 테마의 그라데이션 판이다.
func _preview(kind: String, id: String) -> Control:
	if kind == Economy.THEME_CARD_BACK:
		var view: Control = CardView.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.custom_minimum_size = PREVIEW
		view.configure(PREVIEW, 30.0, host.language(), false)
		view.set_face_down(true)
		view.set_back_theme(id)
		return view
	var mask: NinePatchRect = Art.plate(Art.outgame("mask_round"), [14, 14, 14, 14])
	mask.custom_minimum_size = Vector2(100, PREVIEW.y)
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 1.0])
	gradient.colors = Look.colors(id)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = 64
	var sky := TextureRect.new()
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.add_child(sky)
	for spec: Array in [[Vector2(-10, 4), 26.0, 0.22], [Vector2(62, 40), 30.0, 0.16]]:
		var bubble: TextureRect = Art.picture(Art.play("bubble"), Vector2.ONE * spec[1] * 2.0)
		bubble.position = spec[0]
		bubble.modulate.a = spec[2]
		mask.add_child(bubble)
	return mask


func _buy_theme(id: String) -> void:
	var result: Dictionary = _session.shop.buy_theme(_session.player, id)
	if not result["ok"]:
		_tell_short(int(_session.shop.status(_session.player, id)["short"]))
		return
	host.apply_look()
	_celebrate("tile_" + id)
	rebuild()


func _use(kind: String, id: String) -> void:
	if _session.shop.select_theme(_session.player, kind, id):
		host.apply_look()
		host.audio.play("slot_unlock")
		rebuild()


# ---- 공통 ----

## 가격 버튼: 코인 아이콘과 가격. 코인이 모자라면 가격이 빨간 비활성 모양이고 눌러도 사지 않고 모자란 수를 알린다.
func _price_button(button_name: String, price: int, action: Callable) -> Button:
	var button: Button = Ui.button(button_name, _chip.format_amount(price), false, action,
		Art.skin("icon_coin"), Vector2(22, 22), PRICE_ROOM, [17, 15], 48.0)
	button.custom_minimum_size.x = 104
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _session.player.coins() < price:
		Ui.mark_unaffordable(button, host)
	return button


func _tell_short(short: int) -> void:
	host.sfx.play("error")
	host.audio.vibrate(15)
	host.show_toast(_t("%d more coins needed", "코인이 %d개 모자라요") % short, "red")


## 산 자리에 반짝임을 터뜨리고 코인 칩 숫자를 내린다.
func _celebrate(node_name: String) -> void:
	host.audio.play("coin")
	host.audio.vibrate(10)
	var target: Control = _list.find_child(node_name, true, false) as Control
	if target != null and not Juice.reduced_motion:
		var sparkle: CPUParticles2D = Sparkle.instantiate()
		sparkle.amount = 10
		sparkle.one_shot = true
		sparkle.lifetime = 0.5
		sparkle.emission_sphere_radius = 30.0
		var layer: Control = host.layers.layer("Toast")
		layer.add_child(sparkle)
		sparkle.global_position = target.get_global_rect().get_center()
		sparkle.emitting = true
		sparkle.finished.connect(sparkle.queue_free)
	_chip.set_value(_session.player.coins(), true)
