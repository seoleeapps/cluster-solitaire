extends SceneTree
## 분석 어댑터가 실제로 만드는 요청 본문을 파일로 적는다. 아무것도 보내지 않는다.
## tools/check_ga4_payload.py가 이 파일을 GA4의 검증 주소에 대어 본다.
##   godot --headless --path godot --script res://tests/game/fa_analytics_payload_dump.gd -- --out <파일>
## 이벤트 목록은 기술 제작 계획의 "분석 이벤트 분류"를 옮긴 것이다. 분류가 바뀌면 함께 고친다.

const Analytics := preload("res://game/adapters/fa_ga4_analytics.gd")
const Values := preload("res://game/adapters/fa_service_values.gd")

const ROUND := {"mode": "journey", "level": 12, "tier": 2, "layout": "step"}
const AD := {"placement": "rewarded_booster", "format": "rewarded"}
const EVENTS: Array = [
	["tutorial_begin", {}],
	["tutorial_complete", {"seconds": 95}],
	["level_start", ROUND],
	["level_end", {"mode": "journey", "level": 12, "tier": 2, "layout": "step", "success": true, "stars": 2, "mistakes": 1, "holds": 4, "seconds": 131, "continue_used": false, "slot_unlocked": true}],
	["mistake", {"level": 12, "one_away": true}],
	["group_complete", {"level": 12, "category": "fruits", "order": 1}],
	["stuck_shown", {"level": 12}],
	["dead_end_shown", {"level": 12}],
	["booster_used", {"mode": "journey", "level": 12, "tier": 2, "layout": "step", "booster": "hint", "source": "owned"}],
	["earn_virtual_currency", {"virtual_currency_name": "coin", "value": 13, "source": "journey"}],
	["spend_virtual_currency", {"virtual_currency_name": "coin", "value": 100, "item_name": "hint"}],
	["ad_requested", AD],
	["ad_impression", AD],
	["ad_failed", {"placement": "rewarded_booster", "format": "rewarded", "reason": "not_ready"}],
	["rewarded_earned", AD],
	["ad_declined", {"placement": "rewarded_booster", "format": "rewarded", "reason": "offer"}],
	["daily_complete", {"streak": 3}],
	["attendance_claim", {"day": 2}],
	["album_unlock", {"category": "fruits"}],
	["share", {"streak": 3}],
	["settings_change", {"key": "language", "value": "ko"}],
]


class MemoryFiles extends RefCounted:
	var data: Dictionary = {}

	func read(name: String) -> Variant:
		return data.get(name)

	func write(name: String, value: Variant) -> bool:
		data[name] = value
		return true

	func remove(name: String) -> void:
		data.erase(name)


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = arguments[arguments.find("--out") + 1] if arguments.has("--out") else ""
	if out.is_empty():
		print("usage: -- --out <file>")
		quit(1)
		return
	var bodies: Array = []
	var values: Values = Values.from_text(JSON.stringify({"ga4_measurement_id": "G-DUMP000000", "ga4_api_secret": "payload_dump_only"}), false)
	var analytics: Analytics = Analytics.new(
		values, MemoryFiles.new(),
		func(request: Dictionary, on_done: Callable) -> void:
			bodies.append(JSON.parse_string(request["body"]))
			on_done.call({"ok": true, "status": 204, "text": ""}),
		func() -> int: return Analytics.GATE_OPEN, Time.get_unix_time_from_system,
		str(ProjectSettings.get_setting("application/config/version", "")), false)
	analytics.begin_session()
	analytics.set_enabled(true)
	for event: Array in EVENTS:
		analytics.advance(1.0)
		analytics.log_event(event[0], event[1])
	analytics.flush()
	var sent: int = 0
	for body: Dictionary in bodies:
		sent += body["events"].size()
	var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
	if file == null or sent != EVENTS.size() + 2 or analytics.pending_count() != 0:
		print("Fa analytics payload dump: failed (%d of %d events)" % [sent, EVENTS.size() + 2])
		quit(1)
		return
	file.store_string(JSON.stringify(bodies))
	file.close()
	print("Fa analytics payload dump: %d requests, %d events" % [bodies.size(), sent])
	quit(0)
