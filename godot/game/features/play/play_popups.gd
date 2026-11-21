extends RefCounted
## 플레이에 딸린 팝업을 만든다: 일시정지(SCR-004), 막힘(SCR-005), 실패(SCR-006), 결과(SCR-007),
## 부스터 얻기(SCR-013), 튜토리얼 끝 카드(SCR-012). 모두 공통 기반의 popup_base를 쓰고 화면이 Popup 층에 올린다.
## 버튼은 이름으로 찾는다(resume, restart, home, confirm, cancel, undo, slot, continue, next, double, buy, watch, claim).

const PopupBase := preload("res://addons/seorilabs_game/ui_kit/popup_base.tscn")
const Sparkle := preload("res://addons/seorilabs_game/ui_kit/particles/sparkle.tscn")
const Juice := preload("res://addons/seorilabs_game/ui_kit/juice.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Board := preload("res://game/core/domain/fa_board.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const UseBooster := preload("res://game/core/use_cases/fa_use_booster.gd")
const ContinueRound := preload("res://game/core/use_cases/fa_continue_round.gd")

const ICON_DIR := "res://game/assets/icons/"
const WIDTH := 318.0
const BUTTON_HEIGHT := 54.0
## 버튼 안에서 글자와 아이콘이 쓸 수 있는 폭(창의 폭에서 틀과 버튼의 안쪽 여백을 뺀 값), 둘 사이 간격, 아래 옆면의 높이.
const BUTTON_TEXT_ROOM := 234.0
const BUTTON_ICON_GAP := 8
const BUTTON_LIP := 6.0
const BUTTON_FONT_SIZES: Array[int] = [20, 18, 16]
const BUTTON_SECOND_LINE := 14.0
const PRIMARY_SHADE := Color("b85a00")
const DIM := Color(0.09, 0.07, 0.3, 0.62)
const RED := Color("ff4b5c")
const STAR_SIZE := 52.0
const STAR_GAP := 0.25
const COUNT_SECONDS := 0.6
const FLYING_COINS := 6
## 실패 창에서 코인이 모자라 이어 갈 수 없는 상태.
const WAY_SHORT := "short"

## 실패 창에 펼쳐 보인 남은 묶음의 범주(판의 순서).
var revealed: Array = []

var _screen: Control


func _init(screen: Control) -> void:
	_screen = screen


# =====================================================================
# 일시정지
# =====================================================================

func pause() -> Control:
	var popup: Control = _base(_t("Paused", "잠깐 멈춤"), true)
	var box: VBoxContainer = _column(popup)
	var restart_note: String = _t("Start this board over? Your progress on it will be lost.", "이 판을 처음부터 다시 할까요? 지금까지의 진행이 사라져요.")
	var home_note: String = _t("Go home? Your progress on this board will be lost.", "홈으로 갈까요? 이 판의 진행이 사라져요.")
	box.add_child(_button("resume", _t("Resume", "계속"), true, _screen.close_popup))
	box.add_child(_button("restart", _t("Restart", "다시 하기"), false, _confirm.bind(popup, box, restart_note, _t("Restart", "다시 하기"), _screen.restart)))
	box.add_child(_button("home", _t("Home", "홈으로"), false, _confirm.bind(popup, box, home_note, _t("Home", "홈으로"), _screen.leave_home)))
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 8)
	box.add_child(toggles)
	for pair: Array in [["sfx", _t("Sound", "효과음")], ["music", _t("Music", "음악")]]:
		var toggle := CheckButton.new()
		toggle.name = pair[0]
		toggle.text = pair[1]
		toggle.custom_minimum_size.y = 48
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.button_pressed = bool(_screen.host.state.data.settings[pair[0]])
		toggle.toggled.connect(_on_toggle.bind(toggle, pair[0]))
		toggles.add_child(toggle)
	return popup


func _on_toggle(on: bool, toggle: CheckButton, key: String) -> void:
	if _screen.host.state.setting(key, on):
		_screen.host._apply_settings()
	else:
		toggle.set_pressed_no_signal(bool(_screen.host.state.data.settings[key]))


