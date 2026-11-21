class_name FaProgress
extends RefCounted
## 제품 저장 모델. GDD "저장과 리셋 계약"의 묶음을 한 Dictionary로 들고 규칙에 맞게만 고친다.
##   profile: 코인, 부스터 개수, 가진 테마(themes)와 종류별로 고른 테마(selected)
##   journey: 현재 스테이지, 스테이지별 최고 별, 최근 판의 범주
##   run: 진행 중인 판 {mode, stage, date, seconds, board}. 없으면 빈 값
##   daily: 날짜별 결과와 연속 기록(FaDaily 상태)   album: 범주별 본 카드
##   attendance: 마지막 수령일과 주기 안의 날   ads: 광고 정책 상태(FaAdPolicy 상태)
##   flags: 켜진 표시   grants: 이미 지급한 보상의 열쇠
## 파일 읽기와 쓰기는 저장 포트의 구현이 맡고, 여기서는 읽은 값의 판별과 버전 올림만 한다.

const Self := preload("res://game/core/domain/fa_progress.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")

const VERSION := 1
const STATUS_OK := "ok"
const STATUS_UPGRADED := "upgraded"
const STATUS_NEWER := "newer"
const STATUS_CORRUPT := "corrupt"
const FLAG_TUTORIAL_DONE := "tutorial_done"

var _data: Dictionary = {}


## 새로 시작하는 저장.
static func create() -> Self:
	var boosters: Dictionary = {}
	for id: String in Economy.BOOSTERS:
		boosters[id] = 0
	return _wrap({
		"version": VERSION,
		"profile": {"coins": 0, "boosters": boosters, "themes": [], "selected": {}},
		"journey": {"stage": 1, "stars": {}, "recent": []},
		"run": {},
		"daily": Daily.default_state(),
		"album": {},
		"attendance": {"last": "", "day": 0},
		"ads": AdPolicy.default_state(),
		"flags": {},
		"grants": {},
	})


