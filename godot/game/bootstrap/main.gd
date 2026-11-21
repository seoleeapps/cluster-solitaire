extends "res://addons/seorilabs_game/flow/outgame_main.gd"
## Four Alike의 시작 장면. 공통 흐름을 상속해 제품 스킨, 서비스 묶음, 홈 가운데, 플레이 화면을 연결한다.
##
## 연결 지점
##   game_services: 포트 묶음(FaServices). 장면을 트리에 넣기 전에 바꿔 끼울 수 있다(실제 광고·분석 어댑터, 검수 대역).
##   session: 실행 상태와 유스케이스(FaSession). 화면은 이것만 받는다.
##   launch_game → _launch_play: 플레이 화면을 World 층에 올린다. 튜토리얼이 진행 중이면 튜토리얼 판이다.
##   stage_factory → _home_stage: 홈 가운데.  resource_provider: 홈 코인 칩의 값(제품 저장의 코인).
##   feature_routes["shop"]을 등록하면 플레이 화면의 코인 칩에 더하기가 보인다.

const GameServices := preload("res://game/bootstrap/fa_services.gd")
const Session := preload("res://game/bootstrap/fa_session.gd")
const PlayScreen := preload("res://game/features/play/play_screen.tscn")
const PlayLayout := preload("res://game/features/play/play_layout.gd")
const HomeStage := preload("res://game/features/home/home.gd")
const Backdrop := preload("res://game/features/shared/fa_backdrop.gd")
const Art := preload("res://game/features/shared/fa_art.gd")
const GameAudio := preload("res://game/features/shared/fa_audio.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")

const SKIN := "res://game/skins/candy_pop"
## 주 버튼의 글자: 흰색에 짙은 주황 외곽선.
const PRIMARY_OUTLINE := Color(0.62, 0.28, 0.0, 0.7)
const PRIMARY_OUTLINE_SIZE := 5

var game_services: GameServices
var session: Session
## 떠 있는 플레이 화면. 없으면 null.
var play: Control
var audio: Node
## 안전 영역(위, 아래)을 직접 정한다. 음수면 기기의 값을 쓴다. 기준 그림과 같은 여백으로 캡처할 때 쓴다.
var safe_insets_override: Vector2 = Vector2(-1, -1)

## 앱이 뒤로 간 시각(유닉스 초). 오래 있다가 돌아오면 새 실행으로 본다.
var _left_at: int = 0


func _init() -> void:
	var product: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/product.json"))
	game_title = product.name
	game_title_ko = product.name
	home_profile = product.homeProfile
	config.appId = product.id
	state = State.new("user://" + str(product.id) + ".json")
	skin_dir = SKIN
	game_services = GameServices.local("user://" + str(product.id) + "-progress.json")
	stage_factory = _home_stage
	launch_game = _launch_play
	resource_provider = func() -> int: return session.player.coins() if session != null else 0


func _ready() -> void:
	session = Session.open(game_services)
	for problem: String in session.problems:
		push_error("Four Alike data could not be read: " + problem)
	audio = GameAudio.new()
	audio.name = "GameAudio"
	add_child(audio)
	super._ready()
	# 타이틀과 홈, 공통 화면도 플레이 화면과 같은 배경 위에 놓는다.
	var backdrop := Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, backing.get_index())
	session.begin_session()


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
		_left_at = 0


func _apply_settings() -> void:
	super._apply_settings()
	if custom_theme == null and theme != null:
		Art.sharpen(theme)
		for color: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			theme.set_color(color, "PrimaryButton", Color.WHITE)
		theme.set_color("font_disabled_color", "PrimaryButton", Color("f1f2fa"))
		theme.set_color("font_outline_color", "PrimaryButton", PRIMARY_OUTLINE)
		theme.set_constant("outline_size", "PrimaryButton", PRIMARY_OUTLINE_SIZE)
	if audio != null:
		audio.vibration = bool(state.data.settings.vibration)


func _title() -> void:
	super._title()
	if initialized and audio != null:
		audio.start_music()


func _home() -> void:
	if session != null and not state.data.is_empty():
		# 우편함에서 받은 코인을 제품 저장으로 옮긴다.
		session.absorb_outgame_grants(state.data.get("grants", {}))
		var stage: int = session.player.stage()
		if session.player.has_run():
			home_text.action = ["Continue", "이어 하기"]
		else:
			home_text.action = ["Play Stage %d" % stage, "스테이지 %d 시작" % stage]
		home_text.destination = ["Find the four that belong together", "끼리끼리 네 장을 찾아 묶어요"]
	super._home()
	if session != null and session.save_reset:
		session.save_reset = false
		layers.toast(tr_text("Your save could not be read, so the game started fresh.", "저장을 읽지 못해 새로 시작했어요."), 4.0)


func _back() -> void:
	if screen == "play" and play != null:
		play.back_pressed()
		return
	super._back()


## 홈 가운데: 다음에 풀 스테이지 번호와 모은 별.
func _home_stage(_profile: String) -> Control:
	var stage := HomeStage.new()
	stage.stage_number = session.player.stage()
	stage.total_stars = session.player.total_stars()
	stage.caption = tr_text("STAGE", "스테이지")
	return stage


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


## 날짜의 일일 도전 판을 플레이 화면에 띄운다(진입 화면은 일일 도전 작업에서 붙인다).
func launch_daily(date: String) -> void:
	screen = "play"
	_open_round(session.open_daily(date))


func _open_round(round: Dictionary) -> void:
	if not round["ok"]:
		_close_play()
		_home()
		layers.toast(tr_text("This board could not be opened.", "판을 열 수 없어요."), 3.0)
		return
	screen = "play"
	_view += 1
	ceremony.skip()
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
		layers.toast(tr_text("This board could not be opened.", "판을 열 수 없어요."), 3.0)
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


## 튜토리얼의 시작 선물을 홈에서 보상 연출로 보여 준다. 코인과 부스터가 코인 칩으로 날아가고 숫자가 올라간다.
func _present_gift(gift: Dictionary) -> void:
	var items: Array = [{"icon": Art.skin("icon_coin"), "amount": int(gift.get("coins", 0))}]
	var boosters: Dictionary = gift.get("boosters", {})
	for pair: Array in [[Economy.BOOSTER_HINT, "gift_hint"], [Economy.BOOSTER_UNDO, "gift_undo"], [Economy.BOOSTER_SLOT, "gift_slot"]]:
		if int(boosters.get(pair[0], 0)) > 0:
			items.append({"icon": Art.play(pair[1]), "amount": int(boosters[pair[0]])})
	var chip: Control = content.find_child("coins", true, false) as Control
	var coins: int = session.player.coins()
	if chip != null:
		chip.set_value(coins - int(gift.get("coins", 0)), false)
		ceremony.finished.connect(chip.set_value.bind(coins, true), CONNECT_ONE_SHOT)
	# 연출은 홈 가운데의 스테이지 번호 위쪽 빈 자리에 둔다.
	ceremony.present(items, tr_text("Starter gift", "시작 선물"), chip, null, 0, 0, Vector2(0.5, 0.27))


func _safe_insets() -> Vector2:
	if safe_insets_override.x >= 0.0:
		return safe_insets_override
	# 기기의 안전 영역은 앱이 화면 전체를 쓰는 휴대전화에서만 뜻이 있다.
	if not OS.has_feature("mobile") or get_viewport() != get_tree().root:
		return Vector2.ZERO
	return PlayLayout.safe_insets(DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), get_viewport_rect().size.y)