## 진행을 잃는 행동은 한 줄로 알린 뒤에 실행한다.
func _confirm(popup: Control, box: VBoxContainer, message: String, confirm_label: String, action: Callable) -> void:
	box.visible = false
	var ask := VBoxContainer.new()
	ask.name = "ask"
	ask.add_theme_constant_override("separation", 10)
	popup.add_content(ask)
	ask.add_child(_note(message))
	ask.add_child(_button("confirm", confirm_label, true, action))
	ask.add_child(_button("cancel", _t("Cancel", "취소"), false, _cancel_confirm.bind(ask, box)))


func _cancel_confirm(ask: Control, box: Control) -> void:
	ask.queue_free()
	box.visible = true


# =====================================================================
# 막힘
# =====================================================================

func stuck() -> Control:
	var popup: Control = _base(_t("No room left", "칸이 가득 찼어요"), true)
	var box: VBoxContainer = _column(popup)
	var board: Board = _screen.board
	# 그림: 가득 찬 임시 칸.
	var picture := HBoxContainer.new()
	picture.alignment = BoxContainer.ALIGNMENT_CENTER
	picture.add_theme_constant_override("separation", 6)
	for card: String in board.holds():
		if card.is_empty():
			continue
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", Art.box(Art.play("card_face"), [20, 20, 20, 29], [8, 8, 8, 15]))
		cell.add_child(_card_icon(_screen.session.catalog.item_icon(card), 36.0))
		picture.add_child(cell)
	box.add_child(picture)
	box.add_child(_note(_t("Take a card back, open one more slot, or start over.", "카드를 되돌리거나 칸을 하나 더 열거나 다시 시작하세요.")))

	var player: RefCounted = _screen.player()
	var undo_ok: bool = _screen.session.use_booster.check(player, board, Economy.BOOSTER_UNDO)["ok"]
	var undo_owned: int = player.booster(Economy.BOOSTER_UNDO)
	var undo: Button
	if undo_owned > 0:
		undo = _button("undo", _t("Undo (%d left)", "되돌리기 (%d개 남음)") % undo_owned, true, _use_owned.bind(Economy.BOOSTER_UNDO))
	else:
		undo = _coin_button("undo", _t("Undo for %d coins", "코인 %d으로 되돌리기"), Economy.BOOSTER_UNDO, true)
	undo.visible = undo_ok
	box.add_child(undo)

	var slot_ok: bool = _screen.session.use_booster.check(player, board, Economy.BOOSTER_SLOT)["ok"]
	var slot_owned: int = player.booster(Economy.BOOSTER_SLOT)
	var slot: Button
	if slot_owned > 0:
		slot = _button("slot", _t("One more slot (%d left)", "칸 하나 더 (%d개 남음)") % slot_owned, not undo_ok, _use_owned.bind(Economy.BOOSTER_SLOT))
	elif _screen._ad_ready(AdPolicy.REWARDED_BOOSTER):
		slot = _ad_button("slot", _t("Watch ad for +1 slot", "광고 보고 칸 하나 더"), not undo_ok, _watch_booster.bind(Economy.BOOSTER_SLOT, Callable()))
	else:
		slot = _coin_button("slot", _t("One more slot for %d coins", "코인 %d으로 칸 하나 더"), Economy.BOOSTER_SLOT, not undo_ok)
	slot.visible = slot_ok
	box.add_child(slot)
	box.add_child(_button("restart", _t("Restart", "다시 하기"), not undo_ok and not slot_ok, _screen.restart))
	return popup


## 창을 닫고 보유한 부스터를 쓴다.
func _use_owned(kind: String) -> void:
	_screen.close_popup(_screen.apply_booster.bind(kind, UseBooster.SOURCE_OWNED))


# =====================================================================
# 부스터 얻기
# =====================================================================

