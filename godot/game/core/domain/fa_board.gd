class_name FaBoard
extends RefCounted
## 한 판의 상태와 규칙. 카드는 item id 문자열이고 어느 묶음인지는 레벨의 groups가 정한다.
## 열은 뒤에서 앞 순서로 담고 마지막 원소만 열려 있다. 예비 칸과 임시 칸은 자리를 유지하며 빈 자리는 "".

const Self := preload("res://game/core/domain/fa_board.gd")

const GROUP_SIZE := 4
const MISTAKE_LIMIT := 4
const HOLD_SLOTS_BASE := 2
const HOLD_SLOTS_MAX := 3
const CONTINUE_RESTORE := 2

const ZONE_COLUMN := "column"
const ZONE_RESERVE := "reserve"
const ZONE_HOLD := "hold"

const KIND_GROUP := "group"
const KIND_ONE_AWAY := "one_away"
const KIND_MISS := "miss"
const KIND_REPEAT := "repeat"
const KIND_INVALID := "invalid"

var _meta: Dictionary = {}
var _categories: Array[String] = []
var _group_items: Dictionary = {}
var _card_category: Dictionary = {}
var _cols: Array[Array] = []
var _reserve: Array[String] = []
var _holds: Array[String] = []
var _mistakes: int = 0
var _solved: Array[String] = []
var _undo: Dictionary = {}
var _continued: bool = false
var _tried: Dictionary = {}
var _hold_moves: int = 0


## 레벨과 임시 칸 수(2~3)로 새 판을 만든다. 레벨 형식이 틀리면 null.
static func create(level: Dictionary, hold_slots: int) -> Self:
	if hold_slots < HOLD_SLOTS_BASE or hold_slots > HOLD_SLOTS_MAX:
		return null
	var holds: Array = []
	holds.resize(hold_slots)
	holds.fill("")
	var state: Dictionary = level.duplicate()
	state.merge({
		"holds": holds, "mistakes": 0, "solved": [], "undo": {},
		"continued": false, "tried": [], "hold_moves": 0,
	}, true)
	return from_dict(state)


## to_dict()가 만든 상태에서 판을 되살린다. 형식이 틀리거나 카드가 맞지 않으면 null.
static func from_dict(data: Dictionary) -> Self:
	var board: Self = new()
	return board if board._load(data) else null


func to_dict() -> Dictionary:
	var groups: Array = []
	for category: String in _categories:
		groups.append({"cat": category, "items": _group_items[category].duplicate()})
	var cols: Array = []
	for column: Array in _cols:
		cols.append(column.duplicate())
	var data: Dictionary = _meta.duplicate()
	data.merge({
		"groups": groups, "cols": cols, "reserve": _reserve.duplicate(), "holds": _holds.duplicate(),
		"mistakes": _mistakes, "solved": _solved.duplicate(), "undo": _undo.duplicate(),
		"continued": _continued, "tried": _tried.keys(), "hold_moves": _hold_moves,
	})
	return data


## 레벨 정보 {n, layout, tier, f}. 레벨에 없던 값은 0, "", 0, 0.0이다.
func meta() -> Dictionary:
	return _meta.duplicate()


## 이 판의 범주 id(레벨의 묶음 순서).
func categories() -> Array[String]:
	return _categories.duplicate()


func group_items(category: String) -> Array[String]:
	var items: Array[String] = []
	if _group_items.has(category):
		items.assign(_group_items[category])
	return items


## 카드가 속한 범주 id. 이 판의 카드가 아니면 "".
func category_of(card: String) -> String:
	return _card_category.get(card, "")


func column_count() -> int:
	return _cols.size()


## 열에 남은 카드 수(열린 맨 앞 카드 포함).
func column_size(column: int) -> int:
	return _cols[column].size()


## 열에서 뒤집혀 있는 카드 수.
func hidden_count(column: int) -> int:
	return maxi(0, _cols[column].size() - 1)


## 열의 맨 앞(열린) 카드. 빈 열이면 "".
func front_card(column: int) -> String:
	return "" if _cols[column].is_empty() else _cols[column].back()


