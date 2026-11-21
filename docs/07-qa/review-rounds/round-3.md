# 재설계 UI 검수 3

- 회차: 3 / 3
- 집중 범위: 기능 사이 연결(플레이↔상점↔홈↔도감↔일일 도전↔출석↔알림함↔설정), 재시작과 저장 복구(진행 중 판 저장/복원, 설정·테마·출석·일일 연속 기록 유지, 백업 `.bak` 복구, 데이터 초기화 후 재시작), 반복 플레이의 자연스러움(스테이지 1→6+ 난도/부스터 튜토리얼 전환, 일일 도전과 여정 교차 플레이, 전면 광고 간격 및 보상형 후 쿨다운)

## 실행 전 계획

- 설계 ID·조건 ID·후보 SHA·변경점:
  - 설계 ID: `2026-11-21-four-alike-launch` (v1, `test-plan.json` 기준 `level: "L3"`, `redesign: true`)
  - 조건 ID: AC-001~018, AC-101~105 (개발 환경 범위. 실기기 항목 AC-106 / AND-01~08은 본 회차 범위 밖)
  - 후보 SHA: `980b1d897cd884cc2bd2a8a3abf14d8acf8421db`
  - 회차 2 이후 변경점 (`46dd6246` → `980b1d89`):
    - 회차 2 검수 기록(`docs/07-qa/review-rounds/round-2.md` 및 `round-2/` 증거 그림 7장) 추가. 제품 코드·자산·테스트 변경 없음.
    - 회차 2 결과 연계: 막힘 0건, 중요 0건, 사소 2건(일일 도전 달력 칸 가로 폭 `40px` 이하 잔여, 작은 화면 일일 도전 결과 복사/상점 꾸미기 일시 토스트 하단 겹침)이 남았으며, 회차 3에서 동일 제품 후보의 기능 간 연결·재시작과 저장 복구·반복 플레이를 독립 검증한다.
- 계획 작성 시각·실행 순서·통과 기준:
  - 계획 작성 시각: `2026-11-21T20:29:25+09:00` (`2026-11-21T11:29:25Z`)
  - 실행 순서:
    1. 정적·아키텍처·팩·수익화·전체 테스트 명령 실행(`npm test`, `npm run check:architecture`, `python3 tools/bundle.py verify`, `python3 tools/levels/verify_packs.py`, `bash tools/check_monetization.sh`)
    2. 4개 해상도(`390x844`, `390x693`, `390x866`, `360x640`) 렌더링 여정 캡처 실행(`build/r3-390`, `build/r3-693`, `build/r3-866`, `build/r3-640`) 및 주요 PNG 직접 열람 확인(`The window lost focus` 발생 시 재실행)
    3. 독립 탐색적 회귀 스크립트 `build/r3_explore.gd` 작성 및 렌더링 실행(`--audio-driver Dummy --capture`, 격리 저장 경로 `build/r3-explore/user_data/`):
       - 기능 사이 연결: 플레이 중 상점 진입→부스터/꾸미기 구매 및 적용→홈 복귀(`이어 하기` 유지)→판 재개 시 구매한 부스터 수·새 카드 뒷면/배경 즉시 반영; 판 클리어 결과 창의 새 범주가 도감에 즉시 반영 및 10개 단위 보상(코인 50) 반영; 알림함 보상·출석·도감 보상·상점 소비·설정이 서로 일치; 일일 도전과 일반 스테이지 교차 진행 시 각각의 진행·임시칸·부스터 규칙(`일일 도전 부스터 없음`) 간섭 여부 확인.
       - 재시작과 저장 복구: 판 중간(일부 묶음 완성 + 카드 임시 칸 이동 + 힌트 사용)에 앱 종료→재실행 시 홈 `이어 하기`로 정확히 동일 판·묶음·임시칸·실수·부스터 복원; 설정·테마·출석·일일 연속 기록 재시작 후 유지; 제품 저장 손상 시 `.bak` 자동 복구 확인; 데이터 초기화 후 재실행 시 튜토리얼·코인 0·도감 0·기본 테마·기본 설정 완전 초기화 확인.
       - 반복 플레이의 자연스러움: 튜토리얼→스테이지 1~6 연속 진행(스테이지 3 힌트, 스테이지 6 `step` 보통 난도 진입, 결과 2배 보상형, 두 번째 실행+3분 누적 후 전면 광고 2판 간격·보상형 뒤 120초 쿨다운 준수), 출석 7일 순환 후 8일째 1일째 복귀 확인.
    4. 실제 관찰·증거·발견 문제·회차 3 판정 및 3회 종합 결론 기록 후 `qa/review-3` 브랜치 커밋
  - 통과 기준:
    - 필수 명령 5종 및 4개 해상도 캡처 여정 모두 `SCRIPT ERROR`, `ERROR:` 없이 통과(`The window lost focus` 없는 정상 실행)
    - 회차 3 집중 범위(기능 사이 연결, 재시작과 저장 복구, 반복 플레이의 자연스러움)에서 `막힘` 또는 `중요` 결함 0건
    - `docs/qa/feature-inventory.json` 핵심 기능 25개 전체가 여정·회귀 흐름에서 누락 없이 동작
