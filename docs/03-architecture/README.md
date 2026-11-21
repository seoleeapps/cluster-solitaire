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
| `skin_dir` | 제품 스킨 폴더 | `game/skins/candy_pop`. 테마를 적용할 때마다 그림 판을 `DPITexture`로 바꿔 끼우고 주 버튼의 글자를 흰색으로 맞춘다(`_apply_settings` 재정의) |
| `game_services` | 포트 묶음(`FaServices`: store, ads, clock, config, analytics) | `FaServices.local(저장 경로)`: 파일 저장과 기기 시계, 나머지는 아무 일도 하지 않는 기본 포트. 장면을 트리에 넣기 전에 필드를 바꿔 끼우면 그 구현이 쓰인다 |
| `session` | 실행 상태와 유스케이스(`FaSession`). `_ready`에서 `FaSession.open(game_services)`로 콘텐츠, 레벨 팩, 저장을 읽는다 | 화면은 이 묶음만 받는다 |
| `launch_game(owner)` | 홈의 플레이 버튼이나 첫 실행에서 플레이를 시작한다 | `_launch_play`: 공통 튜토리얼이 진행 중이면 튜토리얼 판, 아니면 하던 판이나 다음 스테이지를 `features/play/play_screen.tscn`에 띄운다 |
| `stage_factory(profile) -> Control` | 홈 가운데에 놓을 제품 Control | `features/home/home.gd`: 다음 스테이지 번호와 모은 별. 시작은 그 아래 공통 주 버튼(`play`)이 맡고 문구는 `_home` 재정의에서 `스테이지 N 시작`이나 `이어 하기`로 바꾼다 |
| `resource_provider` | 홈 코인 칩의 값 | 제품 저장의 코인. 우편함에서 받은 코인은 `_home`에서 제품 저장으로 한 번씩 옮긴다(`FaSession.absorb_outgame_grants`) |
| `feature_routes[이름] = Callable` | `_open("이름")`으로 여는 제품 화면을 등록한다. 내장 화면보다 먼저 찾는다 | 없음. `shop`을 등록하면 플레이 화면의 코인 칩에 더하기가 보이고 누르면 그 경로를 연다 |
| `launch_daily(date)` | 날짜의 일일 도전 판을 플레이 화면에 띄운다 | 진입 화면은 아직 없다 |

플레이 화면은 공통 흐름의 내용 칸을 쓰지 않는다. `_open_round`가 내용 칸을 비우고 화면을 `layers.layer("World")`에 올리며, 팝업은 `Popup` 층, 토스트는 `Toast` 층, 튜토리얼의 손가락과 말풍선은 `Ftue` 층에 올린다. 화면이 끝나면 `exit_requested`로 알리고 `main.gd`가 화면을 지운 뒤 홈을 그린다. 시스템 뒤로 가기는 `_back` 재정의가 플레이 화면에 넘겨 일시정지를 열거나 열린 창을 닫는다.

타이틀(`_title`)과 홈(`_home`)은 공통 흐름이 직접 호출한다. 제품 화면으로 바꾸려면 `main.gd`에서 해당 함수를 재정의한다. 지금은 두 화면 모두 공통 구성에 제품 배경(`features/shared/fa_backdrop.gd`)만 깔았다. 여정 테스트는 `start`, `play`, `settings`, `inbox`, `back`, `close` 같은 노드 이름으로 버튼을 찾으므로, 화면을 바꾸면 여정도 함께 고친다.

튜토리얼 상태는 공통 저장(`flow/state.gd`)이 관리한다. 튜토리얼 판(`godot/data/levels/tutorial.json`)의 묶음 하나를 완성할 때마다 `state.action_completed("target_hit")`를 부르고(세 번), 끝 카드의 받기에서 `state.action_completed("reward_collected")`를 부른다. 시작 선물은 제품 저장의 지급 열쇠 `starter_gift`로 한 번만 준다. 설정의 안내 다시 보기는 같은 판을 다시 하고 선물은 또 주지 않는다.

## 플레이 화면의 구성

| 파일 | 내용 |
|---|---|
| `features/play/play_screen.tscn`, `play_screen.gd` | 화면. 선택 상태와 연출, 팝업과 광고의 앞뒤를 맡고 규칙은 코어에 묻는다 |
| `features/play/play_layout.gd` | 배치 계산. 화면 크기와 안전 영역, 판의 모양에서 각 구역의 자리를 낸다. 수치는 기준 그림에서 잰 값이다 |
| `features/play/card_view.gd`, `slot_cell.gd`, `medal_view.gd`, `booster_button.gd` | 카드, 칸(임시 칸과 예비 자리), 메달, 부스터 버튼 |
| `features/play/play_popups.gd` | 일시정지, 막힘, 실패, 결과, 부스터 얻기, 튜토리얼 끝 카드. 공통 기반의 `popup_base`를 쓴다 |
| `features/play/tutorial_guide.gd` | 튜토리얼 안내: 강조, 손가락, 말풍선, 안내 밖 입력 막기 |
| `features/shared/fa_art.gd`, `fa_fonts.gd`, `fa_audio.gd`, `fa_backdrop.gd` | 그림(SVG를 `DPITexture`로), 서체, 효과음과 음악과 진동, 배경 |
| `bootstrap/fa_services.gd`, `fa_session.gd` | 포트 묶음과 실행 상태 |
| `adapters/fa_file_store.gd`, `fa_system_clock.gd`, `fa_scripted_ads.gd` | 파일 저장, 기기 시계, 여정용 광고 대역 |

실제 광고와 분석, 원격 설정 어댑터(`adapters/fa_live_services.gd`)를 시작 장면에 끼우는 일은 아직 하지 않았다. 끼울 자리는 `main.gd`의 `game_services`다.

## 로컬 모드

이 제품은 로그인, 결제, 서버 연결이 없다. 프로필의 `mode`는 `local`이고 제품 코드는 플랫폼 클라이언트를 연결하지 않는다. 분석(GA4)과 원격 설정(정적 JSON)은 플랫폼 클라이언트를 거치지 않는 제품의 어댑터이고, 주입 값이 없는 실행에서는 꺼져 있다. `npm run check:local-mode`와 `npm test`의 `test_local_mode.py`가 이를 확인한다.
