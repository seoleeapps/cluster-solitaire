extends SceneTree
## 광고 정책 검사: 배치 기본값, 금지 사유 하나하나, 노출 기록, 날짜 변경, 실행 시작, 원격 설정 덮어쓰기, 상태 직렬화.

const Policy := preload("res://game/core/domain/fa_ad_policy.gd")

const NOON := 1800000000

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("기본 설정", _defaults)
	_section("허용", _allowed)
	_section("금지 사유", _reasons)
	_section("전면 광고 흐름(AC-016)", _interstitial_flow)
	_section("보상형 상한과 간격", _rewarded_limits)
	_section("날짜 변경과 실행 시작", _date_and_session)
	_section("원격 설정", _overrides)
	_section("수익화 프로필과 대조", _profile)
	_section("상태 직렬화", _state)
	print("Fa ad policy probe: %d checks, %d failed" % [_checks, _failed.size()])
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


## 모든 배치가 허용되는 상태: 두 번째 실행, 누적 플레이 10분, 전면 뒤 3판.
func _ready_state() -> Dictionary:
	var state: Dictionary = Policy.default_state()
	Policy.roll_date(state, "2026-12-10")
	Policy.begin_session(state)
	Policy.begin_session(state)
	Policy.add_play_seconds(state, 600)
	for _round: int in 3:
		Policy.record_round_end(state)
	return state


func _reason(state: Dictionary, placement: String, now: int = NOON, mode: String = "journey", config: Dictionary = Policy.default_config()) -> String:
	var verdict: Dictionary = Policy.can_show(config, state, placement, now, mode)
	_check(verdict["ok"] == verdict["reason"].is_empty(), placement + ": ok와 reason이 맞물린다")
	return verdict["reason"]


func _defaults() -> bool:
	var config: Dictionary = Policy.default_config()
	_check(config.keys() == ["rewarded_booster", "rewarded_continue", "rewarded_result_bonus", "interstitial_level_end"], "배치 4개")
	_check(config["rewarded_booster"] == {
		"format": "rewarded", "enabled": true, "cooldown_s": 30, "session_cap": 2, "daily_cap": 5,
		"first_session": 1, "first_play_seconds": 0,
	}, "칸 추가와 부스터 충전")
	_check(config["rewarded_continue"] == {
		"format": "rewarded", "enabled": true, "cooldown_s": 60, "session_cap": 1, "daily_cap": 2,
		"first_session": 1, "first_play_seconds": 0,
	}, "이어하기")
	_check(config["rewarded_result_bonus"] == {
		"format": "rewarded", "enabled": true, "cooldown_s": 60, "session_cap": 1, "daily_cap": 3,
		"first_session": 1, "first_play_seconds": 0,
	}, "결과 2배")
	_check(config["interstitial_level_end"] == {
		"format": "interstitial", "enabled": true, "cooldown_s": 120, "session_cap": 3, "daily_cap": 8,
		"first_session": 2, "first_play_seconds": 180, "completion_interval": 2, "rewarded_gap_s": 120,
	}, "판 종료 전면")
	config["rewarded_booster"]["cooldown_s"] = 1
	_check(Policy.default_config()["rewarded_booster"]["cooldown_s"] == 30, "돌려준 설정을 고쳐도 기본값은 그대로다")
	_check(Policy.default_state() == {
		"date": "", "daily": {}, "session": {}, "last": {}, "session_no": 0, "play_seconds": 0,
		"rounds_since_interstitial": 0, "rewarded_at": 0, "declined_at": 0,
	}, "처음 상태")
	return true


func _allowed() -> bool:
	var state: Dictionary = _ready_state()
	for placement: String in Policy.default_config():
		_check(Policy.can_show(Policy.default_config(), state, placement, NOON, "journey") == {"ok": true, "reason": ""}, placement + ": 조건을 채우면 허용")
	var fresh: Dictionary = Policy.default_state()
	Policy.begin_session(fresh)
	for placement: String in ["rewarded_booster", "rewarded_continue", "rewarded_result_bonus"]:
		_check(_reason(fresh, placement) == "", placement + ": 보상형은 첫 실행부터 허용")
	return true


