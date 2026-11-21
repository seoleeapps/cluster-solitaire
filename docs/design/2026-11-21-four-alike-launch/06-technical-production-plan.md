# 기술 제작 계획

- 문서 상태: approved
- 승인 근거: 사용자 질문 응답 2026-11-21 (DEC-001 Godot 모바일 앱, DEC-015 저장소와 식별자, DEC-016 자원 생성)
- Source of truth: 엔진과 구조, 데이터 계약, 분석 이벤트, 성능 예산, 저장 올림, 플랫폼 연동, 제작 단계, 명령

## 아키텍처와 엔진

| 항목 | 값 |
|---|---|
| 엔진 | Godot 4.7.2, GDScript, 2D, 렌더러는 템플릿 기본값 |
| 화면 | 세로 고정, 논리 폭 390, 폭 기준 늘림(높이 693~910) |
| 출발점 | 공개 스타터 템플릿과 공통 기반 묶음 1.1.0. 묶음의 세 폴더는 수정하지 않는다 |
| 대상 | Android(API 26 이상, 대상 36, arm64) |
| 저장소 | GitHub `seoleeapps/cluster-solitaire`(공개) |

```text
godot/
  addons/seorilabs_game, seorilabs_platform   공통 묶음(수정 금지)
  addons/admob                                 광고 플러그인
  game/bootstrap/main.gd                       공통 흐름을 상속해 제품 화면과 서비스를 주입
  game/core/domain                             규칙, 해법 탐색, 생성기, 난도, 경제, 일일 도전, 광고 정책, 저장 모델
  game/core/use_cases                          화면이 부르는 조합(판 시작, 정산, 부스터, 광고 보상)
  game/core/ports                              저장, 광고, 분석, 시계, 원격 설정 인터페이스
  game/adapters                                포트 구현(파일 저장, AdMob, GA4, 설정 JSON, 시스템 시계)과 테스트 대역
  game/features/<화면>                         홈, 플레이, 결과, 일일 도전, 도감, 상점, 출석, 타이틀
  game/skins/candy_pop                         제품 스킨과 테마
  game/assets                                  카드 그림, 소리
  data/content, data/levels, data/monetization, data/outgame
  tests/game                                   프로브와 화면 입력 여정
content/source                                 범주와 카드 원본 표
tools/content, tools/levels, tools/art, tools/audio   생성과 검증 도구
docs/design, docs/qa, docs/game-design
```

의존 방향은 features → use_cases → domain, adapters → ports다. `core`는 엔진 장면과 파일 입출력에 기대지 않으며 구조 검사 도구가 금지 단어로 확인한다. 화면은 공통 흐름의 경로 덮어쓰기(`feature_routes`)와 타이틀·홈 재정의, 플레이 장면 주입(`launch_game`)으로 붙인다.

## 데이터 계약

| 파일 | 형식 | 만드는 도구 | 검사 |
|---|---|---|---|
| `content/source/items.tsv`, `categories.tsv` | 탭 구분 원본 표 | 사람과 에이전트가 편집 | `tools/content/build_content.py --check` |
| `godot/data/content/items.json` | `{version, items:[{id, icon, en, ko}]}` | `build_content.py` | 이름 길이와 중복, 아이콘 존재 |
| `godot/data/content/categories.json` | `{version, categories:[{id, tier, domain, en, ko, members, also}]}` | `build_content.py` | 범주당 4장 이상, 참조 존재 |
| `godot/data/levels/journey.json`, `daily.json` | `{version, content_version, generator, levels:[{n, layout, tier, f, groups:[{cat, items}], cols, reserve}]}` | 생성기를 headless로 실행 | `tools/levels/verify_packs.py`(풀이 가능, 유일성, 관대함 일치) |
| `godot/data/monetization/bm-profile.json` | 사내 수익화 프레임워크 형식 | 프레임워크 도구 | 프레임워크 검사기 strict |
| `godot/data/outgame/outgame-profile.json` | 공통 기반 프로필 | 수동 | 공통 기반 검사기 |
| 원격 설정 JSON | `{version, values:{키: 값}}`. 키와 범위는 수익화 프로필의 `remote_config` | 저장소의 설정 파일을 정적 호스팅으로 배포 | 앱이 범위 검사, 실패 시 내장 기본값 |
| 제품 저장 파일 | `user://`의 JSON, `version` 1부터 | 앱 | 저장 모델 프로브 |

콘텐츠가 바뀌면 `content_version`을 올리고 팩을 다시 만든다. 이미 실린 일일 도전 팩의 날짜별 판은 바꾸지 않고 뒤에 이어 붙인다.

