extends SceneTree
## 난도 검사: 배치 5종, 등급 T1~T5의 조건, 스테이지 번호별 등급 순환, 일일 도전의 요일별 등급.

const Difficulty := preload("res://game/core/domain/fa_difficulty.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("배치", _layouts)
	_section("등급 조건", _tiers)
	_section("여정 순환", _journey)
	_section("일일 도전 등급", _daily)
	print("Fa difficulty probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _layouts() -> bool:
	_check(Difficulty.layout_ids() == ["intro", "open", "step", "classic", "deep"], "배치 5종")
	_check(Difficulty.layout("intro") == {"groups": 3, "columns": [2, 2, 2, 2], "reserve": 4}, "intro")
	_check(Difficulty.layout("open") == {"groups": 4, "columns": [2, 2, 2, 2], "reserve": 8}, "open")
	_check(Difficulty.layout("step") == {"groups": 4, "columns": [3, 3, 2, 2], "reserve": 6}, "step")
	_check(Difficulty.layout("classic") == {"groups": 4, "columns": [3, 3, 3, 3], "reserve": 4}, "classic")
	_check(Difficulty.layout("deep") == {"groups": 4, "columns": [4, 3, 3, 2], "reserve": 4}, "deep")
	_check(Difficulty.layout("wide").is_empty(), "없는 배치는 빈 값")
	var first_open: Dictionary = {"intro": 8, "open": 12, "step": 10, "classic": 8, "deep": 8}
	for id: String in Difficulty.layout_ids():
		var layout: Dictionary = Difficulty.layout(id)
		var in_columns: int = 0
		for depth: int in layout["columns"]:
			in_columns += depth
		_check(in_columns + layout["reserve"] == layout["groups"] * 4, id + ": 카드 수는 범주 수의 4배")
		_check(layout["columns"].size() + layout["reserve"] == first_open[id], id + ": 처음 열린 카드 수")
	var copy: Dictionary = Difficulty.layout("open")
	copy["columns"].append(9)
	_check(Difficulty.layout("open")["columns"].size() == 4, "돌려준 배치를 고쳐도 원본은 그대로다")
	return true


func _tiers() -> bool:
	_check(Difficulty.TIER_MIN == 1 and Difficulty.TIER_MAX == 5, "등급은 1~5")
	_check(Difficulty.tier_rule(1) == {
		"layouts": ["open"], "f_min": 0.90, "f_max": 1.0, "category_tier_max": 1,
		"domain_max": 1, "confusable_max": 0, "outside_max": 2,
	}, "T1 쉬움")
	_check(Difficulty.tier_rule(2) == {
		"layouts": ["step"], "f_min": 0.45, "f_max": 0.90, "category_tier_max": 2,
		"domain_max": 1, "confusable_max": 0, "outside_max": 2,
	}, "T2 보통")
	_check(Difficulty.tier_rule(3) == {
		"layouts": ["classic"], "f_min": 0.25, "f_max": 0.60, "category_tier_max": 3,
		"domain_max": 2, "confusable_max": 0, "outside_max": 3,
	}, "T3 도전")
	_check(Difficulty.tier_rule(4) == {
		"layouts": ["classic", "deep"], "f_min": 0.10, "f_max": 0.30, "category_tier_max": 4,
		"domain_max": 2, "confusable_max": 1, "outside_max": 3,
	}, "T4 어려움")
	_check(Difficulty.tier_rule(5) == {
		"layouts": ["deep"], "f_min": 0.04, "f_max": 0.12, "category_tier_max": 4,
		"domain_max": 2, "confusable_max": 2, "outside_max": 3,
	}, "T5 고수")
	_check(Difficulty.tier_rule(0).is_empty() and Difficulty.tier_rule(6).is_empty(), "없는 등급은 빈 값")
	for tier: int in range(Difficulty.TIER_MIN, Difficulty.TIER_MAX + 1):
		for id: String in Difficulty.tier_rule(tier)["layouts"]:
			_check(Difficulty.layout(id)["groups"] == 4, "T%d의 배치 %s는 범주 4개" % [tier, id])
		_check(Difficulty.outside_limit(tier, "color") == 3, "T%d: 판 밖 색 범주의 후보는 3장까지" % tier)
		_check(Difficulty.outside_limit(tier, "food") == (2 if tier <= 2 else 3), "T%d: 색이 아닌 판 밖 범주의 후보 한도" % tier)
	_check(Difficulty.OUTSIDE_LIMIT == 3 and Difficulty.COLOR_DOMAIN == "color", "판 밖 범주의 후보는 어느 등급에서도 3장을 넘지 않는다")
	return true


func _tiers_of(first: int, last: int) -> Array:
	var tiers: Array = []
	for stage: int in range(first, last + 1):
		tiers.append(Difficulty.journey_tier(stage))
	return tiers


func _journey() -> bool:
	_check(_tiers_of(1, 5) == [1, 1, 1, 1, 1], "스테이지 1~5는 T1")
	_check(_tiers_of(6, 15) == [2, 2, 1, 2, 2, 2, 2, 1, 2, 2], "스테이지 6부터 T2, T2, T1, T2, T2 반복")
	_check(_tiers_of(16, 20) == [2, 2, 1, 2, 2], "스테이지 20까지 같은 순환")
	_check(_tiers_of(21, 30) == [2, 3, 2, 3, 3, 2, 3, 2, 3, 3], "스테이지 21부터 T2, T3, T2, T3, T3 반복")
	_check(_tiers_of(56, 60) == [2, 3, 2, 3, 3], "스테이지 60까지 같은 순환")
	_check(_tiers_of(61, 70) == [3, 3, 4, 2, 3, 4, 3, 3, 4, 5], "스테이지 61부터 10판 순환")
	_check(_tiers_of(141, 150) == [3, 3, 4, 2, 3, 4, 3, 3, 4, 5], "스테이지 150까지 같은 순환")
	_check(_tiers_of(151, 160) == [3, 4, 4, 2, 4, 5, 3, 4, 4, 5], "스테이지 151부터 10판 순환")
	_check(_tiers_of(591, 600) == [3, 4, 4, 2, 4, 5, 3, 4, 4, 5], "팩의 마지막 10판")
	_check(_tiers_of(601, 603) == [3, 4, 4] and Difficulty.journey_tier(100000) == 5, "팩 뒤에도 같은 순환이 이어진다")
	var counts: Array = [0, 0, 0, 0, 0, 0]
	for tier: int in _tiers_of(1, 600):
		counts[tier] += 1
	_check(counts == [0, 8, 82, 159, 252, 99], "스테이지 1~600의 등급별 판 수 %s" % [counts])
	return true


func _daily() -> bool:
	_check(Difficulty.daily_tier(0) == 4 and Difficulty.daily_tier(6) == 4, "일요일과 토요일은 T4")
	for weekday: int in range(1, 6):
		_check(Difficulty.daily_tier(weekday) == 3, "평일(%d)은 T3" % weekday)
	return true