func booster(kind: String) -> Control:
	var names: Dictionary = {
		Economy.BOOSTER_HINT: [_t("Hint", "힌트"), _t("Shows two cards that belong together.", "같은 범주의 카드 두 장을 알려 줘요.")],
		Economy.BOOSTER_UNDO: [_t("Undo", "되돌리기"), _t("Takes back your last move to a holding slot.", "마지막으로 임시 칸에 옮긴 카드를 되돌려요.")],
		Economy.BOOSTER_SLOT: [_t("Extra slot", "칸 추가"), _t("Opens a third holding slot for this board.", "이번 판의 임시 칸을 하나 더 열어요.")],
	}
	var popup: Control = _base(names[kind][0], true)
	var box: VBoxContainer = _column(popup)
	box.add_child(_note(names[kind][1]))
	box.add_child(_wallet())
	box.add_child(_coin_button("buy", _t("%d coins", "코인 %d"), kind, true))
	var ad_row := VBoxContainer.new()
	ad_row.name = "ad_row"
	box.add_child(ad_row)
	_fill_booster_ad(ad_row, kind)
	return popup


## 광고 버튼, 또는 광고가 없으면 그 사유.
func _fill_booster_ad(row: VBoxContainer, kind: String) -> void:
	if not is_instance_valid(row):
		return
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()
	if _screen._ad_ready(AdPolicy.REWARDED_BOOSTER):
		var label: String = _t("Watch ad for +1 slot", "광고 보고 칸 하나 더") if kind == Economy.BOOSTER_SLOT else _t("Watch ad for 1", "광고 보고 1개 받기")
		row.add_child(_ad_button("watch", label, false, _watch_booster.bind(kind, _fill_booster_ad.bind(row, kind))))
	else:
		var reason: Label = _note(_t("No ad available right now", "지금은 광고가 없어요"))
		reason.name = "no_ad"
		reason.custom_minimum_size.y = BUTTON_HEIGHT
		reason.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(reason)


## 부스터 광고를 본다. 끝까지 보면 그 부스터를 받아 바로 쓰고 창을 닫는다. 받지 못하면 창은 그대로 두고 on_missed를 부른다.
func _watch_booster(kind: String, on_missed: Callable) -> void:
	if not _screen.watch_rewarded(AdPolicy.REWARDED_BOOSTER, _on_booster_ad.bind(kind, on_missed)):
		_screen.show_toast(_t("No ad available right now", "지금은 광고가 없어요"))
		if on_missed.is_valid():
			on_missed.call()


func _on_booster_ad(outcome: String, kind: String, on_missed: Callable) -> void:
	if _screen.session.ad_flow.finish_booster(_screen.player(), outcome, kind):
		_screen.close_popup(_screen.apply_booster.bind(kind, UseBooster.SOURCE_AD))
		return
	_screen.show_toast(_t("No reward this time", "이번에는 보상을 받지 못했어요"))
	if on_missed.is_valid():
		on_missed.call()


# =====================================================================
# 실패
# =====================================================================

func fail() -> Control:
	var popup: Control = _base(_t("Out of mistakes", "실수 4번"), false)
	var box: VBoxContainer = _column(popup)
	var board: Board = _screen.board
	# 남은 묶음의 정답과 범주 이름을 펼쳐 보인다.
	revealed = []
	var answers := VBoxContainer.new()
	answers.name = "answers"
	answers.add_theme_constant_override("separation", 6)
	box.add_child(answers)
	for category: String in board.categories():
		if board.solved().has(category):
			continue
		revealed.append(category)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var tag := PanelContainer.new()
		tag.add_theme_stylebox_override("panel", Art.box(Art.play("name_tag"), [9, 9, 9, 11], [10, 3, 10, 5]))
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_label: Label = Fonts.text(_screen.session.catalog.category_name(category, _screen.language()), Fonts.label(_screen.language()), 14)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = 96
		tag.add_child(name_label)
		row.add_child(tag)
		for card: String in board.group_items(category):
			row.add_child(_card_icon(_screen.session.catalog.item_icon(card), 32.0))
		answers.add_child(row)
	var holder := VBoxContainer.new()
	holder.name = "continue_row"
	box.add_child(holder)
	_fill_continue(holder)
	box.add_child(_button("restart", _t("Restart", "다시 하기"), false, _screen.restart))
	box.add_child(_button("home", _t("Home", "홈으로"), false, _screen.leave_home))
	return popup


