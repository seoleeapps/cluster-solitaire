# 규칙 코어 안내

- 대상: 플레이 화면, 어댑터, 팩 운영을 맡는 작업자
- 범위: `godot/game/core`의 규칙과 유스케이스, `godot/data/content`와 `godot/data/levels`, `tools/levels`
- 규칙의 정본: [02 게임 디자인](02-gdd.md). 이 문서는 그 규칙을 코드에서 어떻게 부르는지와 데이터 형식을 적는다
- 작성일: 2026-11-21

규칙 코어는 화면 없이 한 판의 진행, 해법 탐색, 레벨 생성, 경제, 일일 도전, 광고 정책, 저장 모델을 모두 처리한다. 화면은 이 문서의 표에 있는 메서드만 부르면 되고, 파일과 광고 SDK, 시계는 포트를 구현한 어댑터로 연결한다.

## 구성과 의존 방향

| 폴더 | 내용 |
|---|---|
| `godot/game/core/domain` | 순수 규칙. `FaContent`, `FaBoard`, `FaSolver`, `FaDifficulty`, `FaGenerator`, `FaEconomy`, `FaDaily`, `FaAdPolicy`, `FaProgress`, `FaRandom`, `FaRoundMode` |
| `godot/game/core/ports` | 바깥과의 경계. `FaStorePort`, `FaAdsPort`, `FaAnalyticsPort`, `FaClockPort`, `FaConfigPort`. 기본 구현은 아무 일도 하지 않는다 |
| `godot/game/core/use_cases` | 화면이 부르는 조합. `FaLoadProgress`, `FaPickLevel`, `FaStartRound`, `FaFinishRound`, `FaUseBooster`, `FaAdFlow` |
| `godot/tests/game/fa_*_probe.gd` | 프로브 11개. `tools/check.py`가 모두 실행한다 |
| `tools/levels` | 팩 생성 도구(GDScript)와 검증 도구(Python) |

모든 클래스는 `RefCounted`이고 엔진 장면, 파일, 네트워크에 기대지 않는다. 의존은 유스케이스에서 도메인과 포트로만 향한다.

코어와 프로브는 서로를 `preload`로 부른다. 그래서 임포트 캐시가 없는 새 복제본에서도 프로브가 바로 돈다. 화면 코드에서는 `FaBoard` 같은 전역 클래스 이름을 써도 되지만, 그 이름은 에디터나 `godot --headless --path godot --import`가 한 번 돈 뒤에만 풀린다.

## 화면이 부르는 순서

```gdscript
# 앱 시작: 어댑터가 JSON 네 개와 저장을 읽어 넘긴다
var content := FaContent.new(items_doc, categories_doc)
var pick := FaPickLevel.new(content, journey_doc, daily_doc)
var progress: FaProgress = FaLoadProgress.new(store).execute()["progress"]
var ad_flow := FaAdFlow.new(store, ads, clock, config, analytics)
ad_flow.begin_session(progress)

# 판 시작 또는 이어하기
var start_round := FaStartRound.new(store, analytics)
var board: FaBoard = start_round.resume(progress)
if board == null:
	var found := pick.journey(progress.stage(), progress.recent_categories())
	board = start_round.start(progress, FaRoundMode.JOURNEY, progress.stage(), "", found["level"])

# 플레이: 판을 바꾼 뒤마다 저장한다
var outcome := board.submit(selected_cards)
start_round.checkpoint(progress, board, seconds_played)

# 판 종료
var result := FaFinishRound.new(store, analytics, clock).execute(progress, board, seconds_played)
```

일일 도전은 `pick.daily(clock.today())`로 레벨을 찾고 `start(progress, FaRoundMode.DAILY, 0, 날짜, level)`로 시작한다.

## 공개 API

결과 Dictionary의 열쇠는 모두 문자열이다. 카드는 item id 문자열, 범주는 category id 문자열이다. 돌려주는 배열과 Dictionary는 사본이라 고쳐도 내부 상태가 바뀌지 않는다(예외는 표에 적었다).

### FaContent (`domain/fa_content.gd`)

`FaContent.new(items_doc: Dictionary, categories_doc: Dictionary)`로 만든다. 형식이 틀린 항목은 색인하지 않고 `problems()`에 남긴다.

| 메서드 | 입력 | 반환 |
|---|---|---|
| `problems()` | 없음 | `PackedStringArray`. 한 줄은 `코드: 대상`. 코드는 `bad_document`, `bad_version`, `bad_item`, `duplicate_item`, `bad_category`, `duplicate_category`, `too_few_members`, `unknown_item`, `duplicate_member`. 비어 있으면 문제 없음 |
| `version()` | 없음 | `int`. 두 문서가 읽을 수 있는 버전이면 1, 아니면 0 |
| `item_ids()`, `category_ids()` | 없음 | `PackedStringArray`. 문서 순서 |
| `has_item(id)`, `has_category(id)` | `String` | `bool` |
| `item_name(id, language)`, `category_name(id, language)` | id, 언어 코드(`en`, `ko`) | `String`. 모르는 언어는 영어 이름, 없는 id는 `""` |
| `item_icon(id)` | `String` | `String`. 아이콘 열쇠 |
| `category_tier(id)` | `String` | `int`. 난도 1~4, 없는 범주는 0 |
| `category_domain(id)` | `String` | `String`. 대분류 |
| `category_members(id)` | `String` | `PackedStringArray`. 소속 카드 |
| `category_candidates(id)` | `String` | `PackedStringArray`. 소속과 `also`의 합 |
| `is_candidate(category_id, item_id)` | 두 id | `bool` |
| `categories_of_item(item_id)` | `String` | `PackedStringArray`. 이 카드를 후보로 가진 범주 |

`item_ids()`처럼 `PackedStringArray`를 돌려주는 조회는 색인을 그대로 주므로 고치지 않는다.

### FaBoard (`domain/fa_board.gd`)

