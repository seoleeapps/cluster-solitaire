extends SceneTree
## 콘텐츠 색인 검사: 카드와 범주 조회, 후보 집합, 형식 검증이 찾아내는 문제.

const Content := preload("res://game/core/domain/fa_content.gd")

var _checks: int = 0
var _failed: PackedStringArray = []


func _initialize() -> void:
	_section("실은 콘텐츠", _shipped_content)
	_section("조회", _lookups)
	_section("후보", _candidates)
	_section("형식 검증", _validation)
	print("Fa content probe: %d checks, %d failed" % [_checks, _failed.size()])
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


func _items() -> Dictionary:
	return {"version": 1, "items": [
		{"id": "apple", "icon": "red_apple", "en": "Apple", "ko": "사과"},
		{"id": "pear", "icon": "pear", "en": "Pear", "ko": "배"},
		{"id": "plum", "icon": "plum", "en": "Plum", "ko": "자두"},
		{"id": "lime", "icon": "lime", "en": "Lime", "ko": "라임"},
		{"id": "rose", "icon": "rose", "en": "Rose", "ko": "장미"},
		{"id": "ruby", "icon": "gem", "en": "Ruby", "ko": "루비"},
		{"id": "brick", "icon": "brick", "en": "Brick", "ko": "벽돌"},
		{"id": "heart", "icon": "heart", "en": "Heart", "ko": "하트"},
	]}


func _categories() -> Dictionary:
	return {"version": 1, "categories": [
		{"id": "fruits", "tier": 1, "domain": "food", "en": "Fruits", "ko": "과일",
			"members": ["apple", "pear", "plum", "lime"], "also": []},
		{"id": "red", "tier": 3, "domain": "color", "en": "Red Things", "ko": "빨간 것",
			"members": ["rose", "ruby", "brick", "heart"], "also": ["apple"]},
	]}


func _shipped_content() -> bool:
	var content: Content = Content.new(_read("res://data/content/items.json"), _read("res://data/content/categories.json"))
	_check(content.problems().is_empty(), "실은 콘텐츠에 형식 문제가 없다: " + ", ".join(content.problems()))
	_check(content.version() == 1, "콘텐츠 버전 1")
	_check(content.item_ids().size() == 845, "카드 845장")
	_check(content.category_ids().size() == 164, "범주 164개")
	_check(content.item_name("banana", "ko") == "바나나" and content.item_name("banana", "en") == "Banana", "카드 이름 두 언어")
	_check(content.category_name("fruits", "ko") == "과일", "범주 이름")
	_check(content.category_tier("fruits") == 1 and content.category_domain("fruits") == "food", "범주 난도와 대분류")
	_check(content.category_members("fruits").size() == 16, "과일 소속 16장")
	return true


func _lookups() -> bool:
	var content: Content = Content.new(_items(), _categories())
	_check(content.problems().is_empty(), "작은 콘텐츠에 문제 없음")
	_check(content.has_item("apple") and not content.has_item("stone"), "카드 존재 여부")
	_check(content.item_icon("ruby") == "gem", "아이콘 키")
	_check(content.item_name("ruby", "ko") == "루비" and content.item_name("ruby", "en") == "Ruby", "언어별 카드 이름")
	_check(content.item_name("ruby", "fr") == "Ruby", "모르는 언어는 영어 이름")
	_check(content.item_name("stone", "en") == "" and content.item_icon("stone") == "", "없는 카드는 빈 문자열")
	_check(content.has_category("red") and not content.has_category("blue"), "범주 존재 여부")
	_check(content.category_name("red", "en") == "Red Things" and content.category_name("red", "ko") == "빨간 것", "언어별 범주 이름")
	_check(content.category_tier("red") == 3 and content.category_tier("blue") == 0, "범주 난도")
	_check(content.category_domain("red") == "color" and content.category_domain("blue") == "", "범주 대분류")
	_check(Array(content.item_ids()) == ["apple", "pear", "plum", "lime", "rose", "ruby", "brick", "heart"], "카드 순서는 문서 순서")
	_check(Array(content.category_ids()) == ["fruits", "red"], "범주 순서는 문서 순서")
	return true