func _reasons() -> bool:
	var state: Dictionary = _ready_state()
	_check(_reason(state, "banner_home") == "unknown_placement", "없는 배치")

	var off: Dictionary = Policy.default_config()
	off["rewarded_continue"]["enabled"] = false
	_check(_reason(state, "rewarded_continue", NOON, "journey", off) == "disabled", "꺼진 배치")
	_check(_reason(state, "rewarded_booster", NOON, "journey", off) == "", "다른 배치는 켜져 있다")

	for placement: String in Policy.default_config():
		_check(_reason(state, placement, NOON, "tutorial") == "tutorial", placement + ": 튜토리얼에서는 금지")
	_check(_reason(state, "interstitial_level_end", NOON, "daily") == "daily_challenge", "일일 도전 뒤에는 전면 금지")
	_check(_reason(state, "rewarded_booster", NOON, "daily") == "daily_challenge", "일일 도전에서는 부스터 광고 금지")
	_check(_reason(state, "rewarded_continue", NOON, "daily") == "daily_challenge", "일일 도전에서는 이어하기 금지")
	_check(_reason(state, "rewarded_result_bonus", NOON, "daily") == "", "일일 도전 결과의 2배 광고는 허용")

	var first_run: Dictionary = _ready_state()
	first_run["session_no"] = 1
	_check(_reason(first_run, "interstitial_level_end") == "first_session", "전면은 두 번째 실행부터")

	var short_play: Dictionary = _ready_state()
	short_play["play_seconds"] = 179
	_check(_reason(short_play, "interstitial_level_end") == "play_time", "전면은 누적 180초 이후")
	short_play["play_seconds"] = 180
	_check(_reason(short_play, "interstitial_level_end") == "", "누적 180초면 허용")

	var capped: Dictionary = _ready_state()
	capped["daily"] = {"interstitial_level_end": 8}
	_check(_reason(capped, "interstitial_level_end") == "daily_cap", "하루 상한")
	capped["daily"] = {"interstitial_level_end": 7}
	capped["session"] = {"interstitial_level_end": 3}
	_check(_reason(capped, "interstitial_level_end") == "session_cap", "한 번 실행 상한")

	var recent: Dictionary = _ready_state()
	recent["last"] = {"interstitial_level_end": NOON - 119}
	_check(_reason(recent, "interstitial_level_end") == "cooldown", "간격 120초 안")
	recent["last"] = {"interstitial_level_end": NOON - 120}
	_check(_reason(recent, "interstitial_level_end") == "", "간격을 채우면 허용")
	recent["last"] = {"interstitial_level_end": NOON + 500}
	_check(_reason(recent, "interstitial_level_end") == "", "시계가 뒤로 가면 간격을 채운 것으로 본다")

	var few_rounds: Dictionary = _ready_state()
	few_rounds["rounds_since_interstitial"] = 1
	_check(_reason(few_rounds, "interstitial_level_end") == "rounds", "직전 전면 뒤 2판 이상")

	var after_reward: Dictionary = _ready_state()
	after_reward["rewarded_at"] = NOON - 119
	_check(_reason(after_reward, "interstitial_level_end") == "after_rewarded", "보상형을 본 뒤 120초 안")
	after_reward["rewarded_at"] = NOON - 120
	_check(_reason(after_reward, "interstitial_level_end") == "", "보상형 뒤 120초가 지나면 허용")
	after_reward["declined_at"] = NOON - 30
	_check(_reason(after_reward, "interstitial_level_end") == "after_rewarded", "보상형을 거절한 뒤 120초 안")
	_check(_reason(after_reward, "rewarded_booster") == "", "보상형은 다른 보상형 직후에도 허용")
	return true