- 구현자·다른 리뷰 에이전트·페르소나·필요 시 UX 전문가:
  - 구현자: 기존 구현 에이전트(제품 코드 `46dd6246`까지 구현)
  - 검수자(독립 리뷰 에이전트): 본 독립 QA 검수 에이전트(회차 3/3)
  - 페르소나: 회귀 검수자 / 반복 사용자(한국어·영어)
- 실제 환경·격리 계정·데이터·저장 경로:
  - 실행 환경: macOS, Godot 4.7.2 (`--headless` E2E 및 `gl_compatibility` 렌더링 실행), adb 기기 미사용
  - 계정: 로그인·계정 없음(로컬 모드)
  - 격리 저장 경로: `tools/check.py` 실행별 임시 `user://` 격리 폴더 및 탐색 스크립트 전용 `build/r3-explore/user_data/`(`FaSavePaths.under` 경로, 실제 앱 `user://` 미사용)
- 핵심 기능 전체 목록 (`docs/qa/feature-inventory.json` 25개 전체):
  - `startup`, `tutorial`, `account_save`, `settings_support`, `inbox`, `commerce`, `observability`, `operations`, `ui_support_entry`, `ui_analytics_opt_out`, `ui_locale_offline`, `ui_navigation`, `ui_leaderboard`, `ui_kit`, `core_play`, `boosters`, `result_rewards`, `ad_placements`, `run_save`, `title_home`, `daily_challenge`, `album`, `shop`, `attendance`, `data_reset`
- 이어받는 영향 없는 기반 기능(기능 ID·기준 SHA·실제 실행 시각·증거):
  - 없음 (`test-plan.json` 기준 `baseline: null`, 첫 출시 L3 전체 회귀; 본 회차에서 25개 기능 전체 연계·재시작·반복 플레이를 다시 실행해 검증)