## 이어하기 버튼: 광고를 쓸 수 있으면 광고, 못 쓰면 코인 150, 코인도 모자라면 가격이 빨간 비활성 모양.
## 이미 이어 간 판과 일일 도전에서는 버튼이 없다(숨긴 버튼만 둔다).
func _fill_continue(holder: VBoxContainer) -> void:
	if not is_instance_valid(holder):
		return
	for child: Node in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var verdict: Dictionary = _screen.session.continue_round.check(_screen.player(), _screen.board)
	var button: Button
	var coin_label: String = _t("Continue for %d coins", "코인 %d으로 이어 하기") % verdict["price"]
	if verdict["way"] == ContinueRound.WAY_AD:
		button = _ad_button("continue", _t("Watch ad to continue (clears 2)", "광고 보고 이어 하기 (실수 2번 지움)"), true, _continue_with_ad.bind(holder))
		button.set_meta("way", ContinueRound.WAY_AD)
	elif verdict["way"] == ContinueRound.WAY_COINS:
		button = _button("continue", coin_label, true, _continue_with_coins.bind(holder))
		button.set_meta("way", ContinueRound.WAY_COINS)
	elif verdict["reason"] == "no_coins":
		button = _button("continue", coin_label, false, _tell_shortage.bind(int(verdict["price"])))
		_mark_unaffordable(button)
		button.set_meta("way", WAY_SHORT)
	else:
		button = _button("continue", "", false, _nothing)
		button.visible = false
		button.set_meta("way", "")
	holder.add_child(button)


func _continue_with_ad(holder: VBoxContainer) -> void:
	if not _screen.watch_rewarded(AdPolicy.REWARDED_CONTINUE, _on_continue_ad.bind(holder)):
		_fill_continue(holder)


func _on_continue_ad(outcome: String, holder: VBoxContainer) -> void:
	if _screen.session.ad_flow.finish_continue(_screen.player(), outcome, _screen.board):
		_screen.resume_after_continue()
		return
	_screen.show_toast(_t("No reward this time", "이번에는 보상을 받지 못했어요"))
	_fill_continue(holder)


func _continue_with_coins(holder: VBoxContainer) -> void:
	if _screen.session.continue_round.pay_coins(_screen.player(), _screen.board)["ok"]:
		_screen.resume_after_continue()
	else:
		_fill_continue(holder)


func _tell_shortage(price: int) -> void:
	_screen.host.sfx.play("error")
	_screen.show_toast(_t("%d more coins needed", "코인이 %d개 모자라요") % (price - _screen.player().coins()), _screen.TOAST_ALERT)


func _nothing() -> void:
	pass


# =====================================================================
# 결과
# =====================================================================

