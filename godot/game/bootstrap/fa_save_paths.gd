class_name FaSavePaths
extends RefCounted
## 이 게임이 기기에 두는 파일의 자리를 한곳에 모은다. 시작 장면이 이 값으로 공통 흐름의 상태 저장, 제품 저장,
## 어댑터 폴더를 만들고, 여정은 실행마다 만든 격리 폴더를 root로 준다. 설정의 데이터 초기화는 이 자리의 기록을 지운다.
##
##   state: 공통 흐름의 상태 저장(설정, 튜토리얼, 우편, 동의 버전). 곁에 분석 끄기 표식(.analytics-off)을 둔다
##   progress: 제품 저장(FaFileStore). 곁에 직전 백업(.bak)을 둔다
##   services: 어댑터 폴더(FaJsonFiles). 분석 식별자와 대기열, 원격 설정 캐시

const Self := preload("res://game/bootstrap/fa_save_paths.gd")
const AtomicStore := preload("res://addons/seorilabs_platform/core/atomic_json_store.gd")

## 실제 앱의 자리.
const DEVICE_ROOT := "user://"
const SERVICES_DIR := "services"
## 공통 흐름(flow/state.gd)이 분석을 끈 선택을 본 저장과 따로 남기는 표식의 꼬리. 공통 묶음과 같은 값이어야 한다.
const ANALYTICS_OFF_SUFFIX := ".analytics-off"

var state: String
var progress: String
var services: String


## root 폴더 아래에 game_id로 이름을 붙인 자리.
static func under(root: String, game_id: String) -> Self:
	var paths: Self = new()
	paths.state = root.path_join(game_id + ".json")
	paths.progress = root.path_join(game_id + "-progress.json")
	paths.services = root.path_join(SERVICES_DIR)
	return paths


## 공통 흐름의 상태 저장과 그 곁 파일(분석 끄기 표식, 쓰다 남은 임시 파일)을 지운다. 모두 지웠으면 true.
static func erase_state(state_path: String) -> bool:
	var erased: bool = true
	var marker: String = state_path + ANALYTICS_OFF_SUFFIX
	for file: String in [state_path, state_path + AtomicStore.TEMP_SUFFIX, marker, marker + AtomicStore.TEMP_SUFFIX]:
		if FileAccess.file_exists(file):
			erased = DirAccess.remove_absolute(ProjectSettings.globalize_path(file)) == OK and erased
	return erased