| 항목 | 기능 기대 결과 | UX 기대 결과 | 오류·복구 재현 | 남길 증거 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 (`startup`, `operations`, `observability`, `commerce`, `ui_leaderboard`, `ui_support_entry`, `ui_kit`) | `npm test`, `npm run check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh` 모두 통과(AC-013, AC-102, AC-105) | 해당 없음(내부 품질·규칙·로컬 모드 경계) | 팩 변조·경계 위반·미등록 기능 없음을 도구 출력으로 확인 | 각 명령 종료 코드 및 출력 요약 |
| 기능 사이 연결 1: 플레이↔상점↔홈↔도감 (`core_play`, `boosters`, `shop`, `title_home`, `album`, `result_rewards`, `ui_navigation`) | 플레이 중 코인 칩→상점 진입, 부스터/테마 구매·적용→홈 복귀(`이어 하기` 유지, 새 카드 뒷면/배경 반영)→판 재개 시 부스터 개수·새 뒷면/배경 즉시 반영; 판 클리어 결과 창의 새 범주가 도감에 즉시 반영 및 10개 단위(+50 코인) 반영 | 상점 다녀와도 플레이가 끊기지 않고 홈과 판 모두 테마 변화가 바로 체감됨. 결과→도감 전환 시 수치 일치 | 코인 부족 시 구매 거부 및 판·테마 보존; 상점 진입 전 판 상태(`save_now`) 유실 없음 확인 | `r3-390`~`r3-640` 캡처 및 `r3_explore.gd` 실측 JSON·캡처 |
| 기능 사이 연결 2: 일일 도전↔여정↔알림함↔출석↔설정 (`daily_challenge`, `inbox`, `attendance`, `settings_support`, `ui_analytics_opt_out`, `ui_locale_offline`) | 일일 도전과 일반 스테이지 교차 플레이 시 부스터/임시 칸 2칸(`일일 도전 부스터 없음`)·진행 상태가 서로 오염되지 않음; 알림함 보상 흡수·출석 수령이 홈/상점 코인과 부스터에 즉시 반영; 설정 한/영 전환 및 분석 끄기 후 전 화면 일관 반영 | 일일 도전 규칙 한 줄(`부스터 없이 풉니다`)과 부스터 회색 처리, 알림함/출석 배지 소멸 및 보상 연출 자연스러움 | 일일 도전 중 일반 판과의 교차 전환 동작 확인; 이미 받은 우편/출석 중복 수령 차단 | `r3_explore.gd` 교차 플레이·알림함/출석/설정 연동 로그·캡처 |
| 재시작과 저장 복구 (`run_save`, `account_save`, `data_reset`) | 판 중간(일부 묶음 완성 + 카드 임시 칸 이동 + 힌트 사용) 종료 후 재실행 시 홈 `이어 하기`로 동일 판·묶음·임시칸·실수·부스터 복원; 설정·테마·출석·일일 연속 기록 재시작 유지; 제품 저장 손상 시 `.bak` 자동 복구; 데이터 초기화 확정 후 재실행 시 튜토리얼·코인 0·도감 0·기본 테마·기본 설정(시스템 기본 언어·분석 켬) 완전 초기화 | 재시작 시 자연스럽게 `이어 하기`로 복귀하며, `.bak` 복구 시 사용자 진행을 잃지 않음. 데이터 초기화 후 첫 실행과 동일한 온보딩 흐름 제공 | 진행 중 저장 손상→`.bak` 복구, 양쪽 손상→신규 시작 안내 토스트, 초기화 후 파일 시스템 잔여물 부재 확인 | `r3_explore.gd` 저장/복구/초기화 파일 대조 로그·캡처 |
| 반복 플레이의 자연스러움 (`tutorial`, `core_play`, `boosters`, `ad_placements`, `attendance`) | 튜토리얼→스테이지 1~6 연속 진행(스테이지 3 힌트, 스테이지 6 `step` 보통 난도 진입, 결과 2배 보상형), 두 번째 실행+누적 3분 후 전면 광고 2판 간격·보상형 뒤 120초 쿨다운 준수, 출석 7일 순환 후 8일째 1일째 복귀 | 반복 플레이 중 난도 상승(`open`→`step`)과 결과 2배·전면 광고 리듬이 과도하지 않음. 출석 7일 순환이 끊김 없이 이어짐 | 보상형 중도 닫기/시청 후 120초 미만 시 전면 광고 억제 확인, 120초 경과+2판 충족 시 노출 확인, 출석 7일째 이후 8일째 1일 복귀 확인 | `r3_explore.gd` 스테이지 1~6·광고 쿨다운·출석 8일 순환 로그·캡처 |

## 실행 후 관찰·판정