func result(outcome: Dictionary) -> Control:
	var daily: bool = outcome.get("mode", "") == RoundMode.DAILY
	var popup: Control = _base(_t("Cleared!", "클리어!"), false)
	var box: VBoxContainer = _column(popup)
	var stars := HBoxContainer.new()
	stars.name = "stars"
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	box.add_child(stars)
	var star_nodes: Array[TextureRect] = []
	for index: int in Economy.STARS_MAX:
		var star: TextureRect = Art.picture(Art.play("star_empty"), Vector2.ONE * STAR_SIZE)
		star.custom_minimum_size = Vector2.ONE * STAR_SIZE
		star.pivot_offset = Vector2.ONE * STAR_SIZE / 2.0
		stars.add_child(star)
		star_nodes.append(star)

	var earned: int = int(outcome.get("coins", 0)) + int(outcome.get("album", {}).get("coins", 0)) + int(outcome.get("streak_coins", 0))
	var coins := HBoxContainer.new()
	coins.alignment = BoxContainer.ALIGNMENT_CENTER
	coins.add_theme_constant_override("separation", 6)
	box.add_child(coins)
	var coin_icon: TextureRect = Art.picture(Art.skin("icon_coin"), Vector2(32, 32))
	coin_icon.custom_minimum_size = Vector2(32, 32)
	coins.add_child(coin_icon)
	var amount: Label = Fonts.text("+0", Fonts.display(700), 28, Fonts.INK)
	amount.name = "coins_earned"
	coins.add_child(amount)

	var fresh: Array = outcome.get("album", {}).get("new", [])
	if not fresh.is_empty():
		var names: PackedStringArray = []
		for category: String in fresh:
			names.append(_screen.session.catalog.category_name(category, _screen.language()))
		var album: Label = _note(_t("New in your album: %s", "도감에 새로 담았어요: %s") % ", ".join(names))
		album.name = "album_new"
		box.add_child(album)
	if daily and int(outcome.get("streak", 0)) > 0:
		box.add_child(_note(_t("%d-day streak", "%d일 연속") % int(outcome["streak"])))

	if daily:
		box.add_child(_button("next", _t("OK", "확인"), true, _screen.leave_home))
	else:
		box.add_child(_button("next", _t("Next", "다음"), true, _screen.next_round))
	var bonus: Dictionary = outcome.get("bonus", {})
	var context: Dictionary = {"bonus": bonus, "earned": earned, "amount": amount, "coin_icon": coin_icon}
	var double: Button = _ad_button("double", _t("Watch ad to double", "광고 보고 코인 2배"), false, _press_double.bind(context))
	double.visible = not bonus.is_empty() and _screen._ad_ready(AdPolicy.REWARDED_RESULT_BONUS)
	context["button"] = double
	box.add_child(double)
	if not daily:
		box.add_child(_button("home", _t("Home", "홈으로"), false, _screen.leave_home))
	popup.opened.connect(_celebrate.bind(popup, star_nodes, int(outcome.get("stars", 0)), amount, coin_icon, earned))
	return popup


## 결과 2배: 광고를 끝까지 보면 그 판의 코인을 한 번 더 받는다. 받든 못 받든 버튼은 사라진다.
func _press_double(context: Dictionary) -> void:
	if not _screen.watch_rewarded(AdPolicy.REWARDED_RESULT_BONUS, _on_double_ad.bind(context)):
		(context["button"] as Button).visible = false
		_screen.show_toast(_t("No ad available right now", "지금은 광고가 없어요"))


func _on_double_ad(reply: String, context: Dictionary) -> void:
	if is_instance_valid(context["button"]):
		(context["button"] as Button).visible = false
	var bonus: Dictionary = context["bonus"]
	if not _screen.session.ad_flow.finish_bonus(_screen.player(), reply, bonus):
		_screen.show_toast(_t("No reward this time", "이번에는 보상을 받지 못했어요"))
		return
	var earned: int = context["earned"]
	if is_instance_valid(context["amount"]):
		Juice.count_up(context["amount"], earned, earned + int(bonus["coins"]), COUNT_SECONDS, "+%d")
		_fly_coins(context["coin_icon"])
	_screen.audio.play("coin")
	_screen._sync_coins(true)