func _interstitial_flow() -> bool:
	var config: Dictionary = Policy.default_config()
	var state: Dictionary = Policy.default_state()
	Policy.roll_date(state, "2026-12-10")
	Policy.begin_session(state)
	Policy.add_play_seconds(state, 400)
	Policy.record_round_end(state)
	Policy.record_round_end(state)
	_check(_reason(state, "interstitial_level_end") == "first_session", "첫 실행에는 요청하지 않는다")
	Policy.begin_session(state)
	_check(_reason(state, "interstitial_level_end") == "", "두 번째 실행의 판 종료에서 조건을 채우면 요청한다")

	Policy.record_shown(state, config, "interstitial_level_end", NOON)
	_check(state["rounds_since_interstitial"] == 0 and state["last"]["interstitial_level_end"] == NOON, "노출하면 판 수를 0으로 돌리고 시각을 남긴다")
	_check(state["daily"] == {"interstitial_level_end": 1} and state["session"] == {"interstitial_level_end": 1}, "노출 횟수를 센다")
	_check(state["rewarded_at"] == 0, "전면 노출은 보상형 시각을 바꾸지 않는다")
	Policy.record_round_end(state)
	_check(_reason(state, "interstitial_level_end", NOON + 300) == "rounds", "다음 판에서는 내지 않는다(2판에 1번)")
	Policy.record_round_end(state)
	_check(_reason(state, "interstitial_level_end", NOON + 100) == "cooldown", "2판이 지나도 120초 안이면 내지 않는다")
	_check(_reason(state, "interstitial_level_end", NOON + 300) == "", "2판과 120초가 지나면 다시 낸다")

	Policy.record_shown(state, config, "rewarded_result_bonus", NOON + 290)
	_check(state["rewarded_at"] == NOON + 290 and state["rounds_since_interstitial"] == 2, "보상형 노출은 시각만 남긴다")
	_check(_reason(state, "interstitial_level_end", NOON + 300) == "after_rewarded", "보상형 직후에는 내지 않는다")
	Policy.record_declined(state, NOON + 400)
	_check(state["declined_at"] == NOON + 400 and _reason(state, "interstitial_level_end", NOON + 450) == "after_rewarded", "보상형을 거절한 직후에도 내지 않는다")
	_check(_reason(state, "interstitial_level_end", NOON + 520) == "", "거절 뒤 120초가 지나면 낸다")
	return true


func _rewarded_limits() -> bool:
	var config: Dictionary = Policy.default_config()
	var state: Dictionary = _ready_state()
	Policy.record_shown(state, config, "rewarded_booster", NOON)
	_check(_reason(state, "rewarded_booster", NOON + 29) == "cooldown", "보상형 간격 30초")
	_check(_reason(state, "rewarded_booster", NOON + 30) == "", "30초 뒤 허용")
	_check(_reason(state, "rewarded_continue", NOON + 1) == "", "간격은 배치마다 따로 센다")
	Policy.record_shown(state, config, "rewarded_booster", NOON + 30)
	_check(_reason(state, "rewarded_booster", NOON + 600) == "session_cap", "한 번 실행에 2회")
	Policy.begin_session(state)
	_check(_reason(state, "rewarded_booster", NOON + 600) == "", "다시 실행하면 실행 상한이 풀린다")
	for index: int in 3:
		Policy.record_shown(state, config, "rewarded_booster", NOON + 700 + index * 100)
		Policy.begin_session(state)
	_check(state["daily"]["rewarded_booster"] == 5 and _reason(state, "rewarded_booster", NOON + 5000) == "daily_cap", "하루 5회")
	Policy.record_shown(state, config, "banner_home", NOON)
	_check(not state["daily"].has("banner_home"), "없는 배치의 노출은 기록하지 않는다")
	return true


