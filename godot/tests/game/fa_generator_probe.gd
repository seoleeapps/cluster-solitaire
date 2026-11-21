extends SceneTree
## 생성기 검사: 난수열 고정값, 같은 시드의 재현성, 등급별 조건, 유일성과 후보 겹침 한도, 100개 시드 무실패.

const Content := preload("res://game/core/domain/fa_content.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Solver := preload("res://game/core/domain/fa_solver.gd")
const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const Random := preload("res://game/core/domain/fa_random.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")

const SEEDS_PER_TIER := 20

var _checks: int = 0
var _failed: PackedStringArray = []
var _content: Content


func _initialize() -> void:
	_content = Content.new(_read("res://data/content/items.json"), _read("res://data/content/categories.json"))
	_section("난수열", _random)
	_section("재현성", _determinism)
	_section("등급별 조건", _tier_rules)
	_section("최근 범주 제외", _recent)
	_section("묶는 방법 세기", _groupings)
	_section("헷갈리는 카드 한도", _confusable_limits)
	_section("판 밖 범주 한도", _outside_limit)
	_section("여정과 일일 도전 레벨", _named_levels)
	print("Fa generator probe: %d checks, %d failed" % [_checks, _failed.size()])
	for line: String in _failed:
		print("  FAILED ", line)
	quit(0 if _failed.is_empty() else 1)


func _section(title: String, body: Callable) -> void:
	if body.call() != true:
		_failed.append(title + ": 끝까지 실행되지 않음")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failed.append(label)


func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _draws(seed_value: int, count: int) -> Array:
	var random: Random = Random.new(seed_value)
	var values: Array = []
	for _index: int in count:
		values.append(random.next_u32())
	return values


## 기대값은 Mulberry32 원본의 32비트 연산을 Python으로 옮겨 구했다.
func _random() -> bool:
	_check(_draws(0, 4) == [1144304738, 1416247, 958946056, 627933444], "시드 0의 난수열")
	_check(_draws(1, 4) == [2693262067, 11749833, 2265367787, 4213581821], "시드 1의 난수열")
	_check(_draws(20261121, 4) == [2969524423, 1512158564, 2312278096, 4216257302], "큰 시드의 난수열")
	_check(_draws((1 << 40) + 5, 4) == [784168230, 1995205153, 1340320920, 1819642100], "32비트를 넘는 시드는 위아래를 섞어 쓴다")
	var random: Random = Random.new(7)
	var picks: Array = []
	for _index: int in 12:
		picks.append(random.below(10))
	_check(picks == [0, 0, 9, 6, 5, 4, 4, 2, 5, 7, 2, 1], "범위 안의 정수")
	var deck: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	Random.new(7).shuffle(deck)
	_check(deck == [6, 5, 8, 1, 2, 3, 4, 7, 9, 0], "섞기")
	return true


func _determinism() -> bool:
	for tier: int in range(Difficulty.TIER_MIN, Difficulty.TIER_MAX + 1):
		var first: Dictionary = Generator.generate(_content, 4242, tier, [])
		var second: Dictionary = Generator.generate(_content, 4242, tier, [])
		_check(first["ok"] and JSON.stringify(first) == JSON.stringify(second), "T%d: 같은 시드는 같은 레벨" % tier)
		_check(first.keys() == ["ok", "attempts", "level"] and first["attempts"] >= 1 and first["attempts"] <= Generator.CATEGORY_ATTEMPTS, "T%d: 범주를 고른 횟수를 함께 돌려준다" % tier)
		var other: Dictionary = Generator.generate(_content, 4243, tier, [])
		_check(other["ok"] and JSON.stringify(first["level"]) != JSON.stringify(other["level"]), "T%d: 다른 시드는 다른 레벨" % tier)
	_check(Generator.generate(_content, 1, 0, []) == {"ok": false, "error": "bad_tier"}, "없는 등급은 오류")
	_check(Generator.generate(_content, 1, 6, [])["error"] == "bad_tier", "범위 밖 등급은 오류")
	return true


func _flat(level: Dictionary) -> Array:
	var cards: Array = []
	for column: Array in level["cols"]:
		cards.append_array(column)
	cards.append_array(level["reserve"])
	return cards


## 레벨이 등급 조건을 모두 지키는지 본다. 어긴 조건의 이름을 돌려주고 없으면 빈 배열이다.
func _violations(content: Content, level: Dictionary, tier: int) -> Array:
	var rule: Dictionary = Difficulty.tier_rule(tier)
	var broken: Array = []
	if level.get("tier") != tier or not rule["layouts"].has(level.get("layout")):
		return ["tier_or_layout"]
	var layout: Dictionary = Difficulty.layout(level["layout"])
	var depths: Array = []
	for column: Array in level["cols"]:
		depths.append(column.size())
	if depths != layout["columns"] or level["reserve"].size() != layout["reserve"]:
		broken.append("layout_shape")

	var categories: Array = []
	var cards: Array = []
	var domains: Dictionary = {}
	for group: Dictionary in level["groups"]:
		var category: String = group["cat"]
		categories.append(category)
		if content.category_tier(category) < 1 or content.category_tier(category) > rule["category_tier_max"]:
			broken.append("category_tier")
		domains[content.category_domain(category)] = domains.get(content.category_domain(category), 0) + 1
		for item: String in group["items"]:
			if not content.category_members(category).has(item):
				broken.append("not_member")
			cards.append(item)
	if categories.size() != layout["groups"]:
		broken.append("group_count")
	if domains.values().max() > rule["domain_max"]:
		broken.append("domain")
	var sorted_cards: Array = cards.duplicate()
	sorted_cards.sort()
	var sorted_placed: Array = _flat(level)
	sorted_placed.sort()
	if sorted_cards != sorted_placed:
		broken.append("placement")

	var confusable: int = 0
	var outside: Dictionary = {}
	for group: Dictionary in level["groups"]:
		for item: String in group["items"]:
			var also_inside: bool = false
			for owner: String in content.categories_of_item(item):
				if owner == group["cat"]:
					continue
				if categories.has(owner):
					also_inside = true
				else:
					outside[owner] = outside.get(owner, 0) + 1
			if also_inside:
				confusable += 1
	if confusable > rule["confusable_max"]:
		broken.append("confusable")
	if not outside.is_empty() and outside.values().max() > rule["outside_max"]:
		broken.append("outside")
	if Generator.count_groupings(content, categories, cards, 2) != 1:
		broken.append("uniqueness")

	var board: Board = Board.create(level.merged({"n": 1}), Board.HOLD_SLOTS_BASE)
	if board == null:
		broken.append("board")
		return broken
	var solved: Dictionary = Solver.solve_board(board, Board.HOLD_SLOTS_BASE)
	if not solved["solvable"]:
		broken.append("unsolvable")
	if solved["forgiveness"] < rule["f_min"] or solved["forgiveness"] > rule["f_max"]:
		broken.append("forgiveness_range")
	if absf(level["f"] - solved["forgiveness"]) > 0.005 + 1e-9 or level["f"] != roundf(level["f"] * 100.0) / 100.0:
		broken.append("forgiveness_value")
	return broken


func _tier_rules() -> bool:
	var layouts_seen: Dictionary = {}
	var failures: int = 0
	for tier: int in range(Difficulty.TIER_MIN, Difficulty.TIER_MAX + 1):
		for index: int in SEEDS_PER_TIER:
			var result: Dictionary = Generator.generate(_content, 1000 * tier + index, tier, [])
			if not result["ok"]:
				failures += 1
				_check(false, "T%d 시드 %d 생성 실패: %s" % [tier, index, result["error"]])
				continue
			var broken: Array = _violations(_content, result["level"], tier)
			_check(broken.is_empty(), "T%d 시드 %d가 어긴 조건: %s" % [tier, index, broken])
			_check(result["level"].keys() == ["layout", "tier", "f", "groups", "cols", "reserve"], "T%d 시드 %d의 필드 순서" % [tier, index])
			layouts_seen["%d %s" % [tier, result["level"]["layout"]]] = true
	_check(failures == 0, "100개 시드에서 실패 없음(실패 %d)" % failures)
	_check(layouts_seen.has("4 classic") and layouts_seen.has("4 deep"), "T4는 두 배치를 모두 쓴다")
	return true


func _recent() -> bool:
	var first: Dictionary = Generator.generate(_content, 77, 3, [])
	var used: Array = []
	for group: Dictionary in first["level"]["groups"]:
		used.append(group["cat"])
	var second: Dictionary = Generator.generate(_content, 77, 3, used)
	_check(second["ok"], "최근 범주를 빼고도 만든다")
	for group: Dictionary in second["level"]["groups"]:
		_check(not used.has(group["cat"]), "최근 쓴 범주 %s는 다시 쓰지 않는다" % group["cat"])

	var recent: Array = Array(_content.category_ids()).slice(0, 84)
	for seed_value: int in range(1, 11):
		var result: Dictionary = Generator.generate(_content, seed_value, 3, recent)
		var clean: bool = result["ok"]
		if clean:
			for group: Dictionary in result["level"]["groups"]:
				clean = clean and not recent.has(group["cat"])
		_check(clean, "범주 84개를 빼도 만든다(시드 %d)" % seed_value)
	_check(Generator.generate(_content, 1, 3, Array(_content.category_ids())) == {"ok": false, "error": "no_categories"}, "남은 범주가 없으면 오류")
	return true


func _small_items() -> Dictionary:
	var items: Array = []
	for prefix: String in ["a", "b", "c", "d", "x"]:
		for number: int in range(1, 5):
			var id: String = "%s%d" % [prefix, number]
			items.append({"id": id, "icon": id, "en": id.to_upper(), "ko": id})
	return {"version": 1, "items": items}


## 범주마다 소속이 4장뿐인 작은 콘텐츠. also에 범주별로 더할 카드를 준다.
func _small_content(also: Dictionary, with_extra: bool = false) -> Content:
	var categories: Array = []
	for prefix: String in ["a", "b", "c", "d"]:
		categories.append({
			"id": prefix.to_upper(), "tier": 1, "domain": "domain_" + prefix, "en": prefix, "ko": prefix,
			"members": ["%s1" % prefix, "%s2" % prefix, "%s3" % prefix, "%s4" % prefix],
			"also": also.get(prefix.to_upper(), []),
		})
	if with_extra:
		categories.append({
			"id": "X", "tier": 4, "domain": "domain_x", "en": "x", "ko": "x",
			"members": ["x1", "x2", "x3", "x4"], "also": also.get("X", []),
		})
	return Content.new(_small_items(), {"version": 1, "categories": categories})


func _groupings() -> bool:
	var categories: Array = ["A", "B", "C", "D"]
	var cards: Array = ["a1", "a2", "a3", "a4", "b1", "b2", "b3", "b4", "c1", "c2", "c3", "c4", "d1", "d2", "d3", "d4"]
	_check(Generator.count_groupings(_small_content({}), categories, cards, 2) == 1, "겹침이 없으면 한 가지")
	_check(Generator.count_groupings(_small_content({"B": ["a4"]}), categories, cards, 2) == 1, "한쪽으로만 겹치면 한 가지")
	_check(Generator.count_groupings(_small_content({"B": ["a4"], "A": ["b4"]}), categories, cards, 2) == 2, "서로 바꿀 수 있으면 두 가지")
	var cycle: Content = _small_content({"B": ["a4"], "C": ["b4"], "A": ["c4"]})
	_check(Generator.count_groupings(cycle, categories, cards, 2) == 2, "세 범주가 돌려 가질 수 있어도 두 가지 이상")
	var many: Content = _small_content({"B": ["a3", "a4"], "A": ["b3", "b4"]})
	_check(Generator.count_groupings(many, categories, cards, 100) == 6, "상한을 크게 주면 모든 방법을 센다")
	_check(Generator.count_groupings(many, categories, cards, 2) == 2, "상한에 닿으면 세기를 멈춘다")
	_check(Generator.count_groupings(_small_content({}), categories, cards.slice(0, 15) + ["x1"], 2) == 0, "후보가 없는 카드가 있으면 0")
	return true


func _confusable_limits() -> bool:
	var one: Content = _small_content({"B": ["a4"]})
	_check(Generator.generate(one, 5, 3, []) == {"ok": false, "error": "exhausted"}, "T3은 다른 범주로도 보이는 카드를 쓰지 않는다")
	var result: Dictionary = Generator.generate(one, 5, 4, [])
	_check(result["ok"] and _violations(one, result["level"], 4).is_empty(), "T4는 그런 카드 1장을 허용한다")

	var swap: Content = _small_content({"B": ["a4"], "A": ["b4"]})
	_check(Generator.generate(swap, 5, 4, [])["error"] == "exhausted", "T4는 2장을 허용하지 않는다")
	_check(Generator.generate(swap, 5, 5, [])["error"] == "exhausted", "T5도 묶는 방법이 둘이면 만들지 않는다")

	var two: Content = _small_content({"B": ["a4"], "D": ["c4"]})
	_check(Generator.generate(two, 5, 4, [])["error"] == "exhausted", "T4는 서로 다른 범주의 2장도 허용하지 않는다")
	result = Generator.generate(two, 5, 5, [])
	_check(result["ok"] and _violations(two, result["level"], 5).is_empty(), "T5는 2장을 허용한다")
	return true


func _outside_limit() -> bool:
	var three: Content = _small_content({"X": ["a1", "a2", "a3"]}, true)
	_check(Generator.generate(three, 9, 1, [])["error"] == "exhausted", "T1은 판 밖 범주의 후보가 3장이면 만들지 않는다")
	_check(Generator.generate(three, 9, 2, [])["error"] == "exhausted", "T2도 같다")
	var result: Dictionary = Generator.generate(three, 9, 3, [])
	_check(result["ok"] and _violations(three, result["level"], 3).is_empty(), "T3은 3장까지 허용한다")
	var four: Content = _small_content({"X": ["a1", "a2", "a3", "a4"]}, true)
	_check(Generator.generate(four, 9, 3, [])["error"] == "exhausted", "T3도 4장이면 만들지 않는다")
	var two: Content = _small_content({"X": ["a1", "a2"]}, true)
	result = Generator.generate(two, 9, 1, [])
	_check(result["ok"] and _violations(two, result["level"], 1).is_empty(), "T1은 2장까지 허용한다")
	return true


func _named_levels() -> bool:
	_check(Generator.VERSION == 1, "생성기 버전")
	var journey: Dictionary = Generator.journey_level(_content, 7, [])
	_check(journey["ok"] and journey["level"]["n"] == 7 and journey["level"]["tier"] == Difficulty.journey_tier(7), "여정 레벨의 번호와 등급")
	_check(journey["level"].keys() == ["n", "layout", "tier", "f", "groups", "cols", "reserve"], "여정 레벨의 필드 순서")
	_check(JSON.stringify(journey) == JSON.stringify(Generator.journey_level(_content, 7, [])), "같은 스테이지는 같은 레벨")
	var late: Dictionary = Generator.journey_level(_content, 601, [])
	_check(late["ok"] and late["level"]["n"] == 601 and late["level"]["tier"] == 3, "팩 뒤의 스테이지도 번호로 만든다")
	_check(Board.create(late["level"], Board.HOLD_SLOTS_BASE) != null, "만든 레벨로 판을 시작할 수 있다")

	var weekday: Dictionary = Generator.daily_level(_content, 1, [])
	_check(Daily.weekday(Daily.challenge_date(1)) == 2 and weekday["level"]["tier"] == 3 and weekday["level"]["n"] == 1, "일일 도전 1번은 화요일이라 T3")
	var weekend: Dictionary = Generator.daily_level(_content, 5, [])
	_check(Daily.weekday(Daily.challenge_date(5)) == 6 and weekend["level"]["tier"] == 4, "일일 도전 5번은 토요일이라 T4")
	_check(JSON.stringify(weekday["level"]["groups"]) != JSON.stringify(Generator.journey_level(_content, 1, [])["level"]["groups"]), "여정과 일일 도전은 같은 번호라도 다른 판")
	return true