- 시작·종료 시각·실제 후보 SHA:
  - 시작 시각: `2026-11-21T20:29:51+09:00` (`2026-11-21T11:29:51Z`)
  - 종료 시각: `2026-11-21T20:50:45+09:00` (`2026-11-21T11:50:45Z`)
  - 실제 후보 SHA: `980b1d897cd884cc2bd2a8a3abf14d8acf8421db` (브랜치 `qa/review-3`)
  - 전체 판정: **통과** (막힘 0건, 중요 0건, **사소 4건** — 실행 전 계획의 통과 기준 "`막힘` 또는 `중요` 결함 0건" 충족)

### 실행 명령 및 결과 요약

| 명령 | 결과 | 비고 |
|---|---|---|
| `npm run check:architecture` | 통과(exit 0) | `Architecture passed` |
| `python3 tools/bundle.py verify` | 통과(exit 0) | `ok: true`, `game-foundation@ca2ff1f2`, 공통 묶음 82개 파일 해시 일치 |
| `python3 tools/levels/verify_packs.py` | 통과(exit 0) | `journey: 600`, `daily: 1100`, `tutorial: 1`, 문제 0건 |
| `bash tools/check_monetization.sh` | 통과(exit 0) | `PASS: errors=0 warnings=4 strict=on` (BM-017/037/073 경고 4건은 설계 DEC-002·원격 설정의 기존 승인 예외) |
| `npm test` | 통과(exit 0) | 생성물·스크린숏·레벨·원격설정·Python 단위 74건·네이티브·`check.py`(22 시나리오)·`check:export-pack`(2,344파일, SVG 원문 100, 문제 0) 모두 통과 |
| `python3 tools/check.py --capture --size 390x844 --out build/r3-390` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x693 --out build/r3-693` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 390x866 --out build/r3-866` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| `python3 tools/check.py --capture --size 360x640 --out build/r3-640` | 통과(exit 0) | 22개 시나리오 통과, `The window lost focus` 없음, 68장 캡처 |
| 탐색 스크립트 `build/r3_explore.gd` (`--audio-driver Dummy --capture --out build/r3-explore`) | 재실행 통과(exit 0) | 1차 실행은 스크립트 종료 `quit()` 누락(EXIT 137)과 스크립트 기대값 오기 2건(튜토리얼 완료 코인 `200` vs 도감 3범주 `15` 합산 `215`, 알림함 버튼명 `claim`) 수정 후 재실행. 2차 실행에서 3개 시나리오 144단계 전부 통과(`SCRIPT ERROR`, `ERROR:`, `The window lost focus` 0건), 7장 캡처 및 `explore-findings.json` 기록 |

### 항목별 관찰·판정

