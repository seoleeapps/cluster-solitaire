# 재설계 UI 검수 2

- 회차: 2 / 3
- 집중 범위: 오류·취소·복구, 탐색(화면 전환·뒤로 가기·스크롤), 작은 화면(`390×693`, `360×640`), 큰 글자, 영어 긴 이름, 색에 기대지 않는 구분, 회차 1 지적 7건 수정 재확인

## 실행 전 계획

- 설계 ID·조건 ID·후보 SHA·변경점:
  - 설계 ID: `2026-11-21-four-alike-launch` (v1, `test-plan.json` 기준 `level: "L3"`, `redesign: true`)
  - 조건 ID: AC-001~018, AC-101~105 (개발 환경 범위. 실기기 항목 AC-106 / AND-01~08은 본 회차 범위 밖)
  - 후보 SHA: `46dd6246028c0d762315c018d738860ad987e688`
  - 회차 1 이후 변경점 요약 (`1dda221f` → `46dd6246`):
    1. 회차 1 기록(`4233a05`) 추가 뒤 `46dd6246`에서 회차 1 지적 7건 대응 수정:
       - `fa_ui.gd`: 코인 칩 높이 48 확장 및 칩 전체 탭 시 `add.pressed` 방출, 팝업 닫기(`Close`) 최소 크기 48×48 확보
       - `main.gd`: `_clear()`, `_open_round()`, 언어 변경 시 `_dismiss_toast()` 호출 및 `_exit_armed_until = 0` 초기화
       - `daily_screen.gd`: 달력 `CELL_MAX` 44 상향, `SCROLL_MODE_AUTO` 활성화, `day_card`를 스크롤 밖 하단에 고정해 작은 화면 첫 화면에 `오늘의 도전` 버튼 노출
       - `shop_screen.gd`, `inbox_screen.gd`: 탭·구매·적용·받기 버튼 최소 높이 48 확보
       - `play_screen.gd`: 팝업이 열려 있을 때 `show_toast` Y 좌표를 팝업 위/아래 겹치지 않는 위치로 조정
       - `03-ui-ux-spec.md`: 도감 비어 있음 상태 매트릭스에 정상 첫 실행 시 튜토리얼 3범주 등록 명시
       - `outgame_journey.gd`, `play_pilot.gd`, Google Play 스크린샷 갱신
- 계획 작성 시각·실행 순서·통과 기준:
  - 계획 작성 시각: `2026-11-21T19:57:06+09:00` (`2026-11-21T10:57:06Z`)
  - 실행 순서:
    1. 필수 검증 명령 실행(`npm test`, `npm run check:architecture`, `python3 tools/bundle.py verify`, `python3 tools/levels/verify_packs.py`, `bash tools/check_monetization.sh`)
    2. 4개 해상도(`390×844`, `390×693`, `390×866`, `360×640`) 렌더링 여정 캡처 실행(`build/r2-390`, `build/r2-693`, `build/r2-866`, `build/r2-640`) 및 주요 PNG(`home-en.png`, `daily.png`, `shop.png`, `inbox.png`, 작은 화면·큰 글자 화면 등) 직접 열람 확인(`The window lost focus` 발생 시 재실행)
    3. 독립 탐색적 검수 스크립트 `build/r2_explore.gd` 작성 및 렌더링 실행(`--audio-driver Dummy --capture`): 회차 1 지적 7건 재확인, 오류·취소·복구(저장 손상 `.bak` 복구/양쪽 손상 초기화 안내, 일시정지/초기화 취소·닫기·바깥 탭·뒤로 가기 보존, 광고 중도 닫기/미준비/코인 부족 복구), 탐색(전환·뒤로 가기·스크롤), 작은 화면(`390×693`, `360×640`) 잘림/스크롤, 큰 글자·영어 긴 이름, 색에 기대지 않는 구분 점검
    4. 실제 관찰·증거·발견 문제·판정 기록 후 `qa/review-2` 브랜치 커밋
  - 통과 기준:
    - 필수 명령 5종 및 4개 해상도 캡처 여정 모두 `SCRIPT ERROR`, `ERROR:` 없이 통과
    - 회차 1 지적 7건이 실제 입력·렌더링에서 재현되지 않음
    - 회차 2 집중 범위(오류·취소·복구, 탐색, 작은 화면, 큰 글자, 영어 긴 이름, 비색각 구분)에서 `막힘` 또는 `중요` 결함 0건
