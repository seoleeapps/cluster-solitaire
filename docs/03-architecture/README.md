# 구조

Godot 프로젝트는 `godot/`에 있다. 제품 코드는 `godot/game`에만 두고, 공통 묶음은 고치지 않고 연결해서 쓴다. 승인된 책임 분담은 [첫 출시 설계](../design/2026-11-21-four-alike-launch/design.md)의 "구조·책임·의존성" 절에, 앞으로 채울 폴더와 데이터 계약은 [기술 제작 계획](../design/2026-11-21-four-alike-launch/06-technical-production-plan.md)에 있다. 이 문서는 지금 저장소에 있는 것을 적는다.

| 위치 | 책임 |
|---|---|
| `godot/game/bootstrap` | 시작 장면. 공통 흐름을 상속하고 제품 화면과 서비스를 주입한다 |
| `godot/game/core` | 엔진 장면에 기대지 않는 규칙. `domain`, `use_cases`, `ports` |
| `godot/game/features` | 화면과 그 화면 전용 그림 |
| `godot/game/adapters` | core의 포트를 구현하는 저장, 광고, 분석, 원격 설정 같은 바깥 연결. 광고와 동의, 분석, 원격 설정은 [서비스 어댑터](service-adapters.md)에 적었다 |
| `godot/addons/seorilabs_game`, `godot/addons/seorilabs_platform`, `godot/tests/common` | [공통 묶음](common-bundle.md). 해시로 고정돼 있다 |
| `godot/addons/admob` | AdMob 플러그인 5.1.0. 편집기 플러그인으로 켜져 있고 내보낼 때 Android 라이브러리와 앱 ID를 넣는다. 제품 코드에서는 `game/adapters/fa_admob_sdk.gd`만 이 플러그인을 부른다 |
| `godot/tests/game` | 제품 여정(`outgame_journey.gd`)과 프로브(`*_probe.gd`) |
| `godot/config/product.json` | 제품 이름, 식별자, 홈 형식 |
| `godot/data/outgame/outgame-profile.json` | 필수 기능, 선택 기능, 서비스 상태 선언 |
| `remote/config.json` | 원격 설정 파일. GitHub Pages로 배포하고 앱이 시작할 때 받는다 |

의존 방향은 [의존 규칙](clean-architecture.md)을 따른다. `npm run check:architecture`는 `godot/game/core`의 스크립트에 `Node`, `Control`, `SceneTree`, `JavaScriptBridge`, `HTTPRequest`, `FileAccess`라는 단어나 `res://addons`, `res://game/adapters` 경로가 있으면 실패한다. 주석에 써도 실패한다.

## 화면 방향

세로 고정이고 논리 해상도는 390×844다. `godot/project.godot`에서 늘림은 `canvas_items`, 비율은 `keep_width`라서 폭 390을 유지하고 화면이 길어지면 세로만 늘어난다. 예를 들어 360×640 기기에서는 논리 화면이 390×693이 된다. Godot 4의 Android 내보내기는 화면 방향을 프로젝트 설정 `window/handheld/orientation`에서 읽으므로 export preset에는 방향 값이 없다. `tools/check_native.py`가 이 설정이 바뀌면 실패한다.

공통 흐름은 세로에서 UI 배율을 1.0으로 고정한다. 그래서 논리 폭을 390 근처로 유지해야 버튼과 글자 크기가 맞는다.

## 제품 화면을 공통 흐름에 넣는 방법

`godot/game/bootstrap/main.gd`는 공통 흐름 `addons/seorilabs_game/flow/outgame_main.gd`를 상속한다. 공통 파일을 고치지 않고 아래 자리에 제품 코드를 넣는다.

