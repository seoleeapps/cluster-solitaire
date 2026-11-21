# 검수 전략

기본 검수 환경은 개발 환경의 headless 여정과 렌더 캡처다. 기기는 개발 환경으로 확인할 수 없는 항목(설계의 AND-01~08)에만 쓴다.

## 명령

| 명령 | 확인하는 것 |
|---|---|
| `npm test` | 생성물 대조(`check:generated`), 레벨 팩 검증(`check:levels`), 원격 설정 대조(`check:remote-config`), 도구 단위 테스트, Android 설정 검사, 아래 `tools/check.py` 전체, 내보낸 묶음 검사(`check:export-pack`) |
| `python3 tools/check.py` | 구조 검사, 공통 묶음 해시, import, 공통 계약 프로브, 제품 여정(시간 제한 600초, 나머지는 180초), `tests/game`의 프로브, 기능 목록 누락, 추적 파일 불변 |
| `python3 tools/check.py --capture --size 390x844 --out build/render-390` | 같은 여정을 렌더링해 장면별 PNG를 남긴다. 지원하는 가장 낮은 화면 `--size 390x693`, 긴 화면 `--size 390x866`, 지원 범위 밖의 작은 화면 `--size 360x640`도 찍는다 |
| `npm run test:core` | `godot/game/core`의 규칙 프로브만. `python3 tools/run_probes.py board solver`처럼 이름 일부를 주면 그 프로브만 돈다 |
| `npm run check:levels` | 실린 레벨 팩의 모든 판을 참고용 Python 탐색기로 다시 검사한다(풀이 가능, 관대함, 묶음 유일성, 등급의 범주 조건). 손으로 만든 튜토리얼 판과 안내 순서도 본다 |
| `npm run check:export-pack` | Android 프리셋으로 자원 묶음을 내보내(`--export-pack`, 내보내기 템플릿과 SDK 없이 돈다) 선명한 그림의 SVG 원문 묶음, 카드 아이콘, 소리, 데이터 파일이 들어 있는지 본다 |
| `npm run build:levels` | 여정과 일일 도전 팩을 다시 만들고 바로 검사한다. 콘텐츠 표나 생성 규칙을 고친 뒤에 쓴다 |
| `npm run check:architecture`, `npm run check:bundle`, `npm run check:local-mode` | core 경계, 공통 묶음 해시, 로컬 전용 구성 |
| `npm run check:remote-config` | `remote/config.json`의 열쇠, 형, 범위를 수익화 프로필과 대조한다 |
| `npm run check:aab` | 만든 릴리스 AAB를 다시 읽어 패키지, 버전, 서명, 권한, 주입 값을 검사한다. `npm run build:android`가 끝에 실행한다 |
| `python3 tools/check_ga4_payload.py` | 분석 어댑터가 만든 요청 본문을 GA4의 검증 주소에 대어 본다. 기록되지 않는 주소이고 네트워크와 측정 값이 필요해 `npm test`에는 없다 |

`tools/check.py`는 Godot 로그에 `SCRIPT ERROR`나 `ERROR:`로 시작하는 줄이 있으면 실패한다. `--out`은 `build/` 아래의 새 폴더나 빈 폴더여야 한다. Linux에서 `--capture`는 `xvfb-run -a`로 감싼다.

`--size`는 기기 픽셀이 아니라 논리 화면 크기다. 폭 기준으로 늘리므로 360×640 기기의 논리 화면은 390×693, 412×915 기기는 390×866이다. 검수 범위와 크기의 정본은 [QA 론칭 계획](../design/2026-11-21-four-alike-launch/07-qa-launch-plan.md)과 [테스트 계획](../design/2026-11-21-four-alike-launch/test-plan.json)이다.

렌더링 여정은 실제 창을 띄운다. 같은 데스크톱에서 다른 창이 초점을 가져가는 동안에는 탭 입력 하나가 빠져 실패한 적이 있다. 창이 초점을 잃으면 엔진이 누르고 있던 입력을 취소하기 때문이다(누름과 뗌 사이에 창 초점 상실 알림을 넣어 재현했다). 플레이 여정은 창이 초점을 잃을 때마다 로그에 `The window lost focus at frame N`을 남기므로, 실패한 단계 바로 앞에 이 줄이 있으면 같은 명령을 다시 실행해 확인한다. 이 줄 없이 실패하거나 반복해서 같은 단계에서 실패하면 결함으로 본다. headless 실행과 CI의 `xvfb-run`에서는 이 현상을 보지 못했다. 고치는 자리는 공통 묶음의 `e2e_driver.gd`다.

## 여정