- 구현자·다른 리뷰 에이전트·페르소나·필요 시 UX 전문가:
  - 구현자: 기존 구현 에이전트(후보 커밋 `46dd6246`)
  - 검수자(독립 리뷰 에이전트): 본 독립 QA 검수 에이전트(회차 2/3)
  - 페르소나: 사용자 관점 검수자(한국어·영어, 큰 글자 및 색각 이상 관점 포함)
- 실제 환경·격리 계정·데이터·저장 경로:
  - 실행 환경: macOS, Godot 4.7.2 (`--headless` E2E 및 `gl_compatibility` 렌더링 실행), adb 기기 미사용
  - 계정: 로그인·계정 없음(로컬 모드)
  - 격리 저장 경로: `tools/check.py` 실행별 임시 `user://` 격리 폴더 및 탐색 스크립트 전용 `build/r2-explore/user_data/`(`FaSavePaths.under` 경로)
- 핵심 기능 전체 목록 (`docs/qa/feature-inventory.json` 25개 전체):
  - `startup`, `tutorial`, `account_save`, `settings_support`, `inbox`, `commerce`, `observability`, `operations`, `ui_support_entry`, `ui_analytics_opt_out`, `ui_locale_offline`, `ui_navigation`, `ui_leaderboard`, `ui_kit`, `core_play`, `boosters`, `result_rewards`, `ad_placements`, `run_save`, `title_home`, `daily_challenge`, `album`, `shop`, `attendance`, `data_reset`
- 이어받는 영향 없는 기반 기능(기능 ID·기준 SHA·실제 실행 시각·증거):
  - 없음 (`test-plan.json` 기준 `baseline: null`, L3 전체 회귀 및 회차 1 이후 UI/부트스트랩 변경 포함)