## 열의 카드 전체(뒤에서 앞 순서). 뒤집힌 카드도 들어 있으므로 해법 탐색과 검수에만 쓴다.
func column_cards(column: int) -> Array[String]:
	var cards: Array[String] = []
	cards.assign(_cols[column])
	return cards


func reserve() -> Array[String]:
	return _reserve.duplicate()


func holds() -> Array[String]:
	return _holds.duplicate()


func slot_count() -> int:
	return _holds.size()


## 열린 카드와 위치. 순서는 열, 예비 칸, 임시 칸이고 한 항목은 {card, zone, index}다.
func open_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for index: int in _cols.size():
		if not _cols[index].is_empty():
			cards.append(_place(_cols[index].back(), ZONE_COLUMN, index))
	for index: int in _reserve.size():
		if not _reserve[index].is_empty():
			cards.append(_place(_reserve[index], ZONE_RESERVE, index))
	for index: int in _holds.size():
		if not _holds[index].is_empty():
			cards.append(_place(_holds[index], ZONE_HOLD, index))
	return cards


## 카드가 열려 있어 선택할 수 있는지.
func can_select(card: String) -> bool:
	return not _locate(card).is_empty()


## 카드를 지금 임시 칸으로 옮길 수 있는지.
func can_hold(card: String) -> bool:
	return not is_won() and not is_failed() and _front_column(card) != -1 and _holds.has("")


func mistakes() -> int:
	return _mistakes


## 완성한 묶음의 범주 id(완성 순서).
func solved() -> Array[String]:
	return _solved.duplicate()


func remaining_groups() -> int:
	return _categories.size() - _solved.size()


## 임시 칸으로 옮긴 횟수. 되돌린 이동은 세지 않는다.
func hold_moves() -> int:
	return _hold_moves


func can_undo() -> bool:
	return not _undo.is_empty() and not is_failed()


func can_unlock_slot() -> bool:
	return _holds.size() < HOLD_SLOTS_MAX and not is_won()


func continue_used() -> bool:
	return _continued


func can_continue() -> bool:
	return is_failed() and not _continued


func is_won() -> bool:
	return _solved.size() == _categories.size()


func is_failed() -> bool:
	return _mistakes >= MISTAKE_LIMIT


## 열린 카드로 완성할 묶음이 없고, 임시 칸이 가득 찼거나 옮길 열이 없는 상태. 실수 횟수와 무관하다.
func is_stuck() -> bool:
	if is_won() or _has_open_group():
		return false
	if not _holds.has(""):
		return true
	for column: Array in _cols:
		if not column.is_empty():
			return false
	return true


## 열린 카드 중 같은 범주 2장. 열린 카드가 가장 많은 묶음을 고르고, 같으면 레벨의 묶음 순서를 따른다. 없으면 빈 배열.
func hint_pair() -> Array[String]:
	var by_category: Dictionary = _open_by_category()
	var best: Array = []
	for category: String in _categories:
		var cards: Array = by_category.get(category, [])
		if cards.size() >= 2 and cards.size() > best.size():
			best = cards
	var pair: Array[String] = []
	if not best.is_empty():
		pair.assign(best.slice(0, 2))
	return pair


## 열린 카드 4장을 묶는다. 결과 kind는 group, one_away, miss, repeat, invalid 중 하나다.
func submit(cards: Array) -> Dictionary:
	if is_won():
		return _rejected("finished")
	if is_failed():
		return _rejected("failed")
	if cards.size() != GROUP_SIZE:
		return _rejected("count")
	var places: Array[Dictionary] = []
	var counts: Dictionary = {}
	for card: Variant in cards:
		var place: Dictionary = _locate(card) if card is String else {}
		if place.is_empty():
			return _rejected("not_open")
		if places.has(place):
			return _rejected("duplicate")
		places.append(place)
		var category: String = _card_category[card]
		counts[category] = counts.get(category, 0) + 1
	var top_category: String = ""
	for category: String in counts:
		if counts[category] > counts.get(top_category, 0):
			top_category = category
	if counts[top_category] == GROUP_SIZE:
		return _complete(top_category, places)
	var key: String = _combination_key(cards)
	if _tried.has(key):
		return _outcome(KIND_REPEAT)
	_tried[key] = true
	_mistakes += 1
	return _outcome(KIND_ONE_AWAY if counts[top_category] == GROUP_SIZE - 1 else KIND_MISS)


