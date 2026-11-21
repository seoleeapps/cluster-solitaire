class_name FaAdFlow
extends RefCounted
## 광고의 앞뒤를 맡는다. 흐름은 세 단계다.
##   1. request로 정책과 준비 여부를 확인한다(버튼을 보일지 정할 때는 기록을 남기지 않는 check를 쓴다).
##   2. 허용이면 화면이 광고 포트의 show로 광고를 보여 준다.
##   3. 그 결과(earned, dismissed, failed)를 finish_*에 넘긴다. 노출을 기록하고, earned일 때만 보상을 준다.
## finish_*는 request가 허용한 배치에 한 번만 듣는다. 결과가 두 번 와도 보상은 한 번이다.

const Board := preload("res://game/core/domain/fa_board.gd")
const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const AdPolicy := preload("res://game/core/domain/fa_ad_policy.gd")
const RoundMode := preload("res://game/core/domain/fa_round_mode.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")
const ClockPort := preload("res://game/core/ports/fa_clock_port.gd")
const ConfigPort := preload("res://game/core/ports/fa_config_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

const REASON_NOT_READY := "not_ready"

var _store: StorePort
var _ads: AdsPort
var _clock: ClockPort
var _config: ConfigPort
var _analytics: AnalyticsPort
## request가 허용해 결과를 기다리는 배치. 없으면 "".
var _pending: String = ""


func _init(store: StorePort, ads: AdsPort, clock: ClockPort, config: ConfigPort, analytics: AnalyticsPort) -> void:
	_store = store
	_ads = ads
	_clock = clock
	_config = config
	_analytics = analytics


## 실행(세션)을 시작할 때 한 번 부른다. 날짜를 맞추고 실행 번호를 올린다.
func begin_session(progress: Progress) -> void:
	progress.roll_date(_clock.today())
	AdPolicy.begin_session(progress.ads())
	_store.write(progress.to_dict())


## 플레이한 시간을 누적한다. 저장은 다음 판 저장 때 함께 된다.
func add_play_time(progress: Progress, seconds: int) -> void:
	AdPolicy.add_play_seconds(progress.ads(), seconds)


## placement를 mode(journey, daily, tutorial)의 판에서 지금 내도 되는지. 결과는 {ok, reason}이다.
## reason은 FaAdPolicy.can_show의 사유이거나, 정책은 허용하지만 광고가 불러와지지 않았으면 not_ready다.
func check(progress: Progress, placement: String, mode: String) -> Dictionary:
	progress.roll_date(_clock.today())
	var config: Dictionary = _current_config()
	var verdict: Dictionary = AdPolicy.can_show(config, progress.ads(), placement, _clock.now_unix(), mode)
	if verdict["ok"] and not _ads.is_ready(config[placement]["format"]):
		return {"ok": false, "reason": REASON_NOT_READY}
	return verdict


## 광고를 보여 주기 직전에 부른다. check와 같은 판정을 하고, 허용이면 요청을 알린 뒤 이 배치의 결과를 기다린다.
func request(progress: Progress, placement: String, mode: String) -> Dictionary:
	var verdict: Dictionary = check(progress, placement, mode)
	if verdict["ok"]:
		_pending = placement
		_log("ad_requested", placement, "")
	elif verdict["reason"] == REASON_NOT_READY:
		_log("ad_failed", placement, REASON_NOT_READY)
	return verdict


## 보상형 제안을 보지 않고 거절했을 때 부른다. 직후의 전면 광고를 막는다.
func decline(progress: Progress, placement: String) -> void:
	AdPolicy.record_declined(progress.ads(), _clock.now_unix())
	_store.write(progress.to_dict())
	_log("ad_declined", placement, "offer")


## 판 종료 전면 광고가 끝났을 때 부른다.
func finish_interstitial(progress: Progress, result: String) -> void:
	if _take(AdPolicy.INTERSTITIAL_LEVEL_END):
		_record(progress, AdPolicy.INTERSTITIAL_LEVEL_END, result)
		_store.write(progress.to_dict())


## 부스터 광고(칸 추가, 힌트와 되돌리기 충전)가 끝났을 때 부른다. 끝까지 봤으면 그 부스터 1개를 주고 true다.
## 받은 부스터는 FaUseBooster.execute에 source를 ad로 넘겨 쓴다.
func finish_booster(progress: Progress, result: String, booster: String) -> bool:
	if not _take(AdPolicy.REWARDED_BOOSTER):
		return false
	var granted: bool = _record(progress, AdPolicy.REWARDED_BOOSTER, result) \
		and progress.add_reward(Economy.booster_reward(booster))
	_store.write(progress.to_dict())
	return granted


## 이어하기 광고가 끝났을 때 부른다. 끝까지 봤으면 진행 중인 판 board의 실수를 2 줄이고 true다.
## 판당 1회이고 일일 도전에서는 이어 가지 못한다.
func finish_continue(progress: Progress, result: String, board: Board) -> bool:
	if not _take(AdPolicy.REWARDED_CONTINUE):
		return false
	var run: Dictionary = progress.run()
	var allowed: bool = not run.is_empty() and run["mode"] != RoundMode.DAILY
	var granted: bool = _record(progress, AdPolicy.REWARDED_CONTINUE, result) and allowed and board.apply_continue()
	if granted:
		progress.update_run(board, run["seconds"])
	_store.write(progress.to_dict())
	return granted


## 결과 2배 광고가 끝났을 때 부른다. bonus는 FaFinishRound 결과의 bonus다. 끝까지 봤으면 그만큼 코인을 주고 true다.
func finish_bonus(progress: Progress, result: String, bonus: Dictionary) -> bool:
	if not _take(AdPolicy.REWARDED_RESULT_BONUS):
		return false
	var granted: bool = _record(progress, AdPolicy.REWARDED_RESULT_BONUS, result) \
		and bonus.get("key") is String and progress.grant(bonus["key"], {"coins": bonus.get("coins")})
	_store.write(progress.to_dict())
	if granted:
		Events.coins_earned(_analytics, bonus["coins"], AdPolicy.REWARDED_RESULT_BONUS)
	return granted


## 원격 설정 값으로 덮어쓴 지금의 광고 설정.
func _current_config() -> Dictionary:
	var values: Dictionary = {}
	for key: String in AdPolicy.remote_keys():
		values[key] = _config.value(key)
	return AdPolicy.config_from(values)


## request가 허용해 기다리던 배치면 기다림을 풀고 true다. 요청한 적이 없거나 이미 끝낸 광고면 false다.
func _take(placement: String) -> bool:
	if _pending != placement:
		return false
	_pending = ""
	return true


## 광고가 떴으면 노출을 기록하고 알린다. 보상형을 끝까지 보지 않았으면 거절로도 남긴다. 보상형을 끝까지 봤으면 true.
func _record(progress: Progress, placement: String, result: String) -> bool:
	if result != AdsPort.RESULT_EARNED and result != AdsPort.RESULT_DISMISSED:
		_log("ad_failed", placement, "show")
		return false
	var now: int = _clock.now_unix()
	AdPolicy.record_shown(progress.ads(), _current_config(), placement, now)
	_log("ad_impression", placement, "")
	if AdPolicy.DEFAULTS[placement]["format"] != AdPolicy.FORMAT_REWARDED:
		return false
	if result == AdsPort.RESULT_EARNED:
		_log("rewarded_earned", placement, "")
		return true
	AdPolicy.record_declined(progress.ads(), now)
	_log("ad_declined", placement, "dismissed")
	return false


## 광고 이벤트를 {placement, format}과 함께 보낸다. reason이 있으면 함께 싣는다.
func _log(event: String, placement: String, reason: String) -> void:
	var params: Dictionary = {"placement": placement, "format": AdPolicy.DEFAULTS.get(placement, {}).get("format", "")}
	if not reason.is_empty():
		params["reason"] = reason
	_analytics.log_event(event, params)