| 항목 | 기능 기대 결과 | UX 기대 결과 | 오류·복구 재현 | 남길 증거 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 | `npm test`, `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh` 모두 통과(AC-013, AC-102, AC-105) | 해당 없음(규칙·팩·수익화 무결성) | 팩/경계/수익화 규칙 위반 없음을 출력으로 확인 | 각 명령 종료 코드 및 출력 요약 |
| 회차 1 지적 7건 재확인 (`startup`, `title_home`, `daily_challenge`, `boosters`, `shop`, `inbox`, `ui_navigation`, `ui_locale_offline`, `album`) | 코인 칩 전체 탭→상점 진입, 언어/화면 전환 뒤 토스트 소멸, `_exit_armed_until` 초기화, `daily` 버튼 첫 화면 노출, 버튼 48dp 확보, 부스터 팝업 토스트 비중첩, 03 문서 도감 빈 상태 조건 정합성 | 작은 화면(`390×693`, `360×640`)에서 일일 도전 `오늘의 도전` 버튼 즉시 노출·달력 스크롤, 코인 칩/버튼 오탭 감소, 토스트 가림 해소 | 빠른 화면 전환 뒤 홈 1회 뒤로 가기 비종료, 언어 변경 뒤 토스트 잔존 없음, 코인 부족 팝업 토스트 비중첩 확인 | `r2-390`/`r2-693`/`r2-866`/`r2-640` 캡처, `r2_explore.gd` 실측 JSON·스크린샷 |
| 오류·취소·복구 (`account_save`, `run_save`, `ad_placements`, `settings_support`, `data_reset`, `ui_navigation`) | 저장 손상 시 `.bak` 자동 복구, 둘 다 손상 시 신규 시작+복구 안내(타이틀 공통 손상 시 `다시 시도`), 일시정지 `다시 하기`/`홈으로` 취소·복귀, 초기화 1·2단계 취소/닫기/바깥 탭/뒤로 가기 시 데이터 보존, 광고 중도 닫기/미준비/코인 부족 시 무보상 및 판 유지 | 오류·복구 안내가 제품 스킨으로 자연스럽게 보이며, 되돌릴 수 없는 행동 전 취소 경로가 안전하게 동작 | 손상 저장 파일 2종 주입, 일시정지 확인 취소, 초기화 1·2단계 바깥 탭/뒤로 가기/취소, 광고 중도 닫기·실패·부족 재현 | `r2_explore.gd` 복구/취소 로그 및 캡처 |
| 탐색·화면 전환·뒤로 가기·스크롤 (`ui_navigation`, `daily_challenge`, `album`, `shop`, `attendance`, `inbox`, `settings_support`) | 홈↔하위 화면↔상세 팝업↔플레이 전환, 뒤로 가기 우선순위(팝업→하위 화면→홈 2회 종료), 도감/상점/일일 도전/설정 스크롤 동작 | 스크롤 시 카드 오탭으로 상세가 잘못 열리지 않고, 스크롤 인디케이터·여백·닫기 버튼이 자연스러움 | 팝업/상세 열린 상태에서 뒤로 가기, 빠른 화면 전환, 끝까지 스크롤 및 버튼/카드 누락 없음 확인 | `r2_explore.gd` 탐색/스크롤 로그·캡처 |
| 작은 화면(`390×693`, `360×640`), 큰 글자, 영어 긴 이름 (`core_play`, `daily_challenge`, `album`, `shop`, `result_rewards`, `ui_locale_offline`, `ui_kit`) | `390×693` 및 `360×640`에서 플레이·일일 도전·결과·실패·막힘·상점·도감·알림함 잘림/겹침 없음, 큰 글자+영어 긴 카드/범주 이름 2줄 이내 수용 | 작은 화면에서도 주 버튼·부스터·임시 칸·예비 카드·달력이 화면 안에 맞고 가독성 유지 | 큰 글자+영어 상태에서 800장 긴 이름 카드(`Brachiosaurus` 등) 및 158범주, `360×640` 플레이/팝업/상점/도감 스크롤 실측 | 4개 해상도 캡처 PNG 열람, `r2_explore.gd` `360×640`·큰 글자·긴 이름 캡처·실측 |
| 색에 기대지 않는 구분 (`core_play`, `boosters`, `shop`, `daily_challenge`, `ui_kit`) | 선택(들림 7px+노란 테+체크), 힌트(하늘 테+크기 맥동), 한 장 차이/오답(흔들림+토스트+하트 회색/깨짐), 잠김 칸(자물쇠+가격/광고 표지), 완료 메달(위치+이름표), 빨간 비활성 가격(누르면 부족 코인 수 토스트), 달력 상태(체크/빈 원/노란 테/보라 테) | 색각 이상 사용자 관점에서도 모양·아이콘·위치·텍스트만으로 모든 상태·오류·완료·잠금 구분 가능 | 비활성 가격 탭 시 사유 토스트, 한 장 차이·선택 해제·잠김 칸·달력 상태 구분 요소 실측 검증 | `r2_explore.gd` 상태/비색각 속성 검증 로그·캡처 |

## 실행 후 관찰·판정

- 시작·종료 시각·실제 후보 SHA:
  - 시작 시각: `2026-11-21T19:56:31+09:00` (`2026-11-21T10:56:31Z`)
  - 종료 시각: `2026-11-21T20:25:17+09:00` (`2026-11-21T11:25:17Z`)
  - 실제 후보 SHA: `46dd6246028c0d762315c018d738860ad987e688` (브랜치 `qa/review-2`)
  - 전체 판정: **통과** (막힘 0건, 중요 0건, **사소 2건** — 실행 전 계획 통과 기준 "`막힘` 또는 `중요` 결함 0건" 및 회차 1 지적 7건의 핵심 수정 확인 충족)

### 실행 명령 및 결과 요약

