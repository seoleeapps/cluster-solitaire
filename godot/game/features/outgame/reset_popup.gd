extends RefCounted
## 데이터 초기화(SCR-014)의 두 번 확인 창. 같은 창에서 두 단계를 차례로 보인다.
##   첫 확인: 무엇이 지워지는지(꼬리표 목록), 지우기(주 버튼)와 취소.
##   둘째 확인: 되돌릴 수 없다는 문장, 빨간 주 버튼(모두 지우기)과 취소.
## 취소, 닫기, 어두운 바깥 누르기, 뒤로 가기는 아무것도 지우지 않고 창만 닫는다. 지우기는 host.erase_all_data()가 맡는다.

const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")

const CHIP_BACK := Color("eef0fb")
const CHIP_RADIUS := 14
const CHIP_SIZE := 14
## 지워지는 것(영어, 한국어). 저장과 리셋 계약(02 문서)의 묶음과 공통 흐름의 설정이다.
const ERASED := [
	["Stage progress", "스테이지 진행"], ["Coins", "코인"], ["Boosters", "부스터"], ["Album", "도감"],
	["Daily & check-in", "일일 도전과 출석"], ["Decor", "꾸미기"], ["Settings", "설정"],
]


## 창을 만든다. 처음에는 첫 확인을 보인다.
static func build(host: Control) -> Control:
	var popup: Control = Ui.popup(host.tr_text("Reset game data", "데이터 초기화"), true, host.size.x)
	popup.name = "reset_popup"
	popup.set_meta("step", "first")
	var box := VBoxContainer.new()
	box.name = "column"
	box.add_theme_constant_override("separation", 12)
	popup.add_content(box)
	box.add_child(Ui.note(host.tr_text("This deletes everything below from this device and starts the game over.",
		"아래 기록을 이 기기에서 모두 지우고 처음부터 다시 시작해요."), 15))
	box.add_child(_erased_list(host))
	box.add_child(Ui.button("delete", host.tr_text("Delete", "지우기"), true, func() -> void: _second(host, popup, box)))
	box.add_child(Ui.button("cancel", host.tr_text("Cancel", "취소"), false, popup.close))
	return popup


## 둘째 확인으로 바꾼다.
static func _second(host: Control, popup: Control, first: Control) -> void:
	# 누른 버튼이 이 안에 있으므로 지금은 숨기기만 하고 프레임 끝에 지운다.
	first.visible = false
	first.queue_free()
	popup.set_meta("step", "final")
	popup.set_title(host.tr_text("Delete all data?", "정말 지울까요?"))
	var box := VBoxContainer.new()
	box.name = "final"
	box.add_theme_constant_override("separation", 12)
	popup.add_content(box)
	var warning: Label = Ui.note(host.tr_text("This can't be undone. Your progress and coins won't come back.",
		"되돌릴 수 없어요. 지운 진행과 코인은 다시 찾을 수 없어요."), 16, Ui.DANGER_INK)
	warning.name = "warning"
	box.add_child(warning)
	var delete_all: Button = Ui.button("delete_all", host.tr_text("Delete all", "모두 지우기"), true, func() -> void: pass)
	Ui.danger(delete_all)
	var cancel: Button = Ui.button("cancel", host.tr_text("Cancel", "취소"), false, popup.close)
	delete_all.pressed.connect(func() -> void:
		# 두 번 눌러도 한 번만 지운다.
		delete_all.disabled = true
		cancel.disabled = true
		host.erase_all_data())
	box.add_child(delete_all)
	box.add_child(cancel)


## 지워지는 것을 꼬리표로 늘어놓는다. 줄이 모자라면 꼬리표 단위로 다음 줄로 넘긴다.
static func _erased_list(host: Control) -> Control:
	var flow := HFlowContainer.new()
	flow.name = "erased"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = CHIP_BACK
	plate.set_corner_radius_all(CHIP_RADIUS)
	plate.content_margin_left = 11
	plate.content_margin_right = 11
	plate.content_margin_top = 4
	plate.content_margin_bottom = 5
	for pair: Array in ERASED:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", plate)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = Fonts.text(host.tr_text(pair[0], pair[1]), Fonts.display(600), Ui.sized(CHIP_SIZE), Fonts.INK)
		chip.add_child(label)
		flow.add_child(chip)
	return flow