## 열 맨 앞 카드를 첫 빈 임시 칸으로 옮긴다.
func hold(card: String) -> Dictionary:
	if is_won():
		return {"ok": false, "reason": "finished"}
	if is_failed():
		return {"ok": false, "reason": "failed"}
	var column: int = _front_column(card)
	if column == -1:
		return {"ok": false, "reason": "not_front"}
	var slot: int = _holds.find("")
	if slot == -1:
		return {"ok": false, "reason": "no_slot"}
	_cols[column].pop_back()
	_holds[slot] = card
	_undo = {"card": card, "column": column, "slot": slot}
	_hold_moves += 1
	return {"ok": true, "card": card, "column": column, "slot": slot, "opened": front_card(column)}


## 마지막 임시 칸 이동 하나를 취소한다. 묶음이 완성된 뒤에는 되돌릴 기록이 없다.
func undo() -> Dictionary:
	if _undo.is_empty():
		return {"ok": false, "reason": "nothing"}
	if is_failed():
		return {"ok": false, "reason": "failed"}
	var card: String = _undo["card"]
	var column: int = _undo["column"]
	var slot: int = _undo["slot"]
	var closed: String = front_card(column)
	_cols[column].append(card)
	_holds[slot] = ""
	_undo = {}
	_hold_moves -= 1
	return {"ok": true, "card": card, "column": column, "slot": slot, "closed": closed}


## 이번 판의 임시 칸을 3개로 늘린다. 판당 1회.
func unlock_slot() -> bool:
	if not can_unlock_slot():
		return false
	_holds.append("")
	return true


## 실패한 판을 이어 간다. 실수를 2 줄이고 판당 1회만 된다.
func apply_continue() -> bool:
	if not can_continue():
		return false
	_mistakes -= CONTINUE_RESTORE
	_continued = true
	return true


func _place(card: String, zone: String, index: int) -> Dictionary:
	return {"card": card, "zone": zone, "index": index}


func _front_column(card: String) -> int:
	for index: int in _cols.size():
		if not _cols[index].is_empty() and _cols[index].back() == card:
			return index
	return -1


func _locate(card: String) -> Dictionary:
	if card.is_empty():
		return {}
	var index: int = _front_column(card)
	if index != -1:
		return _place(card, ZONE_COLUMN, index)
	index = _reserve.find(card)
	if index != -1:
		return _place(card, ZONE_RESERVE, index)
	index = _holds.find(card)
	if index != -1:
		return _place(card, ZONE_HOLD, index)
	return {}


func _open_by_category() -> Dictionary:
	var by_category: Dictionary = {}
	for entry: Dictionary in open_cards():
		var category: String = _card_category[entry["card"]]
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(entry["card"])
	return by_category


func _has_open_group() -> bool:
	for cards: Array in _open_by_category().values():
		if cards.size() == GROUP_SIZE:
			return true
	return false


func _combination_key(cards: Array) -> String:
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort()
	return "|".join(sorted_cards)


func _outcome(kind: String) -> Dictionary:
	return {"kind": kind, "mistakes": _mistakes, "won": is_won(), "failed": is_failed()}


func _rejected(reason: String) -> Dictionary:
	var result: Dictionary = _outcome(KIND_INVALID)
	result["reason"] = reason
	return result


func _complete(category: String, places: Array[Dictionary]) -> Dictionary:
	var touched: Array[int] = []
	for place: Dictionary in places:
		var index: int = place["index"]
		match place["zone"]:
			ZONE_COLUMN:
				_cols[index].pop_back()
				touched.append(index)
			ZONE_RESERVE:
				_reserve[index] = ""
			ZONE_HOLD:
				_holds[index] = ""
	touched.sort()
	var opened: Array[Dictionary] = []
	for index: int in touched:
		if not _cols[index].is_empty():
			opened.append(_place(_cols[index].back(), ZONE_COLUMN, index))
	_solved.append(category)
	_undo = {}
	var result: Dictionary = _outcome(KIND_GROUP)
	result["category"] = category
	result["removed"] = places
	result["opened"] = opened
	return result