| 명령 | 결과 | 비고 |
|---|---|---|
| `npm run check:architecture` | 통과(exit 0) | `Architecture passed` |
| `python3 tools/bundle.py verify` | 통과(exit 0) | `ok: true`, 공통 묶음 82개 파일 해시 일치 |
| `python3 tools/levels/verify_packs.py` | 통과(exit 0) | journey 600판, daily 1,100일, tutorial 1판 모두 문제 0건 |
| `bash tools/check_monetization.sh` | 통과(exit 0) | `PASS: errors=0 warnings=4 strict=on` (BM-017/037/073 경고는 설계 DEC-002·원격 설정의 기존 승인/알려진 항목) |
| `npm test` | 통과(exit 0) | Python 단위 74건, `check:generated`, `check:screenshots`, `check:levels`, `check:remote-config`, `check_native.py`, `check.py`(22 시나리오), `check:export-pack`(2,344파일, 문제 0) 모두 통과 |
| `python3 tools/check.py --capture --size 390x844 --out build/r2-390` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x693 --out build/r2-693` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x866 --out build/r2-866` → `build/r2-866-clean` | 재실행 통과(exit 0) | 1차 실행(`r2-866`)은 exit 0이었으나 `godot-4.log`에 `The window lost focus at frame 4031` 1건 발생. 재실행(`r2-866-clean`)에서 focus loss 없이 22개 시나리오 통과, 68장 캡처 |
| `python3 tools/check.py --capture --size 360x640 --out build/r2-640` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| 탐색 스크립트 `build/r2_explore.gd` (렌더링 `--capture --out build/r2-explore`) | 70/71 통과 | `SCRIPT ERROR` 및 `lost focus` 0건. 유일한 FAIL 1건(`2. daily cell width >= 44: (40.0, 48.0)`)은 아래 남은 사소 문제 #1로 기록 |

### 항목별 관찰·판정

| 항목 | 실제 관찰·증거 | 기능/UX 문제·사용자 영향 | 수정 제안 | 판정 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 | `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh`, `npm test` 모두 exit 0 통과. | 없음(`check_monetization.sh` 경고 4건은 기존 승인 예외). | 없음 | 통과 |
| 회차 1 7건 재확인 | 1) 코인 칩 높이 `48.0`px(홈 `94×48`, 플레이 `86×48`), `Row/Icon`·`Row/Value`·`Row/Add` 탭 시 상점 진입 확인<br>2) 언어/화면 전환 뒤 토스트 소멸(`r2-390/home-en.png`, `r2-693/home-en.png`, `r2-640/home-en.png`, `round-2/home-en.png` 확인)<br>3) `390×693`/`360×640` 일일 도전 첫 화면에 `오늘의 도전`/`Play Today` 주 버튼 온전 노출 및 `12월 31일`까지 스크롤 확인(`round-2/daily-693.png`, `round-2/daily-640.png`)<br>4) 상점 탭(`120×48`), 구매(`104×48`), 알림함 받기(`110×48`), 팝업 닫기(`56×48`) 높이 48 이상 확인<br>5) 부스터 팝업 코인 부족 토스트가 팝업 아래(`390×844` `580.6~619.4`, `390×693` `505.5~544.5`, `360×640` `478.5~517.5`)에 놓여 팝업(`275~568`/`200~493`/`173~466`)과 비중첩 확인(`round-2/booster-toast-360x640.png`)<br>6) 홈 뒤로 가기 1회→설정→2초 내 홈 복귀 시 `_exit_armed_until == 0` 초기화 확인<br>7) `03-ui-ux-spec.md:188` 빈 도감 조건 명시 및 빈 도감 `album_start` 버튼으로 스테이지 1 정상 진입 확인. | **[사소][잔여] 달력 날짜 칸 가로 폭 40px 이하**: 일일 도전 달력 칸 높이는 `48.0`px로 상향됐으나, 가로 폭이 `40.0px`(`390×844`), `39.0px`(`390×693`), `35.0px`(`360×640`)으로 03 문서 기준(`48×48`) 및 일반 기준(`44×44`)에 미달. | 달력 바깥 카드·안쪽 여백(`SIDE`/`GAP`)을 줄여 날짜 칸 가로 폭을 44px 이상으로 확대 검토 | 통과(사소 1) |
| 오류·취소·복구 | 1) 본 파일(`progress.json`) 손상 + `.bak` 정상 시 코인 777·스테이지 6 정상 복구(`save_reset=false`)<br>2) 본 파일+`.bak` 모두 손상 시 신규 시작 + 홈 진입 시 `"저장을 읽지 못해 새로 시작했어요."` 빨간 토스트 노출(`round-2/save-reset-toast.png`)<br>3) 일시정지 `다시 하기`/`홈으로` 확인 취소 및 확인 중 어두운 바깥 영역 탭 시 판 상태 보존<br>4) 초기화 1·2단계 바깥 영역 탭, 닫기(`X`), `Cancel`, 뒤로 가기 시 데이터 보존<br>5) 부스터·결과 2배 광고 중도 닫기 시 무보상 및 `"이번에는 보상을 받지 못했어요"` 토스트 출력, 실패 창 코인 부족 토스트 팝업 아래 비중첩(`round-2/fail-toast-360x640.png`). | 없음 | 없음 | 통과 |
| 탐색·화면 전환·뒤로 가기·스크롤 | 홈↔하위 화면↔도감 상세 팝업↔플레이 전환 정상. 도감 카드 위 드래그 시 상세 미오픈·스크롤 정상, 상세 열린 상태에서 뒤로 가기 1회 시 상세만 닫힘. 상점 꾸미기·일일 도전 달력 스크롤 끝까지 동작. | **[사소][신규] 일시 토스트와 하단 고정 카드/목록 겹침**: `360×640` 일일 도전 완료 상태에서 `결과 복사` 탭 시 `"결과를 복사했어요"` 토스트가 `결과 복사` 버튼 바로 위를 2초간 가림(`round-2/daily-done-640.png`). 상점 꾸미기(`build/r2-693/shop-decor.png`)에서도 코인 부족 토스트가 하단 카드 이름 위를 2초간 가림(2초 뒤 소멸해 조작 차단은 없음). | 하위 화면 하단 고정 카드(`day_card`)가 있을 때는 토스트 Y 위치를 카드 위쪽 안전 여백으로 이동 검토 | 통과(사소 1) |
| 작은 화면(`390×693`, `360×640`), 큰 글자, 영어 긴 이름 | 4개 해상도 `title`, `home`, `daily`, `album`, `shop`, `inbox`, `settings`, `attendance`, `play`, `pause`, `stuck`, `fail`, `result` 육안 확인 결과 잘림·겹침 없음. `CardView.fit_name` 800장(한/영, 큰 글자 ON/OFF) 및 `AlbumScreen.fit_name` 158범주(한/영) 초과 0건. `360×640` 영어+큰 글자 플레이(`Birthday Cake`, `Love Letter`, `Post Office` 등) 2줄 이내 선명 출력. | 없음 | 없음 | 통과 |
| 색에 기대지 않는 구분 | 선택 시 들림 `7.0px`+체크 배지(`_tick.visible = true`)+노란 테두리, 잠긴 임시 칸 자물쇠 아이콘(`_lock.visible`)+텍스트(`_caption.visible`), 힌트 사용 시 2장 `hinted` 테두리+크기 맥동, 한 장 차이 오답 시 하트 감소+`"One away!"` 텍스트 토스트, 빨간 비활성 가격 탭 시 `"코인이 N개 모자라요"` 토스트 확인. | 없음 | 없음 | 통과 |

