extends RefCounted
## 플레이 화면을 화면 좌표 입력으로만 모는 여정 도우미. 판의 상태는 읽기만 하고, 진행은 모두 드라이버의 tap과 drag로 한다.
## 대역은 광고와 시계뿐이다. 저장은 실행마다 새로 만든 경로를 쓴다.

const Solver := preload("res://game/core/domain/fa_solver.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const ClockPort := preload("res://game/core/ports/fa_clock_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

## 애니메이션이 끝나길 기다리는 한도(프레임). headless는 초당 약 145프레임, 렌더링은 60프레임이다.
const SETTLE_FRAMES := 1500


## 여정이 앞으로 돌릴 수 있는 시계. 광고 간격과 날짜 판정에 쓰인다.
class FakeClock extends ClockPort:
	var now: int = 1796126400  # 2026-12-01 12:00:00 UTC
	var date: String = "2026-12-01"

	func now_unix() -> int:
		return now

	func today() -> String:
		return date


## 보낸 분석 이벤트를 기억한다.
class Recorder extends AnalyticsPort:
	var events: Array[Dictionary] = []

	func log_event(name: String, params: Dictionary) -> void:
		events.append({"name": name, "params": params})

	func count(name: String) -> int:
		return events.filter(func(event: Dictionary) -> bool: return event["name"] == name).size()

	func last(name: String) -> Dictionary:
		for index: int in range(events.size() - 1, -1, -1):
			if events[index]["name"] == name:
				return events[index]["params"]
		return {}


var d: RefCounted
var main: Control


func _init(driver: RefCounted) -> void:
	d = driver


func play() -> Control:
	return main.play


func board() -> Board:
	return main.play.board


## 연출과 광고가 끝나 입력을 받을 때까지 기다린다.
func settle() -> bool:
	return await d.wait_for(func() -> bool: return main.play != null and main.play.idle(), SETTLE_FRAMES)


## 팝업이 다 열릴 때까지 기다린다. kind가 비어 있으면 어느 팝업이든 된다.
func popup_open(kind: String = "") -> bool:
	return await d.wait_for(func() -> bool:
		return main.play != null and main.play.popup != null and main.play.popup.state == "open" \
			and (kind.is_empty() or main.play.popup_kind == kind), SETTLE_FRAMES)


func popup_closed() -> bool:
	return await d.wait_for(func() -> bool: return main.play == null or main.play.popup == null, SETTLE_FRAMES)


func tap_card(card: String) -> bool:
	return await d.tap(main.play.card_view(card))


func tap_popup(button_name: String) -> bool:
	return await d.tap(main.play.popup_button(button_name))


## 열린 카드 네 장을 차례로 누르고 묶기를 누른다. 연출이 끝날 때까지 기다린다.
func submit(cards: Array) -> bool:
	for card: String in cards:
		if not main.play.selection.has(card) and not await tap_card(card):
			return false
	if main.play.selection.size() != cards.size() or not await d.tap(main.play.submit_button):
		return false
	return await d.wait_for(func() -> bool: return main.play.idle() or main.play.popup != null or main.play.ad_showing, SETTLE_FRAMES)


## 열 맨 앞 카드를 누른 뒤 빈 임시 칸을 눌러 옮긴다.
func hold(card: String) -> bool:
	var slot: int = board().holds().find("")
	if slot == -1 or not await tap_card(card) or not await d.tap(main.play.hold_cell(slot)):
		return false
	return await d.wait_for(func() -> bool: return main.play.idle() or main.play.popup != null, SETTLE_FRAMES)


## 열린 카드를 범주별로 모은다.
func open_by_category() -> Dictionary:
	var groups: Dictionary = {}
	for entry: Dictionary in board().open_cards():
		var category: String = board().category_of(entry["card"])
		if not groups.has(category):
			groups[category] = []
		groups[category].append(entry["card"])
	return groups


## 네 장이 모두 열린 묶음. 없으면 빈 배열.
func open_group() -> Array:
	var groups: Dictionary = open_by_category()
	for category: String in groups:
		if groups[category].size() == Board.GROUP_SIZE:
			return groups[category]
	return []


## 판을 한 수 진행한다: 열린 묶음이 있으면 묶고, 없으면 해법 탐색기가 알려 준 열의 맨 앞 카드를 임시 칸으로 옮긴다.
func advance() -> bool:
	var group: Array = open_group()
	if not group.is_empty():
		return await submit(group)
	var column: int = Solver.solve_board(board(), board().slot_count())["next_hold"]
	if column == -1:
		return false
	return await hold(board().front_card(column))


## 판을 끝까지 푼다. 결과 창이나 광고가 뜨면 멈춘다.
func clear_board(max_moves: int = 40) -> bool:
	for move: int in max_moves:
		if board().is_won():
			return true
		if not await advance():
			return false
	return board().is_won()


## 오답이 되는 열린 카드 네 장. same이 3이면 세 장이 같은 범주(한 장 차이), 2면 같은 범주가 두 장 이하(그냥 오답)다.
## 열린 카드의 네 장 조합을 차례로 훑어 조건에 맞는 skip번째 조합을 돌려준다. 없으면 빈 배열.
func wrong_pick(same: int, skip: int = 0) -> Array:
	var open: Array = []
	for entry: Dictionary in board().open_cards():
		open.append(entry["card"])
	var seen: int = 0
	for a: int in open.size():
		for b: int in range(a + 1, open.size()):
			for c: int in range(b + 1, open.size()):
				for e: int in range(c + 1, open.size()):
					var cards: Array = [open[a], open[b], open[c], open[e]]
					var counts: Dictionary = {}
					for card: String in cards:
						var category: String = board().category_of(card)
						counts[category] = counts.get(category, 0) + 1
					var top: int = counts.values().max()
					if (same == 3 and top == 3) or (same != 3 and top <= 2):
						if seen == skip:
							return cards
						seen += 1
	return []


## 임시 칸으로 옮기면 "둘 수는 있지만 풀 수 없는" 상태가 되는 맨 앞 카드들(순서대로). 없으면 빈 배열.
func dead_end_holds() -> Array:
	return _dead_end_search(Board.from_dict(board().to_dict()), [])


func _dead_end_search(copy: Board, path: Array) -> Array:
	if not path.is_empty() and not copy.is_stuck() and not Solver.solve_board(copy, copy.slot_count())["solvable"]:
		return path
	if copy.is_stuck() or not copy.holds().has(""):
		return []
	for column: int in copy.column_count():
		var card: String = copy.front_card(column)
		if card.is_empty():
			continue
		var next: Board = Board.from_dict(copy.to_dict())
		next.hold(card)
		var found: Array = _dead_end_search(next, path + [card])
		if not found.is_empty():
			return found
	return []


## 임시 칸으로 옮기면 판이 막히는 맨 앞 카드들(순서대로). 지금 판의 사본으로 찾아본다. 없으면 빈 배열.
func stuck_holds() -> Array:
	return _stuck_search(Board.from_dict(board().to_dict()), [])


func _stuck_search(copy: Board, path: Array) -> Array:
	if copy.is_stuck():
		return path
	if not copy.holds().has(""):
		return []
	for column: int in copy.column_count():
		var card: String = copy.front_card(column)
		if card.is_empty():
			continue
		var next: Board = Board.from_dict(copy.to_dict())
		next.hold(card)
		var found: Array = _stuck_search(next, path + [card])
		if not found.is_empty():
			return found
	return []


## 화면에 보이는 플레이 화면의 조작 대상이 화면 안에 있고 서로 겹치지 않는지 본다. 문제가 없으면 "".
func fits() -> String:
	var screen := Rect2(Vector2.ZERO, Vector2(d.viewport.size))
	var screen_play: Control = main.play
	var named: Dictionary = {
		"pause": screen_play.pause_button, "coins": screen_play.coin_chip, "submit": screen_play.submit_button,
		"hint": screen_play.hint_button, "undo": screen_play.undo_button,
	}
	for index: int in board().categories().size():
		named["medal %d" % index] = screen_play.medal(index)
	for index: int in screen_play.hold_cell_count():
		named["hold %d" % index] = screen_play.hold_cell(index)
	for index: int in board().reserve().size():
		named["reserve %d" % index] = screen_play.reserve_cell(index)
	var cards: Dictionary = {}
	for entry: Dictionary in board().open_cards():
		cards[entry["card"]] = screen_play.card_view(entry["card"])
	for key: String in named:
		var rect: Rect2 = named[key].get_global_rect()
		if not screen.encloses(rect):
			return "%s leaves the screen: %s" % [key, rect]
	for key: String in cards:
		var view: Control = cards[key]
		if view == null:
			return "open card %s has no view" % key
		if not screen.encloses(view.get_global_rect()):
			return "card %s leaves the screen: %s" % [key, view.get_global_rect()]
		if not view.name_fits:
			return "card %s name is cut: %s" % [key, view.name_label.text]
		if view.get_global_rect().size.y < 84.0 * screen_play.stage_scale() - 0.5:
			return "card %s is shorter than 84: %s" % [key, view.get_global_rect().size]
	# 임시 칸과 예비 카드 줄의 카드, 아래 버튼은 서로 겹치지 않아야 한다.
	var solid: Array = [named["submit"], named["hint"], named["undo"]]
	for entry: Dictionary in board().open_cards():
		if entry["zone"] != Board.ZONE_COLUMN:
			solid.append(cards[entry["card"]])
	for first: int in solid.size():
		for second: int in range(first + 1, solid.size()):
			if solid[first].get_global_rect().grow(-1.0).intersects(solid[second].get_global_rect().grow(-1.0)):
				return "%s overlaps %s" % [solid[first].name, solid[second].name]
	# 누르는 영역은 48 이상이다(화면을 줄인 작은 화면에서는 그 비율만큼).
	var minimum: float = 48.0 * screen_play.stage_scale() - 0.5
	for key: String in ["pause", "submit", "hint", "undo"]:
		var size: Vector2 = named[key].get_global_rect().size
		if size.x < minimum or size.y < minimum:
			return "%s touch area is under 48: %s" % [key, size]
	return ""