func _date_and_session() -> bool:
	var config: Dictionary = Policy.default_config()
	var state: Dictionary = _ready_state()
	Policy.record_shown(state, config, "rewarded_continue", NOON)
	Policy.record_shown(state, config, "interstitial_level_end", NOON)
	Policy.record_round_end(state)
	_check(not Policy.roll_date(state, "2026-12-10"), "같은 날짜면 바뀌지 않는다")
	_check(state["daily"] == {"rewarded_continue": 1, "interstitial_level_end": 1}, "같은 날짜면 일 횟수가 남는다")
	var before: Dictionary = state.duplicate(true)
	_check(Policy.roll_date(state, "2026-12-11"), "날짜가 바뀌면 알린다")
	before["date"] = "2026-12-11"
	before["daily"] = {}
	_check(state == before, "날짜가 바뀌면 일 횟수만 0으로 돌린다")
	_check(state["session"]["rewarded_continue"] == 1 and state["last"]["rewarded_continue"] == NOON and state["play_seconds"] == 600, "실행 횟수와 시각, 누적 플레이는 그대로다")

	Policy.begin_session(state)
	_check(state["session_no"] == 3 and state["session"].is_empty(), "실행을 시작하면 실행 번호가 오르고 실행 횟수가 비워진다")
	_check(state["last"]["rewarded_continue"] == NOON and state["rounds_since_interstitial"] == 1, "실행을 시작해도 시각과 판 수는 그대로다")
	Policy.add_play_seconds(state, 45)
	Policy.add_play_seconds(state, -10)
	_check(state["play_seconds"] == 645, "누적 플레이 초는 늘기만 한다")
	return true