상수: `GROUP_SIZE` 4, `MISTAKE_LIMIT` 4, `HOLD_SLOTS_BASE` 2, `HOLD_SLOTS_MAX` 3, `CONTINUE_RESTORE` 2. 위치의 `zone`은 `column`, `reserve`, `hold`다.

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaBoard.create(level, hold_slots)` | 레벨 Dictionary, 임시 칸 수(2~3) | `FaBoard`. 레벨 형식이 틀리면 `null` |
| `FaBoard.from_dict(data)` | `to_dict()`의 값(JSON에서 읽은 것도 됨) | `FaBoard`. 형식이나 카드가 맞지 않으면 `null` |
| `to_dict()` | 없음 | 판 상태 Dictionary(아래 데이터 형식) |
| `meta()` | 없음 | `{n, layout, tier, f}` |
| `categories()` | 없음 | `Array[String]`. 이 판의 범주(레벨 순서). 범주 이름은 완성 전까지 화면에 보이지 않아야 한다 |
| `group_items(category)` | `String` | `Array[String]`. 그 범주의 카드 4장 |
| `category_of(card)` | `String` | `String`. 이 판의 카드가 아니면 `""` |
| `column_count()` | 없음 | `int` |
| `column_size(column)` | 열 번호 | `int`. 남은 카드 수(열린 카드 포함) |
| `hidden_count(column)` | 열 번호 | `int`. 뒤집힌 카드 수 |
| `front_card(column)` | 열 번호 | `String`. 맨 앞 카드, 빈 열이면 `""` |
| `column_cards(column)` | 열 번호 | `Array[String]`. 뒤집힌 카드까지 전부. 해법 탐색과 검수에만 쓴다 |
| `reserve()` | 없음 | `Array[String]`. 자리를 유지하며 빈 자리는 `""` |
| `holds()` | 없음 | `Array[String]`. 길이가 임시 칸 수이고 빈 칸은 `""` |
| `slot_count()` | 없음 | `int`. 2 또는 3 |
| `open_cards()` | 없음 | `Array[Dictionary]`. 한 항목은 `{card, zone, index}`. 순서는 열, 예비 칸, 임시 칸 |
| `can_select(card)` | `String` | `bool`. 열려 있어 선택할 수 있는지 |
| `can_hold(card)` | `String` | `bool`. 지금 임시 칸으로 옮길 수 있는지 |
| `mistakes()` | 없음 | `int` |
| `solved()` | 없음 | `Array[String]`. 완성한 범주(완성 순서) |
| `remaining_groups()` | 없음 | `int` |
| `hold_moves()` | 없음 | `int`. 임시 칸으로 옮긴 횟수(되돌린 이동 제외) |
| `can_undo()`, `can_unlock_slot()`, `can_continue()` | 없음 | `bool`. 막힘 창과 실패 창에서 보여 줄 버튼을 정한다 |
| `continue_used()` | 없음 | `bool` |
| `is_won()`, `is_failed()`, `is_stuck()` | 없음 | `bool`. 실패는 실수 4회, 막힘은 완성할 묶음이 없고 임시 칸이 가득 찼거나 옮길 열이 없는 상태 |
| `hint_pair()` | 없음 | `Array[String]`. 열린 카드 중 같은 범주 2장, 없으면 빈 배열 |
| `submit(cards)` | 열린 카드 4장 | 아래 표 |
| `hold(card)` | 열 맨 앞 카드 | 성공 `{ok: true, card, column, slot, opened}`(`opened`는 새로 열린 카드, 없으면 `""`). 실패 `{ok: false, reason}`. reason은 `finished`, `failed`, `not_front`, `no_slot` |
| `undo()` | 없음 | 성공 `{ok: true, card, column, slot, closed}`(`closed`는 다시 뒤집힌 카드). 실패 `{ok: false, reason}`. reason은 `nothing`, `failed` |
| `unlock_slot()` | 없음 | `bool`. 판당 1회 |
| `apply_continue()` | 없음 | `bool`. 실패한 판에서 판당 1회, 실수를 2 줄인다 |

`submit`의 결과는 항상 `kind`, `mistakes`, `won`, `failed`를 담는다.

| `kind` | 뜻 | 더 담는 값 |
|---|---|---|
| `group` | 완성 | `category`, `removed`(사라진 카드 4장의 `{card, zone, index}`), `opened`(새로 열린 카드의 `{card, zone, index}`, 열 순서) |
| `one_away` | 3장만 같음. 실수 1 | 없음 |
| `miss` | 그 밖의 오답. 실수 1 | 없음 |
| `repeat` | 이미 낸 오답 조합. 실수가 늘지 않음 | 없음 |
| `invalid` | 받지 않은 입력. 실수가 늘지 않음 | `reason`: `finished`, `failed`, `count`, `not_open`, `duplicate` |

### FaSolver (`domain/fa_solver.gd`)

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaSolver.solve_board(board, slots)` | 판, 임시 칸 수 | `{solvable: bool, min_holds: int, forgiveness: float, next_hold: int}` |
| `FaSolver.solve(cols, reserve, held, slots)` | 묶음 번호(0부터의 정수)로 나타낸 열들, 예비 카드, 임시 칸 카드, 임시 칸 수 | 위와 같음 |

- `min_holds`: 끝내는 데 필요한 최소 임시 칸 이동 수. 풀 수 없으면 -1
- `forgiveness`: 임시 칸에 넣을 열을 균등 무작위로 골라도 끝까지 풀리는 확률(관대함)
- `next_hold`: 최소 해법에서 다음에 옮길 열 번호. 옮길 필요가 없거나 풀 수 없으면 -1
- 완성할 수 있는 묶음은 먼저 묶는다고 보고 계산한다. 막힌 길 안내는 `solve_board(board, board.slot_count())["solvable"]`이 `false`이고 `board.is_stuck()`도 `false`일 때다. 칸 추가가 도움이 되는지는 `slots`에 3을 넣어 본다