func _candidates() -> bool:
	var content: Content = Content.new(_items(), _categories())
	_check(Array(content.category_members("red")) == ["rose", "ruby", "brick", "heart"], "소속")
	_check(Array(content.category_candidates("red")) == ["rose", "ruby", "brick", "heart", "apple"], "후보는 소속과 also의 합")
	_check(content.is_candidate("red", "apple") and content.is_candidate("fruits", "apple"), "사과는 두 범주의 후보")
	_check(not content.is_candidate("fruits", "rose") and not content.is_candidate("blue", "rose"), "후보가 아닌 경우")
	_check(Array(content.categories_of_item("apple")) == ["fruits", "red"], "카드가 후보인 범주 목록")
	_check(Array(content.categories_of_item("pear")) == ["fruits"], "한 범주에만 속한 카드")
	_check(content.categories_of_item("stone").is_empty() and content.category_members("blue").is_empty(), "없는 id는 빈 목록")
	return true


func _problems_of(items: Dictionary, categories: Dictionary) -> String:
	return "\n".join(Content.new(items, categories).problems())


func _validation() -> bool:
	var categories: Dictionary = _categories()
	categories["categories"][0]["members"] = ["apple", "pear", "plum", "stone"]
	_check(_problems_of(_items(), categories).contains("unknown_item: fruits stone"), "없는 카드 참조")

	categories = _categories()
	categories["categories"][1]["also"] = ["ghost"]
	_check(_problems_of(_items(), categories).contains("unknown_item: red ghost"), "also의 없는 카드 참조")

	categories = _categories()
	categories["categories"][0]["members"] = ["apple", "pear", "plum"]
	_check(_problems_of(_items(), categories).contains("too_few_members: fruits"), "소속 4장 미만")

	categories = _categories()
	categories["categories"][0]["members"] = ["apple", "pear", "plum", "lime", "pear"]
	_check(_problems_of(_items(), categories).contains("duplicate_member: fruits pear"), "소속 중복")

	categories = _categories()
	categories["categories"][1]["also"] = ["apple", "rose"]
	_check(_problems_of(_items(), categories).contains("duplicate_member: red rose"), "소속과 also 중복")

	categories = _categories()
	categories["categories"].append(categories["categories"][0].duplicate(true))
	_check(_problems_of(_items(), categories).contains("duplicate_category: fruits"), "범주 id 중복")

	var items: Dictionary = _items()
	items["items"].append({"id": "apple", "icon": "x", "en": "Apple 2", "ko": "사과 2"})
	_check(_problems_of(items, _categories()).contains("duplicate_item: apple"), "카드 id 중복")

	items = _items()
	items["items"][1] = {"id": "pear", "icon": "pear", "en": "", "ko": "배"}
	_check(_problems_of(items, _categories()).contains("bad_item: pear"), "이름이 빈 카드")

	categories = _categories()
	categories["categories"][0]["tier"] = 5
	_check(_problems_of(_items(), categories).contains("bad_category: fruits"), "난도 범위 밖")

	categories = _categories()
	categories["categories"][0].erase("domain")
	_check(_problems_of(_items(), categories).contains("bad_category: fruits"), "대분류 없음")

	items = _items()
	items["version"] = 2
	_check(_problems_of(items, _categories()).contains("bad_version: items"), "카드 문서 버전")
	_check(_problems_of({}, {}).contains("bad_document: items") and _problems_of({}, {}).contains("bad_document: categories"), "빈 문서")

	var broken: Content = Content.new(_items(), {"version": 1, "categories": [{"id": "fruits"}, 7]})
	_check(broken.problems().size() == 2 and broken.category_ids().is_empty(), "깨진 범주는 색인하지 않는다")
	return true
