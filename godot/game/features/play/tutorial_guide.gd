extends RefCounted
## 튜토리얼 안내 층(SCR-012). 강조할 카드나 칸, 버튼만 밝게 남기고 나머지를 어둡게 하며,
## 손가락이 누를 곳을 가리키고 한 줄 말풍선이 뜬다. 안내하는 것 밖의 입력은 받지 않는다. 건너뛰기는 없다.
##
## 단계는 판의 상태에서 정한다(튜토리얼 판의 guide: 묶는 범주 순서와 임시 칸으로 옮길 카드).
##   pick → pick_submit: 첫 묶음 네 장을 고르고 묶는다.
##   hold_card → hold_cell: 맨 앞 카드를 골라 임시 칸으로 옮긴다.
##   regroup → regroup_submit: 열린 카드로 둘째 묶음을 완성한다.
##   last: 남은 네 장은 안내 없이 스스로 묶는다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const PICK := "pick"
const PICK_SUBMIT := "pick_submit"
const HOLD_CARD := "hold_card"
const HOLD_CELL := "hold_cell"
const REGROUP := "regroup"
const REGROUP_SUBMIT := "regroup_submit"
const LAST := "last"
## 손가락 그림에서 손끝의 자리.
const FINGERTIP := Vector2(25, 3)
const BUBBLE_WIDTH := 300.0
const FOCUS_Z := 60

var _screen: Control
var _step: String = ""
var _targets: Array = []
var _raised: Array[CanvasItem] = []
var _finger: TextureRect
var _finger_tween: Tween
var _bubble: PanelContainer
var _bubble_label: Label


func _init(screen: Control) -> void:
	_screen = screen


## 지금 강조하는 카드들.
func targets() -> Array:
	return _targets.duplicate()


## 판의 상태에 맞춰 단계를 다시 정하고 화면에 반영한다.
func update() -> void:
	_step = _find_step()
	_screen.guide_step = _step
	var showing: bool = not _step.is_empty() and not _screen.busy and _screen.popup == null
	_lower()
	_screen._dim.visible = showing and _step != LAST
	if not showing:
		_hide_pointer()
		if _bubble != null:
			_bubble.visible = false
		return
	var point_at: Control = null
	match _step:
		PICK, REGROUP:
			for card: String in _targets:
				var view: Control = _screen.card_view(card)
				_raise(view)
				if point_at == null and not _screen.selection.has(card):
					point_at = view
		PICK_SUBMIT, REGROUP_SUBMIT:
			for card: String in _targets:
				_raise(_screen.card_view(card))
			_raise(_screen.submit_button)
			point_at = _screen.submit_button
		HOLD_CARD:
			point_at = _screen.card_view(_targets[0])
			_raise(point_at)
		HOLD_CELL:
			_raise(_screen.card_view(_targets[0]))
			point_at = _screen.hold_cell(_screen.board.holds().find(""))
			_raise(point_at)
	_show_bubble()
	if point_at != null:
		_point(point_at)
	else:
		_hide_pointer()


func allows_card(card: String) -> bool:
	return _step in ["", LAST] or _targets.has(card)


func allows_hold(card: String) -> bool:
	return _step in ["", LAST] or (_step in [HOLD_CARD, HOLD_CELL] and _targets.has(card))


func allows_cell() -> bool:
	return _step in ["", LAST, HOLD_CELL]


func allows_submit() -> bool:
	return not _step in [HOLD_CARD, HOLD_CELL]


## 튜토리얼에서는 부스터를 쓰지 않는다.
func allows_booster() -> bool:
	return _screen.mode != RoundMode.TUTORIAL


func clear() -> void:
	_lower()
	if is_instance_valid(_finger):
		_finger.queue_free()
	if is_instance_valid(_bubble):
		_bubble.queue_free()
	_finger = null
	_bubble = null