## 결과 연출 3단계. 기대(anticipation): 창이 튀어나온 뒤 빈 별이 놓여 있다. 충격(impact): 얻은 별이 0.25초 간격으로
## 튀어나오며 반짝인다. 정착(settle): 코인 숫자가 올라가고 코인이 칩으로 날아간다.
func _celebrate(popup: Control, stars: Array[TextureRect], earned_stars: int, amount: Label, coin_icon: TextureRect, coins: int) -> void:
	var tree: SceneTree = popup.get_tree()
	for index: int in earned_stars:
		if not Juice.reduced_motion:
			await tree.create_timer(STAR_GAP).timeout
		if not is_instance_valid(popup):
			return
		var star: TextureRect = stars[index]
		star.texture = Art.play("star_full")
		Juice.pop_in(star, 0.22, 0.4)
		_screen.audio.play("star_%d" % (index + 1))
		_screen.audio.vibrate(10)
		if not Juice.reduced_motion:
			var sparkle: CPUParticles2D = Sparkle.instantiate()
			sparkle.amount = 6
			sparkle.one_shot = true
			sparkle.lifetime = 0.5
			sparkle.emission_sphere_radius = STAR_SIZE / 2.0
			sparkle.position = star.size / 2.0
			star.add_child(sparkle)
			sparkle.emitting = true
	if not Juice.reduced_motion:
		await tree.create_timer(STAR_GAP).timeout
	if not is_instance_valid(popup):
		return
	Juice.count_up(amount, 0, coins, COUNT_SECONDS, "+%d")
	if coins > 0:
		_screen.audio.play("coin")
		_screen.host.sfx.play("reward_sting")
		_fly_coins(coin_icon)
	_screen._sync_coins(true)
	if not Juice.reduced_motion:
		await tree.create_timer(COUNT_SECONDS).timeout
	if is_instance_valid(popup):
		_screen.result_settled = true


## 코인 여섯 개가 화면 위쪽의 코인 칩으로 날아간다.
func _fly_coins(from: Control) -> void:
	if Juice.reduced_motion or not is_instance_valid(from):
		return
	var layer: Control = _screen.host.layers.layer("System")
	var target: Vector2 = _screen.coin_chip.fly_target()
	for index: int in FLYING_COINS:
		var coin: TextureRect = Art.picture(Art.skin("icon_coin"), Vector2(24, 24))
		layer.add_child(coin)
		coin.global_position = from.get_global_rect().get_center() - coin.size / 2.0 + Vector2(randf_range(-14, 14), randf_range(-8, 8))
		Juice.fly_to(coin, target, 0.5, index * 0.06)


# =====================================================================
# 튜토리얼 끝 카드
# =====================================================================

func tutorial_done(outcome: Dictionary) -> Control:
	var gift: Dictionary = outcome.get("gift", {})
	var popup: Control = _base(_t("You're ready!", "준비 완료!"), false)
	var box: VBoxContainer = _column(popup)
	# 실수 규칙과 "한 장만 달라요"를 그림 한 장으로 보여 준다.
	var rules := PanelContainer.new()
	rules.name = "rules"
	rules.add_theme_stylebox_override("panel", Art.box(Art.play("cell_empty"), [20, 20, 20, 20], [12, 12, 12, 12]))
	box.add_child(rules)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	rules.add_child(lines)
	var hearts := HBoxContainer.new()
	hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	hearts.add_theme_constant_override("separation", 4)
	for index: int in Board.MISTAKE_LIMIT:
		var heart: TextureRect = Art.picture(Art.play("heart_full"), Vector2(26, 26))
		heart.custom_minimum_size = Vector2(26, 26)
		hearts.add_child(heart)
	lines.add_child(hearts)
	lines.add_child(_note(_t("Four mistakes end the board.", "실수 네 번이면 판이 끝나요.")))
	var sample := HBoxContainer.new()
	sample.alignment = BoxContainer.ALIGNMENT_CENTER
	sample.add_theme_constant_override("separation", 4)
	var first: Array = _screen.board.group_items(_screen.board.categories()[0])
	var odd: String = _screen.board.group_items(_screen.board.categories()[1])[0]
	for card: String in first.slice(0, 3) + [odd]:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", Art.box(Art.play("card_face"), [20, 20, 20, 29], [6, 6, 6, 13]))
		cell.add_child(_card_icon(_screen.session.catalog.item_icon(card), 30.0))
		sample.add_child(cell)
	lines.add_child(sample)
	var near := PanelContainer.new()
	near.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	near.add_theme_stylebox_override("panel", Art.box(Art.play("toast_yellow"), [18, 18, 18, 22], [16, 5, 16, 9]))
	near.add_child(Fonts.text(_t("One away!", "한 장만 달라요!"), Fonts.display(700), 15, Fonts.INK))
	lines.add_child(near)
	lines.add_child(_note(_t("When three of your four match, we tell you.", "네 장 가운데 세 장이 맞으면 알려 줘요.")))

	if not gift.is_empty():
		var title: Label = Fonts.text(_t("Starter gift", "시작 선물"), Fonts.display(700), 18, Fonts.INK)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(title)
		var row := HBoxContainer.new()
		row.name = "gift"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		row.add_child(_gift_item(Art.skin("icon_coin"), str(int(gift.get("coins", 0)))))
		var boosters: Dictionary = gift.get("boosters", {})
		for spec: Array in [[Economy.BOOSTER_HINT, "gift_hint"], [Economy.BOOSTER_UNDO, "gift_undo"], [Economy.BOOSTER_SLOT, "gift_slot"]]:
			if int(boosters.get(spec[0], 0)) > 0:
				row.add_child(_gift_item(Art.play(spec[1]), "×%d" % int(boosters[spec[0]])))
	box.add_child(_button("claim", _t("Claim", "받기") if not gift.is_empty() else _t("OK", "확인"), true, _screen.claim_tutorial))
	return popup