`godot/tests/game/outgame_journey.gd`는 실제 시작 장면을 띄우고 화면 좌표 입력으로만 진행한다. 판의 상태는 읽어서 확인만 하고, 대역은 광고와 동의(`FaScriptedAds`), 시계, 분석 기록(`FaMemoryAnalytics`), 저장 경로, 그리고 OS 경계 셋(앱 끝내기, 바깥 주소 열기, 클립보드)뿐이다. 상점에서 꾸미기를 사는 단계만 제품 저장 파일에 코인을 넣고 다시 띄운다(고정 자료). 마지막 시나리오는 대역 없이 실제 어댑터(`FaLiveServices`)를 끼운 기본 구성으로 띄운다. 저장은 실행마다 새로 만든 임시 경로를 쓴다. 단계 이름의 `AC-번호`는 GDD 인수 시나리오의 조건이다. 플레이 화면을 모는 도우미는 `play_pilot.gd`에 있다.

| 시나리오 | 흐름 |
|---|---|
| `first-run-tutorial-stage-one` | 타이틀, 튜토리얼 세 단계(안내 밖 카드는 무시), 끝 카드와 시작 선물, 홈의 보상 연출, 우편함, 스테이지 1 클리어, 결과, 다음 |
| `wrong-answers` | 한 장 차이 토스트, 같은 조합 다시 내기, 그냥 오답, 다섯 번째 선택 무시 |
| `hold-undo-drag` | 임시 칸으로 옮기기, 예비 카드는 옮겨지지 않음, 되돌리기, 끌어서 옮기기, 보유한 칸 추가, 다음 판에서 다시 잠김 |
| `resume-in-english` | 힌트, 판 도중 종료 뒤 재실행, 홈의 이어 하기, 설정에서 영어로 바꾼 뒤 같은 판 |
| `result-double` | 결과 2배 광고: 떠 있는 동안 지급 없음, 끝까지 본 뒤 지급 |
| `pause-restart-home` | 일시정지의 계속, 뒤로 가기, 다시 하기와 홈으로(확인 뒤 실행) |
| `interstitial-at-level-end` | 누적 플레이 3분과 보상형 뒤 2분을 채운 판 종료에서만 전면 광고, 결과 창보다 먼저 |
| `stuck-extra-slot` | 막힘 창의 선택지, 광고로 칸 추가, 다시 막힌 뒤 닫고 판에서 되돌리기 |
| `fail-continue` | 부스터 얻기 창에서 광고 중도 닫기와 코인 구매, 실수 네 번, 광고로 이어하기, 두 번째 실패, 코인 이어하기, 코인 부족 표시 |
| `dead-end-notice` | 풀 수 없게 되는 수를 둔 뒤 막힌 길 안내와 되돌리기 강조 |
| `settings-language-support-focus` | 분석 끄기, 지원코드, 한국어 전환, 큰 글자, 키보드 초점, 큰 글자의 판, 재실행 뒤 설정 유지 |
| `replay-guide` | 설정의 안내 다시 보기: 튜토리얼 판을 다시 하고 선물은 또 받지 않음 |
| `daily-challenge` | 홈의 일일 도전 카드, 오늘의 판을 풀고 연속 기록, 결과와 결과 복사(범주 이름 없이), 이틀 뒤 놓친 날 다시 풀기(연속 기록 제외 안내) |
| `album` | 모은 범주 수, 결과 창이 보인 범주가 도감에 있음, 칸 위에서 밀어도 스크롤되고 상세가 열리지 않음, 상세(본 카드는 채움, 못 본 카드는 윤곽), 뒤로 가기는 상세부터 닫음 |
| `shop-and-decor` | 플레이 화면 코인 칩의 더하기로 상점, 힌트 사기, 코인 부족 표시와 안내, 고정 자료로 코인을 넣은 뒤 카드 뒷면과 배경 사기, 홈과 판에 적용, 기본으로 되돌리기 |
| `attendance` | 받을 것이 있으면 맥동, 일곱 칸, 받기와 보상 연출, 받은 날은 내일을 기다림, 이틀을 건너뛰어도 2일째 |
| `settings-privacy-licenses` | 개인정보처리방침, 동의 지역에서만 보이는 개인정보 선택, 제품 스위치, 오픈소스 고지 원문, 설정 변경 분석 |
| `back-to-exit` | 홈에서 뒤로 가기 한 번은 안내, 두 번이면 끝냄 |
| `outgame-english-large-text` | 영어와 큰 글자로 홈, 일일 도전, 도감, 상점, 출석, 알림함 |
| `title-error-retry` | 공통 저장을 읽지 못한 타이틀: 막대 대신 문구와 다시 시도, 저장을 고친 뒤 다시 시도하면 준비 완료 |
| `live-services-offline` | 대역 없는 기본 구성: `FaLiveServices`가 시작 장면의 자식으로 돌고, SDK가 없어 광고는 준비되지 않고 동의는 기다릴 것이 없음. 영어 타이틀 |