| 자리 | 쓰임 | 지금 들어 있는 것 |
|---|---|---|
| `skin_dir` | 제품 스킨 폴더 | `game/skins/candy_pop`. 테마를 적용할 때마다 그림 판을 `DPITexture`로 바꿔 끼우고 주 버튼의 글자를 흰색으로, 설정의 토글을 제품 스위치 그림으로 맞춘다(`_apply_settings` 재정의) |
| `game_services` | 포트 묶음(`FaServices`: store, ads, clock, config, analytics) | `_init`에서 `FaServices.local(save_paths.progress)`(파일 저장과 기기 시계)를 만들고 `use_live_services()`로 실제 광고, 분석, 원격 설정 어댑터(`FaLiveServices`)를 끼운다. 장면을 트리에 넣기 전에 필드를 바꿔 끼우면 그 구현이 쓰인다(여정의 대역). 실제 어댑터를 하나도 쓰지 않으면 `FaLiveServices`는 트리에 들어가지 않는다 |
| `session` | 실행 상태와 유스케이스(`FaSession`) | 타이틀의 "카드 준비" 단계에서 `FaSession.open(game_services)`로 콘텐츠, 레벨 팩, 제품 저장을 읽는다. 공통 흐름이 저장을 읽은 화면을 한 번 그린 다음이다. 화면은 이 묶음만 받는다 |
| `_title()`, `_home()` 재정의 | 공통 흐름이 직접 부르는 타이틀과 홈 | `features/outgame/title_screen.gd`, `home_screen.gd`. 타이틀은 다시 그릴 때 값만 바꿔 진입 모션을 한 번만 보인다 |
| `launch_game(owner)` | 홈의 플레이 버튼이나 첫 실행에서 플레이를 시작한다 | `_launch_play`: 공통 튜토리얼이 진행 중이면 튜토리얼 판, 아니면 하던 판이나 다음 스테이지를 `features/play/play_screen.tscn`에 띄운다 |
| `resource_provider` | 공통 화면의 코인 값 | 제품 저장의 코인. 우편함에서 받은 코인은 받을 때와 `_home`에서 제품 저장으로 한 번씩 옮긴다(`FaSession.absorb_outgame_grants`) |
| `feature_routes[이름] = Callable` | `_open("이름")`으로 여는 제품 화면. 내장 화면보다 먼저 찾는다 | `daily`, `album`, `shop`, `inbox`, `licenses`. 모두 공통 흐름의 흰 판(`_clear`)에 제품 화면을 얹는다. `shop`이 있어서 플레이 화면의 코인 칩에 더하기가 보이고 누르면 상점을 연다 |
| `launch_daily(date)` | 날짜의 일일 도전 판을 플레이 화면에 띄운다 | 일일 도전 화면의 시작 버튼이 부른다 |

플레이 화면은 공통 흐름의 내용 칸을 쓰지 않는다. `_open_round`가 내용 칸을 비우고 화면을 `layers.layer("World")`에 올리며, 팝업은 `Popup` 층, 토스트는 `Toast` 층, 튜토리얼의 손가락과 말풍선은 `Ftue` 층에 올린다. 화면이 끝나면 `exit_requested`로 알리고 `main.gd`가 화면을 지운 뒤 홈을 그린다. 시스템 뒤로 가기는 `_back` 재정의가 플레이 화면에 넘겨 일시정지를 열거나 열린 창을 닫는다.

타이틀(`_title`)과 홈(`_home`)은 공통 흐름이 직접 호출하므로 `main.gd`에서 재정의해 제품 화면을 그린다. 하위 화면(설정, 알림함, 일일 도전, 도감, 상점, 오픈소스 고지)은 공통 흐름의 흰 판과 머리 줄을 쓰고, `_clear` 재정의가 머리 줄의 뒤로와 닫기를 제품 그림으로, 제목을 제품 서체로 바꾼다. 설정은 공통 화면에 개인정보처리방침, 개인정보 선택(동의 지역에서만), 오픈소스 고지, 데이터 초기화를 더하고 목록을 그림과 꺾쇠가 있는 줄로 바꾼다(`_settings` 재정의). 공통 흐름의 초점 되돌리기(`_restore_focus`)는 글자가 없는 그림 버튼에서 멈추므로 제품이 같은 일을 이름 우선으로 다시 한다. 여정 테스트는 `start`, `play`, `settings`, `inbox`, `daily`, `album`, `shop`, `attendance`, `back`, `close` 같은 노드 이름으로 버튼을 찾으므로, 화면을 바꾸면 여정도 함께 고친다.

타이틀의 막대는 실제 준비 단계 셋(공통 흐름의 저장 읽기, 카드 준비, 동의 확인)이 끝난 만큼 찬다(`title_progress`). 동의 확인은 광고 포트의 `consent_settled()`로 보고, 동의 SDK가 답하지 않아도 5초 뒤에는 시작할 수 있다. 뒤로 가기는 팝업, 하위 화면, 홈 순서로 닫고, 타이틀과 홈에서는 한 번 더 누르면 끝낸다고 알린 뒤 2초 안에 또 누르면 끝낸다. 이를 위해 `application/config/quit_on_go_back`을 끈다.

