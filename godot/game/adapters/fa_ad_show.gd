class_name FaAdShow
extends RefCounted
## 떠 있는 광고 하나의 결과를 정한다. SDK가 알려 주는 일(event)과 흐른 시간(advance)을 받아
## earned, dismissed, failed 가운데 하나를 한 번만 정하고, 정한 뒤에 오는 것은 무시한다.
##
## 보상 알림과 닫힘 알림은 어느 쪽이 먼저 와도 된다. 보상형이 보상 없이 닫히면 늦게 오는 보상 알림을
## REWARD_GRACE_SECONDS 동안 기다린 뒤 dismissed로 정한다.
## 알림이 끊기면 시간으로 끝낸다. 떴다는 알림 없이 START_STALL_SECONDS가 지나면 failed,
## 뜬 뒤 OPEN_STALL_SECONDS 동안 아무 알림이 없으면 받은 알림만으로 정한다.
## 시간은 게임이 화면 앞에서 돌아간 시간만 센다. 광고가 화면을 덮는 동안에는 게임이 멈춰 흐르지 않는다.

const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")

const EVENT_SHOWED := "showed"
const EVENT_REWARD := "reward"
const EVENT_DISMISSED := "dismissed"
const EVENT_FAILED := "failed"

const FORMAT_REWARDED := "rewarded"

const START_STALL_SECONDS := 10.0
const OPEN_STALL_SECONDS := 90.0
const REWARD_GRACE_SECONDS := 1.5
## 한 번에 세는 시간의 상한. 광고에서 돌아온 첫 프레임의 긴 간격을 광고를 본 시간으로 세지 않는다.
const MAX_STEP_SECONDS := 0.25

var format: String
## 정해진 결과. 아직이면 "".
var result: String = ""

var _showed: bool = false
var _rewarded: bool = false
var _dismissed: bool = false
var _quiet: float = 0.0
var _grace: float = 0.0


func _init(ad_format: String) -> void:
	format = ad_format


func is_done() -> bool:
	return not result.is_empty()


## SDK가 알려 준 일을 받는다. 모르는 이름은 무시한다.
func event(kind: String) -> void:
	if is_done():
		return
	_quiet = 0.0
	match kind:
		EVENT_SHOWED:
			_showed = true
		EVENT_REWARD:
			if format != FORMAT_REWARDED:
				return
			_rewarded = true
			if _dismissed:
				result = AdsPort.RESULT_EARNED
		EVENT_DISMISSED:
			_dismissed = true
			if format != FORMAT_REWARDED:
				result = AdsPort.RESULT_DISMISSED
			elif _rewarded:
				result = AdsPort.RESULT_EARNED
		EVENT_FAILED:
			# 보상 알림을 이미 받았으면 보상을 지킨다.
			result = AdsPort.RESULT_EARNED if _rewarded else AdsPort.RESULT_FAILED


## 게임이 화면 앞에서 돌아간 시간을 더한다.
func advance(seconds: float) -> void:
	if is_done() or seconds <= 0.0:
		return
	var step: float = minf(seconds, MAX_STEP_SECONDS)
	if _dismissed:
		_grace += step
		if _grace >= REWARD_GRACE_SECONDS:
			result = AdsPort.RESULT_DISMISSED
		return
	_quiet += step
	if not _showed and not _rewarded:
		if _quiet >= START_STALL_SECONDS:
			result = AdsPort.RESULT_FAILED
	elif _quiet >= OPEN_STALL_SECONDS:
		result = AdsPort.RESULT_EARNED if _rewarded else AdsPort.RESULT_DISMISSED