### FaDifficulty (`domain/fa_difficulty.gd`)

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaDifficulty.layout_ids()` | 없음 | `Array[String]`. `intro`, `open`, `step`, `classic`, `deep` |
| `FaDifficulty.layout(id)` | 배치 id | `{groups, columns, reserve}`. 없는 id면 빈 값 |
| `FaDifficulty.tier_rule(tier)` | 등급 1~5 | `{layouts, f_min, f_max, category_tier_max, domain_max, confusable_max, outside_max}`. 없는 등급이면 빈 값 |
| `FaDifficulty.journey_tier(stage)` | 스테이지 번호 | `int`. 등급 |
| `FaDifficulty.daily_tier(weekday)` | 요일(0 일요일~6 토요일) | `int`. 평일 3, 주말 4 |

### FaGenerator (`domain/fa_generator.gd`)

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaGenerator.generate(content, seed_value, tier, recent)` | 콘텐츠, 시드, 등급, 쓰지 않을 범주 목록 | `{ok: true, level}` 또는 `{ok: false, error}`. level은 `n`이 없는 레벨 |
| `FaGenerator.journey_level(content, stage, recent)` | 콘텐츠, 스테이지 번호, 쓰지 않을 범주 | 위와 같되 level에 `n`이 붙는다. 시드는 스테이지 번호 |
| `FaGenerator.daily_level(content, number, recent)` | 콘텐츠, 일일 도전 번호, 쓰지 않을 범주 | 위와 같음. 시드는 `2^24 + 번호`, 등급은 그 번호 날짜의 요일 |
| `FaGenerator.count_groupings(content, categories, cards, limit)` | 범주 목록, 카드 목록, 세기를 멈출 수 | `int`. 후보 기준으로 범주마다 4장씩 나누는 방법의 수 |

`error`는 `bad_tier`, `no_categories`(조건에 맞는 범주가 4개가 안 됨), `exhausted`(범주를 200번 다시 골라도 실패)다. 상수 `VERSION`(1), `JOURNEY_RECENT_LEVELS`(3), `DAILY_RECENT_LEVELS`(21)를 팩 도구와 저장 모델이 함께 쓴다.

### FaEconomy (`domain/fa_economy.gd`)

수치는 이 파일의 상수에만 있다. 보상은 `{"coins": 정수, "boosters": {부스터 id: 개수}}` 꼴이고 두 열쇠 모두 생략할 수 있다. 부스터 id는 `hint`, `undo`, `slot`이다.

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaEconomy.stars(mistakes, continued)` | 실수 수, 이어하기 사용 여부 | `int`. 실수 0은 3, 1~2는 2, 3 또는 이어하기는 1 |
| `FaEconomy.stage_reward(star_count)` | 별 수 | `int`. 10, 13, 16 |
| `FaEconomy.ad_bonus(base)` | 그 판에서 받은 코인 | `int`. 결과 광고로 더 받는 코인(같은 금액) |
| `FaEconomy.price(booster)` | 부스터 id | `int`. 힌트 100, 되돌리기 80, 칸 추가 150 |
| `FaEconomy.starter_gift()` | 없음 | 보상. 코인 200, 힌트 3, 되돌리기 3, 칸 추가 2 |
| `FaEconomy.booster_reward(booster)` | 부스터 id | 보상. 그 부스터 1개 |
| `FaEconomy.album_milestone(count)` | 도감의 범주 수 | `int`. 10개 단위면 50, 아니면 0 |
| `FaEconomy.attendance_reward(day)` | 주기 안의 날(0부터) | 보상. 20코인, 힌트 1, 30코인, 되돌리기 1, 40코인, 칸 추가 1, 60코인 |

그 밖의 상수: `DAILY_REWARD` 30, `ALBUM_NEW_CATEGORY` 5, `AD_MULTIPLIER` 2.

### FaDaily (`domain/fa_daily.gd`)

날짜는 현지 날짜 문자열 `YYYY-MM-DD`다. 기준일 `BASE_DATE`는 `2026-12-01`이고 그날이 1번이다.

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaDaily.is_date(text)` | `String` | `bool` |
| `FaDaily.add_days(date, days)` | 날짜, 날 수 | `String` |
| `FaDaily.days_between(from, to)` | 두 날짜 | `int` |
| `FaDaily.weekday(date)` | 날짜 | `int`. 0 일요일~6 토요일 |
| `FaDaily.same_month(a, b)` | 두 날짜 | `bool` |
| `FaDaily.challenge_number(date)` | 날짜 | `int`. 기준일 전이나 잘못된 날짜는 0 |
| `FaDaily.challenge_date(number)` | 번호 | `String` |
| `FaDaily.pack_number(number, pack_size)` | 번호, 팩 길이 | `int`. 팩에서 쓸 판 번호(1부터). 길이를 넘으면 순환 |
| `FaDaily.default_state()` | 없음 | `{results, streak, best, last}` |
| `FaDaily.state_from(raw)` | 저장에서 읽은 값 | 정리한 상태. 형식이 틀리면 빈 값 |
| `FaDaily.streak(state, today)` | 상태, 오늘 | `int`. 마지막 성공이 오늘이나 어제가 아니면 0 |
| `FaDaily.can_play(state, date, today)` | 상태, 풀 날짜, 오늘 | `bool`. 오늘과 이번 달의 지난 날 가운데 아직 성공하지 않은 날 |
| `FaDaily.record_success(state, date, today, summary)` | 상태(고쳐진다), 날짜, 오늘, 요약 `{mistakes, holds, seconds, order}` | `{recorded, counted, streak}`. 오늘의 판만 연속 기록에 넣는다 |

화면은 보통 `FaProgress`의 `can_play_daily`, `daily_streak`, `daily_result`를 쓴다.