### 한곳에서만 하는 일

| 일 | 맡는 곳 | 하지 않는 곳 |
|---|---|---|
| 광고가 떠 있는 동안 음악 멈춤 | 플레이 화면이 광고를 보여 달라고 할 때 멈추고 결과를 받으면 되돌린다(`_begin_ad`, `_end_ad`). 어느 광고 포트에서나 같은 길이라 여정이 확인할 수 있다 | 광고 어댑터의 `presenting_changed`는 연결하지 않는다 |
| 앱 복귀 때 새 실행(세션) | `main.gd`의 `_notification`이 시계 포트로 백그라운드에 있던 시간을 재고, 수익화 프로필의 1,800초를 넘으면 `FaSession.begin_session()`과 `FaLiveServices.begin_session()`(분석의 세션)을 부른다 | `FaLiveServices`는 스스로 판단하지 않는다 |
| `app_first_run`, `app_session` | 분석 어댑터(`FaGa4Analytics`) | bootstrap과 화면은 보내지 않는다 |
| 동의가 바뀜 | 광고 포트의 `consent_changed` 신호. `main.gd`가 받아 분석 선택을 다시 적용하고 타이틀이나 설정 화면을 다시 그린다 | |

### 저장 자리와 데이터 초기화

기기에 두는 파일의 자리는 `bootstrap/fa_save_paths.gd`(`FaSavePaths`) 한곳에서 정한다. 실제 앱은 `user://` 아래이고, 여정은 실행마다 만든 격리 폴더를 같은 함수(`FaSavePaths.under(폴더, 이름)`)에 넘긴다.

| 자리 | 파일 | 쓰는 곳 |
|---|---|---|
| `state` | `<제품 ID>.json`과 곁의 분석 끄기 표식 `.analytics-off` | 공통 흐름의 상태 저장(`flow/state.gd`): 설정, 튜토리얼, 우편, 동의 버전 |
| `progress` | `<제품 ID>-progress.json`과 직전 백업 `.bak` | 제품 저장(`FaFileStore`) |
| `services` | `services/` 폴더 | 어댑터의 작은 파일(`FaJsonFiles`): 분석 식별자와 대기열, 원격 설정 캐시 |

설정의 데이터 초기화(SCR-014)는 두 번 확인한 뒤 `main.gd`의 `erase_all_data()`가 맡는다. 지금 쓰는 객체에서 자리를 읽어 지우므로 여정의 격리 폴더에서도 같은 길로 돈다. 저장 포트의 `erase()`가 제품 저장과 백업을, 분석 포트의 `forget_device()`가 분석 식별자와 대기열을, `FaSavePaths.erase_state()`가 공통 흐름의 상태 저장과 분석 끄기 표식을 지운다. 그 뒤 공통 흐름의 시작(`_initialize`)과 제품 실행 상태(`_open_session`)를 처음부터 다시 돌아 처음 실행한 것처럼 타이틀과 튜토리얼로 간다. 설정은 기본값이고 분석 허용도 기본(켬)으로 돌아간다. 광고 동의(UMP)는 SDK가 기억하므로 건드리지 않고, 원격 설정 캐시는 기록이 아니어서 남긴다. 확인 창은 `features/outgame/reset_popup.gd`다.

튜토리얼 상태는 공통 저장(`flow/state.gd`)이 관리한다. 튜토리얼 판(`godot/data/levels/tutorial.json`)의 묶음 하나를 완성할 때마다 `state.action_completed("target_hit")`를 부르고(세 번), 끝 카드의 받기에서 `state.action_completed("reward_collected")`를 부른다. 시작 선물은 제품 저장의 지급 열쇠 `starter_gift`로 한 번만 준다. 설정의 안내 다시 보기는 같은 판을 다시 하고 선물은 또 주지 않는다.

## 플레이 화면의 구성

