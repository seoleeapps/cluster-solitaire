extends SceneTree
## 바깥 화면의 규칙 검사: 꾸미기 목록과 가격, 상점(부스터와 꾸미기 사기, 고르기), 출석 받기, 도감 칸의 범주 이름 맞춤.
## 저장은 메모리 대역, 분석은 FaMemoryAnalytics에 받아 무엇을 보냈는지 본다.

const Economy := preload("res://game/core/domain/fa_economy.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Shop := preload("res://game/core/use_cases/fa_shop.gd")
const Attendance := preload("res://game/core/use_cases/fa_attendance.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const MemoryAnalytics := preload("res://game/adapters/fa_memory_analytics.gd")
const Content := preload("res://game/core/domain/fa_content.gd")
const AlbumScreen := preload("res://game/features/outgame/album_screen.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")


class MemoryStore extends StorePort:
	var writes: int = 0
	var saved: Dictionary = {}

	func write(data: Dictionary) -> bool:
		writes += 1
		saved = data.duplicate(true)
		return true


var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("꾸미기 목록", _catalog)
	_section("상점: 부스터", _boosters)
	_section("상점: 꾸미기", _themes)
	_section("출석", _attendance)
	_section("도감 칸의 범주 이름", _album_names)
	print("Fa outgame probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _rich(coins: int) -> Progress:
	var progress: Progress = Progress.create()
	progress.add_reward({"coins": coins})
	return progress


func _catalog() -> bool:
	var backs: Array = Economy.themes(Economy.THEME_CARD_BACK)
	var tables: Array = Economy.themes(Economy.THEME_BACKGROUND)
	_check(backs.size() == 3 and tables.size() == 3, "파는 카드 뒷면 3종과 배경 3종(기본은 따로)")
	_check(backs.map(func(t: Dictionary) -> int: return t["price"]) == [600, 900, 1200], "카드 뒷면 600, 900, 1,200")
	_check(tables.map(func(t: Dictionary) -> int: return t["price"]) == [800, 1200, 1600], "배경 800, 1,200, 1,600")
	var total: int = 0
	for theme: Dictionary in backs + tables:
		total += Economy.theme_price(theme["id"])
	_check(total == 6300, "꾸미기 6종의 합은 6,300(05 문서)")
	_check(Economy.theme_price("") == 0 and Economy.theme_price("nope") == 0, "기본과 모르는 테마는 0")
	_check(Economy.theme_kind("card_back_mint") == Economy.THEME_CARD_BACK and Economy.theme_kind("background_night") == Economy.THEME_BACKGROUND, "종류")
	_check(Economy.theme_kind("nope") == "", "모르는 테마의 종류는 비어 있다")
	return true


func _boosters() -> bool:
	var store := MemoryStore.new()
	var analytics := MemoryAnalytics.new()
	var shop := Shop.new(store, analytics)
	var progress: Progress = _rich(250)
	var bought: Dictionary = shop.buy_booster(progress, Economy.BOOSTER_HINT)
	_check(bought["ok"] and progress.coins() == 150 and progress.booster(Economy.BOOSTER_HINT) == 1, "힌트 100으로 1개")
	_check(store.writes == 1 and store.saved["profile"]["boosters"]["hint"] == 1, "사면 바로 저장한다")
	_check(analytics.last("spend_virtual_currency") == {"virtual_currency_name": "coin", "value": 100, "item_name": "hint"}, "코인 사용을 알린다")
	var short: Dictionary = shop.buy_booster(progress, Economy.BOOSTER_SLOT)
	_check(short["ok"] and progress.coins() == 0, "칸 추가 150")
	var poor: Dictionary = shop.buy_booster(progress, Economy.BOOSTER_UNDO)
	_check(not poor["ok"] and poor["reason"] == "no_coins" and poor["short"] == 80, "코인이 모자라면 모자란 수를 돌려준다")
	_check(store.writes == 2, "못 사면 저장하지 않는다")
	_check(shop.buy_booster(progress, Economy.CONTINUE)["reason"] == "unknown", "이어하기는 상점에서 팔지 않는다")
	return true


func _themes() -> bool:
	var store := MemoryStore.new()
	var analytics := MemoryAnalytics.new()
	var shop := Shop.new(store, analytics)
	var progress: Progress = _rich(700)
	_check(shop.status(progress, "card_back_mint") == {"owned": false, "selected": false, "price": 600, "short": 0}, "사기 전 상태")
	_check(shop.status(progress, "card_back_night")["short"] == 500, "모자란 코인")
	_check(shop.status(progress, "")["owned"] and shop.status(progress, "")["selected"], "기본 테마는 가지고 있고 고른 상태")
	var bought: Dictionary = shop.buy_theme(progress, "card_back_mint")
	_check(bought["ok"] and progress.coins() == 100 and progress.owns_theme("card_back_mint"), "카드 뒷면을 산다")
	_check(progress.selected_theme(Economy.THEME_CARD_BACK) == "card_back_mint", "산 테마는 바로 쓴다")
	_check(store.writes == 1 and analytics.last("spend_virtual_currency")["item_name"] == "card_back_mint", "저장과 알림")
	_check(shop.buy_theme(progress, "card_back_mint")["reason"] == "owned", "가진 테마는 다시 사지 않는다")
	_check(shop.buy_theme(progress, "background_mint")["reason"] == "no_coins", "코인이 모자라면 사지 않는다")
	_check(shop.buy_theme(progress, "nope")["reason"] == "unknown", "모르는 테마")
	_check(shop.select_theme(progress, Economy.THEME_CARD_BACK, ""), "기본으로 되돌린다")
	_check(progress.selected_theme(Economy.THEME_CARD_BACK) == "" and store.writes == 2, "되돌림도 저장한다")
	_check(not shop.select_theme(progress, Economy.THEME_BACKGROUND, "background_mint"), "안 가진 테마는 고를 수 없다")
	_check(not shop.select_theme(progress, Economy.THEME_BACKGROUND, "card_back_mint"), "다른 종류의 테마는 고를 수 없다")
	return true


func _attendance() -> bool:
	var store := MemoryStore.new()
	var analytics := MemoryAnalytics.new()
	var attendance := Attendance.new(store, analytics)
	var progress: Progress = Progress.create()
	var before: Dictionary = attendance.status(progress, "2026-12-01")
	_check(before["can_claim"] and before["today"] == 0 and before["claimed"] == 0, "첫날은 1일째를 받을 수 있다")
	_check(before["rewards"].size() == 7 and before["rewards"][0] == {"coins": 20} and before["rewards"][5] == {"boosters": {"slot": 1}}, "7칸의 보상")
	var first: Dictionary = attendance.claim(progress, "2026-12-01")
	_check(first["ok"] and first["day"] == 0 and progress.coins() == 20 and store.writes == 1, "1일째 코인 20")
	_check(analytics.last("attendance_claim") == {"day": 1} and analytics.last("earn_virtual_currency")["source"] == "attendance", "출석과 코인을 알린다")
	var after: Dictionary = attendance.status(progress, "2026-12-01")
	_check(not after["can_claim"] and after["today"] == -1 and after["claimed"] == 1, "받은 날은 다시 받을 수 없다")
	_check(not attendance.claim(progress, "2026-12-01")["ok"] and store.writes == 1, "같은 날 두 번 받지 않는다")
	# 하루를 건너뛰어도 2일째로 이어진다.
	var second: Dictionary = attendance.claim(progress, "2026-12-03")
	_check(second["ok"] and second["day"] == 1 and progress.booster(Economy.BOOSTER_HINT) == 1, "건너뛰어도 2일째(힌트 1)")
	_check(analytics.count("earn_virtual_currency") == 1, "부스터만 받으면 코인 획득은 알리지 않는다")
	for day: int in range(4, 9):
		attendance.claim(progress, "2026-12-%02d" % day)
	var full: Dictionary = attendance.status(progress, "2026-12-08")
	_check(full["claimed"] == 7 and not full["can_claim"], "7일째까지 받으면 일곱 칸이 모두 찬다")
	var next: Dictionary = attendance.status(progress, "2026-12-09")
	_check(next["can_claim"] and next["today"] == 0 and next["claimed"] == 0, "다음 날 다시 1일째부터")
	return true


## 모든 범주의 한국어와 영어 이름이 가장 좁은 도감 칸(폭 360 화면)에서 두 줄 안에 들어가고, 한국어는 낱말 가운데서 줄이 바뀌지 않는다.
func _album_names() -> bool:
	var content := Content.new(_read("res://data/content/items.json"), _read("res://data/content/categories.json"))
	var ids: PackedStringArray = content.category_ids()
	_check(ids.size() == 158, "범주 158개를 모두 본다: %d" % ids.size())
	for language: String in ["en", "ko"]:
		var cut: PackedStringArray = []
		var shrunk: int = 0
		for category: String in ids:
			var display_name: String = content.category_name(category, language)
			var fit: Dictionary = AlbumScreen.fit_name(display_name, language, AlbumScreen.NAME_MIN_WIDTH)
			if not fit["fits"] or int(fit["lines"]) > AlbumScreen.NAME_LINES:
				cut.append(display_name)
			elif int(fit["size"]) < AlbumScreen.NAME_SIZES[0]:
				shrunk += 1
		_check(cut.is_empty(), "%s category names fit two lines of the narrowest album cell: %s" % [language, ", ".join(cut)])
		print("  %s: %d of %d names use a smaller size" % [language, shrunk, ids.size()])
	# 띄어쓰기에서만 나뉜다: 두 줄이면 첫 줄은 낱말 경계에서 끝난다.
	var pot: Dictionary = AlbumScreen.fit_name("냄비와 그릇 요리", "ko", AlbumScreen.NAME_MIN_WIDTH)
	_check(pot["fits"] and int(pot["lines"]) == 2 and _breaks_at_spaces(pot["text"], int(pot["size"]), AlbumScreen.NAME_MIN_WIDTH),
		"'냄비와 그릇 요리' breaks at a space, not inside 요리")
	var long_word: Dictionary = AlbumScreen.fit_name("브라키오사우루스", "ko", AlbumScreen.NAME_MIN_WIDTH)
	_check(not long_word["fits"] and int(long_word["size"]) == AlbumScreen.NAME_SIZES.back(), "a word wider than the cell is never broken inside; it is reported as not fitting")
	return true


## 낱말 이음표를 넣은 글이 폭 width에서 줄마다 띄어쓰기로 끝나는지(마지막 줄 빼고).
func _breaks_at_spaces(text: String, font_size: int, width: float) -> bool:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	paragraph.add_string(text, Fonts.label("ko"), font_size)
	for line: int in paragraph.get_line_count() - 1:
		var span: Vector2i = paragraph.get_line_range(line)
		var tail: String = text.substr(span.x, span.y - span.x).replace(Fonts.WORD_JOINER, "")
		if not tail.ends_with(" "):
			return false
	return true


func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