### FaAdPolicy (`domain/fa_ad_policy.gd`)

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaAdPolicy.default_config()` | 없음 | 배치 설정(아래 데이터 형식) |
| `FaAdPolicy.remote_keys()` | 없음 | `Array[String]`. 원격 설정 열쇠 16개 |
| `FaAdPolicy.config_from(values)` | `{열쇠: 값}` | 덮어쓴 배치 설정. 형식이 틀리거나 범위를 벗어난 값은 기본값 |
| `FaAdPolicy.default_state()` | 없음 | 광고 상태 |
| `FaAdPolicy.state_from(raw)` | 저장에서 읽은 값 | 정리한 상태. 형식이 틀리면 빈 값 |
| `FaAdPolicy.can_show(config, state, placement, now, mode)` | 설정, 상태, 배치 id, 유닉스 초, 판 종류 | `{ok: bool, reason: String}` |
| `FaAdPolicy.roll_date(state, today)` | 상태(고쳐진다), 오늘 | `bool`. 날짜가 바뀌어 일 횟수를 0으로 돌렸으면 `true` |
| `FaAdPolicy.begin_session(state)` | 상태(고쳐진다) | 없음. 실행 번호를 올리고 실행 횟수를 비운다 |
| `FaAdPolicy.add_play_seconds(state, seconds)` | 상태(고쳐진다), 초 | 없음 |
| `FaAdPolicy.record_round_end(state)` | 상태(고쳐진다) | 없음 |
| `FaAdPolicy.record_shown(state, config, placement, now)` | 상태(고쳐진다), 설정, 배치 id, 유닉스 초 | 없음 |
| `FaAdPolicy.record_declined(state, now)` | 상태(고쳐진다), 유닉스 초 | 없음 |

`reason`은 판정 순서대로 `unknown_placement`, `disabled`, `tutorial`, `daily_challenge`, `first_session`, `play_time`, `daily_cap`, `session_cap`, `cooldown`, `rounds`, `after_rewarded`이고 허용이면 `""`다. 화면은 이 함수들을 직접 부르지 않고 `FaAdFlow`를 쓴다.

### FaProgress (`domain/fa_progress.gd`)

| 메서드 | 입력 | 반환 |
|---|---|---|
| `FaProgress.create()` | 없음 | 새 저장 |
| `FaProgress.read(raw)` | 저장에서 읽은 값 | `{status, progress}`. status는 `ok`, `upgraded`, `newer`, `corrupt`. 뒤의 둘은 progress가 `null` |
| `FaProgress.upgrade(data, steps, target)` | 저장 Dictionary, `{이전 버전: 올리는 함수}`, 목표 버전 | 올린 사본. 올리지 못하면 빈 값 |
| `to_dict()` | 없음 | 저장할 Dictionary |
| `coins()`, `booster(id)` | 없음, 부스터 id | `int` |
| `grant(key, reward)` | 중복 지급 방지 열쇠, 보상 | `bool`. 같은 열쇠로 이미 줬거나 보상 형식이 틀리면 `false`이고 아무것도 바뀌지 않는다 |
| `has_grant(key)` | 열쇠 | `bool` |
| `add_reward(reward)` | 보상 | `bool`. 열쇠 없이 더한다 |
| `spend_coins(amount)` | 코인 | `bool` |
| `use_booster(id)` | 부스터 id | `bool`. 1개를 쓴다 |
| `buy_booster(id)` | 부스터 id | `bool`. 정가로 1개를 산다 |
| `owns_theme(id)`, `buy_theme(id, price)` | 테마 id, 가격 | `bool` |
| `selected_theme(kind)` | 종류(카드 뒷면, 테이블 등 화면이 정한 이름) | `String`. 고르지 않았으면 `""`(기본 테마) |
| `select_theme(kind, id)` | 종류, 가진 테마 id 또는 `""` | `bool` |
| `stage()` | 없음 | `int`. 지금 풀 차례인 스테이지 |
| `best_stars(stage_number)` | 스테이지 번호 | `int`. 깬 적이 없으면 0 |
| `clear_stage(stage_number, star_count, categories)` | 스테이지, 별, 그 판의 범주 | `bool`. 지금 풀 차례인 스테이지를 처음 깨 다음이 열렸으면 `true` |
| `recent_categories()` | 없음 | `Array[String]`. 최근에 처음 깬 3판의 범주 |
| `has_run()`, `run()` | 없음 | `bool`, 진행 중인 판 `{mode, stage, date, seconds, board}` 또는 빈 값 |
| `set_run(mode, stage_number, date, seconds, board)` | 판 종류, 스테이지, 날짜, 걸린 초, 판 | `bool` |
| `update_run(board, seconds)` | 판, 걸린 초 | `bool`. 진행 중인 판의 상태와 시간만 고친다 |
| `clear_run()` | 없음 | 없음 |
| `can_play_daily(date, today)` | 날짜, 오늘 | `bool` |
| `record_daily_success(date, today, summary)` | 날짜, 오늘, 요약 | `{recorded, counted, streak}` |
| `daily_result(date)` | 날짜 | 요약 `{mistakes, holds, seconds, order}` 또는 빈 값 |
| `daily_streak(today)`, `daily_best()` | 오늘, 없음 | `int` |
| `register_album(category, items)` | 범주, 본 카드 | `bool`. 처음 등록한 범주면 `true` |
| `album_count()`, `album_categories()`, `album_items(category)` | 없음, 없음, 범주 | `int`, `Array[String]`, `Array[String]` |
| `attendance_day()` | 없음 | `int`. 주기 안에서 다음에 받을 날(0~6) |
| `can_claim_attendance(today)` | 오늘 | `bool` |
| `claim_attendance(today)` | 오늘 | 받은 보상, 받을 수 없으면 빈 값 |
| `ads()` | 없음 | 광고 상태. 사본이 아니라 저장 안의 값 그대로다 |
| `roll_date(today)` | 오늘 | `bool`. 날짜가 바뀌어 광고의 일 횟수를 0으로 돌렸으면 `true` |
| `flag(name)`, `set_flag(name, on)` | 표시 이름 | `bool`, 없음. 튜토리얼 완료는 `FaProgress.FLAG_TUTORIAL_DONE` |

`FaProgress`의 메서드는 메모리의 값만 바꾼다. 파일에 쓰는 일은 유스케이스가 저장 포트로 한다. 화면이 `claim_attendance`나 `buy_theme`처럼 유스케이스 없이 바꾼 뒤에는 `store.write(progress.to_dict())`를 직접 부른다.

### 포트 (`ports/`)

| 포트 | 메서드 | 입력 | 반환 |
|---|---|---|---|
| `FaStorePort` | `read(slot)` | `main` 또는 `backup` | `{found: bool, data}`. data는 JSON으로 읽은 값, 읽지 못했으면 `null` |
| | `write(data)` | 저장 Dictionary | `bool`. 구현은 쓰기 전의 저장을 `backup`으로 남긴다 |
| `FaAdsPort` | `is_ready(format)` | `rewarded` 또는 `interstitial` | `bool` |
| | `request(format)` | 형식 | 없음. 미리 불러온다 |
| | `show(format, on_result)` | 형식, 결과를 받을 함수 | 없음. `on_result`를 `earned`, `dismissed`, `failed` 중 하나와 함께 한 번 부른다 |
| | `privacy_choice_required()` | 없음 | `bool` |
| | `open_privacy_choice()` | 없음 | 없음 |
| `FaAnalyticsPort` | `log_event(name, params)` | 이벤트 이름, 매개변수 | 없음 |
| `FaClockPort` | `now_unix()` | 없음 | `int`. 유닉스 초 |
| | `today()` | 없음 | `String`. 현지 날짜 |
| `FaConfigPort` | `value(key)` | 원격 설정 열쇠 | 값. 받지 못했으면 `null` |

### 유스케이스 (`use_cases/`)

| 유스케이스 | 메서드 | 입력 | 반환 |
|---|---|---|---|
| `FaLoadProgress.new(store)` | `execute()` | 없음 | `{progress, origin, reset}`. origin은 `main`, `backup`, `new`. `reset`이 `true`면 저장을 쓸 수 없어 새로 시작했다는 뜻이라 화면이 알린다 |
| `FaPickLevel.new(content, journey_pack, daily_pack)` | `problems()` | 없음 | `PackedStringArray`. 쓸 수 없는 팩은 `bad_pack: journey` 꼴 |
| | `journey_size()`, `daily_size()` | 없음 | `int` |
| | `journey(stage, recent)` | 스테이지, 팩 뒤의 판을 만들 때 피할 범주 | `{ok: true, level}` 또는 `{ok: false, error}`. error는 `bad_stage`와 생성기의 오류 |
| | `daily(date)` | 날짜 | `{ok: true, level, number}` 또는 `{ok: false, error}`. error는 `bad_date`, `no_pack` |
| `FaStartRound.new(store, analytics)` | `start(progress, mode, stage, date, level)` | 저장, 판 종류, 스테이지, 날짜, 레벨 | `FaBoard`. 레벨이 틀리거나 아직 열리지 않은 스테이지, 잘못된 날짜면 `null` |
| | `resume(progress)` | 저장 | `FaBoard`. 진행 중인 판이 없으면 `null` |
| | `checkpoint(progress, board, seconds)` | 저장, 판, 이 판에 쓴 초 | `bool`. 저장했는지 |
| | `abandon(progress)` | 저장 | 없음. 다시 하기와 나가기 |
| `FaFinishRound.new(store, analytics, clock)` | `execute(progress, board, seconds)` | 저장, 끝난 판, 걸린 초 | 아래 설명 |
| `FaUseBooster.new(store, analytics)` | `execute(progress, board, booster, pay_coins)` | 저장, 판, 부스터 id, 보유분이 없을 때 코인으로 살지 | 아래 설명 |
| `FaAdFlow.new(store, ads, clock, config, analytics)` | `begin_session(progress)` | 저장 | 없음. 앱 실행마다 한 번 |
| | `add_play_time(progress, seconds)` | 저장, 플레이한 초 | 없음 |
| | `check(progress, placement, mode)` | 저장, 배치 id, 판 종류 | `{ok, reason}`. `FaAdPolicy`의 사유에 `not_ready`가 더해진다 |
| | `decline(progress)` | 저장 | 없음. 보상형 제안을 거절했을 때 |
| | `finish_interstitial(progress, result)` | 저장, 광고 결과 | 없음 |
| | `finish_booster(progress, result, booster)` | 저장, 광고 결과, 부스터 id | `bool`. 부스터 1개를 줬는지 |
| | `finish_continue(progress, result, board)` | 저장, 광고 결과, 실패한 판 | `bool`. 이어 갔는지 |
| | `finish_bonus(progress, result, bonus)` | 저장, 광고 결과, 정산 결과의 `bonus` | `bool`. 코인을 줬는지 |

`FaFinishRound.execute`는 진행 중인 판이 없으면 `{ok: false, reason: "no_run"}`, 판이 끝나지 않았으면 `{ok: false, reason: "not_won"}`을 돌려준다. 정산하면 다음 값을 돌려준다.

| 열쇠 | 값 |
|---|---|
| `ok`, `mode`, `stars`, `mistakes` | `true`, 판 종류, 별, 실수 수 |
| `coins` | 이 판으로 받은 코인. 여정은 처음 깬 스테이지만, 일일 도전은 처음 성공한 날짜만 받는다. 튜토리얼은 시작 선물의 코인 |
| `bonus` | 결과 광고를 끝까지 보면 더 받을 `{key, coins}`. 받을 것이 없으면 빈 값 |
| `album` | `{new: 새로 등록한 범주, coins: 도감으로 받은 코인}` |
| `saved` | 저장했는지 |
| 여정만 | `first_clear`, `next_stage` |
| 일일 도전만 | `recorded`, `counted`, `streak` |
| 튜토리얼만 | `gift`. 받은 시작 선물, 이미 받았으면 빈 값 |

`FaUseBooster.execute`는 쓰지 못하면 `{ok: false, reason}`을 돌려준다. reason은 `no_run`, `daily`(일일 도전), `unknown`, `no_effect`(쓸 상황이 아님), `no_stock`(보유분이 없고 `pay_coins`가 `false`), `no_coins`다. 쓰면 `{ok: true, booster, paid, saved}`에 효과가 붙는다. `paid`는 `stock` 또는 `coins`다.

| 부스터 | 더 담는 값 |
|---|---|
| `hint` | `pair`(같은 범주 2장, 짝이 없으면 빈 배열), `column`(짝이 없을 때 다음에 옮길 열, 짝이 있으면 -1) |
| `undo` | `card`, `column`, `slot`, `closed` |
| `slot` | `slots`. 늘어난 임시 칸 수 |

분석 이벤트는 유스케이스가 보낸다: `level_start`, `level_end`, `earn_virtual_currency`, `spend_virtual_currency`, `use_booster`, `ad_result`.

## 데이터 형식

### 콘텐츠 (`godot/data/content`)

```json
{"version": 1, "items": [{"id": "banana", "icon": "banana", "en": "Banana", "ko": "바나나"}]}
```

```json
{"version": 1, "categories": [{"id": "fruits", "tier": 1, "domain": "food", "en": "Fruits", "ko": "과일",
  "members": ["banana", "grapes"], "also": []}]}