| 항목 | 실제 관찰·증거 | 기능/UX 문제·사용자 영향 | 수정 제안 | 판정 |
|---|---|---|---|---|
| 정적·아키텍처·팩·수익화 게이트 | `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh`, `npm test` 모두 exit 0 통과. `feature-inventory.json` 25개 기능 전체 `check.py` 22개 시나리오로 덮음 확인. | 없음(`check_monetization.sh` 경고 4건은 기존 승인 예외). | 없음 | 통과 |
| 기능 사이 연결 1: 플레이↔상점↔홈↔도감 | 스테이지 9 진행 중 카드 1장을 `hold_0`에 둔 상태에서 플레이 코인 칩(`+`) 탭→상점 진입→유기적 획득 코인 `855`로 `힌트` 1개(`100`) 및 `민트 줄무늬` 카드 뒷면(`600`) 구매→홈 복귀 시 `이어 하기` 유지 및 스테이지 카드 뒷면 즉시 변경→판 재개 시 `힌트` 배지 `4`(+1)·`hold_0` 카드(`붓`)·`민트 줄무늬` 카드 뒷면 즉시 반영 확인(`round-3/play-after-shop.png`, `build/r3-390/home-decor.png`, `build/r3-390/board-decor.png`). 스테이지 9 클리어 결과 창의 새 범주 4개(`toys`, `art_supplies`, `construction`, `farm_animals`)가 도감에 즉시 등록(`38/158`, `all_synced: true`)되고, 스테이지 2 클리어 시 도감 10개 단위(`7→11`) 보상 `+50` 포함 `+70` 도감 코인 지급 확인(`explore-findings.json`). | **[사소][회차 2-2 잔여] 작은 화면 상점 꾸미기 일시 토스트 겹침**: `build/r3-693/shop-decor.png`에서 코인 부족 토스트가 하단 카드 이름 위를 2초간 가림. | 하단 목록과 겹치지 않는 상·하 안전 여백 조정 검토 | 통과(사소 1) |
| 기능 사이 연결 2: 일일 도전↔여정↔알림함↔출석↔설정 | 1) 알림함: 배지 `1` 확인→환영 우편 `claim` 수령(+5 코인)→홈 코인 즉시 반영 및 배지 `0` 소멸.<br>2) 일일 도전↔여정 교차: 스테이지 10 진행 중(카드 1장 `hold_0`) 상점 경유 홈→일일 도전 진입→일일 판은 임시 칸 2칸(`slot_count=2`, `hold_cell_count=2`), 힌트/되돌리기 `off`·비활성, `holds[0]==""`으로 완전히 독립 실행(`round-3/daily-cross.png`). 일일 도전 완료 후 홈 복귀 시 스테이지 10은 건너뛰어지지 않고 `스테이지 10 시작`으로 유지.<br>3) 설정 한/영 전환 및 큰 글자·분석 끄기 후 홈·플레이·하위 화면 일관 반영 확인. | **[사소][신규] 여정·일일 도전 단일 `run` 공유에 따른 홈 `이어 하기` 표기 및 전환 안내 부재**: `FaProgress`에 진행 중 판(`run`) 슬롯이 하나뿐이어서(`02-gdd.md:242`), 일일 도전 중 상점을 거쳐 홈으로 나오면 `스테이지 10` 카드 아래 주 버튼이 `이어 하기`로 뜨고(실제 누르면 일일 도전 재개), 일일 도전 카드도 `푸는 중`으로 표시됨(`round-3/daily-in-progress-home.png`). 반대로 여정 판 진행 중 일일 도전을 시작하면 이전 여정 판이 확인 없이 중단됨(완성한 범주는 도감에 보존). | 1) `run.mode == "daily"`일 때 홈 주 버튼에 `일일 도전 이어 하기` 또는 `스테이지 10 시작`과의 구분 표기 검토<br>2) 진행 중인 여정 판을 덮고 일일 도전을 시작할 때 1줄 확인 안내 검토 | 통과(사소 1) |
| 재시작과 저장 복구 | 1) 스테이지 10 진행 중(1묶음 완성 + `hold_0` 카드 이동 + 실수 1회 + 힌트 1회) 상태에서 영어·큰 글자 적용 뒤 앱 종료→재실행 시 홈 `Continue` 노출, 설정(`en`, `large_text`), `card_back_mint` 테마, 출석 주기, 일일 연속 기록(`1`) 유지 및 `Continue` 시 `board.to_dict()`, 보유 코인·부스터 정확히 복원.<br>2) 제품 저장 파일(`progress.json`)을 `{corrupted_json_by_r3`로 손상시킨 뒤 재실행 시 `.bak`에서 자동 복구(`save_reset: false`, 오류 토스트 미노출, 스테이지 10·코인 `286`·도감 `41`·테마·연속 기록 유지, `round-3/bak-recovered.png`).<br>3) 설정→데이터 초기화 2단계 확정 후 타이틀 복귀, 공통 저장·`.analytics-off`·`.bak` 파일 삭제, `stage=1`, `coins=0`, `album_count=0`, `selected_theme=""`, `language="system"`, `large_text=false`, `analytics=true` 초기화 및 튜토리얼 첫 단계(`pick`) 재진입 확인(`round-3/after-reset-tutorial.png`). | 없음 | 없음 | 통과 |
| 반복 플레이의 자연스러움 | 튜토리얼(보상 코인 `200` + 도감 3범주 `15` = `215`, 부스터 `3/3/2`)→스테이지 1~8 연속 진행 확인. 스테이지 3 힌트 사용, 스테이지 5(세션 2 + 누적 `185s` 초과) 클리어 시 결과 창 앞 전면 광고 노출 및 결과 2배 보상형 지급 확인, 스테이지 6 `step` 보통 난도(T2) 진입 확인, 스테이지 7(전면 뒤 2판째이나 보상형 뒤 `90s < 120s`) 전면 광고 차단 확인(`interstitials_shown: 1`), 스테이지 8(`130s >= 120s`) 클리어 시 결과 앞 전면 광고 재노출 확인. 출석 1~7일(`20`, `힌트 1`, `30`, `되돌리기 1`, `40`, `칸 추가 1`, `60`) 수령 후 8일째 다시 `1일째`(`20` 코인)로 순환 확인(`round-3/attendance-day8-cycle.png`). | **[사소][신규] 스테이지 3·6·8 부스터 안내(`02-gdd.md:206`, `05:60`) 미구현/문서 불일치**: `stage_3_state`와 `stage_6_state`에서 `guide_step == ""`, `hint_highlighted == false`이며 `fa_progress.gd:25`에도 튜토리얼 완료 외 부스터 안내 플래그가 없음. 플레이어는 스테이지 1부터 시작 선물 부스터를 자유롭게 쓸 수 있으며 막힘/막힌 길 상황에서만 되돌리기/칸 추가가 강조됨.<br>**[사소][회차 1-4/2-1 잔여] 일일 도전 달력 칸 가로 폭 `40px` 이하**: 4개 해상도 캡처 확인 결과 회차 2와 동일(`daily_screen.gd:133`). | 1) 스테이지 3/6/8 첫 진입 1회 강조를 넣을지, 아니면 현재 자유 사용 방식으로 `02-gdd.md:206`·`05:60` 문서를 맞출지 정리<br>2) 달력 좌우 여백 축소로 날짜 칸 폭 44px 이상 확대 검토 | 통과(사소 2) |