func _overrides() -> bool:
	_check(Policy.remote_keys() == [
		"rewarded_booster_enabled", "rewarded_booster_cooldown_s", "rewarded_booster_session_cap", "rewarded_booster_daily_cap",
		"rewarded_continue_enabled", "rewarded_continue_cooldown_s", "rewarded_continue_session_cap", "rewarded_continue_daily_cap",
		"rewarded_result_bonus_enabled", "rewarded_result_bonus_cooldown_s", "rewarded_result_bonus_session_cap", "rewarded_result_bonus_daily_cap",
		"interstitial_level_end_enabled", "interstitial_level_end_cooldown_s", "interstitial_level_end_session_cap", "interstitial_level_end_daily_cap",
		"interstitial_min_play_seconds", "interstitial_min_stages_between",
	], "원격 설정 열쇠는 배치마다 켜짐, 간격, 실행 상한, 하루 상한과 전면 광고 조건 둘")
	var gate: Dictionary = Policy.config_from({"interstitial_min_play_seconds": 600, "interstitial_min_stages_between": 4})["interstitial_level_end"]
	_check(gate["first_play_seconds"] == 600 and gate["completion_interval"] == 4, "전면 광고의 플레이 시간과 판 수 조건을 덮어쓴다")
	gate = Policy.config_from({"interstitial_min_play_seconds": 1800.0, "interstitial_min_stages_between": 6})["interstitial_level_end"]
	_check(gate["first_play_seconds"] == 1800 and gate["completion_interval"] == 6, "조건의 가장 큰 값")
	for loose: Dictionary in [
		{"interstitial_min_play_seconds": 179}, {"interstitial_min_play_seconds": 1801}, {"interstitial_min_play_seconds": 0},
		{"interstitial_min_stages_between": 1}, {"interstitial_min_stages_between": 7}, {"interstitial_min_stages_between": "3"},
	]:
		_check(Policy.config_from(loose) == Policy.default_config(), "기본값보다 느슨하거나 범위를 넘는 조건은 받지 않는다: %s" % [loose])
	var strict: Dictionary = Policy.config_from({"interstitial_min_stages_between": 3})
	var waiting: Dictionary = _ready_state()
	waiting["rounds_since_interstitial"] = 2
	_check(_reason(waiting, "interstitial_level_end", NOON, "journey", strict) == "rounds", "덮어쓴 판 수 조건으로 판정한다")
	var edge: Dictionary = Policy.config_from({
		"interstitial_level_end_cooldown_s": 600, "interstitial_level_end_session_cap": 6, "interstitial_level_end_daily_cap": 16,
		"rewarded_booster_cooldown_s": 600, "rewarded_booster_session_cap": 4, "rewarded_booster_daily_cap": 10,
	})
	_check(edge["interstitial_level_end"]["cooldown_s"] == 600 and edge["rewarded_booster"]["cooldown_s"] == 600, "간격은 기본값의 4배와 600초 중 큰 값까지 받는다")
	_check(edge["interstitial_level_end"]["session_cap"] == 6 and edge["interstitial_level_end"]["daily_cap"] == 16, "상한은 기본값의 2배까지 받는다")
	_check(edge["rewarded_booster"]["session_cap"] == 4 and edge["rewarded_booster"]["daily_cap"] == 10, "보상형 상한도 기본값의 2배까지 받는다")
	edge = Policy.config_from({
		"interstitial_level_end_cooldown_s": 601, "interstitial_level_end_session_cap": 7, "interstitial_level_end_daily_cap": 17,
		"rewarded_booster_cooldown_s": 601, "rewarded_booster_session_cap": 5, "rewarded_booster_daily_cap": 11,
	})
	_check(edge == Policy.default_config(), "범위를 하나라도 넘는 값은 기본값을 쓴다")

	var config: Dictionary = Policy.config_from({
		"rewarded_booster_enabled": false, "rewarded_booster_cooldown_s": 45,
		"rewarded_booster_session_cap": 4, "rewarded_booster_daily_cap": 10,
		"interstitial_level_end_cooldown_s": 180.0, "interstitial_level_end_daily_cap": 0,
	})
	_check(config["rewarded_booster"] == {
		"format": "rewarded", "enabled": false, "cooldown_s": 45, "session_cap": 4, "daily_cap": 10,
		"first_session": 1, "first_play_seconds": 0,
	}, "범위 안의 값은 덮어쓴다")
	_check(config["interstitial_level_end"]["cooldown_s"] == 180 and config["interstitial_level_end"]["cooldown_s"] is int, "JSON에서 실수로 읽힌 정수도 받는다")
	_check(config["interstitial_level_end"]["daily_cap"] == 0 and config["interstitial_level_end"]["session_cap"] == 3, "범위의 끝 값은 받고 주지 않은 값은 기본값")
	_check(config["rewarded_continue"] == Policy.default_config()["rewarded_continue"], "주지 않은 배치는 기본값")

	config = Policy.config_from({
		"interstitial_level_end_cooldown_s": 601, "interstitial_level_end_session_cap": 7,
		"interstitial_level_end_daily_cap": -1, "interstitial_level_end_enabled": "yes",
		"rewarded_continue_cooldown_s": 30.5, "rewarded_continue_session_cap": "1", "rewarded_continue_daily_cap": null,
		"interstitial_level_end_first_session": 1, "interstitial_level_end_completion_interval": 1,
		"interstitial_level_end_format": "rewarded", "banner_home_enabled": true,
	})
	_check(config == Policy.default_config(), "범위를 벗어나거나 형식이 틀린 값, 덮어쓸 수 없는 열쇠는 기본값을 쓴다")
	_check(Policy.config_from({}) == Policy.default_config(), "값을 받지 못하면 기본값")

	config = Policy.config_from({"interstitial_level_end_enabled": false})
	_check(_reason(_ready_state(), "interstitial_level_end", NOON, "journey", config) == "disabled", "덮어쓴 설정으로 판정한다")
	return true