```

범주의 후보는 `members`와 `also`의 합이다. `members`는 4장 이상이어야 하고 `tier`는 1~4다.

### 레벨과 팩 (`godot/data/levels`)

```json
{"version":1,"content_version":1,"generator":1,"levels":[
{"n":1,"layout":"open","tier":1,"f":1.0,"groups":[{"cat":"beach","items":["thong_sandal","tropical_drink","ring_buoy","sunglasses"]},{"cat":"boats","items":["sailboat","speedboat","passenger_ship","ferry"]},{"cat":"tools","items":["toolbox","pick","axe","screwdriver"]},{"cat":"electronics","items":["mobile_phone","television","battery","radio"]}],"cols":[["television","sunglasses"],["axe","speedboat"],["battery","screwdriver"],["tropical_drink","ring_buoy"]],"reserve":["ferry","toolbox","thong_sandal","mobile_phone","radio","pick","sailboat","passenger_ship"]}
]}
```

- 파일은 머리말 한 줄, 판마다 한 줄, 닫는 줄로 이뤄진다. 판마다 한 줄이라 바뀐 판만 차이로 보인다
- `cols`의 각 배열은 뒤에서 앞 순서이고 마지막 원소가 열린 카드다
- `f`는 임시 칸 2개 기준 관대함을 소수 둘째 자리로 반올림한 값이다
- `journey.json`은 스테이지 1~600, `daily.json`은 일일 도전 1~1100번이다

### 판 상태 (`FaBoard.to_dict()`, 저장의 `run.board`)

```json
{"n": 7, "layout": "classic", "tier": 3, "f": 0.31,
 "groups": [{"cat": "A", "items": ["a1", "a2", "a3", "a4"]}],
 "cols": [["b1", "c1"], ["d1", "b2", "a2"]], "reserve": ["", "b4", "c4", "d4"], "holds": ["a1", "", ""],
 "mistakes": 1, "solved": ["A"], "undo": {"card": "a1", "column": 0, "slot": 0},
 "continued": false, "tried": ["a1|a2|a3|b3"], "hold_moves": 1}
