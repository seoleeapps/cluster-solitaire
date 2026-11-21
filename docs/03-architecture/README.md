# 구조

Godot 프로젝트는 `godot/`에 있다. 제품 코드는 `godot/game`에만 두고, 공통 묶음은 고치지 않고 연결해서 쓴다. 승인된 책임 분담은 [첫 출시 설계](../design/2026-11-21-four-alike-launch/design.md)의 "구조·책임·의존성" 절에, 앞으로 채울 폴더와 데이터 계약은 [기술 제작 계획](../design/2026-11-21-four-alike-launch/06-technical-production-plan.md)에 있다. 이 문서는 지금 저장소에 있는 것을 적는다.

| 위치 | 책임 |
|---|---|
| `godot/game/bootstrap` | 시작 장면. 공통 흐름을 상속하고 제품 화면과 서비스를 주입한다 |
| `godot/game/core` | 엔진 장면에 기대지 않는 규칙. `domain`, `use_cases`, `ports` |
| `godot/game/features` | 화면과 그 화면 전용 그림 |
| `godot/game/adapters` | core의 포트를 구현하는 저장, 광고, 분석 같은 바깥 연결 |
| `godot/addons/seorilabs_game`, `godot/addons/seorilabs_platform`, `godot/tests/common` | [공통 묶음](common-bundle.md). 해시로 고정돼 있다 |
| `godot/addons/admob` | AdMob 플러그인 5.1.0. 지금은 편집기 플러그인으로 켜져 있지 않다 |
| `godot/tests/game` | 제품 여정(`outgame_journey.gd`)과 프로브(`*_probe.gd`) |
| `godot/config/product.json` | 제품 이름, 식별자, 홈 형식 |
| `godot/data/outgame/outgame-profile.json` | 필수 기능, 선택 기능, 서비스 상태 선언 |

의존 방향은 [의존 규칙](clean-architecture.md)을 따른다. `npm run check:architecture`는 `godot/game/core`의 스크립트에 `Node`, `Control`, `SceneTree`, `JavaScriptBridge`, `HTTPRequest`, `FileAccess`라는 단어나 `res://addons`, `res://game/adapters` 경로가 있으면 실패한다. 주석에 써도 실패한다.

## 화면 방향

세로 고정이고 논리 해상도는 390×844다. `godot/project.godot`에서 늘림은 `canvas_items`, 비율은 `keep_width`라서 폭 390을 유지하고 화면이 길어지면 세로만 늘어난다. 예를 들어 360×640 기기에서는 논리 화면이 390×693이 된다. Godot 4의 Android 내보내기는 화면 방향을 프로젝트 설정 `window/handheld/orientation`에서 읽으므로 export preset에는 방향 값이 없다. `tools/check_native.py`가 이 설정이 바뀌면 실패한다.

공통 흐름은 세로에서 UI 배율을 1.0으로 고정한다. 그래서 논리 폭을 390 근처로 유지해야 버튼과 글자 크기가 맞는다.

## 제품 화면을 공통 흐름에 넣는 방법

`godot/game/bootstrap/main.gd`는 공통 흐름 `addons/seorilabs_game/flow/outgame_main.gd`를 상속한다. 공통 파일을 고치지 않고 아래 자리에 제품 코드를 넣는다.

| 자리 | 쓰임 | 지금 들어 있는 것 |
|---|---|---|
| `stage_factory(profile) -> Control` | 홈 가운데에 놓을 제품 Control. 홈 형식이 `map`이나 `world`일 때만 불린다 | `features/home/home.gd`의 샘플 지도 |
| `launch_game(owner)` | 홈의 플레이 버튼이나 첫 실행 안내에서 플레이를 시작한다 | `features/sample_round`의 샘플 라운드 |
| `score_provider() -> Dictionary` | 결과에서 점수를 제출할 때 쓴다 | 샘플 점수 |
| `feature_routes[이름] = Callable` | `_open("이름")`으로 여는 제품 화면을 등록한다. 내장 화면보다 먼저 찾는다 | 없음 |
| `home_text`, `resource_provider` | 홈의 문구와 재화 칩 값 | 공통 기본값 |
| `skin_dir`, `custom_theme` | 제품 스킨 폴더나 테마 | 공통 `soft_adventure` |

플레이 화면은 `owner._clear(제목)`으로 프레임과 뒤로, 닫기 버튼을 그린 뒤 `owner.content`나 `owner._scroll()`에 내용을 넣는다. 판이 끝나면 `owner.popups.enqueue("reward", {"text": ..., "amount": ...})`와 `owner._show_next_popup()`으로 공통 결과 화면과 보상 연출을 띄운다. 샘플 라운드(`features/sample_round/sample_round.gd`)가 이 순서를 그대로 보여 준다.

타이틀(`_title`), 홈(`_home`), 결과(`_draw_result`)는 공통 흐름이 직접 호출하므로 `feature_routes`에 같은 이름을 넣어도 바뀌지 않는 경로가 있다. 이 화면을 제품 화면으로 바꾸려면 `main.gd`에서 해당 함수를 재정의한다. 여정 테스트는 `start`, `play`, `settings`, `inbox`, `back`, `close`, `reward_continue` 같은 노드 이름으로 버튼을 찾으므로, 화면을 바꾸면 여정도 함께 고친다.

튜토리얼 상태는 공통 저장(`flow/state.gd`)이 관리한다. `state.action_completed("target_hit")` 세 번과 `state.action_completed("reward_collected")` 한 번으로만 진행하고, 첫 완료 보상은 한 번만 준다. 설계는 튜토리얼 판의 묶음 3개를 이 행동에 연결한다.

## 로컬 모드

이 제품은 로그인, 결제, 서버 연결이 없다. 프로필의 `mode`는 `local`이고 제품 코드는 플랫폼 클라이언트를 연결하지 않는다. `npm run check:local-mode`와 `npm test`의 `test_local_mode.py`가 이를 확인한다.
