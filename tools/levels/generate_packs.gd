extends SceneTree
## 레벨 팩 생성 도구. 저장소 루트에서 실행한다.
##
##   godot --headless --path godot --script res://../tools/levels/generate_packs.gd
##   godot --headless --path godot --script res://../tools/levels/generate_packs.gd -- --check
##
## 인자 없이 돌리면 godot/data/levels/journey.json(스테이지 1~600)과 daily.json(1~1100)을 다시 쓴다.
## --check는 파일을 쓰지 않고, 새로 만든 결과가 실려 있는 파일과 바이트까지 같은지 본다.
## 실패하면 종료 코드 1이다. 콘텐츠(godot/data/content)가 바뀌면 다시 만들어야 한다.

const Content := preload("res://game/core/domain/fa_content.gd")
const Generator := preload("res://game/core/domain/fa_generator.gd")
const PickLevel := preload("res://game/core/use_cases/fa_pick_level.gd")

const CONTENT_DIR := "res://data/content/"
const LEVELS_DIR := "res://data/levels/"
const JOURNEY_COUNT := 600
const DAILY_COUNT := 1100


func _initialize() -> void:
	quit(0 if _run() == true else 1)


func _run() -> bool:
	var check_only: bool = OS.get_cmdline_user_args().has("--check")
	var content: Content = Content.new(_read_json(CONTENT_DIR + "items.json"), _read_json(CONTENT_DIR + "categories.json"))
	if not content.problems().is_empty():
		print("content problems: ", ", ".join(content.problems()))
		return false
	var packs: Array[Dictionary] = [
		{"file": "journey.json", "count": JOURNEY_COUNT, "recent": Generator.JOURNEY_RECENT_LEVELS, "make": Generator.journey_level},
		{"file": "daily.json", "count": DAILY_COUNT, "recent": Generator.DAILY_RECENT_LEVELS, "make": Generator.daily_level},
	]
	for pack: Dictionary in packs:
		var started: int = Time.get_ticks_msec()
		var text: String = _pack_text(content, pack)
		if text.is_empty():
			return false
		var path: String = LEVELS_DIR + pack["file"]
		var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
		if check_only:
			if FileAccess.get_file_as_string(path) != text:
				print("%s: regenerated pack differs from the committed file" % pack["file"])
				return false
			print("%s: %d levels identical to the committed file (%.1f s)" % [pack["file"], pack["count"], seconds])
		else:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				print("%s: cannot write (%s)" % [path, error_string(FileAccess.get_open_error())])
				return false
			file.store_string(text)
			file.close()
			print("%s: wrote %d levels (%.1f s)" % [pack["file"], pack["count"], seconds])
		_print_attempts(pack["attempts"])
	return true


## 범주를 고른 횟수를 등급별로 알린다. 1이면 처음 고른 범주로 만든 판이고, 상한은 Generator.CATEGORY_ATTEMPTS다.
func _print_attempts(by_tier: Dictionary) -> void:
	var tiers: Array = by_tier.keys()
	tiers.sort()
	for tier: int in tiers:
		var counts: Array = by_tier[tier]
		var total: int = 0
		for count: int in counts:
			total += count
		print("  T%d: %d levels, category picks mean %.1f, max %d of %d allowed, first pick worked for %d" % [
			tier, counts.size(), float(total) / counts.size(), counts.max(), Generator.CATEGORY_ATTEMPTS, counts.count(1),
		])


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## 팩 파일의 글자. 판마다 한 줄이라 바뀐 판만 차이로 보인다. 생성에 실패하면 빈 문자열.
## 판마다 범주를 고른 횟수를 pack의 attempts에 등급별로 모은다.
func _pack_text(content: Content, pack: Dictionary) -> String:
	var lines: PackedStringArray = []
	var history: Array[Array] = []
	pack["attempts"] = {}
	for number: int in range(1, pack["count"] + 1):
		var recent: Array = []
		for categories: Array in history:
			recent.append_array(categories)
		var result: Dictionary = pack["make"].call(content, number, recent)
		if not result["ok"]:
			print("%s level %d: %s" % [pack["file"], number, result["error"]])
			return ""
		var tier: int = result["level"]["tier"]
		if not pack["attempts"].has(tier):
			pack["attempts"][tier] = []
		pack["attempts"][tier].append(result["attempts"])
		var used: Array = []
		for group: Dictionary in result["level"]["groups"]:
			used.append(group["cat"])
		history.append(used)
		if history.size() > pack["recent"]:
			history.pop_front()
		lines.append(JSON.stringify(result["level"], "", false))
	return '{"version":%d,"content_version":%d,"generator":%d,"levels":[\n%s\n]}\n' % [
		PickLevel.PACK_VERSION, content.version(), Generator.VERSION, ",\n".join(lines),
	]
