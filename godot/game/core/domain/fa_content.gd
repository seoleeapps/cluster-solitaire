class_name FaContent
extends RefCounted
## 카드와 범주 원장의 색인. 두 JSON 문서를 Dictionary로 받아 조회와 형식 검증을 제공한다.
## 한 범주의 후보는 소속(members)과 그 범주로도 보일 수 있는 카드(also)의 합이다.
## 문서의 version은 콘텐츠 판 번호(1 이상)다. 두 문서의 번호가 같아야 하고, 레벨 팩의 content_version과 맞춰 본다.

const TIER_MIN := 1
const TIER_MAX := 4
const MIN_MEMBERS := 4

var _version: int = 0
var _problems: PackedStringArray = []
var _item_ids: PackedStringArray = []
var _items: Dictionary = {}
var _category_ids: PackedStringArray = []
var _categories: Dictionary = {}
var _members: Dictionary = {}
var _candidates: Dictionary = {}
var _candidate_sets: Dictionary = {}
var _item_categories: Dictionary = {}


func _init(items_doc: Dictionary, categories_doc: Dictionary) -> void:
	var items_version: int = _document_version(items_doc, "items")
	var categories_version: int = _document_version(categories_doc, "categories")
	if items_version > 0:
		_index_items(items_doc["items"])
	if categories_version > 0:
		_index_categories(categories_doc["categories"])
	if items_version > 0 and categories_version > 0:
		if items_version == categories_version:
			_version = items_version
		else:
			_problems.append("version_mismatch: items %d categories %d" % [items_version, categories_version])


## 형식 문제 목록. 한 줄은 "코드: 대상" 꼴이고 비어 있으면 문제가 없다.
func problems() -> PackedStringArray:
	return _problems


## 콘텐츠 판 번호. 두 문서를 읽을 수 없거나 번호가 서로 다르면 0.
func version() -> int:
	return _version


func item_ids() -> PackedStringArray:
	return _item_ids


func has_item(item_id: String) -> bool:
	return _items.has(item_id)


## 언어 코드에 맞는 카드 이름. 모르는 언어는 영어 이름을 쓴다.
func item_name(item_id: String, language: String) -> String:
	return _localized(_items.get(item_id, {}), language)


func item_icon(item_id: String) -> String:
	return _items.get(item_id, {}).get("icon", "")


func category_ids() -> PackedStringArray:
	return _category_ids


func has_category(category_id: String) -> bool:
	return _categories.has(category_id)


func category_name(category_id: String, language: String) -> String:
	return _localized(_categories.get(category_id, {}), language)


## 범주 난도 1~4. 없는 범주는 0.
func category_tier(category_id: String) -> int:
	return _categories.get(category_id, {}).get("tier", 0)


func category_domain(category_id: String) -> String:
	return _categories.get(category_id, {}).get("domain", "")


func category_members(category_id: String) -> PackedStringArray:
	return _members.get(category_id, PackedStringArray())


func category_candidates(category_id: String) -> PackedStringArray:
	return _candidates.get(category_id, PackedStringArray())


func is_candidate(category_id: String, item_id: String) -> bool:
	return _candidate_sets.get(category_id, {}).has(item_id)


## 이 카드를 후보로 가진 범주 목록(문서 순서).
func categories_of_item(item_id: String) -> PackedStringArray:
	return _item_categories.get(item_id, PackedStringArray())


func _localized(entry: Dictionary, language: String) -> String:
	return entry.get(language, entry.get("en", ""))


## 문서의 판 번호. 목록이 없거나 번호가 1 이상의 정수가 아니면 문제로 남기고 0을 돌려준다.
func _document_version(doc: Dictionary, list_key: String) -> int:
	if not doc.get(list_key) is Array:
		_problems.append("bad_document: " + list_key)
		return 0
	if not _is_whole(doc.get("version")) or doc["version"] < 1:
		_problems.append("bad_version: " + list_key)
		return 0
	return int(doc["version"])


func _index_items(entries: Array) -> void:
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not entry is Dictionary or not _is_text(entry.get("id")):
			_problems.append("bad_item: #%d" % index)
			continue
		var item_id: String = entry["id"]
		if _items.has(item_id):
			_problems.append("duplicate_item: " + item_id)
			continue
		if not (_is_text(entry.get("icon")) and _is_text(entry.get("en")) and _is_text(entry.get("ko"))):
			_problems.append("bad_item: " + item_id)
			continue
		_items[item_id] = {"icon": entry["icon"], "en": entry["en"], "ko": entry["ko"]}
		_item_ids.append(item_id)


func _index_categories(entries: Array) -> void:
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not entry is Dictionary or not _is_text(entry.get("id")):
			_problems.append("bad_category: #%d" % index)
			continue
		var category_id: String = entry["id"]
		if _categories.has(category_id):
			_problems.append("duplicate_category: " + category_id)
			continue
		var tier: Variant = entry.get("tier")
		var fields_ok: bool = _is_text(entry.get("domain")) and _is_text(entry.get("en")) and _is_text(entry.get("ko"))
		var tier_ok: bool = _is_whole(tier) and int(tier) >= TIER_MIN and int(tier) <= TIER_MAX
		if not (fields_ok and tier_ok and entry.get("members") is Array and entry.get("also") is Array):
			_problems.append("bad_category: " + category_id)
			continue
		var seen: Dictionary = {}
		var members: PackedStringArray = _collect(category_id, entry["members"], seen)
		var candidates: PackedStringArray = members.duplicate()
		candidates.append_array(_collect(category_id, entry["also"], seen))
		if members.size() < MIN_MEMBERS:
			_problems.append("too_few_members: " + category_id)
		_categories[category_id] = {"tier": int(tier), "domain": entry["domain"], "en": entry["en"], "ko": entry["ko"]}
		_category_ids.append(category_id)
		_members[category_id] = members
		_candidates[category_id] = candidates
		_candidate_sets[category_id] = seen
		for item_id: String in candidates:
			var owners: PackedStringArray = _item_categories.get(item_id, PackedStringArray())
			owners.append(category_id)
			_item_categories[item_id] = owners


## 한 범주의 카드 목록에서 쓸 수 있는 id만 고른다. seen에는 이 범주에서 이미 나온 id가 쌓인다.
func _collect(category_id: String, entries: Array, seen: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = []
	for entry: Variant in entries:
		if not _is_text(entry) or not _items.has(entry):
			_problems.append("unknown_item: %s %s" % [category_id, str(entry)])
		elif seen.has(entry):
			_problems.append("duplicate_member: %s %s" % [category_id, entry])
		else:
			seen[entry] = true
			result.append(entry)
	return result


static func _is_text(value: Variant) -> bool:
	return value is String and not value.is_empty()


static func _is_whole(value: Variant) -> bool:
	return value is int or (value is float and value == floorf(value))
