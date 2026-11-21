# 검수 전략

기본 검수 환경은 개발 환경의 headless 여정과 렌더 캡처다. 기기는 개발 환경으로 확인할 수 없는 항목(설계의 AND-01~08)에만 쓴다.

## 명령

| 명령 | 확인하는 것 |
|---|---|
| `npm test` | 도구 단위 테스트, Android 설정 검사, 아래 `tools/check.py` 전체 |
| `python3 tools/check.py` | 구조 검사, 공통 묶음 해시, import, 공통 계약 프로브, 제품 여정, `tests/game`의 프로브, 기능 목록 누락, 추적 파일 불변 |
| `python3 tools/check.py --capture --size 390x844 --out build/render-390` | 같은 여정을 렌더링해 장면별 PNG를 남긴다. `--size 360x640`으로 작은 화면도 찍는다 |
| `npm run test:core` | `godot/game/core`의 규칙 프로브만 |
| `npm run check:architecture`, `npm run check:bundle`, `npm run check:local-mode` | core 경계, 공통 묶음 해시, 로컬 전용 구성 |

`tools/check.py`는 Godot 로그에 `SCRIPT ERROR`나 `ERROR:`로 시작하는 줄이 있으면 실패한다. `--out`은 `build/` 아래의 새 폴더나 빈 폴더여야 한다. Linux에서 `--capture`는 `xvfb-run -a`로 감싼다.

`--size`는 기기 픽셀이 아니라 논리 화면 크기다. 폭 기준으로 늘리므로 360×640 기기의 논리 화면은 390×693, 412×915 기기는 390×866이다. 검수 범위와 크기의 정본은 [QA 론칭 계획](../design/2026-11-21-four-alike-launch/07-qa-launch-plan.md)과 [테스트 계획](../design/2026-11-21-four-alike-launch/test-plan.json)이다.

렌더링 여정은 실제 창을 띄운다. 같은 데스크톱에서 다른 창이 초점을 가져가는 동안에는 탭 입력 하나가 빠져 실패한 적이 있다. 같은 명령을 다시 실행해 확인하고, 반복해서 같은 단계에서 실패하면 결함으로 본다. headless 실행과 CI의 `xvfb-run`에서는 이 현상을 보지 못했다.

## 여정

`godot/tests/game/outgame_journey.gd`는 실제 시작 장면을 띄우고 화면 좌표 입력으로만 진행한다. 저장은 실행마다 새로 만든 임시 경로를 주입한다.

| 시나리오 | 흐름 |
|---|---|
| `offline-first-play-restart` | 타이틀, 안내, 샘플 라운드, 보상 연출, 결과, 홈, 우편함, 재실행 뒤 보상 복원 |
| `settings-language-support-focus` | 분석 끄기, 지원코드, 한국어 전환, 큰 글자, 키보드 초점, 재실행 뒤 설정 유지 |
| `skip-guide-home-replay` | 안내 건너뛰기, 재실행 뒤 안내를 강제하지 않음, 홈의 두 플레이 버튼 |

타이틀, 샘플 라운드, 결과, 홈에서는 버튼이 세로 화면 밖으로 나가거나 서로 겹치지 않는지도 검사한다. 함수 직접 호출로 화면을 건너뛰지 않는다. 캡처한 PNG는 직접 열어 글자 잘림과 겹침을 본다. PNG를 저장한 것만으로 화면 검수가 끝나지 않는다.

`core`의 규칙, 해법 탐색, 생성기, 경제, 광고 정책은 요구사항 때문에 실패하는 프로브를 먼저 쓰고 구현한다. `godot/tests/game`에 `*_probe.gd`로 두면 `tools/check.py`가 자동으로 실행한다.

## 기능을 더하거나 뺄 때

1. `docs/qa/feature-inventory.json`의 `features`에 항목을 넣는다. `paths`는 그 기능의 실제 파일을 가리키는 glob이고, 네이티브 SDK를 직접 부르는 파일은 `platformPaths`에도 적는다. 어느 파일과도 맞지 않는 glob은 `npm test`에서 실패한다.
2. 여정의 시나리오에 그 기능 ID를 적고 실제 화면 입력으로 확인한다. `core: true`인 기능이 통과한 시나리오에 없으면 `tools/check.py`가 `missing feature journeys`로 실패한다.
3. `godot/data/outgame/outgame-profile.json`을 지금 상태대로 고친다. 서비스에 어댑터를 붙이면 `services`의 `status`를 `local`이나 `wired`로, `binding`을 실제 파일로 바꾼다. `ads`나 `payments`를 `exposed: true`로 두려면 `bmProfile`에 수익화 프로필 파일이 있어야 한다. 선택 기능은 `optional`의 `enabled`와 `reason`으로 적는다.
4. 제품이 새로 쓰는 스킨, 글꼴, 장면은 `uiStandard.resources`에 넣는다.

프로필의 `optional`에서 켜 둔 출석, 일일 도전(events), 코인 상점(shop)은 첫 출시에 넣기로 한 결정이고 화면은 아직 없다. 구현하면서 기능 목록과 여정에 추가한다.

## 출시

출시 단계의 검사와 기록은 [출시 체크리스트](../06-release/release-checklist.md)를 따른다.