### 증거 그림 (300KB 이하)

- `docs/07-qa/review-rounds/round-3/play-after-shop.png` (83KB, 플레이 중 상점 구매 뒤 판 재개 시 힌트 `4`·민트 줄무늬 뒷면·`hold_0` 카드 즉시 반영)
- `docs/07-qa/review-rounds/round-3/daily-cross.png` (72KB, 여정 진행 중 일일 도전 진입 시 2칸·부스터 `off`·독립 상태)
- `docs/07-qa/review-rounds/round-3/daily-in-progress-home.png` (67KB, 일일 도전 진행 중 홈의 `스테이지 10` 아래 `이어 하기` 및 일일 도전 `푸는 중` 표기)
- `docs/07-qa/review-rounds/round-3/attendance-day8-cycle.png` (65KB, 출석 7일 완료 후 8일째 `1일째` 복귀)
- `docs/07-qa/review-rounds/round-3/bak-recovered.png` (89KB, 제품 저장 손상 후 `.bak` 자동 복구된 홈 화면)
- `docs/07-qa/review-rounds/round-3/after-reset-tutorial.png` (72KB, 데이터 초기화 후 시스템 언어·코인 0·기본 테마 튜토리얼 첫 단계)

## 수정·재확인·남은 문제

본 회차는 독립 QA 검수 회차 3/3으로, 제품 코드·자산·기존 테스트는 수정하지 않았다.

### 회차 3 남은 문제 목록 (총 4건: 막힘 0, 중요 0, 사소 4)

1. **[사소][회차 1-4/2-1 잔여] 일일 도전 달력 날짜 칸(`day_*`) 가로 폭 `40px` 이하**
   - 재현: `390×844`, `390×693`, `360×640`에서 일일 도전 화면 진입 시 7열 달력 날짜 버튼 폭이 `40px`(`390×844`)~`35px`(`360×640`)로 03 문서 기준(`48×48`)에 미달(`godot/game/features/outgame/daily_screen.gd:133`).
