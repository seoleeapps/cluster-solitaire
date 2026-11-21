# 재설계 UI 검수 1

- 회차: 1 / 3
- 집중 범위: 인수조건(AC-001~013), 입력·상태·결과, 처음 보는 사람의 규칙 이해

## 실행 전 계획

- 설계 ID·조건 ID·후보 SHA·변경점:
  - 설계 ID: `2026-11-21-four-alike-launch` (v1, `test-plan.json` 기준 `level: "L3"`, `redesign: true`)
  - 조건 ID: AC-001~018, AC-101~105 (개발 환경 범위. 실기기 항목 AC-106 / AND-01~08은 본 회차 범위 밖)
  - 후보 SHA: `1dda221f41885e92214f527d442d3057c8a8dae2`
  - 변경점: Four Alike / 끼리끼리 첫 출시 전체 구현(순수 코어 규칙·해법 탐색·팩 600판 및 일일 도전 1,100일, 캔디 팝 UI 플레이 및 바깥 화면 15종, 부스터 3종·경제·도감·상점·출석·일일 도전, 광고·동의·GA4·원격 설정 어댑터, 데이터 초기화, Google Play 스크린샷 갱신 포함)
- 계획 작성 시각·실행 순서·통과 기준:
  - 계획 작성 시각: `2026-11-21T16:14:00+09:00` (`2026-11-21T07:14:00Z`)
  - 실행 순서:
    1. 정적·구조·팩·수익화 검증 명령 실행(`npm test`, `npm run check:architecture`, `python3 tools/bundle.py verify`, `python3 tools/levels/verify_packs.py`, `bash tools/check_monetization.sh`)
    2. 4개 해상도(`390x844`, `390x693`, `390x866`, `360x640`) 렌더링 여정 캡처 실행 및 주요 PNG 직접 열람 확인(`The window lost focus` 발생 시 재실행)
    3. `build/` 아래 독립 탐색적 검수 스크립트 작성·실행(첫 실행~스테이지 3 실제 플레이, 실수 4회 실패→이어하기→다시하기, 부스터 0개 얻기·코인 부족, 일일 도전 완료 후 재진입, 언어 전환 전 화면 순회, 큰 글자·움직임 줄이기, 앱 백그라운드·복귀, 뒤로 가기 연타, 데이터 초기화, 03 문서 화면 계약·터치 영역 48/44dp·빈/오류 상태 스킨 확인)
    4. 실제 관찰·증거·발견 문제·판정 기록 및 `qa/review-1` 커밋
  - 통과 기준:
    - 모든 필수 정적·여정·팩·수익화 명령 오류 없이 통과(`SCRIPT ERROR`, `ERROR:` 0건)
    - 회차 1 집중 범위(AC-001~013, 입력·상태·결과, 처음 보는 사람의 규칙 이해) 및 03 문서 화면 계약에서 `막힘` 또는 `중요` 결함 0건
    - 4개 해상도 및 한국어·영어 전 화면에서 글자 잘림·겹침·오번역·언어 혼용·터치 영역 기준 미달 없음
- 구현자·다른 리뷰 에이전트·페르소나·필요 시 UX 전문가:
  - 구현자: 기존 구현 에이전트(후보 커밋 `1dda221f`까지 구현)
  - 검수자(독립 리뷰 에이전트): 본 독립 QA 검수 에이전트 (회차 1/3)
  - 페르소나: 요구사항 검수자, 처음 하는 캐주얼 퍼즐 이용자(한국어·영어)
- 실제 환경·격리 계정·데이터·저장 경로:
  - 실행 환경: macOS, Godot 4.7.2 (`--headless` E2E 및 `gl_compatibility` 렌더링 실행), adb 기기 미사용
  - 계정: 로그인·계정 없음(로컬 모드)
  - 격리 저장 경로: `tools/check.py` 실행마다 생성되는 임시 `user://` 격리 폴더 및 탐색 스크립트 전용 `build/r1-explore/user_data/`(`FaSavePaths.under` 경로, 실제 앱 `user://` 미사용)
