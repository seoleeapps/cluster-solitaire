class_name FaGenerator
extends RefCounted
## 레벨 생성기. 콘텐츠, 시드, 등급, 최근 사용 범주가 같으면 어느 기기에서나 같은 레벨을 만든다.
## 범주 4개와 카드 16장을 고르고, 묶는 방법이 하나뿐인지 전수 확인한 뒤,
## 임시 칸 2개로 풀리고 관대함이 등급 범위에 드는 배치가 나올 때까지 카드를 다시 놓는다.
## 결과는 {ok: true, level, attempts} 또는 {ok: false, error}이고 error는 bad_tier, no_categories, exhausted 중 하나다.
## attempts는 범주를 고른 횟수다. 1이면 처음 고른 범주로 만들었다는 뜻이고 팩 통계에 쓴다.

const Self := preload("res://game/core/domain/fa_generator.gd")
const Content := preload("res://game/core/domain/fa_content.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Random := preload("res://game/core/domain/fa_random.gd")

## 팩의 generator 값. 같은 입력에서 다른 레벨이 나오게 고치면 올린다.
const VERSION := 1
## 범주를 다시 고르는 횟수의 상한. 넘으면 exhausted로 끝낸다.
const CATEGORY_ATTEMPTS := 200
## 한 범주 조합에서 카드를 다시 놓는 횟수의 상한.
const PLACEMENT_ATTEMPTS := 80
## 일일 도전 시드는 여정 스테이지 번호와 겹치지 않게 띄운다.
const DAILY_SEED_BASE := 1 << 24
## 여정은 최근 3판, 일일 도전은 최근 21일의 범주를 다시 쓰지 않는다. recent를 꾸리는 쪽이 이 길이를 쓴다.
const JOURNEY_RECENT_LEVELS := 3
const DAILY_RECENT_LEVELS := 21

var _content: Content
var _random: Random
var _rule: Dictionary


## 레벨 {layout, tier, f, groups, cols, reserve}를 만든다. recent의 범주는 쓰지 않는다.
static func generate(content: Content, seed_value: int, tier: int, recent: Array) -> Dictionary:
	var rule: Dictionary = Difficulty.tier_rule(tier)
	if rule.is_empty():
		return _failure("bad_tier")
	var generator: Self = new()
	generator._content = content
	generator._random = Random.new(seed_value)
	generator._rule = rule
	return generator._build(tier, recent)


## 여정 스테이지의 레벨. 시드는 스테이지 번호이고 등급은 순환표를 따른다. 레벨에 n이 붙는다.
static func journey_level(content: Content, stage: int, recent: Array) -> Dictionary:
	return _numbered(stage, generate(content, stage, Difficulty.journey_tier(stage), recent))


## 일일 도전 번호(1부터)의 레벨. 등급은 그 번호의 날짜가 무슨 요일인지로 정한다.
static func daily_level(content: Content, number: int, recent: Array) -> Dictionary:
	var tier: int = Difficulty.daily_tier(Daily.weekday(Daily.challenge_date(number)))
	return _numbered(number, generate(content, DAILY_SEED_BASE + number, tier, recent))


## cards를 categories의 후보 기준으로 범주마다 4장씩 나누는 방법의 수. limit에 닿으면 세기를 멈춘다.
static func count_groupings(content: Content, categories: Array, cards: Array, limit: int) -> int:
	var options: Array[Array] = []
	for card: String in cards:
		var allowed: Array[int] = []
		for index: int in categories.size():
			if content.is_candidate(categories[index], card):
				allowed.append(index)
		options.append(allowed)
	var sizes: Array[int] = []
	sizes.resize(categories.size())
	sizes.fill(0)
	return _count_from(options, 0, sizes, limit)


static func _count_from(options: Array[Array], position: int, sizes: Array[int], limit: int) -> int:
	if position == options.size():
		return 1
	var total: int = 0
	for index: int in options[position]:
		if sizes[index] == Board.GROUP_SIZE:
			continue
		sizes[index] += 1
		total += _count_from(options, position + 1, sizes, limit - total)
		sizes[index] -= 1
		if total >= limit:
			break
	return total


static func _numbered(number: int, result: Dictionary) -> Dictionary:
	if result["ok"]:
		var level: Dictionary = {"n": number}
		level.merge(result["level"])
		result["level"] = level
	return result


static func _failure(error: String) -> Dictionary:
	return {"ok": false, "error": error}


func _build(tier: int, recent: Array) -> Dictionary:
	var layout_ids: Array = _rule["layouts"]
	var layout_id: String = layout_ids[_random.below(layout_ids.size())]
	var layout: Dictionary = Difficulty.layout(layout_id)
	var pool: Array[String] = []
	for category: String in _content.category_ids():
		if _content.category_tier(category) <= _rule["category_tier_max"] and not recent.has(category):
			pool.append(category)
	for attempt: int in CATEGORY_ATTEMPTS:
		var categories: Array[String] = _pick_categories(pool, layout["groups"])
		if categories.size() < layout["groups"]:
			return _failure("no_categories")
		var groups: Array[Dictionary] = _pick_cards(categories)
		if groups.is_empty():
			continue
		var deck: Array[String] = []
		for group: Dictionary in groups:
			deck.append_array(group["items"])
		if count_groupings(_content, categories, deck, 2) != 1:
			continue
		var placed: Dictionary = _place(groups, deck, layout)
		if placed.is_empty():
			continue
		return {"ok": true, "attempts": attempt + 1, "level": {
			"layout": layout_id, "tier": tier, "f": placed["f"],
			"groups": groups, "cols": placed["cols"], "reserve": placed["reserve"],
		}}
	return _failure("exhausted")


## 대분류 조건을 지키는 범주를 무작위 순서로 count개 고른다. 모자라면 고른 만큼만 돌려준다.
func _pick_categories(pool: Array[String], count: int) -> Array[String]:
	var order: Array[String] = pool.duplicate()
	_random.shuffle(order)
	var chosen: Array[String] = []
	var per_domain: Dictionary = {}
	for category: String in order:
		var domain: String = _content.category_domain(category)
		if per_domain.get(domain, 0) >= _rule["domain_max"]:
			continue
		per_domain[domain] = per_domain.get(domain, 0) + 1
		chosen.append(category)
		if chosen.size() == count:
			break
	return chosen


## 범주마다 소속에서 4장을 고른다. 판의 다른 범주로도 보이는 카드와 판 밖 범주의 후보가 되는 카드는
## 등급의 한도까지만 받는다. 4장을 채우지 못한 범주가 있으면 빈 배열.
func _pick_cards(categories: Array[String]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var used: Dictionary = {}
	var outside: Dictionary = {}
	var confusable_left: int = _rule["confusable_max"]
	for category: String in categories:
		var members: Array = Array(_content.category_members(category))
		_random.shuffle(members)
		var items: Array[String] = []
		for item: String in members:
			if used.has(item):
				continue
			var confusable: bool = false
			var fits: bool = true
			var outsiders: Array[String] = []
			for owner: String in _content.categories_of_item(item):
				if owner == category:
					continue
				if categories.has(owner):
					confusable = true
				elif outside.get(owner, 0) >= _rule["outside_max"]:
					fits = false
				else:
					outsiders.append(owner)
			if not fits or (confusable and confusable_left == 0):
				continue
			if confusable:
				confusable_left -= 1
			for owner: String in outsiders:
				outside[owner] = outside.get(owner, 0) + 1
			used[item] = true
			items.append(item)
			if items.size() == Board.GROUP_SIZE:
				break
		if items.size() < Board.GROUP_SIZE:
			return []
		groups.append({"cat": category, "items": items})
	return groups


## 카드를 배치에 무작위로 놓고 탐색기로 확인한다. 조건에 맞는 배치 {cols, reserve, f}를 돌려주고 없으면 빈 값.
func _place(groups: Array[Dictionary], deck: Array[String], layout: Dictionary) -> Dictionary:
	var group_of: Dictionary = {}
	for index: int in groups.size():
		for item: String in groups[index]["items"]:
			group_of[item] = index
	for _attempt: int in PLACEMENT_ATTEMPTS:
		_random.shuffle(deck)
		var cols: Array = []
		var col_groups: Array = []
		var used: int = 0
		for depth: int in layout["columns"]:
			var column: Array[String] = deck.slice(used, used + depth)
			cols.append(column)
			col_groups.append(_groups_of(column, group_of))
			used += depth
		var reserve: Array[String] = deck.slice(used)
		var solved: Dictionary = Solver.solve(col_groups, _groups_of(reserve, group_of), [], Board.HOLD_SLOTS_BASE)
		var forgiveness: float = solved["forgiveness"]
		if solved["solvable"] and forgiveness >= _rule["f_min"] and forgiveness <= _rule["f_max"]:
			return {"cols": cols, "reserve": reserve, "f": roundf(forgiveness * 100.0) / 100.0}
	return {}


func _groups_of(cards: Array[String], group_of: Dictionary) -> Array:
	var groups: Array = []
	for card: String in cards:
		groups.append(group_of[card])
	return groups
