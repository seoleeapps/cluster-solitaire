extends "res://addons/seorilabs_game/flow/outgame_main.gd"
## Four Alike의 시작 장면. 공통 흐름을 상속해 제품 스킨, 서비스 묶음, 타이틀과 홈, 바깥 화면, 플레이 화면을 연결한다.
##
## 연결 지점
##   game_services: 포트 묶음(FaServices). _init에서 로컬 저장과 시계에 실제 광고, 분석, 원격 설정 어댑터(FaLiveServices)를 끼운다.
##     장면을 트리에 넣기 전에 필드를 바꿔 끼우면 그 구현이 쓰인다(여정의 대역). 실제 어댑터를 하나도 쓰지 않으면 FaLiveServices는 돌지 않는다.
##   session: 실행 상태와 유스케이스(FaSession). 타이틀이 저장을 읽은 뒤 한 단계로 연다. 화면은 이것만 받는다.
##   _title, _home: 제품 화면(features/outgame)으로 바꿔 그린다. 하위 화면은 feature_routes(daily, album, shop, inbox, licenses)다.
##   launch_game → _launch_play: 플레이 화면을 World 층에 올린다. 튜토리얼이 진행 중이면 튜토리얼 판이다.
##   launch_daily(date): 날짜의 일일 도전 판. resource_provider: 공통 화면의 코인 값(제품 저장의 코인).
##
## 한곳에서만 하는 일
##   광고 중 음악 멈춤: 플레이 화면이 광고를 보여 달라고 할 때 멈추고 결과를 받으면 되돌린다(어느 광고 포트에서나 같은 길).
##   앱 복귀 때 새 실행: 이 장면의 _notification이 시계 포트로 판단하고 FaSession과 FaLiveServices의 begin_session을 부른다.
##   app_first_run과 app_session: 분석 어댑터만 보낸다.
##   저장 파일의 자리: FaSavePaths. 데이터 초기화(erase_all_data)는 지금 쓰는 저장 객체에서 자리를 읽어 지운다.