## 코드의 기본값과 원격 설정 열쇠, 범위가 정본인 수익화 프로필과 같은지 본다.
func _profile() -> bool:
	var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monetization/bm-profile.json"))
	var defaults: Dictionary = Policy.default_config()
	_check(profile["ad_placements"].size() == defaults.size(), "배치 수가 프로필과 같다")
	for placement: Dictionary in profile["ad_placements"]:
		var id: String = placement["placement_id"]
		var rule: Dictionary = defaults.get(id, {})
		_check(not rule.is_empty(), id + ": 프로필의 배치가 코드에 있다")
		if rule.is_empty():
			continue
		_check(rule["format"] == placement["format"] and rule["enabled"] == placement["enabled_default"], id + ": 형식과 기본 상태")
		_check(rule["cooldown_s"] == placement["cooldown_s"], id + ": 간격")
		_check(rule["session_cap"] == placement["session_cap"] and rule["daily_cap"] == placement["daily_cap"], id + ": 실행 상한과 하루 상한")
		_check(rule["first_session"] == placement["first_eligible_at"]["session_index"], id + ": 최초 실행 조건")

	var extra_fields: Dictionary = {
		"interstitial_min_play_seconds": "first_play_seconds", "interstitial_min_stages_between": "completion_interval",
	}
	var profile_keys: Array = []
	for entry: Dictionary in profile["remote_config"]:
		var key: String = entry["key"]
		profile_keys.append(key)
		var placement_id: String = "interstitial_level_end"
		var field: String = extra_fields.get(key, "")
		for id: String in defaults:
			if field.is_empty() and key.begins_with(id + "_"):
				placement_id = id
				field = key.trim_prefix(id + "_")
		var code_default: Variant = defaults[placement_id].get(field)
		_check(code_default == entry["default"], key + ": 기본값이 프로필과 같다")
		if entry["type"] != "int":
			continue
		var low: int = int(entry["range"]["min"])
		var high: int = int(entry["range"]["max"])
		for inside: int in [low, high]:
			_check(Policy.config_from({key: inside})[placement_id][field] == inside, "%s: 범위의 끝 값 %d를 받는다" % [key, inside])
		for outside: int in [low - 1, high + 1]:
			_check(Policy.config_from({key: outside})[placement_id][field] == code_default, "%s: 범위 밖의 값 %d는 기본값을 쓴다" % [key, outside])
	var code_keys: Array = Array(Policy.remote_keys())
	profile_keys.sort()
	code_keys.sort()
	_check(profile_keys == code_keys, "원격 설정 열쇠가 프로필과 같다")
	return true


func _state() -> bool:
	var config: Dictionary = Policy.default_config()
	var state: Dictionary = _ready_state()
	Policy.record_shown(state, config, "rewarded_booster", NOON)
	Policy.record_shown(state, config, "interstitial_level_end", NOON + 200)
	Policy.record_declined(state, NOON + 300)
	var restored: Dictionary = Policy.state_from(JSON.parse_string(JSON.stringify(state)))
	_check(restored == state, "저장 뒤 읽으면 같은 상태다")
	_check(restored["last"]["rewarded_booster"] is int and restored["daily"]["rewarded_booster"] is int and restored["session_no"] is int, "저장에서 읽은 숫자는 정수로 바꾼다")
	_check(Policy.state_from(Policy.default_state()) == Policy.default_state(), "처음 상태도 읽는다")
	_check(Policy.state_from(null).is_empty() and Policy.state_from({}).is_empty(), "형식이 틀리면 빈 값")
	var broken: Dictionary = state.duplicate(true)
	broken["daily"] = {"rewarded_booster": -1}
	_check(Policy.state_from(broken).is_empty(), "음수 횟수는 빈 값")
	broken = state.duplicate(true)
	broken["play_seconds"] = "many"
	_check(Policy.state_from(broken).is_empty(), "숫자가 아닌 값은 빈 값")
	broken = state.duplicate(true)
	broken.erase("rounds_since_interstitial")
	_check(Policy.state_from(broken).is_empty(), "필드가 빠지면 빈 값")
	return true