```

위 값은 열쇠를 보여 주려는 예시라 카드 수는 맞지 않는다. `holds`의 길이가 3이면 3번째 칸을 연 판이다. `undo`는 되돌릴 이동이 없으면 빈 Dictionary다. `tried`는 낸 오답 조합이고 카드 id를 정렬해 `|`로 이은 글자다.

### 저장 (`FaProgress.to_dict()`)

```json
{"version": 1,
 "profile": {"coins": 170, "boosters": {"hint": 3, "undo": 3, "slot": 2}, "themes": ["card_back_mint"], "selected": {"card_back": "card_back_mint"}},
 "journey": {"stage": 3, "stars": {"1": 3, "2": 2}, "recent": [["fruits", "birds", "tools", "planets"], ["boats", "trees", "bakery", "weather"]]},
 "run": {"mode": "journey", "stage": 3, "date": "", "seconds": 42, "board": {}},
 "daily": {"results": {"2026-12-01": {"mistakes": 1, "holds": 4, "seconds": 120, "order": ["a", "b", "c", "d"]}}, "streak": 1, "best": 1, "last": "2026-12-01"},
 "album": {"fruits": ["banana", "lemon", "grapes", "peach"]},
 "attendance": {"last": "2026-12-01", "day": 1},
 "ads": {"date": "2026-12-01", "daily": {"rewarded_booster": 1}, "session": {"rewarded_booster": 1}, "last": {"rewarded_booster": 1800000000},
         "session_no": 1, "play_seconds": 0, "rounds_since_interstitial": 0, "rewarded_at": 1800000000, "declined_at": 0},
 "flags": {"tutorial_done": true},
 "grants": {"starter_gift": true, "attendance:2026-12-01": true}}