func _gift_item(picture: Texture2D, text: String) -> Control:
	var item := VBoxContainer.new()
	item.add_theme_constant_override("separation", 2)
	var art: TextureRect = Art.picture(picture, Vector2(42, 42))
	art.custom_minimum_size = Vector2(42, 42)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	item.add_child(art)
	var label: Label = Fonts.text(text, Fonts.display(700), 16, Fonts.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_child(label)
	return item


# =====================================================================
# 공통 조각
# =====================================================================

func _t(en: String, ko: String) -> String:
	return _screen.tr_text(en, ko)


## 창의 틀: 제목, 닫기(closable일 때만), 어두운 배경. 버튼은 내용 칸에 세로로 쌓는다.
func _base(title: String, closable: bool) -> Control:
	var popup: Control = PopupBase.instantiate()
	popup.dismiss_on_dim = closable
	popup.set_title(title)
	(popup.get_node("Dim") as ColorRect).color = DIM
	var frame: Control = popup.get_node("Center/Frame")
	frame.custom_minimum_size.x = minf(WIDTH, _screen.size.x - 24.0)
	(popup.get_node("Center/Frame/Body/Actions") as Control).visible = false
	var close: Button = popup.get_node("Center/Frame/Body/Header/Close")
	close.visible = closable
	close.focus_mode = Control.FOCUS_NONE
	var heading: Label = popup.get_node("Center/Frame/Body/Header/Title")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if closable else HORIZONTAL_ALIGNMENT_CENTER
	return popup


func _column(popup: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "column"
	box.add_theme_constant_override("separation", 10)
	popup.add_content(box)
	box.sort_children.connect(_equalize.bind(box))
	return box


## 한 창의 버튼은 모두 같은 높이다. 문구가 두 줄이 되는 버튼이 있으면 나머지도 그 높이에 맞춘다.
func _equalize(box: Control) -> void:
	var buttons: Array = box.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return node.has_meta("needed"))
	var tallest: float = BUTTON_HEIGHT
	for button: Button in buttons:
		if button.visible:
			tallest = maxf(tallest, float(button.get_meta("needed")))
	for button: Button in buttons:
		if not is_equal_approx(button.custom_minimum_size.y, tallest):
			button.custom_minimum_size.y = tallest


func _note(text: String) -> Label:
	var label: Label = Fonts.text(text, Fonts.body(), 15, Fonts.INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _card_icon(icon_key: String, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(ICON_DIR + icon_key + ".png")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## 창의 버튼. 판은 스킨 테마가 그리고, 글자와 아이콘은 한 줄로 묶어 가운데에 둔다. 글자는 제목 서체이고
## 주 버튼은 흰 글자에 짙은 주황 그림자다. 글자가 넘치면 한 단계 줄이고, 그래도 넘치면 두 줄로 나누며 버튼이 높아진다.
## primary는 한 창에 하나만 준다.
func _button(button_name: String, text: String, primary: bool, action: Callable, icon: Texture2D = null, icon_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.name = button_name
	button.set_meta("label", text)
	button.set_meta("needed", BUTTON_HEIGHT)
	button.custom_minimum_size.y = BUTTON_HEIGHT
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		button.theme_type_variation = &"PrimaryButton"
		button.set_meta("ui_sfx_kind", "confirm")
	button.pressed.connect(action)
	button.button_down.connect(Juice.press_punch.bind(button, 0.96, 0.1))
	if text.is_empty():
		return button
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", BUTTON_ICON_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -BUTTON_LIP
	button.add_child(row)
	var room: float = BUTTON_TEXT_ROOM
	if icon != null:
		var picture: TextureRect = Art.picture(icon, icon_size)
		picture.custom_minimum_size = picture.size
		picture.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(picture)
		room -= picture.size.x + BUTTON_ICON_GAP
	var font: Font = Fonts.display(700)
	var label: Label = Fonts.text(text, font, BUTTON_FONT_SIZES[0], Color.WHITE if primary else Fonts.INK)
	label.name = "label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if primary:
		Fonts.shade(label, PRIMARY_SHADE)
	for font_size: int in BUTTON_FONT_SIZES:
		label.add_theme_font_size_override("font_size", font_size)
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= room:
			row.add_child(label)
			return button
	# 가장 작은 글자로도 한 줄에 안 들어가면 두 줄로 나눈다.
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = room
	label.add_theme_constant_override("line_spacing", -2)
	button.set_meta("needed", BUTTON_HEIGHT + BUTTON_SECOND_LINE)
	button.custom_minimum_size.y = BUTTON_HEIGHT + BUTTON_SECOND_LINE
	row.add_child(label)
	return button


## 보상형 광고 버튼: 무엇을 얻는지와 광고 시청을 함께 적고 초록 재생 꼬리표를 붙인다.
func _ad_button(button_name: String, text: String, primary: bool, action: Callable) -> Button:
	return _button(button_name, text, primary, action, Art.play("icon_ad"))


## 코인으로 사는 버튼. label은 가격 자리(%d)가 있는 문구다. 코인이 모자라면 가격이 빨간 비활성 모양이고 누르면 모자란 수를 알린다.
func _coin_button(button_name: String, label: String, kind: String, primary: bool) -> Button:
	var price: int = Economy.price(kind)
	var button: Button = _button(button_name, label % price, primary, _buy.bind(kind), Art.skin("icon_coin"), Vector2(24, 24))
	if _screen.player().coins() < price:
		_mark_unaffordable(button)
	return button


func _buy(kind: String) -> void:
	var price: int = Economy.price(kind)
	if _screen.player().coins() < price:
		_tell_shortage(price)
		return
	_screen.close_popup(_screen.apply_booster.bind(kind, UseBooster.SOURCE_COINS))


## 살 수 없는 가격: 보조 버튼의 비활성 판에 빨간 글자. 눌러서 모자란 수를 알 수 있게 버튼은 살려 둔다.
func _mark_unaffordable(button: Button) -> void:
	button.theme_type_variation = &""
	button.set_meta("unaffordable", true)
	button.set_meta("ui_sfx_kind", "error")
	var plate: StyleBox = _screen.get_theme_stylebox("disabled", "Button")
	for style: String in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(style, plate)
	var label: Label = button.find_child("label", true, false) as Label
	if label != null:
		label.add_theme_color_override("font_color", RED)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)


## 지금 가진 코인.
func _wallet() -> Control:
	var row := HBoxContainer.new()
	row.name = "wallet"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	var icon: TextureRect = Art.picture(Art.skin("icon_coin"), Vector2(22, 22))
	icon.custom_minimum_size = Vector2(22, 22)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(Fonts.text(_t("You have %s", "보유 %s") % _screen.coin_chip.format_amount(_screen.player().coins()), Fonts.display(600), 16, Fonts.INK))
	return row