func _find_step() -> String:
	_targets = []
	if _screen.mode != RoundMode.TUTORIAL or _screen.board == null or not _screen.playing():
		return ""
	var guide: Dictionary = _screen.session.tutorial.get("guide", {})
	var order: Array = guide.get("order", [])
	var board: Board = _screen.board
	var solved: int = board.solved().size()
	if order.size() != board.categories().size() or solved >= order.size():
		return ""
	var group: Array = board.group_items(order[solved])
	var all_open: bool = group.all(func(card: String) -> bool: return board.can_select(card))
	var all_picked: bool = group.all(func(card: String) -> bool: return _screen.selection.has(card))
	match solved:
		0:
			if all_open:
				_targets = group
				return PICK_SUBMIT if all_picked else PICK
		1:
			if all_open:
				_targets = group
				return REGROUP_SUBMIT if all_picked else REGROUP
			var hold: String = guide.get("hold", "")
			if board.can_hold(hold):
				_targets = [hold]
				return HOLD_CELL if _screen.selection == [hold] else HOLD_CARD
		_:
			return LAST
	return ""


func _raise(node: CanvasItem) -> void:
	if node == null:
		return
	node.z_index = FOCUS_Z
	_raised.append(node)


func _lower() -> void:
	for node: CanvasItem in _raised:
		if is_instance_valid(node):
			node.z_index = CardView.SELECTED_Z if node is CardView and (node as CardView).selected else 0
	_raised.clear()


func _layer() -> Control:
	return _screen.host.layers.layer("Ftue")


func _show_bubble() -> void:
	if _bubble == null:
		_bubble = PanelContainer.new()
		_bubble.name = "guide_bubble"
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble.add_theme_stylebox_override("panel", Art.box(Art.skin("ui_panel"), [24, 24, 24, 30], [18, 10, 18, 16]))
		_bubble_label = Fonts.text("", Fonts.display(600), 17, Fonts.INK)
		_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble_label.custom_minimum_size.x = BUBBLE_WIDTH - 36.0
		_bubble.add_child(_bubble_label)
		_layer().add_child(_bubble)
	_bubble.visible = true
	_bubble_label.text = _text()
	_bubble.reset_size()
	# 말풍선은 강조한 것을 가리지 않는 빈 줄에 둔다: 첫 단계는 임시 칸 줄, 그 뒤는 비어 있는 예비 카드 줄.
	var layout: Dictionary = _screen._layout
	var stage: Control = _screen._stage
	var row: Rect2 = (layout["holds"][0] as Rect2) if _step in [PICK, PICK_SUBMIT] else (layout["reserve"][0] as Rect2)
	var center: Vector2 = stage.get_global_transform() * Vector2(stage.size.x / 2.0, row.position.y + row.size.y / 2.0)
	_bubble.position = center - _bubble.size / 2.0


func _text() -> String:
	match _step:
		PICK, REGROUP:
			return _screen.tr_text("Pick four of a kind", "같은 종류 네 장을 골라요")
		PICK_SUBMIT, REGROUP_SUBMIT:
			return _screen.tr_text("Now tap Group", "이제 묶기를 눌러요")
		HOLD_CARD, HOLD_CELL:
			return _screen.tr_text("Move the front card to a holding slot", "맨 앞 카드를 임시 칸으로 옮겨요")
	return _screen.tr_text("Group the last four", "남은 네 장을 묶어 보세요")


## 손가락이 대상의 가운데 아래를 가리키며 위아래로 까딱인다.
func _point(target: Control) -> void:
	if _finger == null:
		_finger = Art.picture(Art.play("finger"))
		_finger.name = "guide_finger"
		_layer().add_child(_finger)
	_finger.visible = true
	var rect: Rect2 = target.get_global_rect()
	# 손끝은 대상의 아래쪽에 둔다. 카드의 그림과 이름, 버튼의 글자를 가리지 않는다.
	var tip: Vector2 = rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.86)
	var rest: Vector2 = tip - FINGERTIP
	if _finger_tween != null and _finger_tween.is_valid():
		_finger_tween.kill()
	_finger.position = rest
	if Juice.reduced_motion:
		return
	_finger_tween = _finger.create_tween().set_loops()
	_finger_tween.tween_property(_finger, "position:y", rest.y + 8.0, 0.4).set_trans(Tween.TRANS_SINE)
	_finger_tween.tween_property(_finger, "position:y", rest.y, 0.4).set_trans(Tween.TRANS_SINE)


func _hide_pointer() -> void:
	if _finger_tween != null and _finger_tween.is_valid():
		_finger_tween.kill()
	if _finger != null:
		_finger.visible = false
