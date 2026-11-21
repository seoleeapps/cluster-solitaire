extends RefCounted
## 출석(SCR-011) 팝업. 일곱 칸에 날짜별 보상을 보이고 오늘 칸을 강조한다. 받은 칸은 체크다.
## 하루를 건너뛰어도 이어서 받는다(주기는 받은 횟수로 센다). 받기는 host.claim_attendance()가 맡는다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")

const CELL := Vector2(62, 84)
const REWARD_ICON := 34.0
## 부스터 보상의 그림(features/play/assets).
const BOOSTER_ART := {Economy.BOOSTER_HINT: "gift_hint", Economy.BOOSTER_UNDO: "gift_undo", Economy.BOOSTER_SLOT: "gift_slot"}


## 팝업을 만든다. status는 FaAttendance.status의 결과다.
static func build(host: Control, status: Dictionary) -> Control:
	var popup: Control = Ui.popup(host.tr_text("Daily Check-in", "출석 보상"), true, host.size.x)
	popup.name = "attendance_popup"
	var box := VBoxContainer.new()
	box.name = "column"
	box.add_theme_constant_override("separation", 12)
	popup.add_content(box)
	box.add_child(Ui.note(host.tr_text("Come back each day for a gift. Missed a day? You just pick up where you left off.",
		"하루에 한 번 선물을 받아요. 하루를 걸러도 이어서 받아요."), 14))
	# 일곱 칸: 네 칸과 세 칸의 두 줄, 둘 다 가운데 정렬.
	var days := VBoxContainer.new()
	days.name = "days"
	days.add_theme_constant_override("separation", 10)
	box.add_child(days)
	var rewards: Array = status["rewards"]
	var row: HBoxContainer
	for day: int in rewards.size():
		if day % 4 == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			days.add_child(row)
		row.add_child(_cell(host, day, rewards[day], day < int(status["claimed"]), day == int(status["today"])))
	var claim: Button
	if status["can_claim"]:
		claim = Ui.button("claim", host.tr_text("Claim", "받기"), true, func() -> void: host.claim_attendance())
	else:
		claim = Ui.button("claim", host.tr_text("Come back tomorrow", "내일 또 만나요"), false, func() -> void: pass)
		claim.disabled = true
	box.add_child(claim)
	return popup


static func _cell(host: Control, day: int, reward: Dictionary, claimed: bool, today: bool) -> Control:
	var cell := Control.new()
	cell.name = "day_%d" % (day + 1)
	cell.custom_minimum_size = CELL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.set_meta("state", "today" if today else ("claimed" if claimed else "later"))
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plate: String = "day_today" if today else "day_cell"
	frame.add_theme_stylebox_override("panel", Art.box(Art.outgame(plate), [12, 12, 12, 16], [4, 6, 4, 10]))
	cell.add_child(frame)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 1)
	frame.add_child(column)
	var label: Label = Fonts.text(host.tr_text("Day %d", "%d일째") % (day + 1), Fonts.display(700), Ui.sized(12), Color("6a6a9a"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var art: Texture2D = Art.skin("icon_coin")
	var amount: String = str(int(reward.get("coins", 0)))
	var boosters: Dictionary = reward.get("boosters", {})
	for id: String in boosters:
		art = Art.play(BOOSTER_ART[id])
		amount = "×%d" % int(boosters[id])
	var icon: TextureRect = Art.picture(art, Vector2.ONE * REWARD_ICON)
	icon.custom_minimum_size = Vector2.ONE * REWARD_ICON
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(icon)
	var value: Label = Fonts.text(amount, Fonts.display(700), Ui.sized(15), Fonts.INK)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	if claimed:
		column.modulate.a = 0.45
		var tick: TextureRect = Art.picture(Art.play("tick"), Vector2(26, 28))
		tick.name = "tick"
		tick.position = Vector2(CELL.x - 20, -8)
		cell.add_child(tick)
	elif today and not Juice.reduced_motion:
		Juice.idle_pulse(icon, 1.12, 1.2)
	return cell