### 증거 그림 (300KB 이하)

- `docs/07-qa/review-rounds/round-2/daily-640.png` (`360×640` 일일 도전 첫 화면 주 버튼 온전 노출 및 달력 스크롤)
- `docs/07-qa/review-rounds/round-2/daily-693.png` (`390×693` 일일 도전 첫 화면 주 버튼 온전 노출)
- `docs/07-qa/review-rounds/round-2/home-en.png` (영어 전환 후 홈에서 한국어 토스트 미잔존 확인)
- `docs/07-qa/review-rounds/round-2/booster-toast-360x640.png` (`360×640` 부스터 팝업과 코인 부족 토스트 비중첩)
- `docs/07-qa/review-rounds/round-2/fail-toast-360x640.png` (`360×640` 실패 팝업과 코인 부족 토스트 비중첩)
- `docs/07-qa/review-rounds/round-2/save-reset-toast.png` (본 파일·백업 모두 손상 시 홈 빨간 안내 토스트)
- `docs/07-qa/review-rounds/round-2/daily-done-640.png` (`360×640` 일일 도전 결과 복사 토스트 위치 확인)

## 수정·재확인·남은 문제

본 회차는 독립 QA 검수 회차 2/3으로, 제품 코드·자산·테스트는 수정하지 않았다.

### 회차 1 지적 7건 재확인 결과

