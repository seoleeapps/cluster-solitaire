extends SceneTree
## 플레이 화면 배치 계산(play_layout.gd)과 카드 이름 맞춤(card_view.gd)의 프로브.
## 모든 배치가 세 화면 크기에서 잘리지 않고 카드 높이가 84~122인지, 기준 그림의 자리와 같은지,
## 모든 카드 이름이 두 언어에서 두 줄 안에 들어가는지 본다.

const Layout := preload("res://game/features/play/play_layout.gd")
const CardView := preload("res://game/features/play/card_view.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Content := preload("res://game/core/domain/fa_content.gd")

## 검수하는 논리 화면 크기: 작은 화면, 기준, 긴 화면, 아주 긴 화면.
const SIZES: Array[Vector2] = [Vector2(390, 693), Vector2(390, 844), Vector2(390, 866), Vector2(390, 910)]
const REFERENCE_INSETS := Vector2(34, 16)

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_every_layout_fits()
	_reference_positions()
	_spare_height()
	_short_screen_scales()
	_safe_insets()
	_card_names_fit()
	for line: String in _failed:
		print("FAILED: " + line)
	print("Play layout probe: %d checks, %d failed" % [_checks, _failed.size()])
	quit(0 if _failed.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


func _compute(size: Vector2, insets: Vector2, layout_id: String, holds: int = 3) -> Dictionary:
	var shape: Dictionary = Difficulty.layout(layout_id)
	return Layout.compute(size, insets.x, insets.y, shape["columns"], shape["reserve"], shape["groups"], holds)


func _every_layout_fits() -> void:
	for layout_id: String in Difficulty.layout_ids():
		for size: Vector2 in SIZES:
			for insets: Vector2 in [Vector2.ZERO, REFERENCE_INSETS]:
				var label: String = "%s %s insets %s" % [layout_id, size, insets]
				var found: Dictionary = _compute(size, insets, layout_id)
				var card: Vector2 = found["card"]
				_check(card.y >= Layout.CARD_MIN - 0.01 and card.y <= Layout.CARD_MAX + 0.01, label + ": card height %.1f is within 84-122" % card.y)
				if insets == Vector2.ZERO:
					_check(is_equal_approx(found["scale"], 1.0), label + ": no scaling at the supported sizes")
				_check(float(found["bottom"]) <= (found["stage"] as Vector2).y + 0.01, label + ": content ends above the bottom edge")
				_check_order(found, insets, label)


## 구역이 위에서 아래로 겹치지 않고, 칸이 받침 안에 있고, 카드의 옆면과 그림자(9)가 다음 구역을 침범하지 않는지.
func _check_order(found: Dictionary, insets: Vector2, label: String) -> void:
	var hud: Rect2 = found["hud"]
	var tableau: Rect2 = found["tableau"]
	var tray: Rect2 = found["tray"]
	var actions: Rect2 = found["actions"]
	var stage: Vector2 = found["stage"]
	var medals: Array = found["medals"]
	_check(hud.position.y >= insets.x + 7.99, label + ": the top row clears the safe area")
	_check(actions.end.y <= stage.y - insets.y - 7.99, label + ": the action row clears the safe area")
	_check((medals[0] as Rect2).position.y >= hud.end.y, label + ": medals below the top row")
	_check((medals[0] as Rect2).end.y + Layout.TAG_OFFSET + Layout.TAG_HEIGHT <= tableau.position.y, label + ": name tags above the tableau")
	_check(tableau.end.y + 9.0 <= tray.position.y + 0.01, label + ": tableau cards above the tray")
	_check(tray.end.y <= actions.position.y, label + ": tray above the action row")
	_check(hud.position.x >= 0.0 and hud.end.x <= stage.x and tray.end.x <= stage.x, label + ": content inside the width")
	var cells: Array = (found["holds"] as Array) + (found["reserve"] as Array)
	for index: int in cells.size():
		var cell: Rect2 = cells[index]
		_check(tray.grow(0.01).encloses(Rect2(cell.position, cell.size + Vector2(0, 9))), label + ": cell %d inside the tray" % index)
		for other: int in range(index + 1, cells.size()):
			_check(not cell.grow(-0.01).intersects((cells[other] as Rect2).grow(-0.01)), label + ": cells %d and %d apart" % [index, other])
	_check((found["primary"] as Rect2).size.y >= 48.0 and (found["hint"] as Rect2).size.x >= 48.0, label + ": touch targets are at least 48")


## 기준 그림(390×844, 위 34와 아래 16의 안전 영역, 표준 배치)에서 잰 자리와 같아야 한다.
func _reference_positions() -> void:
	var found: Dictionary = _compute(Vector2(390, 844), REFERENCE_INSETS, "classic")
	_check((found["card"] as Vector2).is_equal_approx(Vector2(84.5, 122)), "reference: tableau card is 84.5 by 122")
	_check((found["cell"] as Vector2).is_equal_approx(Vector2(80, 122)), "reference: tray card is 80 by 122")
	_check(is_equal_approx(found["icon"], 53.68), "reference: icon is 44% of the card height")
	_check((found["hud"] as Rect2).is_equal_approx(Rect2(14, 50, 362, 44)), "reference: top row at 50")
	_check(((found["medals"] as Array)[0] as Rect2).is_equal_approx(Rect2(27.25, 106, 58, 58)), "reference: first medal at 106")
	_check((found["tableau"] as Rect2).is_equal_approx(Rect2(14, 208, 362, 166)), "reference: tableau at 208")
	_check((found["tray"] as Rect2).is_equal_approx(Rect2(14, 386, 362, 314)), "reference: tray from 386 to 700")
	_check(((found["holds"] as Array)[0] as Rect2).is_equal_approx(Rect2(67, 416, 80, 122)), "reference: first holding slot at 67, 416")
	_check(((found["reserve"] as Array)[3] as Rect2).is_equal_approx(Rect2(287, 568, 80, 122)), "reference: last reserve card at 287, 568")
	_check((found["primary"] as Rect2).is_equal_approx(Rect2(84, 749, 222, 58)), "reference: group button at 84, 749")
	_check((found["undo"] as Rect2).is_equal_approx(Rect2(318, 741, 58, 74)), "reference: undo at 318, 741")
	# 일일 도전은 임시 칸 두 개를 가운데에 둔다.
	var daily: Dictionary = _compute(Vector2(390, 844), REFERENCE_INSETS, "classic", 2)
	_check(((daily["holds"] as Array)[0] as Rect2).is_equal_approx(Rect2(111, 416, 80, 122)), "daily: two slots are centred")
	# 예비 카드 6장은 4장과 2장으로 나누고 둘째 줄을 가운데에 둔다.
	var step: Dictionary = _compute(Vector2(390, 844), Vector2.ZERO, "step")
	_check((step["reserve"] as Array).size() == 6 and is_equal_approx(((step["reserve"] as Array)[4] as Rect2).position.x, 111.0), "step: second reserve row is centred")


## 122로도 남는 높이는 받침과 버튼 사이를 먼저 41까지 벌리고, 그 뒤 위 여백과 더미 아래, 아래쪽에 나눈다.
func _spare_height() -> void:
	var base: Dictionary = _compute(Vector2(390, 844), REFERENCE_INSETS, "classic")
	var tall: Dictionary = _compute(Vector2(390, 910), REFERENCE_INSETS, "classic")
	_check(is_equal_approx((base["actions"] as Rect2).position.y - (base["tray"] as Rect2).end.y, Layout.ACTION_GAP_ROOMY), "spare height first opens the gap above the action row")
	_check(is_equal_approx((tall["card"] as Vector2).y, Layout.CARD_MAX), "very long screen keeps the 122 card")
	_check((tall["hud"] as Rect2).position.y > (base["hud"] as Rect2).position.y, "very long screen adds top margin")
	_check((tall["tray"] as Rect2).position.y - (tall["tableau"] as Rect2).end.y > (base["tray"] as Rect2).position.y - (base["tableau"] as Rect2).end.y, "very long screen widens the gap under the tableau")
	var small: Dictionary = _compute(Vector2(390, 693), Vector2.ZERO, "step")
	_check(is_equal_approx((small["card"] as Vector2).y, Layout.CARD_MIN) and float(small["comfort"]) < 1.0, "small screen with two reserve rows keeps 84 by tightening the gaps")


## 지원 크기보다 낮은 화면은 통째로 줄인다(검수용 360×640 창, 세로가 짧은 기기).
func _short_screen_scales() -> void:
	var found: Dictionary = _compute(Vector2(360, 640), Vector2.ZERO, "step")
	_check(float(found["scale"]) < 1.0 and float(found["scale"]) > 0.85, "360x640 scales down a little")
	_check(float(found["bottom"]) <= (found["stage"] as Vector2).y + 0.01, "360x640 still fits after scaling")
	_check(is_equal_approx((found["card"] as Vector2).y, Layout.CARD_MIN), "360x640 keeps the 84 card in stage units")


func _safe_insets() -> void:
	var insets: Vector2 = Layout.safe_insets(Rect2i(0, 96, 1080, 2256), Vector2i(1080, 2400), 866.0)
	_check(is_equal_approx(insets.x, 96.0 * 866.0 / 2400.0) and is_equal_approx(insets.y, 48.0 * 866.0 / 2400.0), "safe area is converted to logical pixels")
	_check(Layout.safe_insets(Rect2i(0, 0, 1080, 2400), Vector2i(1080, 2400), 866.0) == Vector2.ZERO, "no cutout means no insets")
	_check(Layout.safe_insets(Rect2i(), Vector2i(1080, 2400), 866.0) == Vector2.ZERO, "an empty safe area is ignored")


## 모든 카드 이름이 가장 좁은 카드(받침의 80)에서 두 줄 안에 들어가야 한다. 큰 글자 설정에서도 그렇다.
func _card_names_fit() -> void:
	var content := Content.new(_read("res://data/content/items.json"), _read("res://data/content/categories.json"))
	var width: float = 80.0 - CardView.PAD_SIDE * 2.0
	for language: String in ["en", "ko"]:
		for large: bool in [false, true]:
			var cut: PackedStringArray = []
			for item: String in content.item_ids():
				var fit: Dictionary = CardView.fit_name(content.item_name(item, language), language, width, large)
				if not fit["fits"] or int(fit["lines"]) > CardView.NAME_LINES or int(fit["size"]) < CardView.NAME_MIN:
					cut.append(content.item_name(item, language))
			_check(cut.is_empty(), "%s card names fit in two lines (large text %s): %s" % [language, large, ", ".join(cut)])


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
