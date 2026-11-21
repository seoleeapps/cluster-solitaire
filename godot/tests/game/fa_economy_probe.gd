extends SceneTree
## 경제 수치 검사: 별 판정, 판 보상, 일일 도전 보상, 가격, 시작 선물, 도감 보상, 출석 주기.

const Economy := preload("res://game/core/domain/fa_economy.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("별", _stars)
	_section("판 보상", _stage_rewards)
	_section("가격과 선물", _prices_and_gifts)
	_section("도감", _album)
	_section("출석", _attendance)
	print("Fa economy probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _stars() -> bool:
	_check(Economy.stars(0, false) == 3, "실수 0은 별 3")
	_check(Economy.stars(1, false) == 2 and Economy.stars(2, false) == 2, "실수 1~2는 별 2")
	_check(Economy.stars(3, false) == 1, "실수 3은 별 1")
	_check(Economy.stars(0, true) == 1 and Economy.stars(2, true) == 1 and Economy.stars(3, true) == 1, "이어하기를 쓴 판은 별 1")
	return true


func _stage_rewards() -> bool:
	_check(Economy.stage_reward(1) == 10 and Economy.stage_reward(2) == 13 and Economy.stage_reward(3) == 16, "기본 10에 별 1, 2, 3마다 +0, +3, +6")
	_check(Economy.AD_MULTIPLIER == 2, "광고 2배")
	_check(Economy.ad_bonus(13) == 13 and Economy.ad_bonus(30) == 30, "광고를 보면 받은 만큼 더 받는다")
	_check(Economy.DAILY_REWARD == 30, "일일 도전 보상 30")
	return true


func _prices_and_gifts() -> bool:
	_check(Economy.BOOSTERS == ["hint", "undo", "slot"], "부스터 3종")
	_check(Economy.price("hint") == 100 and Economy.price("undo") == 80 and Economy.price("slot") == 150, "힌트 100, 되돌리기 80, 칸 추가 150")
	_check(Economy.price("bomb") == 0, "없는 부스터의 가격은 0")
	_check(Economy.starter_gift() == {"coins": 200, "boosters": {"hint": 3, "undo": 3, "slot": 2}}, "시작 선물")
	var gift: Dictionary = Economy.starter_gift()
	gift["boosters"]["hint"] = 99
	_check(Economy.starter_gift()["boosters"]["hint"] == 3, "돌려준 선물을 고쳐도 원본은 그대로다")
	_check(Economy.booster_reward("undo") == {"boosters": {"undo": 1}}, "광고 보상은 해당 부스터 1개")
	return true


func _album() -> bool:
	_check(Economy.ALBUM_NEW_CATEGORY == 5, "새 범주 5")
	_check(Economy.album_milestone(10) == 50 and Economy.album_milestone(20) == 50 and Economy.album_milestone(160) == 50, "10개 단위 50")
	_check(Economy.album_milestone(1) == 0 and Economy.album_milestone(9) == 0 and Economy.album_milestone(11) == 0, "단위가 아닌 수는 0")
	_check(Economy.album_milestone(0) == 0, "0개는 달성이 아니다")
	return true


func _attendance() -> bool:
	_check(Economy.ATTENDANCE_DAYS == 7, "7일 주기")
	var expected: Array = [
		{"coins": 20}, {"boosters": {"hint": 1}}, {"coins": 30}, {"boosters": {"undo": 1}},
		{"coins": 40}, {"boosters": {"slot": 1}}, {"coins": 60},
	]
	for day: int in expected.size():
		_check(Economy.attendance_reward(day) == expected[day], "출석 %d일째" % (day + 1))
	_check(Economy.attendance_reward(7) == {"coins": 20} and Economy.attendance_reward(13) == {"coins": 60}, "7일 뒤에는 처음부터 다시")
	return true