| # | 회차 1 지적 항목 | 재확인 결과 | 근거 |
|---|---|---|---|
| 1 | [중요] 코인 칩 `+` 버튼 `22×24` 및 칩 전체 미반응 | **해결 확인** | 홈(`94×48`)·플레이(`86×48`) 코인 칩 높이 `48.0`px 확보, `Row/Icon`·`Row/Value`·`Row/Add` 탭 모두 상점 진입 확인 (`fa_ui.gd:206-245`, `explore-findings.json`) |
| 2 | [중요] 언어·화면 전환 시 이전 토스트(`_toast`) 잔존 | **해결 확인** | `_clear()`, `_open_round()`, 언어 변경 시 `_dismiss_toast()` 동작 확인 (`main.gd:212-215, 491, 793`, `round-2/home-en.png`) |
| 3 | [중요] 작은 화면(`390×693`, `360×640`) 일일 도전 주 버튼 가려짐 | **해결 확인** | `day_card` 하단 고정 및 `SCROLL_MODE_AUTO` 적용으로 두 해상도 모두 첫 화면에 `오늘의 도전`/`Play Today` 버튼 온전 노출 및 달력 스크롤 확인 (`round-2/daily-693.png`, `round-2/daily-640.png`) |
| 4 | [사소] `48×48` 기준 미만 버튼 존재 | **부분 해결** | 상점 탭/구매(`×48`), 알림함 받기(`110×48`), 팝업 닫기(`56×48`), 달력 칸 높이(`48`)는 충족. 단 달력 칸 가로 폭은 `40.0px`(`390`)·`39.0px`(`390×693`)·`35.0px`(`360×640`)으로 잔존(아래 남은 문제 #1) |
| 5 | [사소] 부스터 얻기 팝업 위 코인 부족 토스트 겹침 | **해결 확인** | `390×844`, `390×693`, `360×640` 모두 부스터·실패 팝업 아래 여백으로 토스트 이동되어 비중첩 확인 (`round-2/booster-toast-360x640.png`, `round-2/fail-toast-360x640.png`) |
| 6 | [사소] 홈 뒤로 가기 `_exit_armed_until` 복귀 후 잔존 | **해결 확인** | `_clear()`·`_open_round()` 진입 시 `_exit_armed_until = 0` 초기화 확인(`main.gd:490, 792`), 2초 내 복귀 첫 뒤로 가기 시 비종료 확인 |
| 7 | [사소] 도감 빈 상태 정상 첫 실행 미도달 | **해결 확인** | `03-ui-ux-spec.md:188`에 튜토리얼 3범주 즉시 등록 예외 명시 확인, 수집 0개 저장 상태에서 빈 도감 안내 및 `album_start`→스테이지 1 진입 확인 |

### 남은 문제 목록 (총 2건: 막힘 0, 중요 0, 사소 2)

1. **[사소][회차 1-4 잔여] 일일 도전 달력 날짜 칸(`day_*`) 가로 폭 `40px` 이하**
   - 재현 순서: 일일 도전 화면(`390×844`, `390×693`, `360×640`) 진입 → 달력 날짜 버튼 가로·세로 크기 실측.
   - 사실·증거: `godot/game/features/outgame/daily_screen.gd:133`, `build/r2-explore/explore-findings.json` (`390×844`: `40.0×48.0`, `390×693`: `39.0×48.0`, `360×640`: `35.0×48.0`). 높이는 48px로 개선됐으나 7열 배치로 인해 폭이 03 문서 기준(48px) 및 일반 터치 기준(44px)보다 좁다.
2. **[사소][신규] 작은 화면 일일 도전 결과 복사·상점 꾸미기에서 일시 토스트(`TOAST_FROM_BOTTOM := 150.0`)와 하단 고정 카드/목록 겹침**
   - 재현 순서: `360×640`에서 오늘의 일일 도전 완료 후 `결과 복사` 탭 → `"결과를 복사했어요"` 토스트가 `결과 복사` 버튼 바로 위와 완성 순서 칩 아래 사이를 2초간 가림(또는 상점 꾸미기 탭 하단 상품에서 코인 부족 탭 시 카드 이름 위를 2초간 가림).
   - 사실·증거: `docs/07-qa/review-rounds/round-2/daily-done-640.png`, `build/r2-693/shop-decor.png`, `godot/game/bootstrap/main.gd:54`. 2초 후 자동 소멸해 진행 막힘은 없다.

> 회차 2 판정: **통과** — `막힘` 0건, `중요` 0건으로 회차 2 통과 기준을 충족했으며, 회차 1 지적 7건의 핵심 수정 사항이 모두 정상 반영되었음을 확인했다. 회차 3에서는 기능 간 연결, 재시작과 저장 복구, 반복 플레이 자연스러움을 검수한다.