- 핵심 기능 전체 목록 (`docs/qa/feature-inventory.json` 25개 전체):
  - `startup`, `tutorial`, `account_save`, `settings_support`, `inbox`, `commerce`, `observability`, `operations`, `ui_support_entry`, `ui_analytics_opt_out`, `ui_locale_offline`, `ui_navigation`, `ui_leaderboard`, `ui_kit`, `core_play`, `boosters`, `result_rewards`, `ad_placements`, `run_save`, `title_home`, `daily_challenge`, `album`, `shop`, `attendance`, `data_reset`
- 이어받는 영향 없는 기반 기능(기능 ID·기준 SHA·실제 실행 시각·증거):
  - 없음 (`test-plan.json` 기준 `baseline: null`, 첫 출시 L3 전체 회귀)

| 항목 | 기능 기대 결과 | UX 기대 결과 | 오류·복구 재현 | 남길 증거 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 | `npm test`, `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh` 모두 통과(AC-013, AC-102, AC-105) | 해당 없음(내부 품질·규칙 무결성) | 팩 변조/경계 위반이 없음을 검증 출력으로 확인 | 각 명령 종료 코드 및 출력 요약 |
| `startup`, `title_home` (SCR-001, SCR-002) | 실제 3단계 준비 후 `시작하기`, 홈에서 다음 스테이지 번호·등급·별·일일 도전·출석·알림함 상태 표시 | 시선 순서(로고→카드 4장→진행 막대→시작), 첫 진입 시 바로 할 일 파악 가능 | 손상/미읽음 상태 오류 문구 및 `다시 시도` 스킨 적용, 복구 후 정상 진행 | `r1-390`/`r1-693`/`r1-866`/`r1-640` 캡처 및 탐색 로그 |
| `tutorial` (SCR-012, AC-015) | `intro` 3단계 완료 후 실수 규칙 안내 및 시작 선물 1회만 지급 | 처음 보는 사람이 손가락·말풍선만으로 선택·임시 칸·묶기를 즉시 이해 | 안내 밖 카드 탭 무시 확인, 재실행·다시 보기 시 중복 보상 없음 | 탐색 플레이(첫 실행→튜토리얼→스테이지 1~3) 로그·캡처 |
| `core_play` 묶기·오답·임시 칸 (SCR-003, AC-001~005) | 같은 범주 4장 묶기→범주 띠, 3장 일치→"한 장만 달라요"+실수1, 동일 오답 재시도→실수 유지, 열 앞 카드 임시 칸 이동·드래그, 예비/임시 칸 이동 불가 | 선택 시 들림+테두리+체크(비색각 구분), 5번째 선택 흔들림, 48dp 이상 터치 영역, 카드 글자 2줄 이내 잘림 없음 | 잘못된 이동·5번째 선택·중복 오답 시 상태 손상 없이 안내만 표시 | 프로브·여정·탐색 플레이 캡처 및 좌표/크기 검증 로그 |
| `core_play`, `result_rewards`, `ad_placements` 실패·막힘·결과·전면/보상형 (SCR-005~007, AC-006~008, AC-016~017) | 클리어 시 실수별 별(3/2/1)·코인, 조건 충족 시만 결과 앞 전면 광고, 실수 4회 실패→광고/코인 150 이어하기(1회)→2차 실패 다시하기, 막힘 팝업 | 결과 시선(별→코인→새 범주→다음), 실패 창 남은 정답 표시, 광고 2배·이어하기·다시하기 버튼 크기/위계 명확 | 광고 미준비/중도 닫기/코인 부족 시 무보상 및 대체 경로·토스트 안내 | 탐색 스크립트 실패→이어하기→다시하기·결과 캡처·로그 |
| `boosters` 힌트·되돌리기·칸 추가 (SCR-003, SCR-013, AC-009~011) | 힌트 2장 강조(짝 없으면 옮길 열), 되돌리기 마지막 이동 복원+카드 뒤집힘, 칸 추가 3번째 칸 해금(해당 판 한정) | 0개일 때 `+` 표시 및 부스터 얻기 창(코인 vs 광고 동일 크기), 스테이지 3/6/8 자연스러운 학습 | 부스터 0개 + 광고 없음 + 코인 부족 시 사유 및 부족 코인 안내 후 판 유지 | 탐색 스크립트 부스터 0개·코인 부족 캡처·로그 |
| `run_save`, `account_save`, `ui_navigation` (SCR-004, AC-012) | 판 도중 종료/백그라운드 복귀 시 카드·실수·완성 묶음·부스터 복원, 뒤로 가기 팝업→하위→홈(2회 종료) | 일시정지 확인 문구, 뒤로 가기 연타 시 오동작/화면 깨짐 없음 | 저장 파일 손상 시 `.bak` 복구 또는 초기화 안내 | 탐색 스크립트 백그라운드·복귀, 뒤로 가기 연타 로그·캡처 |
| `daily_challenge` (SCR-008, AC-014) | 날짜별 동일 판, 부스터·이어하기 비활성, 완료 시 연속 기록+결과 공유 텍스트(범주명 비공개), 지난 날 재도전 연속 기록 미반영 | 달력 체크/빈 원/오늘 강조 직관적, 규칙 한 줄(`부스터 없이 풉니다`) 명확 | 완료 후 재진입 시 결과 카드·공유 버튼 유지, 팩 범위 밖 날짜 순환 | 여정·탐색 스크립트 일일 도전 완료 후 재진입 캡처·로그 |
| `album`, `shop`, `attendance`, `inbox` (SCR-009~011, SCR-015) | 도감 대분류 4열·상세·10개 보상, 상점 부스터·꾸미기 구매/적용, 출석 7일 이어받기, 우편 보상 흡수 | 빈 도감("아직 모은 범주가 없어요"+시작 버튼), 상점 코인 부족 빨간 가격+토스트, 알림함 제품 문구 | 코인 부족 구매 차단, 이미 받은 출석·우편 중복 수령 차단 | 네 해상도 캡처 및 탐색 스크립트 스킨·빈 상태 확인 |
| `settings_support`, `ui_locale_offline`, `ui_analytics_opt_out`, `data_reset` (SCR-014, AC-018) | 한/영 전환 전 화면 문구 일치, 큰 글자·움직임 줄이기 반영, 분석 끄기, 지원코드, 2단계 데이터 초기화 후 첫 실행 복귀 | 초기화 1·2단계 경고 및 빨간 주 버튼 구분, 큰 글자/영어 긴 이름 2줄 이내 | 초기화 1·2단계 취소·뒤로 가기 시 데이터 보존, 확정 시 전체 초기화 | 탐색 스크립트 언어 전환 전 화면 순회, 큰 글자/모션 축소, 초기화 캡처·로그 |
| `observability`, `operations`, `commerce`, `ui_leaderboard`, `ui_support_entry`, `ui_kit` | GA4 이벤트/옵트아웃, 원격 설정 범위/폴백, 로컬 모드(`commerce`/`ui_leaderboard` 미노출), UI Kit 프로브 통과 | 공통 UI(`ui_kit`)와 제품 `candy_pop` 스킨 일관성 | 원격 설정·분석 전송 실패 시 게임 진행 무영향 | `tools/check.py` 프로브 결과 및 로그 |