## 분석 이벤트 분류

전송은 GA4 Measurement Protocol이다. 모든 이벤트에 `runtime_platform`(android), `app_market`(google_play), `release_version`을 싣는다. 설정에서 분석을 끄면 보내지 않는다. Measurement Protocol은 `first_open`과 `session_start`를 받지 않으므로 첫 실행과 세션 시작은 자체 이벤트로 보낸다.

| 질문 | 이벤트 | 주요 매개변수 | 발생 시점 |
|---|---|---|---|
| 새 이용자와 재방문 | `app_first_run`, `app_session` | `session_index`, `days_since_install` | 첫 실행, 실행마다 |
| 온보딩 완료율 | `tutorial_begin`, `tutorial_complete` | `seconds` | 튜토리얼 시작과 끝 |
| 어디서 그만두는가 | `level_start`, `level_end` | `mode`(journey, daily), `level`, `tier`, `layout`, `success`, `stars`, `mistakes`, `holds`, `seconds`, `continue_used`, `slot_unlocked` | 판 시작과 끝 |
| 규칙 이해와 억지 범주 | `mistake`, `group_complete` | `level`, `one_away`, `category`, `order` | 오답, 묶음 완성 |
| 막힘과 도움 장치 | `stuck_shown`, `dead_end_shown`, `booster_used` | `level`, `booster`, `source`(owned, coins, ad) | 해당 시점 |
| 경제 | `earn_virtual_currency`, `spend_virtual_currency` | `virtual_currency_name`, `value`, `source` 또는 `item_name` | 지급과 사용 |
| 광고 | `ad_requested`, `ad_impression`, `ad_failed`, `rewarded_earned`, `ad_declined` | `placement`, `format`, `reason` | 광고 흐름 |
| 재방문 장치 | `daily_complete`, `attendance_claim`, `album_unlock`, `share` | `streak`, `day`, `category` | 해당 시점 |
| 설정 | `settings_change` | `key`, `value` | 언어, 소리, 분석 |

GA4에는 `runtime_platform`, `app_market`, `release_version`을 이벤트 범위 맞춤 측정기준으로 등록했다(속성 565197717, 2026-11-21). 매개변수 이름은 조직의 분석 이벤트 정책(`seorilabs/.github`의 `contracts/analytics-event-policy.yaml`)을 따른다.

## 성능 예산

| 항목 | 예산 |
|---|---|
| 프레임 | 60fps, 프레임당 그리기 호출 150 이하 |
| 텍스처 | 카드 그림 192px PNG 800장은 필요할 때만 올린다. 한 판에 16장, 도감은 보이는 줄만 |
| 시작 | 콘텐츠 JSON과 레벨 팩 읽기 합계 300ms 이내(중급 Android) |
| 해법 탐색 | 임시 칸을 옮길 때마다 1회, 10ms 이내 |
| 기기 생성(601판 이후) | 판 하나 200ms 이내, 다음 판을 미리 만들어 둔다 |
| 용량 | AAB 60MB 이하 |
| 저장 | 값이 바뀔 때 쓰되 한 프레임에 한 번으로 묶는다 |

## 저장 마이그레이션

- 공통 기반의 저장 파일(설정, 튜토리얼, 알림함)과 제품 저장 파일(진행, 재화, 판)을 나눈다. 제품 파일은 자체 `version`을 가진다.
- 읽기: 낮은 버전은 단계별 함수로 올린다. 높은 버전과 형식 오류는 직전 백업 파일을 읽고, 그것도 실패하면 새로 시작하고 알린다.
- 쓰기: 임시 파일에 쓰고 이름을 바꾼다. 쓰기 전에 직전 정상본을 백업으로 남긴다.
- 보상은 지급 키를 저장한 뒤 화면에 반영해 중복 지급을 막는다.
- 저장 버전을 올린 릴리스는 낮은 버전으로 되돌리지 않는다.

## 백엔드와 보안 경계

- 서버가 없다. 판정, 보상, 광고 상한은 모두 기기에서 한다. 경쟁 보상이나 결제가 없으므로 조작으로 얻는 이득은 자기 기기의 코인뿐이다.
- 앱에 들어가는 외부 식별자: AdMob 앱 ID와 광고 단위 ID(공개 값), GA4 측정 ID와 Measurement Protocol 비밀값. 비밀값은 저장소에 넣지 않고 빌드할 때 로컬 자격증명에서 주입한다. 공개 저장소이므로 주입 파일은 추적하지 않는다.
- 업로드 서명 키는 로컬 자격증명 카탈로그(`app/four-alike/google-play/upload-key`)에만 있다. 인증서 SHA-256은 `C0:18:B0:2A:93:02:19:8A:15:0B:75:E8:1D:7A:2A:86:E1:D4:48:82:7B:F9:BC:C7:01:6C:EB:A4:A3:A2:3C:9F`다.
- 원격 설정 JSON은 공개 정적 파일이다. 앱은 값의 형과 범위를 검사하고 벗어나면 내장 기본값을 쓴다.