| 파일 | 내용 |
|---|---|
| `features/play/play_screen.tscn`, `play_screen.gd` | 화면. 선택 상태와 연출, 팝업과 광고의 앞뒤를 맡고 규칙은 코어에 묻는다 |
| `features/play/play_layout.gd` | 배치 계산. 화면 크기와 안전 영역, 판의 모양에서 각 구역의 자리를 낸다. 수치는 기준 그림에서 잰 값이다 |
| `features/play/card_view.gd`, `slot_cell.gd`, `medal_view.gd`, `booster_button.gd` | 카드, 칸(임시 칸과 예비 자리), 메달, 부스터 버튼 |
| `features/play/play_popups.gd` | 일시정지, 막힘, 실패, 결과, 부스터 얻기, 튜토리얼 끝 카드. 공통 기반의 `popup_base`를 쓴다 |
| `features/play/tutorial_guide.gd` | 튜토리얼 안내: 강조, 손가락, 말풍선, 안내 밖 입력 막기 |
| `features/shared/fa_art.gd`, `fa_fonts.gd`, `fa_audio.gd`, `fa_backdrop.gd` | 그림(SVG를 `DPITexture`로), 서체(한국어 낱말 단위 줄바꿈 포함), 효과음과 음악과 진동, 배경(고른 배경 테마의 색) |
| `features/shared/fa_ui.gd` | 제품 화면이 함께 쓰는 구성요소: 그림 판 버튼(되돌릴 수 없는 행동의 빨간 주 버튼 포함), 안내 글, 팝업 틀, 코인 칩, 흰 판, 배지, HUD 버튼, 둥근 메뉴 버튼. 큰 글자 설정을 따른다 |
| `features/shared/fa_look.gd` | 꾸미기 테마의 모양(카드 뒷면 그림, 배경 색, 이름). 가격과 목록은 코어(`FaEconomy.THEMES`) |
| `bootstrap/fa_services.gd`, `fa_session.gd`, `fa_save_paths.gd` | 포트 묶음, 실행 상태, 저장 파일의 자리 |
| `adapters/fa_file_store.gd`, `fa_system_clock.gd`, `fa_scripted_ads.gd` | 파일 저장, 기기 시계, 여정용 광고와 동의 대역 |
| `adapters/fa_live_services.gd`와 그 어댑터들 | 실제 광고와 동의, 분석, 원격 설정([서비스 어댑터](service-adapters.md)) |

## 바깥 화면의 구성

| 파일 | 화면 |
|---|---|
| `features/outgame/title_screen.gd` | 타이틀(SCR-001). 로고와 부제, 카드 네 장 부채꼴과 범주 이름표, 실제 준비 단계 막대, 상태 문구, 시작과 다시 시도, 버전과 제작사(공통 흐름의 `studio_name`) |
| `features/outgame/home_screen.gd` | 홈(SCR-002). 설정과 알림함, 코인 칩, 스테이지 카드, 주 버튼, 일일 도전 카드, 도감·상점·출석 |
| `features/outgame/daily_screen.gd` | 일일 도전(SCR-008). 이번 달 달력, 연속 기록, 고른 날의 판과 결과, 결과 복사 |
| `features/outgame/album_screen.gd` | 도감(SCR-009). 대분류별 4열 칸과 상세 팝업 |
| `features/outgame/shop_screen.gd` | 상점(SCR-010). 부스터와 꾸미기 탭 |
| `features/outgame/attendance_popup.gd` | 출석(SCR-011) 팝업 |
| `features/outgame/inbox_screen.gd` | 알림함(SCR-015). 공통 저장의 우편을 제품 문구로 |
| `features/outgame/licenses_screen.gd` | 오픈소스 고지. 저장소의 라이선스 파일을 읽어 보인다 |
| `features/outgame/reset_popup.gd` | 설정의 데이터 초기화(SCR-014) 두 번 확인 창 |
| `features/outgame/assets/` | 바깥 화면 그림(SVG). `tools/art/build_candy_pop.py`가 만든다 |

바깥 화면의 규칙은 코어의 유스케이스가 맡는다. 상점은 `FaShop`(부스터와 테마 사기, 테마 고르기), 출석은 `FaAttendance`(상태와 받기)이고 둘 다 바꾸면 바로 저장하고 분석에 알린다.

## 로컬 모드

이 제품은 로그인, 결제, 서버 연결이 없다. 프로필의 `mode`는 `local`이고 제품 코드는 플랫폼 클라이언트를 연결하지 않는다. 분석(GA4)과 원격 설정(정적 JSON)은 플랫폼 클라이언트를 거치지 않는 제품의 어댑터이고, 주입 값이 없는 실행에서는 꺼져 있다. `npm run check:local-mode`와 `npm test`의 `test_local_mode.py`가 이를 확인한다.