func _load(data: Dictionary) -> bool:
	return _load_meta(data) and _load_groups(data.get("groups")) and _load_zones(data) \
		and _load_progress(data) and _cards_match()


func _load_meta(data: Dictionary) -> bool:
	var number: Variant = data.get("n", 0)
	var layout: Variant = data.get("layout", "")
	var tier: Variant = data.get("tier", 0)
	var forgiveness: Variant = data.get("f", 0.0)
	if not (_is_whole(number) and layout is String and _is_whole(tier) and (forgiveness is float or forgiveness is int)):
		return false
	_meta = {"n": int(number), "layout": layout, "tier": int(tier), "f": float(forgiveness)}
	return true


func _load_groups(groups: Variant) -> bool:
	if not groups is Array or groups.is_empty():
		return false
	for group: Variant in groups:
		if not group is Dictionary:
			return false
		var category: Variant = group.get("cat")
		var items: Variant = group.get("items")
		if not _is_card(category) or _group_items.has(category):
			return false
		if not items is Array or items.size() != GROUP_SIZE:
			return false
		var typed: Array[String] = []
		for item: Variant in items:
			if not _is_card(item) or _card_category.has(item):
				return false
			_card_category[item] = category
			typed.append(item)
		_categories.append(category)
		_group_items[category] = typed
	return true


func _load_zones(data: Dictionary) -> bool:
	var cols: Variant = data.get("cols")
	var holds: Variant = data.get("holds")
	if not cols is Array or cols.is_empty() or not holds is Array:
		return false
	if holds.size() < HOLD_SLOTS_BASE or holds.size() > HOLD_SLOTS_MAX:
		return false
	for column: Variant in cols:
		var typed: Array[String] = []
		if not _load_cards(column, typed, false):
			return false
		_cols.append(typed)
	return _load_cards(data.get("reserve"), _reserve, true) and _load_cards(holds, _holds, true)


func _load_cards(source: Variant, target: Array[String], allow_empty: bool) -> bool:
	if not source is Array:
		return false
	for card: Variant in source:
		if not card is String or (card.is_empty() and not allow_empty):
			return false
		target.append(card)
	return true


func _load_progress(data: Dictionary) -> bool:
	var mistakes: Variant = data.get("mistakes")
	var solved: Variant = data.get("solved")
	var undo_record: Variant = data.get("undo")
	var tried: Variant = data.get("tried")
	var hold_moves: Variant = data.get("hold_moves")
	if not _is_whole(mistakes) or mistakes < 0 or mistakes > MISTAKE_LIMIT:
		return false
	if not solved is Array or not tried is Array or not data.get("continued") is bool:
		return false
	if not _is_whole(hold_moves) or hold_moves < 0 or not undo_record is Dictionary:
		return false
	for category: Variant in solved:
		if not category is String or not _group_items.has(category) or _solved.has(category):
			return false
		_solved.append(category)
	for key: Variant in tried:
		if not key is String:
			return false
		_tried[key] = true
	_mistakes = int(mistakes)
	_continued = data["continued"]
	_hold_moves = int(hold_moves)
	return undo_record.is_empty() or _load_undo(undo_record)


func _load_undo(record: Dictionary) -> bool:
	var card: Variant = record.get("card")
	var column: Variant = record.get("column")
	var slot: Variant = record.get("slot")
	if not (_is_card(card) and _is_whole(column) and _is_whole(slot)):
		return false
	if column < 0 or column >= _cols.size() or slot < 0 or slot >= _holds.size() or _holds[int(slot)] != card:
		return false
	_undo = {"card": card, "column": int(column), "slot": int(slot)}
	return true


## 남은 묶음의 카드는 모두 한 번씩 놓여 있고, 완성한 묶음의 카드는 어디에도 없어야 한다.
func _cards_match() -> bool:
	var placed: Dictionary = {}
	var zones: Array = _cols.duplicate()
	zones.append(_reserve)
	zones.append(_holds)
	for zone: Array in zones:
		for card: String in zone:
			if card.is_empty():
				continue
			if not _card_category.has(card) or placed.has(card) or _solved.has(_card_category[card]):
				return false
			placed[card] = true
	return placed.size() == remaining_groups() * GROUP_SIZE


static func _is_card(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and value == floorf(value))