## 저장에서 읽은 값을 판별한다. 결과는 {status, progress}다.
##   ok: 그대로 읽음. upgraded: 낮은 버전을 올려 읽음.
##   newer: 이 앱보다 높은 버전. corrupt: 형식이 틀림. 뒤의 둘은 progress가 null이다.
static func read(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _is_count(raw.get("version")):
		return {"status": STATUS_CORRUPT, "progress": null}
	var version: int = int(raw["version"])
	if version > VERSION:
		return {"status": STATUS_NEWER, "progress": null}
	var clean: Dictionary = _normalized(upgrade(raw, _upgrade_steps(), VERSION))
	if clean.is_empty():
		return {"status": STATUS_CORRUPT, "progress": null}
	return {"status": STATUS_OK if version == VERSION else STATUS_UPGRADED, "progress": _wrap(clean)}


## data를 target 버전까지 한 단계씩 올린 사본을 돌려준다. steps는 {이전 버전: 그 버전의 값을 받아 다음 버전의 값을 돌려주는 함수}다.
## 단계가 없거나 빈 값을 돌려주면 올리지 못한 것이고 결과는 빈 Dictionary다.
static func upgrade(data: Dictionary, steps: Dictionary, target: int) -> Dictionary:
	var current: Dictionary = data.duplicate(true)
	var version: int = int(current["version"])
	while version < target:
		if not steps.has(version):
			return {}
		current = steps[version].call(current)
		if current.is_empty():
			return {}
		version += 1
		current["version"] = version
	return current


## 저장 형식을 바꿔 VERSION을 올릴 때 이전 버전에서 올리는 함수를 여기에 더한다. 버전 1은 첫 형식이라 비어 있다.
static func _upgrade_steps() -> Dictionary:
	return {}


func to_dict() -> Dictionary:
	return _data.duplicate(true)


func coins() -> int:
	return _data["profile"]["coins"]


## 부스터 보유 개수. 없는 종류는 0.
func booster(id: String) -> int:
	return _data["profile"]["boosters"].get(id, 0)


func has_grant(key: String) -> bool:
	return _data["grants"].has(key)


## 보상을 한 번만 준다. 같은 열쇠로 이미 줬거나 보상 형식이 틀리면 아무것도 바꾸지 않고 false다.
## 지급 기록과 재화가 같은 저장에 함께 들어가므로, 이 값을 저장한 뒤 화면에 반영하면 두 번 받지 않는다.
func grant(key: String, reward: Dictionary) -> bool:
	if key.is_empty() or has_grant(key) or not add_reward(reward):
		return false
	_data["grants"][key] = true
	return true


## 열쇠 없이 보상을 더한다. 광고 보상처럼 받을 때마다 주는 것에 쓴다. 보상 형식이 틀리면 false.
func add_reward(reward: Dictionary) -> bool:
	if not _is_reward(reward):
		return false
	_data["profile"]["coins"] += int(reward.get("coins", 0))
	var boosters: Dictionary = reward.get("boosters", {})
	for id: String in boosters:
		_data["profile"]["boosters"][id] += int(boosters[id])
	return true


func spend_coins(amount: int) -> bool:
	if amount < 0 or amount > coins():
		return false
	_data["profile"]["coins"] -= amount
	return true


## 부스터 1개를 쓴다.
func use_booster(id: String) -> bool:
	if booster(id) < 1:
		return false
	_data["profile"]["boosters"][id] -= 1
	return true


## 코인으로 부스터 1개를 산다.
func buy_booster(id: String) -> bool:
	if not Economy.BOOSTERS.has(id) or not spend_coins(Economy.price(id)):
		return false
	_data["profile"]["boosters"][id] += 1
	return true


func owns_theme(id: String) -> bool:
	return _data["profile"]["themes"].has(id)


func buy_theme(id: String, price: int) -> bool:
	if id.is_empty() or owns_theme(id) or not spend_coins(price):
		return false
	_data["profile"]["themes"].append(id)
	return true


## 종류(카드 뒷면, 테이블 등)별로 고른 테마. 고르지 않았으면 ""이고 기본 테마를 뜻한다.
func selected_theme(kind: String) -> String:
	return _data["profile"]["selected"].get(kind, "")


## 가진 테마를 고른다. id가 ""이면 기본 테마로 되돌린다.
func select_theme(kind: String, id: String) -> bool:
	if kind.is_empty() or not (id.is_empty() or owns_theme(id)):
		return false
	if id.is_empty():
		_data["profile"]["selected"].erase(kind)
	else:
		_data["profile"]["selected"][kind] = id
	return true


## 지금 풀 차례인 스테이지 번호.
func stage() -> int:
	return _data["journey"]["stage"]


## 스테이지의 최고 별. 깬 적이 없으면 0.
func best_stars(stage_number: int) -> int:
	return _data["journey"]["stars"].get(str(stage_number), 0)


## 스테이지 클리어를 반영한다. 지금 풀 차례인 스테이지를 처음 깼으면 다음 스테이지를 열고 true를 돌려준다.
## 이미 깬 스테이지는 최고 별만 고치고, 아직 열리지 않은 스테이지와 범위 밖의 별은 반영하지 않는다.
func clear_stage(stage_number: int, star_count: int, categories: Array) -> bool:
	var journey: Dictionary = _data["journey"]
	if stage_number < 1 or stage_number > journey["stage"]:
		return false
	if star_count < Economy.STARS_MIN or star_count > Economy.STARS_MAX:
		return false
	journey["stars"][str(stage_number)] = maxi(star_count, best_stars(stage_number))
	if stage_number < journey["stage"]:
		return false
	journey["stage"] += 1
	journey["recent"].append(categories.duplicate())
	if journey["recent"].size() > Generator.JOURNEY_RECENT_LEVELS:
		journey["recent"].pop_front()
	return true


## 최근에 처음 깬 판들의 범주. 팩 뒤의 스테이지를 만들 때 피할 범주로 넘긴다.
func recent_categories() -> Array[String]:
	var recent: Array[String] = []
	for categories: Array in _data["journey"]["recent"]:
		recent.append_array(categories)
	return recent


func has_run() -> bool:
	return not _data["run"].is_empty()


## 진행 중인 판 {mode, stage, date, seconds, board}의 사본. 없으면 빈 값.
func run() -> Dictionary:
	return _data["run"].duplicate(true)


## 진행 중인 판을 기록한다. 여정은 stage, 일일 도전은 date가 판의 id이고 seconds는 지금까지 쓴 시간이다.
func set_run(mode: String, stage_number: int, date: String, seconds: int, board: Board) -> bool:
	if not _is_run(mode, stage_number, date, seconds):
		return false
	_data["run"] = {"mode": mode, "stage": stage_number, "date": date, "seconds": seconds, "board": board.to_dict()}
	return true


## 진행 중인 판의 상태와 걸린 시간만 고친다. 판의 종류와 id는 그대로다.
func update_run(board: Board, seconds: int) -> bool:
	if not has_run() or seconds < 0:
		return false
	_data["run"]["seconds"] = seconds
	_data["run"]["board"] = board.to_dict()
	return true


func clear_run() -> void:
	_data["run"] = {}


func can_play_daily(date: String, today: String) -> bool:
	return Daily.can_play(_data["daily"], date, today)


## 일일 도전 성공을 기록한다. 결과는 FaDaily.record_success와 같다.
func record_daily_success(date: String, today: String, summary: Dictionary) -> Dictionary:
	return Daily.record_success(_data["daily"], date, today, summary)


## 날짜의 일일 도전 결과 요약. 성공한 적이 없으면 빈 값.
func daily_result(date: String) -> Dictionary:
	return _data["daily"]["results"].get(date, {}).duplicate(true)


func daily_streak(today: String) -> int:
	return Daily.streak(_data["daily"], today)


func daily_best() -> int:
	return _data["daily"]["best"]


## 완성한 범주와 그 판에서 본 카드를 도감에 넣는다. 처음 등록한 범주면 true.
func register_album(category: String, items: Array) -> bool:
	var album: Dictionary = _data["album"]
	var is_new: bool = not album.has(category)
	if is_new:
		album[category] = []
	for item: String in items:
		if not album[category].has(item):
			album[category].append(item)
	return is_new


## 판에서 완성한 범주를 모두 도감에 넣고 새 범주와 10개 단위 달성의 코인을 준다.
## 결과는 {new: 새로 등록한 범주, coins: 받은 코인}이다. 끝낸 판과 버린 판 모두에 쓴다.
func collect_album(board: Board) -> Dictionary:
	var fresh: Array[String] = []
	var earned: int = 0
	for category: String in board.solved():
		if not register_album(category, board.group_items(category)):
			continue
		fresh.append(category)
		if grant("album:" + category, {"coins": Economy.ALBUM_NEW_CATEGORY}):
			earned += Economy.ALBUM_NEW_CATEGORY
		var milestone: int = Economy.album_milestone(album_count())
		if milestone > 0 and grant("album_count:%d" % album_count(), {"coins": milestone}):
			earned += milestone
	return {"new": fresh, "coins": earned}


func album_count() -> int:
	return _data["album"].size()


func album_categories() -> Array[String]:
	var categories: Array[String] = []
	categories.assign(_data["album"].keys())
	return categories


func album_items(category: String) -> Array[String]:
	var items: Array[String] = []
	items.assign(_data["album"].get(category, []))
	return items


## 주기 안에서 다음에 받을 날(0~6).
func attendance_day() -> int:
	return _data["attendance"]["day"]


func can_claim_attendance(today: String) -> bool:
	var last: String = _data["attendance"]["last"]
	return Daily.is_date(today) and (last.is_empty() or Daily.days_between(last, today) > 0)


## 오늘의 출석 보상을 받는다. 받은 보상을 돌려주고, 받을 수 없으면 빈 값이다. 날을 건너뛰어도 주기는 이어진다.
func claim_attendance(today: String) -> Dictionary:
	if not can_claim_attendance(today):
		return {}
	var attendance: Dictionary = _data["attendance"]
	var reward: Dictionary = Economy.attendance_reward(attendance["day"])
	if not grant("attendance:" + today, reward):
		return {}
	attendance["last"] = today
	attendance["day"] = (attendance["day"] + 1) % Economy.ATTENDANCE_DAYS
	return reward


## 광고 정책 상태. FaAdPolicy의 함수가 이 값을 직접 고친다.
func ads() -> Dictionary:
	return _data["ads"]


## 날짜가 바뀌었으면 광고의 일 횟수를 0으로 돌리고 true를 돌려준다.
func roll_date(today: String) -> bool:
	return AdPolicy.roll_date(_data["ads"], today)


func flag(name: String) -> bool:
	return _data["flags"].has(name)


func set_flag(name: String, on: bool) -> void:
	if on:
		_data["flags"][name] = true
	else:
		_data["flags"].erase(name)


static func _wrap(data: Dictionary) -> Self:
	var progress: Self = new()
	progress._data = data
	return progress


## 읽은 값을 묶음별로 확인해 정수로 정리한 사본을 돌려준다. 하나라도 틀리면 빈 Dictionary.
static func _normalized(data: Dictionary) -> Dictionary:
	var clean: Dictionary = {
		"version": VERSION,
		"profile": _profile_from(data.get("profile")),
		"journey": _journey_from(data.get("journey")),
		"run": _run_from(data.get("run")),
		"daily": _or_null(Daily.state_from(data.get("daily"))),
		"album": _album_from(data.get("album")),
		"attendance": _attendance_from(data.get("attendance")),
		"ads": _or_null(AdPolicy.state_from(data.get("ads"))),
		"flags": _marks_from(data.get("flags")),
		"grants": _marks_from(data.get("grants")),
	}
	return {} if clean.values().has(null) else clean


static func _or_null(state: Dictionary) -> Variant:
	return null if state.is_empty() else state


static func _profile_from(raw: Variant) -> Variant:
	if not raw is Dictionary or not _is_count(raw.get("coins")) or not raw.get("boosters") is Dictionary:
		return null
	if not _is_text_list(raw.get("themes")) or not raw.get("selected") is Dictionary:
		return null
	var boosters: Dictionary = {}
	for id: String in Economy.BOOSTERS:
		if not _is_count(raw["boosters"].get(id)):
			return null
		boosters[id] = int(raw["boosters"][id])
	for kind: Variant in raw["selected"]:
		if not _is_text(kind) or not raw["themes"].has(raw["selected"][kind]):
			return null
	return {
		"coins": int(raw["coins"]), "boosters": boosters,
		"themes": raw["themes"].duplicate(), "selected": raw["selected"].duplicate(),
	}


static func _journey_from(raw: Variant) -> Variant:
	if not raw is Dictionary or not _is_count(raw.get("stage")) or raw["stage"] < 1:
		return null
	var recent: Variant = raw.get("recent")
	if not raw.get("stars") is Dictionary or not recent is Array or recent.size() > Generator.JOURNEY_RECENT_LEVELS:
		return null
	var stars: Dictionary = {}
	for key: Variant in raw["stars"]:
		var star_count: Variant = raw["stars"][key]
		if not key is String or not key.is_valid_int() or key.to_int() < 1 or str(key.to_int()) != key:
			return null
		if not _is_count(star_count) or star_count < Economy.STARS_MIN or star_count > Economy.STARS_MAX:
			return null
		stars[key] = int(star_count)
	for categories: Variant in recent:
		if not _is_text_list(categories):
			return null
	return {"stage": int(raw["stage"]), "stars": stars, "recent": recent.duplicate(true)}


static func _run_from(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	if raw.is_empty():
		return {}
	var mode: Variant = raw.get("mode")
	var date: Variant = raw.get("date")
	if not mode is String or not date is String or not _is_count(raw.get("stage")) or not _is_count(raw.get("seconds")):
		return null
	if not _is_run(mode, int(raw["stage"]), date, int(raw["seconds"])) or not raw.get("board") is Dictionary:
		return null
	var board: Board = Board.from_dict(raw["board"])
	if board == null:
		return null
	return {"mode": mode, "stage": int(raw["stage"]), "date": date, "seconds": int(raw["seconds"]), "board": board.to_dict()}


static func _is_run(mode: String, stage_number: int, date: String, seconds: int) -> bool:
	if not RoundMode.ALL.has(mode) or stage_number < 0 or seconds < 0:
		return false
	if mode == RoundMode.JOURNEY and stage_number < 1:
		return false
	return mode != RoundMode.DAILY or Daily.is_date(date)


static func _album_from(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	for category: Variant in raw:
		if not _is_text(category) or not _is_text_list(raw[category]):
			return null
	return raw.duplicate(true)


static func _attendance_from(raw: Variant) -> Variant:
	if not raw is Dictionary or not raw.get("last") is String or not _is_count(raw.get("day")):
		return null
	if raw["day"] >= Economy.ATTENDANCE_DAYS or not (raw["last"].is_empty() or Daily.is_date(raw["last"])):
		return null
	return {"last": raw["last"], "day": int(raw["day"])}


## 표시와 지급 기록은 {이름: true}만 담는다.
static func _marks_from(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	for name: Variant in raw:
		if not _is_text(name) or not raw[name] is bool or not raw[name]:
			return null
	return raw.duplicate()


static func _is_reward(reward: Dictionary) -> bool:
	var boosters: Variant = reward.get("boosters", {})
	if not _is_count(reward.get("coins", 0)) or not boosters is Dictionary:
		return false
	for id: Variant in boosters:
		if not Economy.BOOSTERS.has(id) or not _is_count(boosters[id]):
			return false
	return true


static func _is_text(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _is_text_list(value: Variant) -> bool:
	if not value is Array:
		return false
	for entry: Variant in value:
		if not _is_text(entry):
			return false
	return true


static func _is_count(value: Variant) -> bool:
	return (value is int or (value is float and value == floorf(value))) and value >= 0