## 플랫폼 연동

| 연동 | 방식 | 대역 | 실제 확인 |
|---|---|---|---|
| 광고 | Poing Studios AdMob 플러그인 5.1.0. 보상형과 전면을 미리 불러 두고 포트의 결과(`earned`, `dismissed`, `failed`)로 돌려준다. 같은 조직의 선례 구현을 참고한다 | `tests`의 광고 대역(성공, 닫기, 실패, 준비 안 됨) | Android 실기기 AND-05~07 |
| 동의 | UMP SDK로 실행마다 동의 정보를 갱신하고 광고 요청 전 요청 가능 여부를 확인한다. 설정에 개인정보 선택 진입점 | 대역 | AND-05 |
| 분석 | GA4 Measurement Protocol HTTP 전송, 실패는 버림 | 메모리 기록 대역 | 내부 테스트 빌드에서 GA4 실시간 보고서 |
| 원격 설정 | 시작할 때 설정 JSON을 받아 캐시, 실패 시 내장 기본값 | 고정 값 대역 | 내부 테스트 빌드 |
| 진동 | 엔진의 기기 진동, 설정으로 끔 | 없음 | AND-08 |
| 뒤로 가기 | 공통 흐름의 처리에 제품 화면을 연결 | 여정 | AND-04 |

## 제작 단계

| 단계 | 플레이어가 볼 수 있는 결과 | 종료 기준 |
|---|---|---|
| 1 뼈대 | 세로 화면의 템플릿 게임이 뜬다 | `npm test`와 세 크기 캡처 검사 통과 |
| 2 규칙 코어 | 화면 없음 | 프로브 전부 통과, 팩 검증 통과 |
| 3 콘텐츠 | 화면 없음 | 원본 표 검사, 아이콘 800장, 모호함 목록 반영 뒤 팩 재생성 |
| 4 플레이 한 화면 | 고른 시안과 같은 플레이 화면에서 한 판을 끝낼 수 있다 | 기준 그림 비교 기록, 플레이 여정 통과 |
| 5 전체 흐름 | 타이틀, 튜토리얼, 홈, 결과, 일일 도전, 도감, 상점, 출석 | 첫 실행 여정과 메타 여정 통과 |
| 6 서비스 | 광고 대역으로 보상형과 전면, 분석, 원격 설정 | 광고 정책 프로브와 여정 통과, 수익화 프로필 검사 |
| 7 다듬기 | 소리, 진동, 연출, 꾸미기 | 필수 재료 게이트, 독립 검수 3회 |
| 8 출시 | 내부 테스트 설치본, 스토어 등록, 공개 | QA 문서의 론칭 게이트 |

단계마다 PR 하나 이상으로 나누고, 코드가 바뀐 PR은 로컬 모델 리뷰를 한 번 돌린 뒤 CI 통과로 병합한다.

## 빌드와 테스트 명령

| 목적 | 명령 |
|---|---|
| 전체 검사 | `npm test` |
| 화면 캡처 검사 | `python3 tools/check.py --capture --size 390x844 --out build/render-390` (693, 866 높이도 같은 방식) |
| 구조 검사 | `npm run check:architecture`, `python3 tools/bundle.py verify` |
| 콘텐츠 | `python3 tools/content/build_content.py --check` |
| 레벨 팩 | 생성기 headless 실행 뒤 `python3 tools/levels/verify_packs.py` |
| 그림과 소리 재생성 비교 | `python3 tools/art/build_candy_pop.py --check`, `python3 tools/audio/build_sfx.py --check` |
| 수익화 프로필 | 사내 프레임워크의 `validate_bm.py --strict` |
| UI 재료 게이트 | 사내 `ui_gate.py --root . --project godot --out docs/game-design/ui/gate-report.json` |
| Android 빌드 | `npm run build:android`(업로드 키와 분석 값은 로컬 자격증명에서 읽는다) |

CI는 PR과 main에서 `npm test`와 캡처 검사를 돌린다. 마켓 업로드는 로컬에서 실행하고 결과를 `release/`에 기록한다.