## 실행 후 관찰·판정

- 시작·종료 시각·실제 후보 SHA:
  - 시작 시각: `2026-11-21T16:13:46+09:00` (`2026-11-21T07:13:46Z`)
  - 종료 시각: `2026-11-21T19:31:00+09:00` (`2026-11-21T10:31:00Z`)
  - 실제 후보 SHA: `1dda221f41885e92214f527d442d3057c8a8dae2` (브랜치 `qa/review-1`)
  - 전체 판정: **미통과** (막힘 0건, **중요 3건**, **사소 4건** — 실행 전 계획의 통과 기준 "`막힘` 또는 `중요` 결함 0건" 미충족)

### 실행 명령 및 결과 요약

| 명령 | 결과 | 비고 |
|---|---|---|
| `npm run check:architecture` | 통과(exit 0) | `Architecture passed` |
| `python3 tools/bundle.py verify` | 통과(exit 0) | `ok: true`, 공통 묶음 82개 파일 해시 일치 |
| `bash tools/check_monetization.sh` | 통과(exit 0) | `PASS: errors=0 warnings=4 strict=on` (BM-017/037/073 경고는 설계 DEC-002·원격 설정의 기존 승인/알려진 항목) |
| `python3 tools/levels/verify_packs.py` | 통과(exit 0) | journey 600판, daily 1,100일, tutorial 1판 모두 문제 0건 |
| `npm test` | 통과(exit 0) | 생성물·스크린숏·레벨·원격설정·Python 단위 74건·네이티브·`check.py`(22 시나리오)·export-pack(2,344파일, 문제 0) 모두 통과 |
| `python3 tools/check.py --capture --size 390x844 --out build/r1-390` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x693 --out build/r1-693` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x866 --out build/r1-866` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 360x640 --out build/r1-640` | 재실행 3차 통과(exit 0) | 1·2차 실행은 `The window lost focus at frame 14683`/`13897`/`9786`으로 탭 누락 발생, 3차 재실행에서 focus loss 없이 22개 시나리오 통과, 68장 캡처 |
| 탐색 스크립트 `build/r1_explore.gd` (렌더링 `--out build/r1-explore-render --capture`) | 통과(exit 0) | 8개 탐색 시나리오 통과, `ERROR:`/`SCRIPT ERROR` 및 focus loss 없음, 9장 캡처 및 `explore-findings.json` 기록 |

### 항목별 관찰·판정

| 항목 | 실제 관찰·증거 | 기능/UX 문제·사용자 영향 | 수정 제안 | 판정 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 | `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh`, `npm test` 모두 종료 코드 0 통과. `journey` 600판, `daily` 1,100일, `tutorial` 1판 불일치 0(AC-013, AC-102, AC-105). | 없음 (`check_monetization.sh`의 경고 4건은 설계 DEC-002 예외와 기존 원격 설정 키 경고). | 없음 | 통과 |
| `startup`, `title_home` (SCR-001, SCR-002) | `r1-390`~`r1-640`의 `title.png`, `title-en.png`, `title-consent.png`, `title-error.png`, `home.png`, `home-en.png` 확인. 3단계 실제 진행 막대, 동의 대기 문구, 손상 시 `다시 시도` 스킨·문구, 홈의 스테이지 카드·일일 도전·배지·출석 맥동·코인 칩 표시 모두 계약 일치. | **[중요] 코인 칩 상점 진입 버튼 터치 영역 미달**: `fa_ui.gd:224`의 `Row/Add`가 `22.0 × 24.0`px이고 `currency_chip.gd:10`이 `+` 버튼만 눌러야 상점을 염. `explore-findings.json` 실측에서 코인 숫자 영역(`75×34`) 탭 시 `tapping_value_opens_shop: false` 확인. 손가락 터치 기준(03 문서 48×48, 일반 44×44)에 크게 못 미쳐 오탭·미반응 유발. | 코인 칩 전체(또는 최소 `48×48` 투명 히트 영역)를 눌러도 상점으로 진입하도록 확장 | **실패**(중요 1) |
| `tutorial` (SCR-012, AC-015) | `r1-390/tutorial-step-1.png`, `tutorial-step-2.png`, `tutorial-done.png` 및 `explore-first-to-stage3` 통과. 손가락·말풍선으로 3단계 유도, 안내 밖 카드 탭 무시, 끝 카드 실수 4회+"한 장만 달라요!" 그림·시작 선물(코인 200, 부스터 3/3/2) 1회 지급 확인. | 처음 보는 사용자가 말풍선과 강조 카드만으로 규칙(묶기·임시 칸 열기·실수)을 바로 이해 가능. 문제 없음. | 없음 | 통과 |
| `core_play` 묶기·오답·임시 칸 (SCR-003, AC-001~005) | `r1-390`~`r1-640`의 `stage-1.png`, `stage-6.png`, `one-away.png`, `english-board.png`, `explore-stage3.png` 및 `explore-first-to-stage3`(스테이지 1→2→3 연속 실제 플레이) 통과. 선택 들림·노랑 테·체크 배지, 한 장 차이 토스트, 동일 오답 재시도, 임시 칸 이동·드래그, 예비/임시 칸 이동 불가, 카드 높이 84 이상, 2줄 이내 이름 맞춤 확인. | 없음 | 없음 | 통과 |
| `core_play`, `result_rewards`, `ad_placements` 실패·막힘·결과 (SCR-005~007, AC-006~008, AC-016~017) | `pause.png`, `stuck.png`, `fail.png`, `fail-short.png`, `result.png`, `dead-end.png`, `explore-fail-continue-restart`(실수 4회→광고 이어하기 실수 2복원→2차 실패 이어하기 숨김·`다시 하기` 주 버튼 승격→재시작) 통과. `fail` 팝업 세 버튼 높이 `68.0` 동일 확인(`explore-findings.json`). | 없음 | 없음 | 통과 |
| `boosters` 힌트·되돌리기·칸 추가 (SCR-003, SCR-013, AC-009~011) | `stage-3` 힌트 사용(보유수 1 감소), `explore-booster-zero-shortage`에서 보유 0개 `+` 배지 표시, 광고 없음 시 `"지금은 광고가 없어요"`, 코인 부족 시 빨간 비활성(`unaffordable`)·부족 코인 수 토스트 확인. `buy`·`watch` 버튼 크기 `274×54` 동일 확인. | **[사소] 부스터 얻기 팝업과 코인 부족 토스트 겹침**: `round-1/booster-shortage-toast.png`에서 `"코인이 47개 모자라요"` 토스트가 `힌트` 팝업 내부 제목 바로 아래 설명 문구 위를 가림. | 플레이 팝업이 열린 상태에서는 토스트 Y 위치를 팝업 위/아래 안전 여백으로 이동 | 통과(사소 1) |
| `run_save`, `account_save`, `ui_navigation` (SCR-004, AC-012) | `explore-a11y-and-background`에서 플레이 중 `NOTIFICATION_APPLICATION_PAUSED` 후 60초·1,900초 뒤 `RESUMED` 시 보드 카드·임시 칸·선택 상태 유지 확인. `explore-back-spam-and-reset`에서 플레이 중 뒤로 가기 3연타(일시정지 열림→닫힘→열림) 및 홈 2회 뒤로 가기 종료 확인. | **[사소] `_exit_armed_until` 화면 전환 후 잔존**: `main.gd:539`의 `_exit_armed_until`이 `_home()`에서 초기화되지 않아, headless 빠른 전환(`task-279`)에서 이전 홈 뒤로 가기 후 다른 화면을 거쳐 2초 내 복귀해 1회만 뒤로 가기를 눌러도 즉시 종료됨(`quit_on_first_back_after_return = true` 재현). | `_home()` 또는 `_open_round()` 진입 시 `_exit_armed_until = 0` 초기화 | 통과(사소 1) |
| `daily_challenge` (SCR-008, AC-014) | `daily.png`, `daily-done.png`, `daily-saturday-en.png`, `explore-daily-reentry` 통과. 오늘 판 완료 후 홈 `daily_tick` 표시 및 재진입 시 결과 카드·완성 순서·`결과 복사` 유지(재플레이 버튼 미노출) 확인. | **[중요] 9:16 작은 화면(`390×693`, `360×640`)에서 주 행동 버튼 가려짐**: `round-1/daily-693.png`에서는 `오늘의 도전` 버튼 윗선만 보이고 `round-1/daily-640.png`에서는 버튼과 규칙 안내가 첫 화면 밖 아래로 완전히 밀림. `daily_screen.gd:58`이 스크롤바를 숨겨(`SCROLL_MODE_SHOW_NEVER`) 스크롤 단서도 없음.<br>**[사소] 달력 날짜 칸 터치 영역 미달**: `explore-findings.json` 기준 `day_*` 버튼 크기가 `40.0 × 44.0`px(폭 44 미만, 48 미만). | 1) 작은 화면에서 달력 셀 높이/간격을 줄이거나 시작 카드를 고정해 첫 화면에 `오늘의 도전` 버튼이 보이게 조정하고 필요 시 스크롤 표시<br>2) 달력 날짜 칸 높이를 48 이상으로 확보 | **실패**(중요 1, 사소 1) |
| `album`, `shop`, `attendance`, `inbox` (SCR-009~011, SCR-015) | `album.png`, `album-detail.png`, `shop.png`, `shop-decor.png`, `attendance.png`, `inbox.png`, `explore-album-empty.png`, `explore-inbox-empty.png` 확인. 빈 상태 스킨, 코인 부족 안내, 구매·적용, 출석 이어받기, 우편 보상 흡수 정상 동작. | **[사소] 상점·알림함·팝업 버튼 48dp 미만**: `explore-findings.json`에서 상점 탭(`44px`), 상점 구매/사용(`46px`), 알림함 `claim`(`46px`), 팝업 닫기 `Close`(`56×46`)가 03 문서 기준(최소 48×48)에 2~4px 미달.<br>**[사소] 도감 빈 상태 정상 흐름 미노출**: 튜토리얼 완료 직후 `album_count_after_tutorial = 3`이 되어 정상 첫 실행 이용자는 빈 도감(`아직 모은 범주가 없어요`)에 도달하지 못함(고정 상태 검증에서는 정상 표시). | 버튼 최소 높이를 48px로 조정하고, 03 문서의 도감 빈 상태 조건을 실제 흐름에 맞게 명시 또는 조정 | 통과(사소 2) |
| `settings_support`, `ui_locale_offline`, `ui_analytics_opt_out`, `data_reset` (SCR-014, AC-018) | `settings.png`, `reset-first-ko.png`, `reset-final-ko.png`, `explore-home-en-large-reduced.png`, `explore-play-en-large-reduced.png`, `explore-back-spam-and-reset` 통과. 큰 글자·움직임 줄이기 반영, 영어 긴 카드 이름 2줄 이내, 초기화 1·2단계 뒤로 가기/취소 보존 및 확정 시 전체 리셋 확인. | **[중요] 언어·화면 전환 후 이전 언어 토스트 잔존**: 한국어 홈에서 뒤로 가기 토스트를 띄운 뒤 설정→영어로 전환해 홈·플레이 화면으로 진입해도 `한 번 더 누르면 게임을 끝내요` 토스트가 그대로 남음(`round-1/toast-after-locale-switch-home.png`, `round-1/toast-after-locale-switch-play.png`, `explore-findings.json`: `toast_visible = true`). 플레이 화면에서는 하단 카드 이름(`Syringe`, `Crutch`)을 가림(`r1-390/home-en.png`, `r1-640/home-en.png`에서도 동일 관찰). | `_home()`, `_open_round()`, `_clear()`, 언어 변경 시 `main._toast`가 유효하면 즉시 제거 | **실패**(중요 1) |
| `observability`, `operations`, `commerce`, `ui_leaderboard`, `ui_support_entry`, `ui_kit` | `tools/check.py`의 `outgame_contract_probe`, `ui_standard_contract_probe`, `ui_kit_probe` 및 `live-services-offline` 시나리오 모두 통과. | 없음 | 없음 | 통과 |

### 증거 그림 (300KB 이하)

- `docs/07-qa/review-rounds/round-1/daily-640.png` (`360×640` 일일 도전 첫 화면 버튼 가려짐)
- `docs/07-qa/review-rounds/round-1/daily-693.png` (`390×693` 일일 도전 첫 화면 버튼 상단만 노출)
- `docs/07-qa/review-rounds/round-1/toast-after-locale-switch-home.png` (영어 전환 후 홈에 남은 한국어 토스트)
- `docs/07-qa/review-rounds/round-1/toast-after-locale-switch-play.png` (영어 플레이 화면 카드 위까지 남은 한국어 토스트)
- `docs/07-qa/review-rounds/round-1/booster-shortage-toast.png` (부스터 얻기 팝업 내부와 겹친 부족 토스트)

## 수정·재확인·남은 문제

본 회차는 독립 QA 검수 회차 1/3로, 제품 코드·자산·테스트는 수정하지 않았다.

### 남은 문제 목록 (총 7건: 막힘 0, 중요 3, 사소 4)

1. **[중요] 코인 칩의 상점 진입(`+`) 버튼 터치 영역 `22×24` 및 칩 전체 미반응**
   - 재현 순서: 홈 또는 플레이 화면 진입 → 코인 칩의 코인 아이콘/숫자 영역 탭 → 상점이 열리지 않음 → 오른쪽 끝 작은 초록 `+` 버튼(`22×24`)을 정확히 탭해야 상점이 열림.
   - 사실·증거: `godot/game/features/shared/fa_ui.gd:224`, `godot/addons/seorilabs_game/ui_kit/currency_chip.gd:10`, `build/r1-explore-render/explore-findings.json` (`add_size: (22.0, 24.0)`, `chip_size: (75.0, 34.0)`, `tapping_value_opens_shop: false`).
   - 수정 제안: 코인 칩 전체 또는 최소 `48×48` 히트 영역이 상점 진입을 받도록 개선(단, 공통 `addons/` 수정 금지 규칙에 따라 `fa_ui.gd`에서 투명 터치 래퍼/확장 버튼 적용).
2. **[중요] 언어·화면 전환 시 이전 화면 토스트(`_toast`) 잔존**
   - 재현 순서: 한국어 홈에서 뒤로 가기 1회 눌러 `"한 번 더 누르면 게임을 끝내요"` 토스트 표시 → 2초 내 설정→언어→English 전환 후 홈 또는 플레이 화면 진입 → 한국어 토스트가 영어 홈·영어 플레이 카드(`Syringe`, `Crutch`) 위에 그대로 남아 있음.
   - 사실·증거: `docs/07-qa/review-rounds/round-1/toast-after-locale-switch-home.png`, `docs/07-qa/review-rounds/round-1/toast-after-locale-switch-play.png`, `build/r1-explore-render/explore-findings.json` (`toast_visible: true`), `build/r1-390/home-en.png`, `build/r1-640/home-en.png`.
   - 수정 제안: `godot/game/bootstrap/main.gd`에서 `_home()`, `_open_round()`, `_clear()`, 언어 변경 시 `is_instance_valid(_toast)`이면 즉시 해제.
3. **[중요] 작은 화면(`390×693`, `360×640`) 일일 도전 화면에서 주 행동 버튼 가려짐**
   - 재현 순서: `390×693` 또는 `360×640` 해상도에서 홈→일일 도전 진입 → 첫 화면에서 달력과 연속 기록 아래 `오늘의 도전` 주 버튼이 잘리거나 완전히 화면 밖에 위치하며 스크롤바도 표시되지 않음.
   - 사실·증거: `docs/07-qa/review-rounds/round-1/daily-693.png`, `docs/07-qa/review-rounds/round-1/daily-640.png`, `godot/game/features/outgame/daily_screen.gd:58`.
   - 수정 제안: 작은 화면에서 달력 셀 높이·여백을 축소하거나 `오늘의 도전` 카드/버튼을 스크롤 밖 하단 또는 상단에 고정하고, 스크롤 가능 시 스크롤 인디케이터를 노출.
4. **[사소] `48×48` 기준 미만 버튼(`40×44`~`56×46`) 존재**
   - 재현 순서: 일일 도전 달력, 상점 부스터/꾸미기 탭, 알림함, 팝업 닫기 버튼 크기 측정.
   - 사실·증거: `build/r1-explore-render/explore-findings.json` (`day_*`: `40×44`, `tab_*`: `118~123×44`, `buy_*`/`claim`: `×46`, `Close`: `56×46`).
   - 수정 제안: 각 버튼의 최소 높이/터치 영역을 48px 이상으로 상향(달력 칸은 행 간격·여백 조정 또는 높이 확보).
5. **[사소] 부스터 얻기 팝업 위에서 코인 부족 토스트가 팝업 제목·본문과 겹침**
   - 재현 순서: 보유 코인 100 미만·힌트 0개·광고 없음 상태에서 힌트 버튼 탭 → `힌트` 팝업 열림 → 빨간 `코인 100` 버튼 탭 → `"코인이 47개 모자라요"` 토스트가 팝업 내부 상단 여백 및 문구 위를 가림.
   - 사실·증거: `docs/07-qa/review-rounds/round-1/booster-shortage-toast.png`.
   - 수정 제안: 플레이 팝업이 열려 있을 때는 토스트 Y 위치를 팝업과 겹치지 않는 상단 또는 하단 안전 위치로 조정.
6. **[사소] 홈 뒤로 가기 종료 무장(`_exit_armed_until`)이 다른 화면 순회 후 2초 내 복귀 시 유지됨**
   - 재현 순서: 홈에서 뒤로 가기 1회(`_exit_armed_until = now + 2000`) → 다른 화면 이동 후 2초 안에 홈 복귀 → 홈에서 뒤로 가기 1회만 눌러도 앱 종료가 호출됨.
   - 사실·증거: `godot/game/bootstrap/main.gd:539-545` 및 headless 탐색 실행(`task-279`)에서 `first back on home does not quit` 실패(`actual=1`) 관찰(렌더링 실행에서는 화면 전환 소요 시간으로 2초가 지나 `armed_ms_remaining_on_home_return: 0`).
   - 수정 제안: `_home()` 또는 `_open_round()` 진입 시 `_exit_armed_until = 0` 초기화.
7. **[사소] 도감 빈 상태의 정상 첫 실행 흐름 도달 불가**
   - 재현 순서: 첫 실행→튜토리얼 완료(과일·악기·날씨 3범주 클리어)→홈 도달→도감 열기 → 이미 3/158이 등록되어 빈 도감 안내(`아직 모은 범주가 없어요`)가 표시되지 않음(튜토리얼 완료 + 빈 도감 저장 상태로 강제 구성 시에는 정상 표시).
   - 사실·증거: `build/r1-explore-render/explore-findings.json` (`album_count_after_tutorial: 3`), `build/r1-explore-render/explore-album-empty.png`.
   - 수정 제안: 의도된 동작이라면 03 문서 상태 매트릭스의 도감 비어 있음 조건에 예외/실제 도달 경로를 명시하거나, 튜토리얼 범주는 도감 미등록으로 둘지 결정.

> 회차 1 판정: **미통과** — 위 중요 3건과 사소 4건을 수정한 뒤 회차 2에서 재확인 필요.