```

- `run`은 진행 중인 판이 없으면 빈 Dictionary다. 예시의 `board`는 줄였고 실제로는 위의 판 상태가 들어간다
- `flags`와 `grants`는 켜진 것만 `true`로 담는다
- 지급 열쇠: `starter_gift`, `stage:<번호>`, `stage_bonus:<번호>`, `daily:<날짜>`, `daily_bonus:<날짜>`, `album:<범주>`, `album_count:<개수>`, `attendance:<날짜>`
- 읽을 때 묶음 하나라도 형식이 틀리면 `corrupt`다. JSON에서 실수로 읽힌 정수는 정수로 되돌린다
- 형식을 바꿀 때는 `VERSION`을 올리고 `FaProgress._upgrade_steps()`에 이전 버전에서 올리는 함수를 더한다. 버전 1은 첫 형식이라 단계가 없다

### 광고 설정과 원격 설정

| 배치 id | 형식 | `cooldown_s` | `session_cap` | `daily_cap` | `first_session` | `first_play_seconds` |
|---|---|---|---|---|---|---|
| `rewarded_booster` | rewarded | 30 | 2 | 5 | 1 | 0 |
| `rewarded_continue` | rewarded | 60 | 1 | 2 | 1 | 0 |
| `rewarded_result_bonus` | rewarded | 60 | 1 | 3 | 1 | 0 |
| `interstitial_level_end` | interstitial | 120 | 3 | 8 | 2 | 180 |

전면에는 `completion_interval` 2(직전 전면 뒤 끝나야 하는 판 수)와 `rewarded_gap_s` 120(보상형을 보거나 거절한 뒤 비워 둘 초)이 더 있다. 튜토리얼에서는 모든 배치를, 일일 도전에서는 `rewarded_booster`, `rewarded_continue`, `interstitial_level_end`를 막는다.

원격 설정은 `<배치 id>_<필드>` 꼴의 열쇠 16개다. 필드는 `enabled`(참 거짓), `cooldown_s`, `session_cap`, `daily_cap`이다. 예: `interstitial_level_end_enabled`, `rewarded_booster_daily_cap`. 숫자는 0부터 받고, 간격은 기본값의 4배와 600초 중 큰 값까지, 상한은 기본값의 2배까지 받는다. 그 밖의 값은 기본값을 쓴다. 최초 조건과 판 수 조건은 원격으로 바꿀 수 없다.

## 팩 재생성과 검증

지금 실린 팩은 `also`가 비어 있는 초안 콘텐츠로 만들었다. `godot/data/content`의 두 파일이 바뀌면 팩을 다시 만들고 아래 통계도 다시 적는다. 생성기의 결과가 달라지게 고쳤을 때도 `FaGenerator.VERSION`을 올리고 다시 만든다.

```bash
# 1. 다시 만든다(저장소 루트에서)
godot --headless --path godot --script res://../tools/levels/generate_packs.gd

# 2. 참고용 Python 탐색기로 모든 판을 다시 검사한다. 불일치가 있으면 종료 코드 1
python3 tools/levels/verify_packs.py

# 3. 통계를 다시 뽑아 이 문서에 옮긴다
python3 tools/levels/verify_packs.py --stats

# 실린 파일이 생성 결과와 바이트까지 같은지만 확인할 때
godot --headless --path godot --script res://../tools/levels/generate_packs.gd -- --check
```

- `generate_packs.gd`는 Godot 프로젝트 밖(`tools/levels`)에 있고 `res://../` 경로로 실행한다. 프로젝트 안의 코어를 `preload`로 그대로 쓴다
- 여정은 직전 3판, 일일 도전은 직전 21일(범주 84개)의 범주를 다시 쓰지 않는다
- 같은 콘텐츠로 다시 돌리면 같은 파일이 나온다. `fa_packs_probe.gd`도 두 팩을 전부 다시 만들어 글자 단위로 대조한다
- `verify_packs.py`는 등급표와 배치를 GDD에서 따로 옮겨 적어 GDScript 구현과 독립으로 본다. 탐색기는 `tools/levels/reference_solver.py`(설계 단계 프로토타입을 옮긴 것)다
- `tools/levels/solver_fixtures.py`는 `fa_solver_probe.gd`에 박아 넣은 기대값 표를 만든다

## 생성 통계

2026-11-21, 초안 콘텐츠(카드 845장, 범주 164개, `also` 없음), Godot 4.7.2, Apple M3 기준이다. 생성에는 여정 0.5초, 일일 도전 1.1초가 걸렸고 Python 검증은 1.2초가 걸렸다. 두 팩 모두 불일치 0건이다.

### 여정 600판

| 등급 | 판 수 | 배치 | 관대함 최소 | 중앙값 | 최대 | 다른 범주로도 보이는 카드가 든 판 |
|---|---|---|---|---|---|---|
| T1 | 8 | open 8 | 1.000 | 1.000 | 1.000 | 0 |
| T2 | 82 | step 82 | 0.453 | 0.556 | 0.854 | 0 |
| T3 | 159 | classic 159 | 0.250 | 0.340 | 0.583 | 0 |
| T4 | 252 | classic 127, deep 125 | 0.100 | 0.156 | 0.299 | 24 |
| T5 | 99 | deep 99 | 0.042 | 0.062 | 0.120 | 10 |

### 일일 도전 1,100판

| 등급 | 판 수 | 배치 | 관대함 최소 | 중앙값 | 최대 | 다른 범주로도 보이는 카드가 든 판 |
|---|---|---|---|---|---|---|
| T3 | 786 | classic 786 | 0.250 | 0.328 | 0.594 | 0 |
| T4 | 314 | classic 162, deep 152 | 0.101 | 0.156 | 0.292 | 51 |

### 범주 사용

두 팩에서 범주를 6,800회 썼고 164개 가운데 162개가 한 번 이상 나왔다.

| 순위 | 범주 | 난도 | 대분류 | 횟수 |
|---|---|---|---|---|
| 1 | `athletes` | 1 | sport | 56 |
| 2 | `two_wheels` | 2 | transport | 56 |
| 3 | `trees` | 1 | plant | 54 |
| 4 | `bakery` | 1 | food | 53 |
| 5 | `hand_signs` | 1 | people | 52 |
| 6 | `aircraft` | 1 | transport | 51 |
| 7 | `forest_animals` | 2 | animal | 50 |
| 8 | `boats` | 1 | transport | 49 |
| 9 | `vegetables` | 1 | food | 49 |
| 10 | `weather` | 1 | sky | 49 |

가장 적게 쓰인 범주는 `with_a_hole` 16회, `night_animals` 17회, `fairy_tale` 21회, `slow_movers` 21회, `lucky` 22회, `zodiac` 25회, `ringers` 26회, `tracks` 27회다. 여덟 개 모두 난도 4라서 T4와 T5 판에만 나올 수 있다.

