class_name FaServices
extends RefCounted
## 제품이 바깥과 닿는 다섯 포트의 묶음. 화면과 유스케이스는 이 묶음만 받고, 어느 구현이 들어 있는지는 모른다.
## 실제 광고와 분석, 원격 설정 어댑터는 bootstrap이 이 묶음의 해당 필드에 넣어 연결한다. 검수는 대역을 넣는다.

const Self := preload("res://game/bootstrap/fa_services.gd")
const StorePort := preload("res://game/core/ports/fa_store_port.gd")
const AdsPort := preload("res://game/core/ports/fa_ads_port.gd")
const ClockPort := preload("res://game/core/ports/fa_clock_port.gd")
const ConfigPort := preload("res://game/core/ports/fa_config_port.gd")
const AnalyticsPort := preload("res://game/core/ports/fa_analytics_port.gd")
const FileStore := preload("res://game/adapters/fa_file_store.gd")
const SystemClock := preload("res://game/adapters/fa_system_clock.gd")

var store: StorePort
var ads: AdsPort
var clock: ClockPort
var config: ConfigPort
var analytics: AnalyticsPort


## 서버와 자격증명 없이 동작하는 기본 구성: 파일 저장과 기기 시계를 쓰고 광고, 원격 설정, 분석은 없는 것처럼 동작한다.
static func local(save_path: String) -> Self:
	var services: Self = new()
	services.store = FileStore.new(save_path)
	services.clock = SystemClock.new()
	services.ads = AdsPort.new()
	services.config = ConfigPort.new()
	services.analytics = AnalyticsPort.new()
	return services