타이틀, 홈, 하위 화면에서는 목록 밖의 버튼이, 플레이에서는 카드와 칸과 버튼이 화면 밖으로 나가거나 서로 겹치지 않는지, 카드 높이가 84 이상인지, 카드 이름이 잘리지 않는지, 누르는 영역이 48 이상인지도 검사한다. 함수 직접 호출로 화면을 건너뛰지 않는다. 여정은 같은 화면 흐름을 되풀이해 스테이지를 넘기는 구간과 누적 플레이 3분을 채우는 구간에서만 시간을 빨리 돌린다. 캡처한 PNG는 직접 열어 글자 잘림과 겹침을 본다. PNG를 저장한 것만으로 화면 검수가 끝나지 않는다.

`godot/tests/game/play_capture.gd`는 여정이 아니라 시안 비교용 캡처 도구다. 저장 파일을 미리 만들어 기준 그림과 같은 판에서 시작하고(고정 자료), 네 화면 크기와 모든 배치, 상태 시트, 연출의 중간 프레임, 일일 도전 모드를 찍는다. `tools/check.py`는 이 스크립트를 돌리지 않는다. 쓰는 법과 비교 기록은 [플레이 화면 비교 기록](../game-design/ui/play-review.md)에 있다.

`godot/tests/game/store_capture.gd`도 여정이 아니라 Google Play 스크린숏의 원본 화면을 찍는 도구다. 실제 유스케이스로 판을 풀어 스테이지 30과 일일 도전 9일 연속의 진행 기록을 만든 뒤, 시작 장면을 띄워 탭으로 여섯 상태를 만들고 3배로 찍는다. `tools/store/build_screenshots.py`가 이 스크립트를 돌리고 문구를 얹는다. 렌더링이 필요하므로 `npm test`는 완성된 스크린숏의 수, 크기, 용량만 본다. 다시 만드는 방법은 [Google Play](../05-markets/google-play.md)의 "스토어 등록정보"에 있다.

플레이 화면의 배치 계산과 카드 이름 맞춤은 `fa_play_layout_probe.gd`가, 튜토리얼 판이 안내 순서대로 풀리는지는 `fa_tutorial_probe.gd`와 `tools/levels/verify_packs.py`가 본다.

서비스 어댑터(광고와 동의, 분석, 원격 설정)의 프로브는 SDK, HTTP, 파일, 시계를 메모리 안의 대역으로 바꿔 끼우고 네트워크 없이 돈다. `fa_admob_sdk_probe.gd`는 AdMob 플러그인의 GDScript 층까지 실제 그대로 쓰고 Android에만 있는 네이티브 싱글턴만 대역으로 바꾼다. 이 프로브는 플러그인의 클래스 이름을 풀어 줄 가져오기 캐시가 있어야 돈다. 새 복제본에서 `npm run test:core`로 바로 돌리면 실행하지 못했다고 알리고 실패하므로 `godot --headless --path godot --import`를 먼저 실행한다. `npm test`는 가져오기를 먼저 한다. 무엇을 확인하는지는 [서비스 어댑터](../03-architecture/service-adapters.md)의 "검수"에 있다.

`core`의 규칙, 해법 탐색, 생성기, 경제, 광고 정책은 요구사항 때문에 실패하는 프로브를 먼저 쓰고 구현한다. `godot/tests/game`에 `*_probe.gd`로 두면 `tools/check.py`가 자동으로 실행한다.

## 기능을 더하거나 뺄 때

1. `docs/qa/feature-inventory.json`의 `features`에 항목을 넣는다. `paths`는 그 기능의 실제 파일을 가리키는 glob이고, 네이티브 SDK를 직접 부르는 파일은 `platformPaths`에도 적는다. 어느 파일과도 맞지 않는 glob은 `npm test`에서 실패한다.
2. 여정의 시나리오에 그 기능 ID를 적고 실제 화면 입력으로 확인한다. `core: true`인 기능이 통과한 시나리오에 없으면 `tools/check.py`가 `missing feature journeys`로 실패한다.
3. `godot/data/outgame/outgame-profile.json`을 지금 상태대로 고친다. 서비스에 어댑터를 붙이면 `services`의 `status`를 `local`이나 `wired`로, `binding`을 실제 파일로 바꾼다. `ads`나 `payments`를 `exposed: true`로 두려면 `bmProfile`에 수익화 프로필 파일이 있어야 한다. 선택 기능은 `optional`의 `enabled`와 `reason`으로 적는다.
4. 제품이 새로 쓰는 스킨, 글꼴, 장면은 `uiStandard.resources`에 넣는다.

프로필의 `optional`에서 출석(attendance), 일일 도전(events), 코인 상점(shop)을 켰다. 기능 목록의 `title_home`, `daily_challenge`, `album`, `shop`, `attendance`가 이 화면들이고 여정이 덮는다.

## 출시

출시 단계의 검사와 기록은 [출시 체크리스트](../06-release/release-checklist.md)를 따른다.