| 한 번도 안 쓰인 범주 | 난도 | 소속 수 | 이유 |
|---|---|---|---|
| `banknotes` | 3 | 4 | 소속 4장이 모두 `money`의 소속이다. `money`가 판에 없으면 판 밖 범주의 후보 4장이 되어 한도(3장)를 넘고, `money`가 판에 있으면 4장 모두 다른 범주로도 보이는 카드가 되어 한도(최대 2장)를 넘는다 |
| `face_parts` | 2 | 6 | 소속 6장이 모두 `body_parts`의 소속이라 같은 이유로 고를 수 없다 |

## 설계 문서에 없어 여기서 정한 것

| 항목 | 정한 내용 | 이유 |
|---|---|---|
| 난수 | `FaRandom`(Mulberry32)을 따로 뒀다 | 엔진 난수기는 버전이 바뀌면 값이 달라질 수 있다. 601판부터 기기에서 만들 때도 같은 결과가 나와야 한다 |
| 시드 | 여정은 스테이지 번호, 일일 도전은 `2^24 + 번호` | 두 팩이 같은 번호에서 같은 판을 내지 않게 한다 |
| 601판 이후의 최근 범주 | 저장의 `journey.recent`에 최근에 처음 깬 3판의 범주를 두고 `FaPickLevel.journey`에 넘긴다 | 팩 밖에서는 앞 판을 다시 만들지 않고는 최근 범주를 알 수 없다 |
| 헷갈리는 카드 | T4와 T5에서 한도까지 허용만 하고 일부러 넣지는 않는다 | GDD가 상한만 정했다. 지금 콘텐츠로는 T4의 약 13%, T5의 10% 판에 들어간다 |
| 광고 설정 열쇠 | `cooldown_s`, `session_cap`, `daily_cap`과 `<배치 id>_<필드>` 원격 열쇠, 범위 규칙 | 사내 수익화 프로필(`bm-profile.json`)의 배치 필드와 원격 설정 생성 규칙에 맞췄다. 프로필이 생기면 그 값이 정본이다 |
| 일일 도전의 광고 | 결과 2배 광고는 허용, 나머지 배치는 금지 | GDD는 부스터와 이어하기, 전면만 막았다 |
| 끝난 판 수 | 클리어한 여정과 일일 도전 판만 센다. 버린 판과 튜토리얼은 세지 않는다 | 실패하고 다시 하기를 되풀이할 때 전면 광고가 앞당겨지지 않게 한다 |
| 스테이지 코인 | 스테이지를 처음 깼을 때만 준다 | 같은 스테이지를 되풀이해 코인을 모으는 길을 막는다 |
| 지난 날짜의 일일 도전 | 코인 30은 주고 연속 기록에만 넣지 않는다 | GDD는 연속 기록만 정했다 |
| 출석 | 날을 건너뛰어도 7일 주기가 이어진다 | GDD에 끊김 규칙이 없다 |
| 시계가 뒤로 간 경우 | 광고 간격은 지난 것으로 본다 | 기기 시간을 되돌렸을 때 보상형 버튼이 오래 막히지 않게 한다 |
| 진행 중인 판의 검증 | 저장을 읽을 때 `run.board`까지 확인하고 틀리면 저장 전체를 `corrupt`로 본다 | 직전 백업은 보통 한 수 전의 온전한 상태다 |
| 유스케이스 추가 | `FaLoadProgress`, `FaPickLevel` | 백업 복구 순서와 팩 순환은 규칙이라 코어에 둬야 프로브로 검증된다 |

## 화면과 어댑터에서 알아둘 점

- 선택 상태(최대 4장, 다시 누르면 해제)는 화면이 들고 있다가 `submit`에 넘긴다. 코어는 `can_select`와 `submit`의 `invalid`로만 확인한다
- 예비 칸과 임시 칸은 자리를 유지한다. 카드가 빠진 자리는 `""`이고 남은 카드가 당겨지지 않는다
- `submit`, `hold`, `undo`, `unlock_slot`, `apply_continue`로 판을 바꾼 뒤에는 `FaStartRound.checkpoint`를 부른다. `FaUseBooster`와 `FaAdFlow.finish_continue`는 스스로 저장한다
- 막힘 창은 `is_stuck()`, 실패 창은 `is_failed()`로 띄우고, 보여 줄 버튼은 `can_undo()`, `can_unlock_slot()`, `can_continue()`로 정한다
- 3번째 칸은 `FaBoard` 안에만 있어서 다음 판을 `start`하면 다시 2칸이다
- 걸린 시간은 화면이 재서 `checkpoint`와 `FaFinishRound.execute`에 넘긴다. 전면 광고의 누적 플레이 조건은 `FaAdFlow.add_play_time`으로 쌓는다
- 광고는 `check`로 확인하고, 포트의 `show`로 보여 주고, 결과를 `finish_*`에 넘기는 세 단계다. 보상은 `earned`일 때만 주며 `finish_*`는 한 번의 `show`에 한 번만 부른다
- 보유분이 없으면 `FaUseBooster.execute(progress, board, booster, false)`가 `no_stock`을 돌려준다. 그때 코인 구매(`pay_coins`를 `true`로 다시 호출)나 광고(`rewarded_booster` 뒤 다시 호출)를 물어본다
- 결과 창의 2배 버튼은 정산 결과의 `bonus`가 비어 있지 않고 `check`가 허용할 때만 보인다
- 팩과 저장은 JSON에서 읽은 Dictionary를 그대로 넘기면 된다. 숫자가 실수로 읽혀도 코어가 정수로 바꾼다
- 튜토리얼 판(`intro` 배치, 범주 3개)의 레벨은 아직 없다. `FaBoard`와 `FaSolver`는 범주 3개 판도 처리하고, `FaStartRound.start`의 판 종류 `tutorial`과 정산의 시작 선물은 준비돼 있다
- 일일 도전 팩은 1,100일 뒤 처음으로 돌아간다. 1,100은 7의 배수가 아니라서 그때부터는 판의 등급과 실제 요일이 하루씩 어긋난다. 순환 경계에서는 21일 재사용 금지도 확인하지 않는다. 그 전에 팩을 늘려야 한다
