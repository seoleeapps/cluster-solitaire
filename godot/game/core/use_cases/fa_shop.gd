class_name FaShop
extends RefCounted
## 코인 상점(결제 없음). 부스터를 코인으로 사고, 꾸미기 테마를 사고 고른다. 바꾸면 바로 저장하고 코인 사용을 알린다.
## 가격은 FaEconomy가 정본이다. 기본 테마의 id는 ""이고 처음부터 가진 것으로 본다.

const Progress := preload("res://game/core/domain/fa_progress.gd")
const Economy := preload("res://game/core/domain/fa_economy.gd")
const Events := preload("res://game/core/use_cases/fa_round_events.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")

var _store: StorePort
var _analytics: AnalyticsPort


func _init(store: StorePort, analytics: AnalyticsPort) -> void:
	_store = store
	_analytics = analytics


## 부스터 1개를 코인으로 산다. 결과는 {ok, reason, price, short}다.
## reason은 unknown(파는 부스터가 아님), no_coins(short개 모자람)이고 사면 "".
func buy_booster(progress: Progress, booster: String) -> Dictionary:
	if not Economy.BOOSTERS.has(booster):
		return {"ok": false, "reason": "unknown", "price": 0, "short": 0}
	var price: int = Economy.price(booster)
	if not progress.buy_booster(booster):
		return {"ok": false, "reason": "no_coins", "price": price, "short": price - progress.coins()}
	_store.write(progress.to_dict())
	Events.coins_spent(_analytics, price, booster)
	return {"ok": true, "reason": "", "price": price, "short": 0}


## 테마의 상태 {owned, selected, price, short}. short는 사기에 모자란 코인(가졌거나 충분하면 0)이다.
func status(progress: Progress, id: String) -> Dictionary:
	var owned: bool = id.is_empty() or progress.owns_theme(id)
	var kind: String = Economy.theme_kind(id)
	var price: int = Economy.theme_price(id)
	return {
		"owned": owned,
		"selected": progress.selected_theme(kind) == id if not id.is_empty() else true,
		"price": price,
		"short": 0 if owned else maxi(0, price - progress.coins()),
	}


## 테마를 코인으로 사고 바로 그 테마를 쓴다. 결과는 {ok, reason}이고 reason은 unknown, owned, no_coins다.
func buy_theme(progress: Progress, id: String) -> Dictionary:
	var kind: String = Economy.theme_kind(id)
	if kind.is_empty():
		return {"ok": false, "reason": "unknown"}
	if progress.owns_theme(id):
		return {"ok": false, "reason": "owned"}
	var price: int = Economy.theme_price(id)
	if not progress.buy_theme(id, price):
		return {"ok": false, "reason": "no_coins"}
	progress.select_theme(kind, id)
	_store.write(progress.to_dict())
	Events.coins_spent(_analytics, price, id)
	return {"ok": true, "reason": ""}


## 가진 테마를 고른다. id가 ""이면 그 종류의 기본 테마로 되돌린다. 바꾸면 저장하고 true.
func select_theme(progress: Progress, kind: String, id: String) -> bool:
	if not id.is_empty() and Economy.theme_kind(id) != kind:
		return false
	if not progress.select_theme(kind, id):
		return false
	_store.write(progress.to_dict())
	return true