2. **[사소][회차 2-2 잔여] 작은 화면(`390×693`, `360×640`) 일일 도전 결과 복사·상점 꾸미기 일시 토스트 하단 겹침**
   - 재현: `390×693`/`360×640` 상점 꾸미기 탭에서 미보유 상품 탭 시 코인 부족 토스트가 하단 카드 이름 위를 2초간 가림(`build/r3-693/shop-decor.png`, `godot/game/bootstrap/main.gd:54`). 2초 뒤 소멸해 조작 차단은 없음.
3. **[사소][회차 3 신규] 여정·일일 도전 단일 `run` 공유에 따른 홈 `이어 하기` 문맥 혼선 및 덮어쓰기 안내 부재**
   - 재현: (a) 일일 도전 도중 코인 칩→상점→홈 이동 시 홈의 `스테이지 10` 카드 바로 아래 주 버튼이 `이어 하기`로 표시되고 누르면 일일 도전이 재개됨(`docs/07-qa/review-rounds/round-3/daily-in-progress-home.png`, `home_screen.gd:181`, `fa_session.gd:98`). (b) 여정 판 도중 상점 경유 홈→일일 도전 시작 시 `fa_session.gd:127`이 이전 여정 판을 확인 창 없이 `abandon`함(완성 범주는 도감에 보존).
4. **[사소][회차 3 신규] 스테이지 3·6·8 부스터 안내(`02-gdd.md:206`, `05-economy-content-liveops.md:60`) 미구현/문서 불일치**
   - 재현: 스테이지 3(힌트)·6(되돌리기) 진입 시 `guide_step == ""`, `hint_highlighted == false`이며(`build/r3-explore/explore-findings.json`), `godot/game/core/domain/fa_progress.gd:25`에도 관련 플래그가 정의되어 있지 않음. 기능 결함 없이 스테이지 1부터 자유 사용 가능하나 GDD/경제 문서와 차이가 있음.

---

## 3회 독립 검수 종합 결론

- **회차별 요약**:
  - **회차 1** (후보 `1dda221f`): **미통과** — 막힘 0, 중요 3(코인 칩 터치 영역 `22×24`, 언어·화면 전환 뒤 이전 토스트 잔존, 작은 화면 일일 도전 주 버튼 가려짐), 사소 4.
  - **회차 2** (후보 `46dd6246`): **통과** — 회차 1 중요 3건과 핵심 사소 항목 수정 확인. 막힘 0, 중요 0, 사소 2.
  - **회차 3** (후보 `980b1d89`): **통과** — `npm test`, `check:architecture`, `bundle.py verify`, `verify_packs.py`, `check_monetization.sh`, 4개 해상도 캡처 여정(`NO_FOCUS_LOSS`), 회차 3 탐색 회귀 3개 시나리오(144단계) 모두 통과. 막힘 0, 중요 0, 사소 4(회차 2 잔여 2 + 회차 3 신규 2).
- **최종 판정 (개발 환경 L3 전체 회귀 / 새 화면 3회 독립 검수)**: **통과** (`막힘` 0건, `중요` 0건으로 3회차 통과 기준 충족). 남은 사소 4건은 출시 차단 결함은 아니며 다음 개선 주기에서 문서/UX 다듬기로 처리할 수 있다.
- **남은 출시 게이트 (본 검수 범위 밖)**: 설계 문서(`test-plan.json`, `07-qa-launch-plan.md`)에 따른 Android 실기기 확인 항목 `AND-01~08` (실제 터치/드래그, 강제 종료 복원, UMP 동의, 실제 AdMob 보상형/전면 광고, 소리·진동), 서명 AAB 빌드, 내부 테스트, Google Play 등록정보 검수 및 심사·공개 게이트가 남아 있다.
