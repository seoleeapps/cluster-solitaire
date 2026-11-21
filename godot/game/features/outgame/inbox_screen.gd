extends VBoxContainer
## 알림함(SCR-015). 공통 저장의 우편(첫 실행 환영 글, 운영 공지, 보상)을 제품 문구와 판으로 보인다.
## 받기는 host.claim_mail(id)가 공통 저장에 기록하고 받은 코인을 제품 저장으로 옮긴다. 화면을 열면 우편을 읽은 것으로 표시한다.

const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")

const MUTED := Color("8a8db5")
## 저장의 우편 id별 제품 문구([영어, 한국어]의 제목과 본문). 공통 기반의 환영 우편은 id가 local-welcome이다.
const MAIL_TEXT := {
	"local-welcome": [
		["Welcome to Four Alike!", "끼리끼리에 오신 걸 환영해요!"],
		["Find the four cards that belong together and group them. Here are a few coins to start.",
			"같은 종류 카드 네 장을 찾아 묶어 보세요. 시작을 돕는 코인을 조금 드려요."],
	],
}

var host: Control


func _ready() -> void:
	name = "inbox_screen"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	rebuild()


func _t(en: String, ko: String) -> String:
	return host.tr_text(en, ko)


func rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var mails: Array = host.state.data.mail
	var waiting: int = host.inbox_claimable()
	if waiting > 1:
		add_child(Ui.button("claim_all", _t("Claim all (%d)", "모두 받기 (%d)") % waiting, true, host.claim_all_mail))
	var scroll := ScrollContainer.new()
	scroll.name = "inbox_scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(box)
	if mails.is_empty():
		var empty: Label = Ui.note(_t("No messages yet", "아직 온 소식이 없어요"), 15, MUTED)
		empty.name = "inbox_empty"
		box.add_child(empty)
	for mail: Dictionary in mails:
		box.add_child(_mail_card(mail, waiting <= 1))


func _mail_card(mail: Dictionary, primary: bool) -> Control:
	var id: String = str(mail["id"])
	var card: PanelContainer = Ui.panel([14, 12, 14, 18])
	card.name = "mail_" + id
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)
	var text: Array = MAIL_TEXT.get(id, [[str(mail["title"]), str(mail["title"])], [str(mail["body"]), str(mail["body"])]])
	var title: Label = Fonts.text(_t(text[0][0], text[0][1]), Fonts.display(700), Ui.sized(17), Fonts.INK)
	title.name = "title"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var body: Label = Fonts.text(Fonts.keep_words(_t(text[1][0], text[1][1])), Fonts.body(500), Ui.sized(14), Color("4a4680"))
	body.name = "body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var amount: int = int(mail["amount"])
	if amount > 0:
		var coin: TextureRect = Art.picture(Art.skin("icon_coin"), Vector2(26, 26))
		coin.custom_minimum_size = Vector2(26, 26)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(coin)
		row.add_child(Fonts.text("+%d" % amount, Fonts.display(700), Ui.sized(18), Fonts.INK))
	var filler := Control.new()
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(filler)
	var expired: bool = int(mail["expiresAt"]) != 0 and int(mail["expiresAt"]) <= host.session.services.clock.now_unix()
	if int(mail["claimedAt"]) != 0:
		var done := HBoxContainer.new()
		done.name = "claimed"
		done.mouse_filter = Control.MOUSE_FILTER_IGNORE
		done.add_theme_constant_override("separation", 4)
		var tick: TextureRect = Art.picture(Art.play("tick"), Vector2(24, 26))
		tick.custom_minimum_size = Vector2(24, 26)
		done.add_child(tick)
		done.add_child(Fonts.text(_t("Received", "받았어요"), Fonts.display(700), Ui.sized(15), Color("2f9a4c")))
		row.add_child(done)
	elif expired:
		row.add_child(Fonts.text(_t("Expired", "기간이 지났어요"), Fonts.display(600), Ui.sized(14), MUTED))
	elif amount > 0:
		var claim: Button = Ui.button("claim", _t("Claim", "받기"), primary, host.claim_mail.bind(id), null, Vector2.ZERO, 100.0, [17, 15], 48.0)
		claim.custom_minimum_size.x = 110
		claim.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(claim)
	return card