const GameServices := preload("res://game/bootstrap/fa_services.gd")
const SavePaths := preload("res://game/bootstrap/fa_save_paths.gd")
const Session := preload("res://game/bootstrap/fa_session.gd")
const LiveServices := preload("res://game/adapters/fa_live_services.gd")
const PlayScreen := preload("res://game/features/play/play_screen.tscn")
const PlayLayout := preload("res://game/features/play/play_layout.gd")
const TitleScreen := preload("res://game/features/outgame/title_screen.gd")
const HomeScreen := preload("res://game/features/outgame/home_screen.gd")
const DailyScreen := preload("res://game/features/outgame/daily_screen.gd")
const AlbumScreen := preload("res://game/features/outgame/album_screen.gd")
const ShopScreen := preload("res://game/features/outgame/shop_screen.gd")
const InboxScreen := preload("res://game/features/outgame/inbox_screen.gd")
const LicensesScreen := preload("res://game/features/outgame/licenses_screen.gd")
const AttendancePopup := preload("res://game/features/outgame/attendance_popup.gd")
const ResetPopup := preload("res://game/features/outgame/reset_popup.gd")
const Backdrop := preload("res://game/features/shared/fa_backdrop.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const Fonts := preload("res://game/features/shared/fa_fonts.gd")
const Look := preload("res://game/features/shared/fa_look.gd")
const Ui := preload("res://game/features/shared/fa_ui.gd")
const GameAudio := preload("res://game/features/shared/fa_audio.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Daily := preload("res://game/core/domain/fa_daily.gd")

const SKIN := "res://game/skins/candy_pop"
## 주 버튼의 글자: 흰색에 짙은 주황 외곽선.
const PRIMARY_OUTLINE := Color(0.62, 0.28, 0.0, 0.7)
const PRIMARY_OUTLINE_SIZE := 5
const PRIVACY_URL := "https://www.seorilabs.com/en/apps/four-alike/privacy/"
## 타이틀이 동의 확인을 기다리는 최대 시간(초). 동의 SDK가 답하지 않아도 시작할 수 있게 한다.
const CONSENT_WAIT_SECONDS := 5.0
## 홈에서 뒤로 가기를 한 번 더 누르면 끝내는 시간(밀리초).
const EXIT_WINDOW_MSEC := 2000
const TOAST_SECONDS := 2.0
const TOAST_MARGINS := [18, 18, 18, 22]
## 안내의 위쪽 끝이 화면 아래(안전 영역 위)에서 떨어진 거리. 홈의 둥근 버튼 줄 바로 위다.
const TOAST_FROM_BOTTOM := 150.0
## 하위 화면(흰 판) 머리 줄의 제목 크기와 줄일 수 있는 최소, 뒤로와 닫기 버튼과 간격이 차지하는 폭.
const SHEET_TITLE_SIZE := 23
const SHEET_TITLE_MIN := 17
const SHEET_BUTTONS := 124.0
## 보상 연출 동안 뒤를 어둡게 해 제목과 아이템이 화면의 글자와 겹쳐 읽히지 않게 한다.
const REWARD_DIM := Color(0.09, 0.07, 0.3, 0.45)
## 바뀌면 settings_change로 알리는 설정(분석 끄기는 끈 뒤라 보내지 않는다).
const SETTINGS_EVENTS: Array[String] = ["language", "music", "sfx", "vibration", "large_text", "reduced_motion"]
## 설정 화면의 토글을 제품 스위치 그림으로 그린다.
const SWITCH_ICONS := [["checked", "switch_on"], ["unchecked", "switch_off"], ["checked_disabled", "switch_on_disabled"], ["unchecked_disabled", "switch_off_disabled"]]
const BOOSTER_ART := {Economy.BOOSTER_HINT: "gift_hint", Economy.BOOSTER_UNDO: "gift_undo", Economy.BOOSTER_SLOT: "gift_slot"}

var game_services: GameServices
## 실제 앱의 저장 자리(user:// 아래). 여정은 격리 폴더의 자리로 state와 game_services를 직접 만들어 끼운다.
var save_paths: SavePaths
## 실제 서비스 어댑터. 여정이 대역만 끼우면 null이다.
var live: LiveServices
var session: Session
## 떠 있는 플레이 화면. 없으면 null.
var play: Control
var audio: Node
var backdrop: Control
var title_view: Control
var home_view: Control
## 지금 그린 제품 하위 화면(일일 도전, 도감, 상점, 알림함, 오픈소스 고지). 없으면 null.
var outgame_view: Control
## 바깥 화면 위에 떠 있는 팝업(출석, 도감 상세). 없으면 null.
var outgame_popup: Control
## 지금까지 띄운 안내 문구(검수용).
var toasts: Array[String] = []
## 안전 영역(위, 아래)을 직접 정한다. 음수면 기기의 값을 쓴다. 기준 그림과 같은 여백으로 캡처할 때 쓴다.
var safe_insets_override: Vector2 = Vector2(-1, -1)
## 홈에서 뒤로 가기를 두 번 눌러 게임을 끝낸다. 여정이 바꿔 끼운다.
var quit_app: Callable
## 바깥 주소(개인정보처리방침)를 연다. 여정이 바꿔 끼운다.
var open_url: Callable

## 앱이 뒤로 간 시각(유닉스 초). 오래 있다가 돌아오면 새 실행으로 본다.
var _left_at: int = 0
var _consent_wait_over: bool = false
var _started_msec: int = 0
var _title_reported: bool = false
var _exit_armed_until: int = 0
var _settings_seen: Dictionary = {}
var _toast: Control


func _init() -> void:
	var product: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/product.json"))
	game_title = product.name
	game_title_ko = product.name
	home_profile = product.homeProfile
	config.appId = product.id
	save_paths = SavePaths.under(SavePaths.DEVICE_ROOT, str(product.id))
	state = State.new(save_paths.state)
	skin_dir = SKIN
	game_services = GameServices.local(save_paths.progress)
	use_live_services()
	launch_game = _launch_play
	resource_provider = func() -> int: return session.player.coins() if session != null else 0
	feature_routes.daily = _route_daily
	feature_routes.album = _route_album
	feature_routes.shop = _route_shop
	feature_routes.inbox = _route_inbox
	feature_routes.licenses = _route_licenses
	quit_app = func() -> void: get_tree().quit()
	open_url = func(url: String) -> void: OS.shell_open(url)


## 실제 광고, 분석, 원격 설정 어댑터를 만들어 포트 묶음에 끼운다. storage_dir은 어댑터가 파일을 두는 폴더(비우면 save_paths.services)다.
## 개발 PC와 headless에서는 광고가 준비되지 않은 것으로, 분석과 원격 설정은 꺼진 것으로 동작하고 네트워크를 쓰지 않는다.
func use_live_services(storage_dir: String = "") -> void:
	if live != null:
		live.free()
	live = LiveServices.new(save_paths.services if storage_dir.is_empty() else storage_dir)
	game_services.ads = live.ads
	game_services.analytics = live.analytics
	game_services.config = live.config


func _ready() -> void:
	_started_msec = Time.get_ticks_msec()
	_attach_services()
	audio = GameAudio.new()
	audio.name = "GameAudio"
	add_child(audio)
	super._ready()
	# 타이틀과 홈, 공통 화면도 플레이 화면과 같은 배경 위에 놓는다.
	backdrop = Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, backing.get_index())
	_settings_seen = state.data.get("settings", {}).duplicate()
	state.committed.connect(_on_state_committed)
	get_tree().create_timer(CONSENT_WAIT_SECONDS).timeout.connect(_on_consent_wait_over)
	# 카드 준비: 공통 흐름이 저장을 읽은 화면을 한 번 그린 다음 콘텐츠와 레벨 팩, 제품 저장을 읽는다.
	await get_tree().process_frame
	if is_inside_tree():
		_open_session()


## 실제 어댑터를 쓰면 트리에 넣고(공통 흐름이 초기화 중에 분석 선택을 적용하므로 super._ready() 전에), 아니면 버린다.
## 분석 포트가 켜고 끄기를 지원하면 설정의 "데이터 분석 허용"이 그 포트를 켜고 끈다.
func _attach_services() -> void:
	if live != null:
		if game_services.ads == live.ads or game_services.analytics == live.analytics or game_services.config == live.config:
			add_child(live)
		else:
			live.free()
			live = null
	var port: RefCounted = game_services.analytics
	if port.has_method("set_enabled") and port.has_method("discard_pending"):
		analytics.port = port
		config["analytics_policy_allowed"] = true
	game_services.ads.consent_changed.connect(_on_consent_changed)


func _open_session() -> void:
	session = Session.open(game_services)
	for problem: String in session.problems:
		push_error("Four Alike data could not be read: " + problem)
	apply_look()
	session.begin_session()
	if screen == "title":
		_title()


## 고른 꾸미기 테마(카드 뒷면, 배경)를 화면에 반영한다. 새로 그리는 카드와 배경이 따른다.
func apply_look() -> void:
	if session == null:
		return
	Look.select(session.player.selected_theme(Economy.THEME_CARD_BACK), session.player.selected_theme(Economy.THEME_BACKGROUND))
	if backdrop != null:
		backdrop.refresh()


func _notification(what: int) -> void:
	if session == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_left_at = session.services.clock.now_unix()
		if play != null:
			play.save_now()
		audio.hold_music("background", true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		audio.hold_music("background", false)
		var away: int = session.services.clock.now_unix() - _left_at
		if _left_at > 0 and session.session_reset_seconds > 0 and away > session.session_reset_seconds:
			session.begin_session()
			if live != null:
				live.begin_session()
		_left_at = 0


func _apply_settings() -> void:
	super._apply_settings()
	if custom_theme == null and theme != null:
		_finish_theme()
	if audio != null:
		audio.vibration = bool(state.data.settings.vibration)
	Ui.text_bonus = Ui.LARGE_TEXT_BONUS if bool(state.data.settings.large_text) else 0


## 스킨 테마에 제품의 마무리를 얹는다: 그림 판을 DPITexture로, 주 버튼 글자를 흰색으로, 토글을 제품 스위치로.
func _finish_theme() -> void:
	Art.sharpen(theme)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color, "PrimaryButton", Color.WHITE)
	theme.set_color("font_disabled_color", "PrimaryButton", Color("f1f2fa"))
	theme.set_color("font_outline_color", "PrimaryButton", PRIMARY_OUTLINE)
	theme.set_constant("outline_size", "PrimaryButton", PRIMARY_OUTLINE_SIZE)
	for pair: Array in SWITCH_ICONS:
		theme.set_icon(pair[0], "CheckButton", Art.outgame(pair[1]))
	if layers != null:
		layers.apply_theme(theme)


## 공통 흐름은 저장을 읽은 뒤에야 테마를 적용한다. 저장을 읽지 못한 타이틀(오류와 다시 시도)도 제품 스킨으로 그린다.
func _ensure_theme() -> void:
	if theme != null or custom_theme != null:
		return
	var built: Theme = load(skin_dir.path_join("theme.tres"))
	if built == null:
		return
	theme = built.duplicate(true)
	ThemeBuilder.localize(theme, ThemeBuilder.load_skin(skin_dir), language(), _ui_font_size)
	_finish_theme()


# =====================================================================
# 동의와 설정
# =====================================================================

## 동의 상태가 바뀌면 분석 선택을 다시 적용하고, 타이틀이나 설정 화면이 떠 있으면 다시 그린다.
func _on_consent_changed() -> void:
	if not state.data.is_empty():
		analytics.apply(state)
	if screen == "title":
		_title()
	elif screen == "settings":
		_route("settings")


func _on_consent_wait_over() -> void:
	_consent_wait_over = true
	if screen == "title":
		_title()


## 공통 설정 화면에 개인정보처리방침, 개인정보 선택(동의 지역에서만), 오픈소스 고지, 데이터 초기화(맨 아래, 빨간 글자)를 더한다.
func _settings() -> void:
	super._settings()
	var language: Control = content.find_child("language", true, false) as Control
	if language == null:
		return
	var box: Node = language.get_parent()
	var version: Node = box.get_child(box.get_child_count() - 1)
	for node: Node in box.get_children():
		if node is Button and (node as Button).text == tr_text("Account and save", "계정과 저장"):
			node.name = "account"
	_button(tr_text("Privacy policy", "개인정보 처리방침"), func() -> void: open_url.call(PRIVACY_URL), box).name = "privacy_policy"
	if game_services.ads.privacy_choice_required():
		_button(tr_text("Privacy choices", "개인정보 선택"), game_services.ads.open_privacy_choice, box).name = "privacy_choice"
	_button(tr_text("Open-source notices", "오픈소스 고지"), func() -> void: _open("licenses"), box).name = "licenses"
	var reset: Button = _button(tr_text("Reset game data", "데이터 초기화"), open_data_reset, box)
	reset.name = "data_reset"
	box.move_child(version, box.get_child_count() - 1)
	_list_rows(box)
	for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		reset.add_theme_color_override(color, Ui.DANGER_INK)


## 설정 목록을 제품의 목록 줄로 바꾼다: 왼쪽에 그림, 글자는 왼쪽 정렬, 다른 화면으로 가는 줄은 오른쪽에 꺾쇠.
func _list_rows(box: Node) -> void:
	for node: Node in box.get_children():
		if node is Label and (node as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			(node as Label).text = Fonts.keep_words((node as Label).text)
		var button: Button = node as Button
		if button == null:
			continue
		var glyph: String = "res://game/features/outgame/assets/set_%s.svg" % button.name
		if Art.has_source(glyph):
			button.icon = Art.texture(glyph)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_constant_override("h_separation", 12)
		for color: String in ["icon_normal_color", "icon_pressed_color", "icon_hover_color", "icon_focus_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(color, Color.WHITE)
		if button is CheckButton:
			continue
		var chevron: TextureRect = Art.picture(Art.outgame("set_chevron"), Vector2(20, 20))
		chevron.name = "chevron"
		button.add_child(chevron)
		var place: Callable = func() -> void: chevron.position = Vector2(button.size.x - 34.0, (button.size.y - 6.0 - 20.0) / 2.0)
		button.resized.connect(place)
		place.call()


## 설정이 바뀌면 분석에 알린다(06 문서의 settings_change).
func _on_state_committed() -> void:
	var settings: Dictionary = state.data.get("settings", {})
	for key: String in SETTINGS_EVENTS:
		if not _settings_seen.is_empty() and settings.has(key) and _settings_seen.get(key) != settings[key]:
			game_services.analytics.log_event("settings_change", {"key": key, "value": str(settings[key])})
	_settings_seen = settings.duplicate()


# =====================================================================
# 데이터 초기화
# =====================================================================

## 설정의 데이터 초기화 줄: 두 번 확인하는 창을 띄운다(ResetPopup).
func open_data_reset() -> void:
	show_popup(ResetPopup.build(self))


## 이 기기의 기록을 모두 지우고 처음 실행한 것처럼 타이틀부터 다시 시작한다. 확인 창의 마지막 단계가 부른다.
## 지우는 것: 제품 저장과 백업(저장 포트), 공통 흐름의 상태 저장과 분석 끄기 표식(설정, 튜토리얼, 우편, 동의 버전),
## 분석 식별자와 대기열(분석 포트). 설정은 기본값으로 돌아가고 분석 허용도 기본(켬)이다.
## 광고 동의(UMP)는 SDK가 기억하므로 건드리지 않고, 원격 설정 캐시는 기록이 아니므로 둔다.
func erase_all_data() -> void:
	var popup: Control = outgame_popup
	if popup != null and is_instance_valid(popup) and popup.state != "closed":
		popup.close()
		await popup.closed
	_close_play()
	_close_outgame_popup()
	session = null
	var erased: bool = game_services.store.erase()
	game_services.analytics.forget_device()
	erased = SavePaths.erase_state(state.path) and erased
	if not erased:
		push_error("Four Alike data could not be erased completely")
	# 공통 흐름의 시작을 처음부터 다시 돈다: 빈 저장을 기본값으로 읽고 설정을 적용한 뒤 타이틀을 그린다.
	navigation.clear()
	_focus_stack.clear()
	transient_notice = ""
	initialized = false
	initializing = false
	progress = 0
	startup_error = ""
	_left_at = 0
	_initialize()
	_settings_seen = state.data.get("settings", {}).duplicate()
	await get_tree().process_frame
	if is_inside_tree():
		_open_session()
		if not erased:
			show_toast(tr_text("Some data could not be deleted.", "일부 기록을 지우지 못했어요."), "red")


# =====================================================================
# 타이틀
# =====================================================================

## 타이틀의 준비 단계. 저장 읽기(공통 흐름), 카드 준비(콘텐츠, 레벨 팩, 제품 저장과 공통 서비스), 동의 확인 순서다.
## 결과는 {stage, done, total, cards}이고 stage는 save, cards, privacy, ready, error다. 막대는 done/total만큼 찬다.
func title_progress() -> Dictionary:
	var steps: Array[bool] = [progress >= 1, session != null and initialized, _consent_done()]
	var stage: String = "ready"
	if not startup_error.is_empty():
		stage = "error"
	elif not steps[0]:
		stage = "save"
	elif not steps[1]:
		stage = "cards"
	elif not steps[2]:
		stage = "privacy"
	return {"stage": stage, "done": steps.count(true), "total": steps.size(), "cards": session != null}


func _consent_done() -> bool:
	return _consent_wait_over or game_services.ads.consent_settled()


func title_error_text() -> String:
	return _error_text(startup_error)


## 타이틀의 시작 버튼이 보이는지(여정이 기다린다).
func start_ready() -> bool:
	return screen == "title" and title_progress()["stage"] == "ready"


func _title() -> void:
	screen = "title"
	_ensure_theme()
	if title_view == null or not is_instance_valid(title_view) or title_view.get_parent() != content:
		_clear(game_title)
		_fill_content()
		title_view = TitleScreen.new()
		title_view.host = self
		content.add_child(title_view)
	else:
		title_view.refresh()
	if title_progress()["stage"] == "ready":
		if audio != null:
			audio.start_music()
		if not _title_reported:
			_title_reported = true
			game_services.analytics.log_event("title_ready", {"ms": Time.get_ticks_msec() - _started_msec})


func _start() -> void:
	if title_progress()["stage"] != "ready":
		return
	super._start()


## 타이틀과 홈은 화면 전체를 쓰고 여백과 안전 영역은 제품 화면이 정한다.
func _fill_content() -> void:
	for side: String in ["left", "right", "top", "bottom"]:
		_content_margin.add_theme_constant_override("margin_" + side, 0)


# =====================================================================
# 홈과 하위 화면
# =====================================================================

func _home() -> void:
	if session == null:
		return
	_sync_metrics()
	screen = "home"
	_close_outgame_popup()
	# 우편함에서 받은 코인을 제품 저장으로 옮긴다.
	session.absorb_outgame_grants(state.data.get("grants", {}))
	_clear("")
	_fill_content()
	home_view = HomeScreen.new()
	home_view.host = self
	content.add_child(home_view)
	if session.save_reset:
		session.save_reset = false
		show_toast(tr_text("Your save could not be read, so the game started fresh.", "저장을 읽지 못해 새로 시작했어요."), "red")


## 하위 화면의 틀(공통 흐름의 흰 판과 머리 줄)에 제품 화면을 얹는다.
func _sheet(title: String, view: Control) -> void:
	_clear(title)
	view.host = self
	content.add_child(view)
	outgame_view = view


func _route_daily() -> void:
	_sheet(tr_text("Daily Challenge", "일일 도전"), DailyScreen.new())


func _route_album() -> void:
	_sheet(tr_text("Album", "도감"), AlbumScreen.new())


func _route_shop() -> void:
	_sheet(tr_text("Shop", "상점"), ShopScreen.new())


func _route_inbox() -> void:
	var now: int = session.services.clock.now_unix()
	for mail: Dictionary in state.data.mail.duplicate(true):
		if int(mail["readAt"]) == 0:
			state.read_mail(str(mail["id"]), now)
	_sheet(tr_text("Inbox", "알림함"), InboxScreen.new())


func _route_licenses() -> void:
	_sheet(tr_text("Open-source notices", "오픈소스 고지"), LicensesScreen.new())


## 공통 흐름의 머리 줄(뒤로, 제목, 닫기)을 제품 그림과 서체로 바꾼다.
func _clear(title: String) -> void:
	super._clear(title)
	outgame_view = null
	if screen in ["title", "home"]:
		return
	var back: Button = content.find_child("back", true, false) as Button
	var close: Button = content.find_child("close", true, false) as Button
	for pair: Array in [[back, "icon_back", tr_text("Back", "뒤로")], [close, "icon_close", tr_text("Close", "닫기")]]:
		var button: Button = pair[0]
		if button != null:
			Ui.icon_only(button, Art.outgame(pair[1]))
			button.tooltip_text = pair[2]
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if header != null:
		# 제목은 한 줄에 쓴다. 큰 글자 설정은 공통 배율을 따르고, 뒤로와 닫기 사이에 안 들어가면 한 단계씩 줄인다.
		var font: Font = Fonts.display(700)
		var room: float = size.x - 24.0 - float(_content_margin.get_theme_constant("margin_left")) * 2.0 - SHEET_BUTTONS
		var font_size: int = _ui_font_size(SHEET_TITLE_SIZE)
		while font_size > SHEET_TITLE_MIN and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room:
			font_size -= 1
		header.add_theme_font_override("font", font)
		header.add_theme_font_size_override("font_size", font_size)
		header.add_theme_color_override("font_color", Fonts.INK)


func _back() -> void:
	if screen == "play" and play != null:
		play.back_pressed()
		return
	if outgame_popup != null and is_instance_valid(outgame_popup):
		if outgame_popup.state == "open":
			outgame_popup.close()
		return
	if screen in ["title", "home"]:
		_confirm_exit()
		return
	super._back()


## 돌아온 화면에서 앞서 누른 버튼에 초점을 되돌린다. 공통 흐름과 같되, 글자가 없는 그림 버튼(TextureButton)과
## 초점을 받지 않는 버튼을 건너뛰고, 글자로 찾을 때는 앞서 누른 버튼에 글자가 있을 때만 찾는다.
func _restore_focus(previous: Dictionary) -> void:
	var wanted_name: String = str(previous.get("name", ""))
	var wanted_text: String = str(previous.get("text", ""))
	for control: Node in content.find_children("*", "BaseButton", true, false):
		var button: BaseButton = control as BaseButton
		if button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		var same_text: bool = not wanted_text.is_empty() and button is Button and (button as Button).text == wanted_text
		if str(button.name) == wanted_name or same_text:
			button.grab_focus()
			return


## 홈에서 뒤로 가기: 처음에는 한 번 더 누르면 끝난다고 알리고, 그 안에 또 누르면 끝낸다.
func _confirm_exit() -> void:
	var now: int = Time.get_ticks_msec()
	if now < _exit_armed_until:
		quit_app.call()
		return
	_exit_armed_until = now + EXIT_WINDOW_MSEC
	show_toast(tr_text("Press back again to exit", "한 번 더 누르면 게임을 끝내요"))


## 바깥 화면 위에 팝업을 띄운다. 닫히면 지운다.
func show_popup(popup: Control) -> void:
	_close_outgame_popup()
	layers.layer("Popup").add_child(popup)
	outgame_popup = popup
	popup.closed.connect(func() -> void:
		if outgame_popup == popup:
			outgame_popup = null
		popup.queue_free())
	popup.open()


func _close_outgame_popup() -> void:
	if outgame_popup != null and is_instance_valid(outgame_popup):
		outgame_popup.queue_free()
	outgame_popup = null


## 화면 아래쪽 가운데에 짧은 안내를 띄운다(홈의 아래 줄 위, 하위 화면 머리 줄과 겹치지 않는 자리). kind는 info 또는 red다.
func show_toast(text: String, kind: String = "info") -> void:
	toasts.append(text)
	if is_instance_valid(_toast):
		_toast.queue_free()
	var plate: NinePatchRect = Art.plate(Art.play("toast_" + kind), TOAST_MARGINS)
	var label: Label = Fonts.text(text, Fonts.display(700), 16, Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(label)
	var width: float = minf(label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40.0, size.x - 24.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plate.size = Vector2(width, 40.0)
	label.size = Vector2(width - 20.0, 36.0)
	label.position = Vector2(10.0, 0.0)
	plate.position = Vector2((size.x - width) / 2.0, size.y - _safe_insets().y - TOAST_FROM_BOTTOM)
	layers.layer("Toast").add_child(plate)
	_toast = plate
	Juice.pop_in(plate, 0.2)
	plate.create_tween().tween_interval(TOAST_SECONDS).finished.connect(func() -> void:
		if is_instance_valid(plate):
			Juice.pop_out(plate, 0.14).finished.connect(plate.queue_free))


func copy_text(text: String) -> bool:
	return bool(clipboard_writer.call(text))


## 날짜 표시. 한국어는 "12월 1일 (월)", 영어는 "Mon, Dec 1".
func date_text(date: String) -> String:
	var month: int = date.substr(5, 2).to_int()
	var day: int = date.substr(8, 2).to_int()
	var weekday: int = Daily.weekday(date)
	if language() == "ko":
		return "%d월 %d일 (%s)" % [month, day, ["일", "월", "화", "수", "목", "금", "토"][weekday]]
	return "%s, %s %d" % [["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday], _month_names()[month - 1].substr(0, 3), day]


## 달 표시. 한국어는 "2026년 12월", 영어는 "December 2026".
func month_text(date: String) -> String:
	var month: int = date.substr(5, 2).to_int()
	if language() == "ko":
		return "%s년 %d월" % [date.substr(0, 4), month]
	return "%s %s" % [_month_names()[month - 1], date.substr(0, 4)]


func _month_names() -> Array[String]:
	return ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


## 걸린 시간 "분:초".
func clock_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


# =====================================================================
# 출석과 알림함
# =====================================================================

func attendance_waiting() -> bool:
	return session.player.can_claim_attendance(session.services.clock.today())


func open_attendance() -> void:
	show_popup(AttendancePopup.build(self, session.attendance.status(session.player, session.services.clock.today())))


## 오늘의 출석 보상을 받는다. 지급을 저장한 뒤 창을 닫고 홈에서 보상 연출을 보인다.
func claim_attendance() -> void:
	var result: Dictionary = session.attendance.claim(session.player, session.services.clock.today())
	if not result["ok"]:
		return
	audio.vibrate(10)
	var popup: Control = outgame_popup
	if popup != null and is_instance_valid(popup):
		popup.close()
		await popup.closed
	_home()
	_present_reward(result["reward"], tr_text("Day %d gift", "%d일째 선물") % (int(result["day"]) + 1))


## 받을 수 있는 우편 수(보상이 있고 받지 않았고 기간이 남은 것).
func inbox_claimable() -> int:
	var count: int = 0
	var now: int = session.services.clock.now_unix()
	for mail: Dictionary in state.data.get("mail", []):
		if int(mail["claimedAt"]) == 0 and int(mail["amount"]) > 0 and (int(mail["expiresAt"]) == 0 or int(mail["expiresAt"]) > now):
			count += 1
	return count


## 홈의 알림함 배지: 받을 보상이나 읽지 않은 소식의 수.
func inbox_waiting() -> int:
	var unread: int = 0
	for mail: Dictionary in state.data.get("mail", []):
		if int(mail["readAt"]) == 0 and int(mail["amount"]) == 0:
			unread += 1
	return inbox_claimable() + unread


## 우편 하나를 받는다. 공통 저장에 기록한 뒤 받은 코인을 제품 저장으로 옮긴다.
func claim_mail(id: String) -> void:
	var result: Dictionary = state.claim_mail(id, session.services.clock.now_unix())
	if not result.get("ok", false):
		show_toast(_error_text(str(result.get("code", ""))), "red")
		return
	_after_mail_claim(int(result.get("amount", 0)) if result.get("applied", false) else 0)


func claim_all_mail() -> void:
	var total: int = 0
	var now: int = session.services.clock.now_unix()
	for mail: Dictionary in state.data.mail.duplicate(true):
		if int(mail["claimedAt"]) == 0 and int(mail["amount"]) > 0 and (int(mail["expiresAt"]) == 0 or int(mail["expiresAt"]) > now):
			var result: Dictionary = state.claim_mail(str(mail["id"]), now)
			if result.get("ok", false) and result.get("applied", false):
				total += int(result["amount"])
	_after_mail_claim(total)


func _after_mail_claim(coins: int) -> void:
	session.absorb_outgame_grants(state.data.get("grants", {}))
	if outgame_view != null and outgame_view.has_method("rebuild"):
		outgame_view.rebuild()
	if coins > 0:
		audio.vibrate(10)
		_present_reward({"coins": coins}, tr_text("Inbox reward", "우편 보상"))


# =====================================================================
# 보상 연출
# =====================================================================

## 받은 보상을 공통 보상 연출로 보인다. 홈이면 코인과 부스터가 코인 칩으로 날아가고 숫자가 올라간다.
func _present_reward(reward: Dictionary, headline: String) -> void:
	var items: Array = []
	if int(reward.get("coins", 0)) > 0:
		items.append({"icon": Art.skin("icon_coin"), "amount": int(reward["coins"])})
	var boosters: Dictionary = reward.get("boosters", {})
	for id: String in [Economy.BOOSTER_HINT, Economy.BOOSTER_UNDO, Economy.BOOSTER_SLOT]:
		if int(boosters.get(id, 0)) > 0:
			items.append({"icon": Art.play(BOOSTER_ART[id]), "amount": int(boosters[id])})
	if items.is_empty():
		return
	audio.play("coin")
	var chip: Control = content.find_child("coins", true, false) as Control if screen == "home" else null
	var coins: int = session.player.coins()
	if chip != null:
		chip.set_value(coins - int(reward.get("coins", 0)), false)
		ceremony.finished.connect(chip.set_value.bind(coins, true), CONNECT_ONE_SHOT)
	_dim_for_ceremony()
	# 연출은 홈 가운데의 스테이지 카드 위쪽에 둔다.
	ceremony.present(items, headline, chip, null, 0, 0, Vector2(0.5, 0.3))


## 보상 연출 뒤를 어둡게 깔고, 연출이 끝나면 걷어 낸다. 입력은 막지 않는다.
func _dim_for_ceremony() -> void:
	var dim := ColorRect.new()
	dim.name = "reward_dim"
	dim.color = REWARD_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer: Control = layers.layer("Popup")
	layer.add_child(dim)
	layer.move_child(dim, ceremony.get_index())
	if not Juice.reduced_motion:
		dim.modulate.a = 0.0
		dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.15)
	ceremony.finished.connect(func() -> void:
		if not is_instance_valid(dim):
			return
		if Juice.reduced_motion:
			dim.queue_free()
		else:
			var fade: Tween = dim.create_tween()
			fade.tween_property(dim, "modulate:a", 0.0, 0.2)
			fade.finished.connect(dim.queue_free), CONNECT_ONE_SHOT)


## 튜토리얼의 시작 선물.
func _present_gift(gift: Dictionary) -> void:
	_present_reward(gift, tr_text("Starter gift", "시작 선물"))


# =====================================================================
# 플레이
# =====================================================================

## 플레이를 시작한다. 공통 흐름의 튜토리얼이 진행 중이면 튜토리얼 판, 아니면 하던 판이나 다음 스테이지다.
func _launch_play(_owner: Control) -> void:
	var tutorial: Dictionary = state.data.tutorial
	var teaching: bool = tutorial.status == "active"
	if teaching and int(tutorial.step) == 1 and not session.player.has_run():
		# 묶음 셋을 끝내고 선물까지 받았지만 받기를 누르기 전에 꺼졌다: 공통 흐름의 완료만 마저 기록한다.
		state.action_completed("reward_collected")
		_home()
		return
	_open_round(session.open_round(teaching))


## 날짜의 일일 도전 판을 플레이 화면에 띄운다.
func launch_daily(date: String) -> void:
	screen = "play"
	_open_round(session.open_daily(date))


func _open_round(round: Dictionary) -> void:
	if not round["ok"]:
		_close_play()
		_home()
		show_toast(tr_text("This board could not be opened.", "판을 열 수 없어요."), "red")
		return
	screen = "play"
	_view += 1
	ceremony.skip()
	_close_outgame_popup()
	outgame_view = null
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	backing.visible = false
	_close_play()
	play = PlayScreen.instantiate()
	play.host = self
	play.session = session
	play.audio = audio
	play.insets = _safe_insets()
	play.shop_available = feature_routes.has("shop")
	play.exit_requested.connect(_on_play_exit)
	play.shop_requested.connect(_on_shop_requested)
	layers.layer("World").add_child(play)
	# 공통 흐름의 튜토리얼 행동 수를 판의 완성 묶음 수에 맞춘다(묶음을 저장한 직후에 꺼진 경우).
	if round["mode"] == "tutorial":
		var solved: int = (round["board"] as RefCounted).solved().size()
		while int(state.data.tutorial.hits) < solved and state.action_completed("target_hit"):
			pass
	play.begin(round)


func _close_play() -> void:
	if play != null:
		play.queue_free()
		play = null


func _on_play_exit(detail: Dictionary) -> void:
	_close_play()
	navigation.clear()
	_focus_stack.clear()
	_home()
	if detail.has("error"):
		show_toast(tr_text("This board could not be opened.", "판을 열 수 없어요."), "red")
	var gift: Dictionary = detail.get("gift", {})
	if not gift.is_empty():
		_present_gift(gift)


func _on_shop_requested() -> void:
	if not feature_routes.has("shop"):
		return
	play.save_now()
	_close_play()
	navigation.clear()
	_focus_stack.clear()
	_home()
	_open("shop")


func _safe_insets() -> Vector2:
	if safe_insets_override.x >= 0.0:
		return safe_insets_override
	# 기기의 안전 영역은 앱이 화면 전체를 쓰는 휴대전화에서만 뜻이 있다.
	if not OS.has_feature("mobile") or get_viewport() != get_tree().root:
		return Vector2.ZERO
	return PlayLayout.safe_insets(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), get_viewport_rect().size.y)
