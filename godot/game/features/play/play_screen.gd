extends Control
## 플레이 화면(SCR-003). 카드를 살피고, 네 장을 골라 묶고, 열 맨 앞 카드를 임시 칸으로 옮긴다.
## 규칙은 모두 코어(FaBoard와 유스케이스)가 판정하고, 이 화면은 선택 상태와 연출, 팝업을 맡는다.
## 구역은 위에서 아래로 상단 줄, 메달 줄, 더미 4열, 받침(임시 칸 줄과 예비 카드 줄), 아래 버튼 줄이다(play_layout.gd).

## 홈으로 나간다. detail의 gift는 튜토리얼을 마치고 받은 시작 선물(없으면 빈 값)이다.
signal exit_requested(detail: Dictionary)
## 코인 칩의 더하기를 눌렀다(상점).
signal shop_requested

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Layout := preload("res://game/features/play/play_layout.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const SlotCell := preload("res://game/features/play/slot_cell.gd")
const MedalView := preload("res://game/features/play/medal_view.gd")
const BoosterButton := preload("res://game/features/play/booster_button.gd")
const Popups := preload("res://game/features/play/play_popups.gd")
const Guide := preload("res://game/features/play/tutorial_guide.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")
const UseBooster := preload("res://game/core/use_cases/fa_use_booster.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const CurrencyChip := preload("res://addons/seorilabs_game/ui_kit/currency_chip.tscn")
const Sparkle := preload("res://addons/seorilabs_game/ui_kit/particles/sparkle.tscn")

enum Phase { DEALING, PLAYING, ENDED }

const TOAST_INFO := "info"
const TOAST_NEAR := "yellow"
const TOAST_ALERT := "red"
const TOAST_SECONDS := 2.0
const TOAST_MARGINS := [18, 18, 18, 22]
const HEARTS := 4
const HEART_SIZE := 19.0
const HEART_PITCH := 23.0
const HEART_SPAN := 87.0
const PAUSE_VISUAL := Vector2(40, 44)
const PAUSE_TOUCH := 48.0
const RIBBON_HEIGHT := 31.0
const RIBBON_PAD := 14.0
const RIBBON_MARGINS := [18, 15, 18, 19]
## 코인 칩의 판 그림은 사방에 1의 빈 테두리가 있다. 보이는 높이는 32다.
const CHIP_HEIGHT := 34.0
const CHIP_EDGE := 1.0
const SHADOW_MARGINS := [34, 34, 34, 34]
const TRAY_MARGINS := [24, 24, 24, 24]
const PILL_MARGINS := [11, 10, 11, 10]
## 카드가 메달로 날아가는 시간과 장 사이 간격, 임시 칸으로 옮기는 시간, 배치 연출의 장 사이 간격.
const FLY_SECONDS := 0.32
const FLY_STAGGER := 0.04
const HOLD_SECONDS := 0.18
const DEAL_STAGGER := 0.03
const DEAL_SECONDS := 0.22
const CLEAR_SECONDS := 1.2
const CONFETTI := 40
const CONFETTI_COLORS := ["ffc61a", "ff6a5c", "48d46a", "35b6f5", "9a6bff", "ffffff"]
const GUIDE_DIM_Z := 50
const GUIDE_FOCUS_Z := 60

# ---- 띄우는 쪽이 넣는 것 ----
## 공통 흐름(문구의 언어, 층, 설정, 공통 효과음).
var host: Control
## 실행 상태와 유스케이스(FaSession).
var session: RefCounted
## 제품 효과음과 진동(fa_audio.gd).
var audio: Node
## 노치와 제스처 바만큼 비울 높이(위, 아래). 논리 픽셀이다.
var insets: Vector2 = Vector2.ZERO
## 코인 칩의 더하기를 보일지. 상점 화면이 붙으면 켠다.
var shop_available: bool = false

# ---- 판 ----
var board: Board
var mode: String = ""
var stage_number: int = 0
var date: String = ""
var seconds: float = 0.0
var phase: Phase = Phase.DEALING
## 연출 중이라 입력을 받지 않는다.
var busy: bool = true
## 고른 카드(최대 4장, 고른 순서).
var selection: Array[String] = []
var popup: Control
var popup_kind: String = ""
## 지금까지 띄운 토스트의 문구(순서대로).
var toasts: Array[String] = []
## 튜토리얼 안내의 단계. 안내가 없으면 "".
var guide_step: String = ""
## 둘 수는 있지만 지금 칸 수로는 풀 수 없는 상태를 알렸는지.
var dead_end: bool = false
## 막힘 창을 닫고 판을 살펴보는 중인지.
var stuck_idle: bool = false
var ad_showing: bool = false
## 끝낸 판의 정산 결과(FaFinishRound)와, 결과 창의 연출이 끝났는지.
var result: Dictionary = {}
var result_settled: bool = false

var pause_button: TextureButton
var coin_chip: PanelContainer
var submit_button: Button
var hint_button: BoosterButton
var undo_button: BoosterButton

var _layout: Dictionary = {}
var _stage: Control
var _board_layer: Control
var _cells_layer: Control
var _cards_layer: Control
var _hud_layer: Control
var _fx_layer: Control
var _dim: ColorRect
var _tray: NinePatchRect
var _hold_label: Label
var _reserve_label: Label
var _lines: Array[ColorRect] = []
var _ribbon: NinePatchRect
var _ribbon_small: Label
var _ribbon_big: Label
var _hearts: Array[TextureRect] = []
var _submit_label: Label
var _submit_count: Label
var _submit_shadow: NinePatchRect
var _medals: Array[MedalView] = []
var _hold_cells: Array[SlotCell] = []
var _reserve_cells: Array[SlotCell] = []
## 열린 카드의 보기(card id → CardView)와, 열마다 뒤에서 앞 순서로 놓인 보기.
var _views: Dictionary = {}
var _columns: Array = []
var _hinted: Array[String] = []
var _toast: Control
var _popups: Popups
var _guide: Guide
var _reported_seconds: int = 0
var _drag_grab: Vector2 = Vector2.ZERO
var _dragging: bool = false
## 광고를 쓸 수 있는지는 시간이 지나며 바뀐다(간격, 광고 불러오기). 잠긴 칸의 꼬리표를 이 간격(초)으로 다시 맞춘다.
const OFFER_REFRESH := 1.0
var _offer_clock: float = 0.0
var _round_token: int = 0

signal _ad_finished


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = $Stage
	_popups = Popups.new(self)
	_guide = Guide.new(self)
	_build_static()
	resized.connect(_on_resized)


## 화면 크기가 바뀌면 자리를 다시 잡는다. 두는 중이면 카드까지 새 크기로 다시 놓고 선택과 힌트 표시는 그대로 둔다.
func _on_resized() -> void:
	if board == null or not idle() or _dragging:
		_relayout()
		return
	_rebuild()
	for card: String in selection:
		(_views[card] as CardView).set_selected(true, false)
	for card: String in _hinted:
		(_views[card] as CardView).set_hinted(true)


## 판을 띄운다. round는 FaSession.open_round의 결과다.
func begin(round: Dictionary) -> void:
	_round_token += 1
	board = round["board"]
	mode = round["mode"]
	stage_number = round["stage"]
	date = round["date"]
	seconds = float(round["seconds"])
	_reported_seconds = int(seconds)
	selection.clear()
	_hinted.clear()
	dead_end = false
	stuck_idle = false
	result = {}
	result_settled = false
	phase = Phase.DEALING
	busy = true
	_rebuild()
	if board.is_won():
		# 정산 직전에 꺼진 판: 연출 없이 바로 정산한다.
		_set_cards_visible(true)
		_win()
		return
	await _deal(not round["resumed"])
	if not is_inside_tree():
		return
	phase = Phase.PLAYING
	busy = false
	_refresh()
	if board.is_failed():
		_fail()
	elif board.is_stuck():
		_open_stuck()
	else:
		_check_dead_end(false)


## 연출과 팝업, 광고가 없어 입력을 받는 상태인지.
func idle() -> bool:
	return phase == Phase.PLAYING and not busy and popup == null and not ad_showing


## 판을 두는 중인지(배치 연출과 끝난 뒤가 아닌지).
func playing() -> bool:
	return phase == Phase.PLAYING


func player() -> RefCounted:
	return session.player


func tr_text(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


func language() -> String:
	return host.language()


## 열린 카드의 보기. 없으면 null.
func card_view(card: String) -> CardView:
	return _views.get(card)


func hold_cell(index: int) -> SlotCell:
	return _hold_cells[index] if index < _hold_cells.size() else null


func hold_cell_count() -> int:
	return _hold_cells.size()


func reserve_cell(index: int) -> SlotCell:
	return _reserve_cells[index] if index < _reserve_cells.size() else null


func medal(index: int) -> MedalView:
	return _medals[index] if index < _medals.size() else null


func stage_scale() -> float:
	return float(_layout.get("scale", 1.0))


func hearts_left() -> int:
	var left: int = 0
	for index: int in _hearts.size():
		if _hearts[index].get_meta("full", false):
			left += 1
	return left


func hinted_cards() -> Array[String]:
	return _hinted.duplicate()


func guide_targets() -> Array:
	return _guide.targets()


func popup_button(button_name: String) -> Button:
	return popup.find_child(button_name, true, false) as Button if popup != null else null


func popup_close() -> Button:
	return popup.get_node("Center/Frame/Body/Header/Close") as Button if popup != null else null


## 실패 창에 펼쳐 보인 남은 묶음의 범주(판의 순서).
func revealed_groups() -> Array:
	return _popups.revealed.duplicate()


## 이름으로 화면의 문구를 읽는다(여정이 언어를 확인할 때).
func text_of(key: String) -> String:
	match key:
		"submit":
			return _submit_label.text
		"hint":
			return hint_button.label_text()
		"undo":
			return undo_button.label_text()
		"hold_label":
			return _hold_label.text
		"reserve_label":
			return _reserve_label.text
		"stage":
			return (_ribbon_small.text + " " + _ribbon_big.text).strip_edges()
	var button: Button = popup_button(key)
	return str(button.get_meta("label", button.text)) if button != null else ""


## 시스템 뒤로 가기: 열린 창을 닫고, 없으면 일시정지를 연다.
func back_pressed() -> void:
	if ad_showing:
		return
	if popup != null:
		if popup_kind in ["pause", "stuck", "booster"] and popup.state == "open":
			popup.close()
	elif idle():
		_open_pause()


## 앱이 뒤로 갈 때 지금 판을 저장한다.
func save_now() -> void:
	if phase == Phase.PLAYING and board != null and player().has_run():
		_checkpoint()


func _process(delta: float) -> void:
	if phase == Phase.PLAYING and popup == null and not ad_showing:
		seconds += delta
	_offer_clock += delta
	if _offer_clock >= OFFER_REFRESH:
		_offer_clock = 0.0
		if idle() and not _dragging:
			_refresh_cells()


# =====================================================================
# 화면 구성
# =====================================================================

func _build_static() -> void:
	_board_layer = _layer("Board")
	_tray = Art.plate(Art.play("tray"), TRAY_MARGINS)
	_board_layer.add_child(_tray)
	_hold_label = _row_label()
	_reserve_label = _row_label()
	for index: int in 2:
		var line := ColorRect.new()
		line.color = Color(1, 1, 1, 0.4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board_layer.add_child(line)
		_lines.append(line)
	_cells_layer = _layer("Cells")
	_hud_layer = _layer("Hud")
	_cards_layer = _layer("Cards")
	_dim = ColorRect.new()
	_dim.name = "GuideDim"
	_dim.color = Color(0.09, 0.07, 0.3, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.z_index = GUIDE_DIM_Z
	_dim.visible = false
	_stage.add_child(_dim)
	_fx_layer = _layer("Fx")
	_fx_layer.z_index = CardView.MOVE_Z + 10
	_build_hud()
	_build_actions()


func _layer(layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(layer)
	return layer


func _row_label() -> Label:
	var label: Label = Fonts.text("", Fonts.display(600), 12)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_layer.add_child(label)
	return label


func _build_hud() -> void:
	pause_button = TextureButton.new()
	pause_button.name = "pause"
	pause_button.custom_minimum_size = Vector2.ONE * PAUSE_TOUCH
	pause_button.size = Vector2.ONE * PAUSE_TOUCH
	var plate: NinePatchRect = Art.plate(Art.play("hud_button"), [16, 16, 16, 20])
	plate.size = PAUSE_VISUAL
	plate.position = Vector2((PAUSE_TOUCH - PAUSE_VISUAL.x) / 2.0, (PAUSE_TOUCH - PAUSE_VISUAL.x) / 2.0)
	plate.pivot_offset = PAUSE_VISUAL / 2.0
	pause_button.add_child(plate)
	var icon: TextureRect = Art.picture(Art.play("icon_pause"))
	icon.position = (Vector2(PAUSE_VISUAL.x, PAUSE_VISUAL.x) - icon.size) / 2.0
	plate.add_child(icon)
	pause_button.button_down.connect(func() -> void: Juice.press_punch(plate, 0.92, 0.1))
	pause_button.pressed.connect(func() -> void:
		if idle():
			_open_pause())
	_hud_layer.add_child(pause_button)

	_ribbon = Art.plate(Art.play("stage_ribbon"), RIBBON_MARGINS)
	_hud_layer.add_child(_ribbon)
	_ribbon_small = Fonts.text("", Fonts.display(700), 12, Color("6a3a00"))
	_ribbon.add_child(_ribbon_small)
	_ribbon_big = Fonts.text("", Fonts.display(700), 20, Color("6a3a00"))
	_ribbon.add_child(_ribbon_big)

	for index: int in HEARTS:
		var heart: TextureRect = Art.picture(Art.play("heart_full"), Vector2.ONE * HEART_SIZE)
		heart.pivot_offset = Vector2.ONE * HEART_SIZE / 2.0
		heart.set_meta("full", true)
		_hud_layer.add_child(heart)
		_hearts.append(heart)

	coin_chip = CurrencyChip.instantiate()
	coin_chip.name = "play_coins"
	coin_chip.show_add = shop_available
	_hud_layer.add_child(coin_chip)
	coin_chip.add_theme_stylebox_override("panel", Art.box(Art.skin("ui_chip"), [22, 14, 22, 14], [0, 0, 5, 0]))
	coin_chip.custom_minimum_size.y = CHIP_HEIGHT
	coin_chip.set_icon(Art.skin("icon_coin"))
	var row: HBoxContainer = coin_chip.get_node("Row")
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip_icon: TextureRect = coin_chip.get_node("Row/Icon")
	chip_icon.custom_minimum_size = Vector2(28, 28)
	chip_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value: Label = coin_chip.get_node("Row/Value")
	value.add_theme_font_override("font", Fonts.display(600))
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", Color.WHITE)
	value.add_theme_constant_override("outline_size", 0)
	var add: Button = coin_chip.get_node("Row/Add")
	add.text = ""
	add.custom_minimum_size = Vector2(22, 24)
	add.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plus: StyleBoxTexture = Art.box(Art.play("plus_button"), [0, 0, 0, 0], [0, 0, 0, 0])
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add.add_theme_stylebox_override(style, plus)
	coin_chip.add_pressed.connect(func() -> void:
		if idle():
			shop_requested.emit())
	coin_chip.resized.connect(_place_hud)


func _build_actions() -> void:
	hint_button = BoosterButton.new()
	hint_button.name = "hint"
	hint_button.pressed.connect(_on_booster_pressed.bind(Economy.BOOSTER_HINT))
	_hud_layer.add_child(hint_button)
	undo_button = BoosterButton.new()
	undo_button.name = "undo"
	undo_button.pressed.connect(_on_booster_pressed.bind(Economy.BOOSTER_UNDO))
	_hud_layer.add_child(undo_button)

	_submit_shadow = Art.plate(Art.play("soft_shadow"), SHADOW_MARGINS)
	_submit_shadow.modulate.a = 0.6
	_hud_layer.add_child(_submit_shadow)
	submit_button = Button.new()
	submit_button.name = "submit"
	submit_button.theme_type_variation = &"PrimaryButton"
	submit_button.set_meta("ui_sfx_kind", "confirm")
	submit_button.focus_mode = Control.FOCUS_NONE
	submit_button.pressed.connect(_on_submit)
	submit_button.button_down.connect(func() -> void: Juice.press_punch(submit_button, 0.96, 0.1))
	_hud_layer.add_child(submit_button)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 9)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 3.0
	row.offset_bottom = -7.0
	submit_button.add_child(row)
	_submit_label = Fonts.text("", Fonts.display(700), 25)
	Fonts.shade(_submit_label, Color("b85a00"))
	row.add_child(_submit_label)
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", Art.box(Art.play("count_pill"), PILL_MARGINS, [9, 1, 9, 2]))
	row.add_child(pill)
	_submit_count = Fonts.text("0/4", Fonts.display(700), 14)
	pill.add_child(_submit_count)


## 판이 바뀌었을 때 판에 딸린 보기(메달, 칸, 카드)를 모두 다시 만든다.
func _rebuild() -> void:
	_close_toast()
	for node: Node in _cards_layer.get_children() + _cells_layer.get_children() + _fx_layer.get_children() + _medals:
		node.get_parent().remove_child(node)
		node.queue_free()
	_medals.clear()
	_hold_cells.clear()
	_reserve_cells.clear()
	_views.clear()
	_columns.clear()

	var large: bool = bool(host.state.data.settings.get("large_text", false))
	_hold_label.text = tr_text("HOLDING", "임시 칸")
	_reserve_label.text = tr_text("RESERVE", "예비 카드")
	for label: Label in [_hold_label, _reserve_label]:
		label.add_theme_font_size_override("font_size", 14 if large else 12)
	_submit_label.text = tr_text("Group", "묶기")
	hint_button.configure("booster_hint", "icon_hint", tr_text("Hint", "힌트"), language(), 14 if large else 12)
	undo_button.configure("booster_undo", "icon_undo", tr_text("Undo", "되돌리기"), language(), 14 if large else 12)
	match mode:
		RoundMode.TUTORIAL:
			_ribbon_small.text = tr_text("TUTORIAL", "튜토리얼")
			_ribbon_big.text = ""
		RoundMode.DAILY:
			_ribbon_small.text = tr_text("DAILY", "일일 도전")
			_ribbon_big.text = "%d/%d" % [int(date.substr(5, 2)), int(date.substr(8, 2))]
		_:
			_ribbon_small.text = tr_text("STAGE", "스테이지")
			_ribbon_big.text = str(stage_number)
	coin_chip.set_value(player().coins(), false)

	for index: int in board.categories().size():
		var medal_view := MedalView.new()
		medal_view.name = "medal_%d" % index
		_hud_layer.add_child(medal_view)
		_medals.append(medal_view)
	# 일일 도전에는 칸 추가가 없어 잠긴 칸을 두지 않는다.
	var hold_count: int = board.slot_count() if mode == RoundMode.DAILY else Board.HOLD_SLOTS_MAX
	for index: int in hold_count:
		_hold_cells.append(_make_cell("hold_%d" % index, index, true))
	for index: int in board.reserve().size():
		_reserve_cells.append(_make_cell("reserve_%d" % index, index, false))
	_relayout()

	var solved: Array[String] = board.solved()
	for index: int in solved.size():
		_complete_medal(index, solved[index], false)
	for column: int in board.column_count():
		var views: Array = []
		for depth: int in board.hidden_count(column):
			var back: CardView = _make_card(_layout["card"])
			back.set_face_down(true)
			back.position = _column_position(column, depth)
			views.append(back)
		var front: String = board.front_card(column)
		if not front.is_empty():
			var view: CardView = _make_card(_layout["card"])
			_show_card(view, front)
			view.position = _column_position(column, views.size())
			views.append(view)
		_columns.append(views)
	var reserve: Array[String] = board.reserve()
	for index: int in reserve.size():
		if not reserve[index].is_empty():
			var view: CardView = _make_card(_layout["cell"])
			_show_card(view, reserve[index])
			view.position = (_layout["reserve"][index] as Rect2).position
	var holds: Array[String] = board.holds()
	for index: int in holds.size():
		if not holds[index].is_empty():
			var view: CardView = _make_card(_layout["cell"])
			_show_card(view, holds[index])
			view.position = (_layout["holds"][index] as Rect2).position
	_refresh()


func _make_cell(cell_name: String, index: int, is_hold: bool) -> SlotCell:
	var cell := SlotCell.new()
	cell.name = cell_name
	cell.index = index
	if is_hold:
		cell.gate = func(_cell: Control) -> bool: return idle()
		cell.pressed.connect(_on_hold_cell_pressed)
	else:
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cells_layer.add_child(cell)
	return cell


func _make_card(card_size: Vector2) -> CardView:
	var view := CardView.new()
	view.gate = _card_gate
	view.draggable = _card_draggable
	view.tapped.connect(_on_card_tapped)
	view.drag_started.connect(_on_drag_started)
	view.drag_moved.connect(_on_drag_moved)
	view.drag_ended.connect(_on_drag_ended)
	view.set_meta("ui_sfx_silent", true)
	_cards_layer.add_child(view)
	view.configure(card_size, _layout["icon"], language(), bool(host.state.data.settings.get("large_text", false)))
	return view


func _show_card(view: CardView, card: String) -> void:
	view.show_card(card, session.catalog.item_icon(card), session.catalog.item_name(card, language()))
	view.set_face_down(false)
	_views[card] = view


func _column_position(column: int, depth: int) -> Vector2:
	return Vector2(_layout["column_x"][column], Layout.stack_y(_layout, depth))


## 화면 크기나 안전 영역이 바뀌면 자리를 다시 잡는다.
func _relayout() -> void:
	if board == null:
		return
	var shape: Dictionary = Difficulty.layout(board.meta()["layout"])
	var columns: Array = shape.get("columns", [])
	if columns.size() != board.column_count():
		columns = []
		for column: int in board.column_count():
			columns.append(board.column_size(column))
	_layout = Layout.compute(size, insets.x, insets.y, columns, board.reserve().size(), board.categories().size(), _hold_cells.size())
	_stage.scale = Vector2.ONE * float(_layout["scale"])
	_stage.size = _layout["stage"]
	_stage.position = Vector2.ZERO
	_dim.size = _stage.size
	for layer: Control in [_board_layer, _cells_layer, _hud_layer, _cards_layer, _fx_layer]:
		layer.size = _stage.size

	var tray: Rect2 = _layout["tray"]
	_tray.position = tray.position
	_tray.size = tray.size
	var labels: Array = [[_hold_label, _layout["hold_label"]], [_reserve_label, _layout["reserve_label"]]]
	for index: int in labels.size():
		var label: Label = labels[index][0]
		var at: Vector2 = labels[index][1]
		label.position = at
		label.size = Vector2(0, Layout.LABEL_HEIGHT)
		var text_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		_lines[index].position = Vector2(at.x + text_width + 6.0, at.y + Layout.LABEL_HEIGHT / 2.0 - 1.0)
		_lines[index].size = Vector2(maxf(0.0, float(_layout["label_width"]) - text_width - 6.0), 2.0)

	var tag_room := Vector2((_layout["card"] as Vector2).x + Layout.GUTTER - 4.0, _layout["tag_room"])
	for index: int in _medals.size():
		var rect: Rect2 = _layout["medals"][index]
		_medals[index].configure(rect.size.x, tag_room, language())
		_medals[index].position = rect.position
	for index: int in _hold_cells.size():
		_place(_hold_cells[index], _layout["holds"][index])
	for index: int in _reserve_cells.size():
		_place(_reserve_cells[index], _layout["reserve"][index])

	_place(hint_button, _layout["hint"])
	_place(undo_button, _layout["undo"])
	var primary: Rect2 = _layout["primary"]
	submit_button.position = primary.position - Vector2(3, 3)
	submit_button.size = primary.size + Vector2(6, 10)
	_submit_shadow.position = primary.position + Vector2(-16, 14 - 16)
	_submit_shadow.size = primary.size + Vector2(32, 32)
	_place_hud()


func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size


## 상단 줄: 일시정지, 스테이지 표지, 하트, 코인 칩을 양 끝에 붙이고 사이를 같은 간격으로 나눈다.
func _place_hud() -> void:
	if _layout.is_empty():
		return
	var hud: Rect2 = _layout["hud"]
	var middle: float = hud.position.y + hud.size.y / 2.0
	var small_font: Font = _ribbon_small.get_theme_font("font")
	var big_font: Font = _ribbon_big.get_theme_font("font")
	var small_width: float = small_font.get_string_size(_ribbon_small.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var big_width: float = big_font.get_string_size(_ribbon_big.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x if not _ribbon_big.text.is_empty() else 0.0
	var between: float = 6.0 if big_width > 0.0 else 0.0
	var ribbon_width: float = RIBBON_PAD * 2.0 + small_width + between + big_width
	var chip_width: float = coin_chip.get_combined_minimum_size().x
	var free: float = hud.size.x - PAUSE_VISUAL.x - ribbon_width - HEART_SPAN - (chip_width - CHIP_EDGE * 2.0)
	var gap: float = maxf(4.0, free / 3.0)

	var x: float = hud.position.x
	pause_button.position = Vector2(x - (PAUSE_TOUCH - PAUSE_VISUAL.x) / 2.0, middle - PAUSE_TOUCH / 2.0)
	x += PAUSE_VISUAL.x + gap
	_ribbon.position = Vector2(x, middle - RIBBON_HEIGHT / 2.0)
	_ribbon.size = Vector2(ribbon_width, RIBBON_HEIGHT + 4.0)
	# 작은 글자와 큰 숫자는 밑줄을 맞춘다.
	var baseline: float = (RIBBON_HEIGHT - big_font.get_height(20)) / 2.0 + big_font.get_ascent(20) - 0.5
	if big_width == 0.0:
		baseline = (RIBBON_HEIGHT - small_font.get_height(12)) / 2.0 + small_font.get_ascent(12)
	_ribbon_small.position = Vector2(RIBBON_PAD, baseline - small_font.get_ascent(12))
	_ribbon_big.position = Vector2(RIBBON_PAD + small_width + between, baseline - big_font.get_ascent(20))
	x += ribbon_width + gap
	for index: int in _hearts.size():
		_hearts[index].position = Vector2(x + index * HEART_PITCH - (HEART_SIZE - 18.0) / 2.0, middle - HEART_SIZE / 2.0 + 2.0)
	coin_chip.size = Vector2(chip_width, CHIP_HEIGHT)
	coin_chip.position = Vector2(hud.end.x - chip_width + CHIP_EDGE, middle - CHIP_HEIGHT / 2.0)


# =====================================================================
# 상태 반영
# =====================================================================

func _refresh() -> void:
	_refresh_hearts()
	_submit_count.text = "%d/%d" % [selection.size(), Board.GROUP_SIZE]
	submit_button.disabled = selection.size() != Board.GROUP_SIZE or phase != Phase.PLAYING
	_submit_label.add_theme_color_override("font_shadow_color", Color("8f95bc") if submit_button.disabled else Color("b85a00"))
	_refresh_boosters()
	_refresh_cells()
	_guide.update()


func _refresh_hearts() -> void:
	# 실수한 만큼 앞쪽 하트부터 회색이 된다.
	for index: int in _hearts.size():
		var full: bool = index >= board.mistakes()
		if _hearts[index].get_meta("full", true) != full:
			_hearts[index].set_meta("full", full)
			_hearts[index].texture = Art.play("heart_full" if full else "heart_empty")


func _refresh_boosters() -> void:
	var attention: bool = dead_end or stuck_idle
	for kind: String in [Economy.BOOSTER_HINT, Economy.BOOSTER_UNDO]:
		var button: BoosterButton = hint_button if kind == Economy.BOOSTER_HINT else undo_button
		var verdict: Dictionary = session.use_booster.check(player(), board, kind)
		var owned: int = player().booster(kind)
		if mode == RoundMode.TUTORIAL or verdict["reason"] in ["daily", "no_run"]:
			button.show_state(BoosterButton.OFF, owned)
		elif not verdict["ok"]:
			button.show_state(BoosterButton.IDLE, owned)
		else:
			button.show_state(BoosterButton.READY if owned > 0 else BoosterButton.EMPTY, owned)
		button.disabled = button.state == BoosterButton.OFF
		button.set_highlight(attention and kind == Economy.BOOSTER_UNDO and verdict["ok"])


func _refresh_cells() -> void:
	var holds: Array[String] = board.holds()
	var can_drop: bool = selection.size() == 1 and board.can_hold(selection[0]) and phase == Phase.PLAYING
	for index: int in _hold_cells.size():
		var cell: SlotCell = _hold_cells[index]
		if index >= holds.size():
			cell.set_state(SlotCell.LOCKED)
			var offer: Dictionary = _slot_offer()
			cell.set_lock(tr_text("+1 slot", "+1칸"), offer["tag"], offer["text"], Art.skin("icon_coin"))
			cell.set_attention((dead_end or stuck_idle) and mode != RoundMode.TUTORIAL)
		else:
			cell.set_attention(false)
			if not holds[index].is_empty():
				cell.set_state(SlotCell.FILLED)
			else:
				cell.set_state(SlotCell.TARGET if can_drop else SlotCell.EMPTY)
	var reserve: Array[String] = board.reserve()
	for index: int in _reserve_cells.size():
		_reserve_cells[index].set_state(SlotCell.EMPTY if reserve[index].is_empty() else SlotCell.FILLED)
	_tray_attention(stuck_idle)


## 잠긴 칸을 어떻게 열 수 있는지: 보유분이 있으면 그 수, 없으면 광고, 광고도 없으면 코인 가격.
func _slot_offer() -> Dictionary:
	var owned: int = player().booster(Economy.BOOSTER_SLOT)
	if owned > 0:
		return {"tag": SlotCell.TAG_OWNED, "text": "×%d" % owned}
	if _ad_ready(AdPolicy.REWARDED_BOOSTER):
		return {"tag": SlotCell.TAG_AD, "text": tr_text("AD", "광고")}
	return {"tag": SlotCell.TAG_COINS, "text": str(Economy.price(Economy.BOOSTER_SLOT))}


func _ad_ready(placement: String) -> bool:
	return session.ad_flow.check(player(), placement, mode)["ok"]


var _tray_pulse: Tween

func _tray_attention(on: bool) -> void:
	if _tray_pulse != null and _tray_pulse.is_valid():
		if on:
			return
		_tray_pulse.kill()
	_tray.modulate.a = 1.0
	if on and not Juice.reduced_motion and is_inside_tree():
		_tray_pulse = create_tween().set_loops()
		_tray_pulse.tween_property(_tray, "modulate:a", 0.45, 0.5).set_trans(Tween.TRANS_SINE)
		_tray_pulse.tween_property(_tray, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)


func _set_cards_visible(on: bool) -> void:
	for node: Node in _cards_layer.get_children():
		(node as Control).modulate.a = 1.0 if on else 0.0


func _sync_coins(animate: bool) -> void:
	coin_chip.set_value(player().coins(), animate)


# =====================================================================
# 입력
# =====================================================================

func _card_gate(view: Control) -> bool:
	return idle() and _guide.allows_card((view as CardView).card_id)


func _card_draggable(view: Control) -> bool:
	var card: String = (view as CardView).card_id
	return idle() and board.can_hold(card) and _guide.allows_hold(card)


func _on_card_tapped(view: Control) -> void:
	var card: String = (view as CardView).card_id
	if not idle() or not board.can_select(card):
		return
	_clear_hint()
	if selection.has(card):
		_deselect(card)
		audio.play("card_deselect")
	elif selection.size() >= Board.GROUP_SIZE:
		# 다섯 번째 선택은 받지 않고 카드가 흔들린다.
		(view as CardView).shake()
		host.sfx.play("error")
		audio.vibrate(10)
	else:
		selection.append(card)
		(view as CardView).set_selected(true)
		# 같은 소리가 겹쳐 시끄럽지 않게 고른 수에 따라 음높이를 한 단계씩 올린다.
		audio.play("card_select", pow(2.0, (selection.size() - 1) * 2.0 / 12.0))
		audio.vibrate(10)
	_refresh()


func _deselect(card: String) -> void:
	selection.erase(card)
	var view: CardView = _views.get(card)
	if view != null:
		view.set_selected(false)


func _clear_selection() -> void:
	for card: String in selection.duplicate():
		_deselect(card)


func _on_hold_cell_pressed(cell: Control) -> void:
	if not idle():
		return
	var index: int = (cell as SlotCell).index
	if index >= board.slot_count():
		if _guide.allows_booster():
			_on_booster_pressed(Economy.BOOSTER_SLOT)
		return
	if selection.size() != 1 or not _guide.allows_cell():
		return
	var card: String = selection[0]
	if board.can_hold(card) and _guide.allows_hold(card):
		_hold(card)
	else:
		# 예비 카드와 임시 칸의 카드는 옮길 수 없다. 선택은 그대로 둔다.
		card_view(card).shake()
		host.sfx.play("error")
		audio.vibrate(10)


func _on_drag_started(view: Control) -> void:
	var card_node: CardView = view
	_dragging = true
	_clear_hint()
	if selection.has(card_node.card_id):
		_deselect(card_node.card_id)
	card_node.set_floating(true)
	_drag_grab = card_node.size / 2.0
	for index: int in _hold_cells.size():
		if index < board.slot_count() and board.holds()[index].is_empty():
			_hold_cells[index].set_state(SlotCell.TARGET)


func _on_drag_moved(view: Control, at: Vector2) -> void:
	(view as CardView).position = _to_stage(at) - _drag_grab


func _on_drag_ended(view: Control, at: Vector2) -> void:
	var card_node: CardView = view
	_dragging = false
	var point: Vector2 = _to_stage(at)
	var dropped: bool = false
	for index: int in _hold_cells.size():
		if index < board.slot_count() and board.holds()[index].is_empty() \
				and Rect2(_hold_cells[index].position, _hold_cells[index].size).grow(12.0).has_point(point):
			dropped = true
	if dropped and idle() and board.can_hold(card_node.card_id):
		_hold(card_node.card_id)
		return
	# 칸 밖에 놓으면 제자리로 돌아간다.
	busy = true
	await _slide(card_node, _home_position(card_node.card_id), 0.12)
	if not is_instance_valid(card_node):
		return
	card_node.set_floating(false)
	busy = false
	_refresh()


func _to_stage(viewport_point: Vector2) -> Vector2:
	return _stage.get_global_transform().affine_inverse() * viewport_point


func _home_position(card: String) -> Vector2:
	for column: int in _columns.size():
		var views: Array = _columns[column]
		if not views.is_empty() and (views.back() as CardView).card_id == card:
			return _column_position(column, views.size() - 1)
	var index: int = board.reserve().find(card)
	if index != -1:
		return (_layout["reserve"][index] as Rect2).position
	index = board.holds().find(card)
	return (_layout["holds"][index] as Rect2).position if index != -1 else Vector2.ZERO


func _on_submit() -> void:
	if not idle() or selection.size() != Board.GROUP_SIZE or not _guide.allows_submit():
		return
	_clear_hint()
	var cards: Array = selection.duplicate()
	var outcome: Dictionary = board.submit(cards)
	match outcome["kind"]:
		Board.KIND_GROUP:
			_resolve_group(outcome)
		Board.KIND_ONE_AWAY, Board.KIND_MISS:
			_resolve_miss(outcome, cards)
		Board.KIND_REPEAT:
			for card: String in cards:
				card_view(card).shake()
			host.sfx.play("error")
			show_toast(tr_text("Already tried", "이미 해 본 조합이에요"), TOAST_INFO)
			_clear_selection()
			_refresh()
		_:
			_clear_selection()
			_refresh()


# =====================================================================
# 판의 변화와 연출
# =====================================================================

## 새 판의 카드가 위에서 한 장씩 내려와 앉는다. 하던 판을 되살릴 때는 제자리에서 바로 보인다.
func _deal(animate: bool) -> void:
	_set_cards_visible(true)
	if not animate or Juice.reduced_motion:
		return
	var cards: Array = _cards_layer.get_children()
	var longest: Tween
	for index: int in cards.size():
		var view: CardView = cards[index]
		var rest: Vector2 = view.position
		view.position = rest - Vector2(0, 70)
		view.modulate.a = 0.0
		var tween: Tween = view.create_tween().set_parallel(true)
		tween.tween_property(view, "position", rest, DEAL_SECONDS).set_delay(index * DEAL_STAGGER).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(view, "modulate:a", 1.0, DEAL_SECONDS * 0.6).set_delay(index * DEAL_STAGGER)
		longest = tween
	audio.play("card_slide")
	if longest != null:
		await longest.finished


func _hold(card: String) -> void:
	var held: Dictionary = board.hold(card)
	if not held["ok"]:
		return
	busy = true
	var token: int = _round_token
	_deselect(card)
	_checkpoint()
	_log("hold_move", {})
	var view: CardView = card_view(card)
	var column: int = held["column"]
	(_columns[column] as Array).pop_back()
	view.set_floating(true)
	view.configure(_layout["cell"], _layout["icon"], language(), bool(host.state.data.settings.get("large_text", false)))
	view.show_card(card, session.catalog.item_icon(card), session.catalog.item_name(card, language()))
	audio.play("card_slide")
	audio.vibrate(10)
	_refresh()
	await _arc(view, (_layout["holds"][held["slot"]] as Rect2).position, HOLD_SECONDS)
	if token != _round_token or not is_inside_tree():
		return
	view.set_floating(false)
	_hold_cells[held["slot"]].bump()
	if not str(held["opened"]).is_empty():
		await _reveal(column, held["opened"])
		if token != _round_token or not is_inside_tree():
			return
	busy = false
	_refresh()
	if board.is_stuck():
		_open_stuck()
	else:
		_check_dead_end(true)


## 열의 맨 위 뒷면 카드가 뒤집혀 열린다.
func _reveal(column: int, card: String) -> void:
	var views: Array = _columns[column]
	if views.is_empty():
		return
	var view: CardView = views.back()
	view.show_card(card, session.catalog.item_icon(card), session.catalog.item_name(card, language()))
	_views[card] = view
	audio.play("card_flip")
	await view.flip(false)


func _resolve_group(outcome: Dictionary) -> void:
	busy = true
	var token: int = _round_token
	var category: String = outcome["category"]
	var order: int = board.solved().size()
	selection.clear()
	_checkpoint()
	_log("group_complete", {"category": category, "order": order})
	if mode == RoundMode.TUTORIAL:
		# 공통 흐름의 튜토리얼 상태: 묶음 하나가 행동 한 번이다.
		host.state.action_completed("target_hit")
	audio.play("group_complete")
	audio.vibrate(25)
	_refresh()

	var target_medal: MedalView = _medals[order - 1]
	var removed: Array = outcome["removed"]
	var last: Tween
	for index: int in removed.size():
		var place: Dictionary = removed[index]
		var view: CardView = _views.get(place["card"])
		_views.erase(place["card"])
		if place["zone"] == Board.ZONE_COLUMN:
			(_columns[place["index"]] as Array).erase(view)
		if view == null:
			continue
		view.set_selected(false, false)
		view.set_floating(true)
		last = _fly_to_medal(view, target_medal, index * FLY_STAGGER)
	if last != null and not Juice.reduced_motion:
		await last.finished
	if token != _round_token or not is_inside_tree():
		return
	_complete_medal(order - 1, category, true)
	for opened: Dictionary in outcome["opened"]:
		await _reveal(opened["index"], opened["card"])
		if token != _round_token or not is_inside_tree():
			return
	_refresh()
	if outcome["won"]:
		_win()
		return
	busy = false
	_refresh()
	if board.is_stuck():
		_open_stuck()


func _fly_to_medal(view: CardView, target_medal: MedalView, delay: float) -> Tween:
	if Juice.reduced_motion:
		view.queue_free()
		return null
	var destination: Vector2 = target_medal.position + target_medal.size / 2.0 - view.size / 2.0
	view.pivot_offset = view.size / 2.0
	var tween: Tween = view.create_tween().set_parallel(true)
	tween.tween_property(view, "position", destination, FLY_SECONDS).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(view, "scale", Vector2.ONE * 0.3, FLY_SECONDS).set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(view, "modulate:a", 0.0, FLY_SECONDS * 0.3).set_delay(delay + FLY_SECONDS * 0.7)
	tween.chain().tween_callback(view.queue_free)
	return tween


func _complete_medal(index: int, category: String, animate: bool) -> void:
	var icons: Array = []
	for card: String in board.group_items(category):
		icons.append(session.catalog.item_icon(card))
	_medals[index].complete(category, session.catalog.category_name(category, language()), icons, animate)


func _resolve_miss(outcome: Dictionary, cards: Array) -> void:
	busy = true
	var token: int = _round_token
	var near: bool = outcome["kind"] == Board.KIND_ONE_AWAY
	_checkpoint()
	_log("mistake", {"one_away": near})
	for card: String in cards:
		card_view(card).shake()
	audio.play("one_away" if near else "miss")
	audio.vibrate_twice(15)
	_break_heart(board.mistakes() - 1)
	if near:
		show_toast(tr_text("One away!", "한 장만 달라요!"), TOAST_NEAR)
	if not Juice.reduced_motion:
		await get_tree().create_timer(0.3).timeout
		if token != _round_token or not is_inside_tree():
			return
	# 오답이면 카드는 그대로 두고 선택만 푼다.
	_clear_selection()
	busy = false
	_refresh()
	if outcome["failed"]:
		_fail()


## 하트 하나가 두 조각으로 갈라지며 회색이 된다.
func _break_heart(index: int) -> void:
	if index < 0 or index >= _hearts.size():
		return
	var heart: TextureRect = _hearts[index]
	heart.set_meta("full", false)
	heart.texture = Art.play("heart_empty")
	if Juice.reduced_motion:
		return
	for side: int in [-1, 1]:
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.size = Vector2(HEART_SIZE / 2.0, HEART_SIZE)
		clip.position = heart.position + Vector2(0.0 if side == -1 else HEART_SIZE / 2.0, 0.0)
		clip.pivot_offset = Vector2(HEART_SIZE / 2.0 if side == -1 else 0.0, HEART_SIZE)
		var half: TextureRect = Art.picture(Art.play("heart_full"), Vector2.ONE * HEART_SIZE)
		half.position = Vector2(0.0 if side == -1 else -HEART_SIZE / 2.0, 0.0)
		clip.add_child(half)
		_fx_layer.add_child(clip)
		var tween: Tween = clip.create_tween().set_parallel(true)
		tween.tween_property(clip, "position", clip.position + Vector2(side * 7.0, 12.0), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(clip, "rotation", side * 0.5, 0.3)
		tween.tween_property(clip, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(clip.queue_free)
	Juice.press_punch(heart, 1.25, 0.2)


## 지금 칸 수로는 끝까지 풀 수 없게 됐으면 판을 멈추지 않고 한 번 알린다. announce가 false면 표시만 맞춘다.
func _check_dead_end(announce: bool) -> void:
	if mode == RoundMode.TUTORIAL or phase != Phase.PLAYING:
		return
	var blocked: bool = not board.is_stuck() and not Solver.solve_board(board, board.slot_count())["solvable"]
	if blocked and not dead_end and announce:
		show_toast(tr_text("No way through from here", "이대로는 풀 수 없어요"), TOAST_ALERT)
		audio.play("stuck")
		_log("dead_end_shown", {})
	dead_end = blocked
	_refresh()


func _win() -> void:
	phase = Phase.ENDED
	busy = true
	var token: int = _round_token
	_flush_play_time()
	result = session.finish_round.execute(player(), board, int(seconds))
	_guide.update()
	audio.play("win")
	audio.vibrate(40)
	await _clear_ceremony()
	if token != _round_token or not is_inside_tree():
		return
	if mode == RoundMode.TUTORIAL:
		_show_popup(_popups.tutorial_done(result), "tutorial_done")
		return
	await _interstitial()
	if token != _round_token or not is_inside_tree():
		return
	_show_popup(_popups.result(result), "result")


## 클리어: 색종이가 쏟아지고 글자가 튀어나온다.
func _clear_ceremony() -> void:
	if Juice.reduced_motion:
		return
	var confetti := CPUParticles2D.new()
	confetti.amount = CONFETTI
	confetti.lifetime = CLEAR_SECONDS
	confetti.one_shot = true
	confetti.explosiveness = 0.7
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(_stage.size.x / 2.0, 4.0)
	confetti.position = Vector2(_stage.size.x / 2.0, -10.0)
	confetti.direction = Vector2(0, 1)
	confetti.spread = 25.0
	confetti.gravity = Vector2(0, 520)
	confetti.initial_velocity_min = 140.0
	confetti.initial_velocity_max = 320.0
	confetti.angular_velocity_min = -360.0
	confetti.angular_velocity_max = 360.0
	confetti.scale_amount_min = 5.0
	confetti.scale_amount_max = 9.0
	var ramp := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for index: int in CONFETTI_COLORS.size():
		offsets.append(float(index) / (CONFETTI_COLORS.size() - 1))
		colors.append(Color(CONFETTI_COLORS[index]))
	ramp.offsets = offsets
	ramp.colors = colors
	confetti.color_initial_ramp = ramp
	_fx_layer.add_child(confetti)
	confetti.emitting = true
	confetti.finished.connect(confetti.queue_free)
	var banner: Label = Fonts.text(tr_text("Cleared!", "클리어!"), Fonts.display(700), 46)
	Fonts.shade(banner, Color("4e54c8"), 4)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(_stage.size.x, 60)
	banner.position = Vector2(0, (_layout["tableau"] as Rect2).position.y + 30.0)
	_fx_layer.add_child(banner)
	Juice.pop_in(banner, 0.3, 0.4)
	await get_tree().create_timer(CLEAR_SECONDS).timeout
	if is_instance_valid(banner):
		banner.queue_free()


func _fail() -> void:
	phase = Phase.ENDED
	busy = true
	audio.play("fail")
	_refresh()
	_show_popup(_popups.fail(), "fail")


func _open_stuck() -> void:
	audio.play("stuck")
	_log("stuck_shown", {})
	stuck_idle = false
	_show_popup(_popups.stuck(), "stuck")


func _open_pause() -> void:
	_show_popup(_popups.pause(), "pause")


# =====================================================================
# 팝업
# =====================================================================

func _show_popup(next: Control, kind: String) -> void:
	if popup != null:
		_drop_popup()
	popup = next
	popup_kind = kind
	popup.name = "popup_" + kind
	host.layers.layer("Popup").add_child(popup)
	popup.closed.connect(_on_popup_closed.bind(popup))
	_close_toast()
	_guide.update()
	popup.open()


func _on_popup_closed(closed: Control) -> void:
	if popup != closed:
		closed.queue_free()
		return
	var kind: String = popup_kind
	_drop_popup()
	if kind == "stuck" and phase == Phase.PLAYING and board.is_stuck():
		# 닫고 판을 살펴보는 동안 받침이 맥동한다.
		stuck_idle = true
	_refresh()


func _drop_popup() -> void:
	if popup != null:
		popup.queue_free()
	popup = null
	popup_kind = ""


## 창을 닫는다. 닫히는 연출이 끝난 뒤 then을 부른다.
func close_popup(then: Callable = Callable()) -> void:
	if popup == null:
		if then.is_valid():
			then.call()
		return
	var closing: Control = popup
	if then.is_valid():
		closing.closed.connect(then, CONNECT_ONE_SHOT)
	closing.close()


# =====================================================================
# 팝업에서 부르는 동작
# =====================================================================

## 다시 하기: 지금 판을 버리고 같은 판을 처음부터.
func restart() -> void:
	close_popup(func() -> void:
		_drop_popup()
		var round: Dictionary = session.restart_round()
		if round["ok"]:
			begin(round)
		else:
			exit_requested.emit({"error": round["error"]}))


## 홈으로: 진행 중인 판을 버린다.
func leave_home() -> void:
	close_popup(func() -> void:
		_drop_popup()
		if player().has_run():
			_flush_play_time()
			session.drop_round()
		exit_requested.emit({}))


## 결과 창의 다음: 다음 스테이지를 띄운다.
func next_round() -> void:
	close_popup(func() -> void:
		_drop_popup()
		var round: Dictionary = session.open_round(false)
		if round["ok"]:
			begin(round)
		else:
			exit_requested.emit({"error": round["error"]}))


## 튜토리얼 끝 카드의 받기: 공통 흐름에 완료를 알리고 홈으로 간다.
func claim_tutorial() -> void:
	var gift: Dictionary = result.get("gift", {})
	host.state.action_completed("reward_collected")
	close_popup(func() -> void:
		_drop_popup()
		exit_requested.emit({"gift": gift}))


## 실패한 판을 이어 간다(이어하기가 끝난 뒤). 실수 두 번이 지워져 있다.
func resume_after_continue() -> void:
	close_popup(func() -> void:
		_drop_popup()
		phase = Phase.PLAYING
		busy = false
		for index: int in _hearts.size():
			if index >= board.mistakes() and not _hearts[index].get_meta("full", true):
				Juice.press_punch(_hearts[index], 1.3, 0.25)
		_sync_coins(true)
		_refresh()
		_check_dead_end(false))


# =====================================================================
# 부스터
# =====================================================================

func _on_booster_pressed(kind: String) -> void:
	if not idle() or not _guide.allows_booster():
		return
	var verdict: Dictionary = session.use_booster.check(player(), board, kind)
	if not verdict["ok"]:
		if kind != Economy.BOOSTER_SLOT:
			(hint_button if kind == Economy.BOOSTER_HINT else undo_button).refuse()
		host.sfx.play("error")
		return
	if player().booster(kind) > 0:
		apply_booster(kind, UseBooster.SOURCE_OWNED)
	else:
		_show_popup(_popups.booster(kind), "booster")


## 부스터를 쓴다. source는 owned(보유분), coins(코인으로 사서), ad(광고로 받은 것)다. 썼으면 true.
func apply_booster(kind: String, source: String) -> bool:
	var used: Dictionary = session.use_booster.execute(player(), board, kind, source)
	if not used["ok"]:
		return false
	_clear_hint()
	stuck_idle = false
	if source != UseBooster.SOURCE_OWNED:
		audio.play("booster")
	audio.vibrate(10)
	_sync_coins(true)
	match kind:
		Economy.BOOSTER_HINT:
			_show_hint(used)
		Economy.BOOSTER_UNDO:
			_show_undo(used)
		Economy.BOOSTER_SLOT:
			_show_slot()
	return true


func _show_hint(used: Dictionary) -> void:
	audio.play("hint")
	_clear_selection()
	var pair: Array = used["pair"]
	if pair.is_empty() and int(used["column"]) >= 0:
		# 짝이 없으면 다음에 옮길 열의 맨 앞 카드를 알려 준다.
		pair = [board.front_card(used["column"])]
	for card: Variant in pair:
		var view: CardView = _views.get(card)
		if view != null:
			view.set_hinted(true)
			_hinted.append(card)
			_sparkle_at(view.position + view.size / 2.0)
	_refresh()


func _clear_hint() -> void:
	for card: String in _hinted:
		var view: CardView = _views.get(card)
		if view != null:
			view.set_hinted(false)
	_hinted.clear()


func _show_undo(used: Dictionary) -> void:
	busy = true
	var token: int = _round_token
	audio.play("undo")
	_clear_selection()
	var card: String = used["card"]
	var column: int = used["column"]
	var views: Array = _columns[column]
	var closed: String = used["closed"]
	if not closed.is_empty() and _views.has(closed):
		# 열렸던 카드는 다시 뒤집힌다.
		var closing: CardView = _views[closed]
		_views.erase(closed)
		closing.flip(true)
	var view: CardView = card_view(card)
	view.set_floating(true)
	view.configure(_layout["card"], _layout["icon"], language(), bool(host.state.data.settings.get("large_text", false)))
	view.show_card(card, session.catalog.item_icon(card), session.catalog.item_name(card, language()))
	views.append(view)
	_cards_layer.move_child(view, -1)
	_refresh()
	await _arc(view, _column_position(column, views.size() - 1), HOLD_SECONDS)
	if token != _round_token or not is_inside_tree():
		return
	view.set_floating(false)
	_sparkle_at(view.position + view.size / 2.0)
	busy = false
	_check_dead_end(false)


func _show_slot() -> void:
	audio.play("slot_unlock")
	var cell: SlotCell = _hold_cells[board.slot_count() - 1]
	_refresh()
	cell.bump()
	_sparkle_at(cell.position + cell.size / 2.0)
	_check_dead_end(false)


func _sparkle_at(point: Vector2) -> void:
	if Juice.reduced_motion:
		return
	var sparkle: CPUParticles2D = Sparkle.instantiate()
	sparkle.position = point
	sparkle.one_shot = true
	sparkle.amount = 8
	sparkle.lifetime = 0.6
	sparkle.emission_sphere_radius = 36.0
	_fx_layer.add_child(sparkle)
	sparkle.emitting = true
	sparkle.finished.connect(sparkle.queue_free)


# =====================================================================
# 광고
# =====================================================================

## 보상형 광고를 보여 주고 결과를 on_result에 넘긴다. 정책이 막거나 광고가 없으면 보여 주지 않고 false를 돌려준다.
## 광고가 떠 있는 동안 화면은 입력을 받지 않고 음악이 멈춘다.
func watch_rewarded(placement: String, on_result: Callable) -> bool:
	if ad_showing or not session.ad_flow.request(player(), placement, mode)["ok"]:
		return false
	_begin_ad()
	session.services.ads.show(AdPolicy.FORMAT_REWARDED, func(outcome: String) -> void:
		_end_ad()
		on_result.call(outcome))
	return true


## 판 종료 전면 광고: 정책이 허용하고 광고가 준비됐을 때만 결과 창 앞에서 낸다.
func _interstitial() -> void:
	if not session.ad_flow.request(player(), AdPolicy.INTERSTITIAL_LEVEL_END, mode)["ok"]:
		return
	_begin_ad()
	session.services.ads.show(AdPolicy.FORMAT_INTERSTITIAL, func(outcome: String) -> void:
		session.ad_flow.finish_interstitial(player(), outcome)
		_end_ad()
		_ad_finished.emit())
	if ad_showing:
		await _ad_finished


func _begin_ad() -> void:
	ad_showing = true
	audio.hold_music("ad", true)


func _end_ad() -> void:
	ad_showing = false
	audio.hold_music("ad", false)
	# 다음 광고를 미리 불러 둔다.
	session.services.ads.request(AdPolicy.FORMAT_REWARDED)
	session.services.ads.request(AdPolicy.FORMAT_INTERSTITIAL)


# =====================================================================
# 토스트, 이동, 저장, 분석
# =====================================================================

## 짧은 안내를 더미 아래에 띄운다. 새 안내는 앞의 것을 바꿔 놓는다.
func show_toast(text: String, kind: String = TOAST_INFO) -> void:
	toasts.append(text)
	_close_toast()
	var plate: NinePatchRect = Art.plate(Art.play("toast_" + kind), TOAST_MARGINS)
	var label: Label = Fonts.text(text, Fonts.display(700), 16, Fonts.INK if kind == TOAST_NEAR else Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(label)
	var width: float = label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0
	plate.size = Vector2(width, 40.0) * stage_scale()
	label.size = Vector2(width, 36.0) * stage_scale()
	label.add_theme_font_size_override("font_size", roundi(16.0 * stage_scale()))
	# 받침의 줄 이름 위에 놓는다. 더미의 카드 이름과 임시 칸을 가리지 않는 자리다.
	var anchor: Vector2 = _stage.get_global_transform() * Vector2(_stage.size.x / 2.0, (_layout["tray"] as Rect2).position.y + 10.0)
	plate.position = anchor - plate.size / 2.0
	host.layers.layer("Toast").add_child(plate)
	_toast = plate
	Juice.pop_in(plate, 0.2)
	plate.create_tween().tween_interval(TOAST_SECONDS).finished.connect(func() -> void:
		if is_instance_valid(plate):
			Juice.pop_out(plate, 0.14).finished.connect(plate.queue_free))


func _close_toast() -> void:
	if is_instance_valid(_toast):
		_toast.queue_free()
	_toast = null


func _slide(view: Control, to: Vector2, duration: float) -> void:
	if Juice.reduced_motion or not is_inside_tree():
		view.position = to
		return
	var tween: Tween = view.create_tween()
	tween.tween_property(view, "position", to, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished


## 호를 그리며 옮긴다.
func _arc(view: Control, to: Vector2, duration: float) -> void:
	if Juice.reduced_motion or not is_inside_tree():
		view.position = to
		return
	var from: Vector2 = view.position
	var lift: float = clampf(from.distance_to(to) * 0.18, 10.0, 36.0)
	var tween: Tween = view.create_tween()
	tween.tween_method(func(progress: float) -> void:
		view.position = from.lerp(to, progress) - Vector2(0, sin(progress * PI) * lift), 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	await tween.finished


func _flush_play_time() -> void:
	var whole: int = int(seconds)
	session.ad_flow.add_play_time(player(), whole - _reported_seconds)
	_reported_seconds = whole


func _checkpoint() -> void:
	_flush_play_time()
	session.start_round.checkpoint(player(), board, int(seconds))


## 화면에서 일어난 일을 분석에 알린다. 판 정보(mode, level)를 함께 싣는다.
func _log(event: String, params: Dictionary) -> void:
	if mode == RoundMode.TUTORIAL or not player().has_run():
		return
	var info: Dictionary = RoundMode.event_params(player().run(), board.meta())
	var payload: Dictionary = {"mode": info["mode"], "level": info["level"]}
	payload.merge(params)
	session.services.analytics.log_event(event, payload)


func _exit_tree() -> void:
	_close_toast()
	_guide.clear()
	if popup != null:
		popup.queue_free()
		popup = null
