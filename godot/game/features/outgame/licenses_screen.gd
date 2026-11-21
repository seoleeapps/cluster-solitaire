extends VBoxContainer
## 오픈소스 고지(설정에서 연다). 카드 그림(Fluent Emoji, MIT), 글꼴(OFL), 광고 플러그인(MIT)의 이름과 고지 원문을 보인다.
## 원문은 저장소의 라이선스 파일에서 읽는다. 내보내기 설정의 포함 목록이 이 파일들을 싣는다(export_presets.cfg).

const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")

## [id, 이름, 라이선스, 원문 경로]
const ENTRIES := [
	["fluent", "Fluent Emoji (Microsoft)", "MIT", "res://data/licenses/FluentEmoji-MIT.txt"],
	["fredoka", "Fredoka", "SIL Open Font License 1.1", "res://addons/seorilabs_game/fonts/Fredoka-OFL.txt"],
	["jua", "Jua", "SIL Open Font License 1.1", "res://addons/seorilabs_game/fonts/Jua-OFL.txt"],
	["noto_sans_kr", "Noto Sans KR", "SIL Open Font License 1.1", "res://addons/seorilabs_game/fonts/NotoSansKR-OFL.txt"],
	["noto_sans_mono", "Noto Sans Mono", "SIL Open Font License 1.1", "res://addons/seorilabs_game/fonts/NotoSansMono-OFL.txt"],
	["admob", "Godot AdMob plugin (Poing Studios)", "MIT", "res://data/licenses/AdMob-MIT.txt"],
]

var host: Control
## 펼친 고지의 id.
var opened: String = ""


func _ready() -> void:
	name = "licenses_screen"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	rebuild()


## 고지 원문. 파일을 읽지 못하면 "".
static func text_of(path: String) -> String:
	return FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""


## 좁은 화면에서 읽기 쉽게 원문의 줄바꿈을 문단 단위로 다시 잇는다. 빈 줄은 문단 사이로 남기고 앞뒤 공백은 지운다.
## 글자는 바꾸지 않는다.
static func reflow(text: String) -> String:
	var paragraphs: PackedStringArray = []
	var current: PackedStringArray = []
	for line: String in text.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			if not current.is_empty():
				paragraphs.append(" ".join(current))
				current = []
		else:
			current.append(trimmed)
	if not current.is_empty():
		paragraphs.append(" ".join(current))
	return "\n\n".join(paragraphs)


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.name = "licenses_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(box)
	box.add_child(Ui.note(host.tr_text("This game uses the open-source works below. Tap one to read its notice.",
		"이 게임은 아래 오픈소스를 씁니다. 눌러서 고지 원문을 볼 수 있어요."), 13))
	for entry: Array in ENTRIES:
		var id: String = entry[0]
		var button: Button = Ui.button("license_" + id, "%s · %s" % [entry[1], entry[2]], false, _toggle.bind(id), null, Vector2.ZERO, 250.0, [15, 14, 13])
		box.add_child(button)
		if opened == id:
			var body: Label = Fonts.text(reflow(text_of(entry[3])), Fonts.body(400), Ui.sized(12), Fonts.INK)
			body.name = "license_text"
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(body)


func _toggle(id: String) -> void:
	opened = "" if opened == id else id
	rebuild()
