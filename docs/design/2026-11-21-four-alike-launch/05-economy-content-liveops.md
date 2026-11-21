# 경제 콘텐츠 라이브옵스

- 문서 상태: approved
- 승인 근거: 사용자 질문 응답 2026-11-21 (DEC-002 광고 전용, DEC-011 코인 가격 제안 포함 설계 승인)
- Source of truth: 재화 수치, 콘텐츠 재고와 생산 방식, 수익화 카탈로그, 원격 설정 기본값

수치는 모두 출시 전 가설이다. 코드의 정본은 `godot/game/core/domain/fa_economy.gd`, 광고의 정본은 `godot/data/monetization/bm-profile.json`이다.

## 재화 Source와 Sink

재화는 코인 하나이고 팔지 않는다. 부스터 세 종류는 개수로 보유한다.

| Source | 양 | 빈도 |
|---|---|---|
| 스테이지 클리어 | 10 + 별 보너스(별 1·2·3에 0·3·6) | 판마다 |
| 결과 2배(보상형) | 그 판 코인만큼 추가 | 실행당 1회, 하루 3회 |
| 일일 도전 성공 | 30 | 하루 1회 |
| 출석 | 7일 주기: 20, 힌트 1, 30, 되돌리기 1, 40, 칸 추가 1, 60 | 하루 1회 |
| 도감 | 새 범주 5, 10개 단위 달성 50 | 범주 164개까지(합계 1,620) |
| 시작 선물 | 코인 200, 힌트 3, 되돌리기 3, 칸 추가 2 | 튜토리얼 완료 1회 |
| 부스터 충전(보상형) | 힌트·되돌리기 1개 또는 이번 판 칸 추가 | 실행당 2회, 하루 5회 |

| Sink | 값 |
|---|---|
| 힌트 | 100 |
| 되돌리기 | 80 |
| 칸 추가 | 150 |
| 카드 뒷면 3종 | 600, 900, 1,200 |
| 배경 3종 | 800, 1,200, 1,600 |

꾸미기 6종의 합은 6,300 코인이다. 하루 6판 이용자가 부스터를 사지 않고 모으면 약 40일이 걸린다.

## 밸런스 모델

난도는 배치와 관대함으로 정한다. 관대함은 임시 칸에 넣을 열을 무작위로 골라도 끝까지 풀리는 확률이다.

| 등급 | 배치 | 관대함 | 목표 클리어율(부스터 없이 첫 시도, 가설) | 판당 막힘 횟수 가정 |
|---|---|---|---|---|
| T1 | open | 0.90 이상 | 95% | 0.05 |
| T2 | step | 0.45 ~ 0.90 | 85% | 0.20 |
| T3 | classic | 0.25 ~ 0.60 | 70% | 0.40 |
| T4 | classic, deep | 0.10 ~ 0.30 | 55% | 0.55 |
| T5 | deep | 0.04 ~ 0.12 | 40% | 0.70 |

코인은 가벼운 이용자의 부스터 수요를 모두 채우고, 자주 하는 이용자에게는 일부만 채워 광고와 다시 하기 중에서 고르게 한다. 무료 길(코인, 다시 하기)은 항상 남는다.

## 보상 일정

| 시점 | 받는 것 | 목적 |
|---|---|---|
| 튜토리얼 완료 | 시작 선물 | 부스터를 써 볼 여유 |
| 스테이지 3, 6, 8 | 부스터를 한 번씩 써 보게 안내(보유분 사용) | 쓰임새 학습 |
| 매 판 | 코인과 별 | 기본 진행 |
| 매일 | 출석, 일일 도전 | 재방문 |
| 범주 10개마다 | 코인 50 | 수집 동기 |
| 일일 도전 7일 연속 | 코인 100 | 연속 기록 |

## 콘텐츠 재고

| 항목 | 출시 재고 | 근거 |
|---|---|---|
| 범주 | 164개(난도 1: 47, 2: 63, 3: 46, 4: 8) | 원본 표 `content/source/categories.tsv` |
| 카드 | 845장, 영어와 한국어 이름 | `content/source/items.tsv` |
| 여정 스테이지 | 600판 사전 생성, 601부터 기기 생성 | 생성기와 팩 검증 도구 |
| 일일 도전 | 1,100일(약 3년) | 최근 21일 범주 재사용 금지 |
| 꾸미기 | 카드 뒷면 4, 배경 4 | 생성 스크립트 색 변형 |

범주 164개에서 대분류 조건을 지켜 4개를 고르는 조합은 수천만 가지이고 카드 선택과 배치가 곱해지므로, 판 재고는 사실상 범주와 카드의 품질에 달려 있다.

## 콘텐츠 생산 예산

| 작업 | 방식 | 비용 |
|---|---|---|
| 범주와 카드 초안 | 에이전트가 Fluent Emoji 목록에서 구성 | 사람 시간 0, 에이전트 실행 |
| 이름 작성 | 에이전트 3개가 그림을 보며 영어·한국어 이름 작성(845장), 부적합 48장 제외 | 에이전트 실행 |
| 모호함 검수 | 별도 에이전트 2개가 범주마다 "그 범주로도 보일 수 있는 카드" 목록 작성 | 에이전트 실행 |
| 판 생성과 검증 | 생성기와 Python 대조 검증 | 자동 |
| 범주 추가(출시 뒤) | 원본 표에 행을 더하고 같은 절차를 돌린 뒤 새 버전으로 낸다. 기존 일일 도전 팩은 바꾸지 않는다 | 범주 10개에 에이전트 실행 1회 |
| 문제 범주 내리기 | 원본 표에서 빼고 팩을 다시 만든다 | 자동 |

사람의 표본 검수(생성 판 200개를 범주 이름을 가리고 풀어 모호한 카드 표시)는 리서치의 가설 H-03에 따라 출시 뒤 첫 개선 주기에 넣는다. 출시 전에는 독립 검수 회차의 플레이와 에이전트 검수로 대신하고, 그 한계를 QA 문서에 적는다.

## 수익화 카탈로그

<!-- bm:ads:start -->
| 배치 | 형식 | 트리거 | 최초 노출 | 쿨다운 | 세션/일 상한 | 기본 상태 | 허들 | 원격 키 | 이벤트 |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| `interstitial_level_end` | 전면 | 레벨 종료 | 세션 2 | 120초 | 3 / 8 | 켜짐 | 없음 | `interstitial_level_end_cooldown_s`, `interstitial_level_end_daily_cap`, `interstitial_level_end_enabled`, `interstitial_level_end_session_cap` | ad_requested, ad_impression, ad_failed |
| `rewarded_booster` | 보상형 | 허들 직면 | 세션 1 | 30초 | 2 / 5 | 켜짐 | 없음 | `rewarded_booster_cooldown_s`, `rewarded_booster_daily_cap`, `rewarded_booster_enabled`, `rewarded_booster_session_cap` | ad_requested, ad_impression, ad_failed, rewarded_earned |
| `rewarded_continue` | 보상형 | 레벨 실패 | 세션 1 | 60초 | 1 / 2 | 켜짐 | 없음 | `rewarded_continue_cooldown_s`, `rewarded_continue_daily_cap`, `rewarded_continue_enabled`, `rewarded_continue_session_cap` | ad_requested, ad_impression, ad_failed, rewarded_earned |
| `rewarded_result_bonus` | 보상형 | 정산 화면 | 세션 1 | 60초 | 1 / 3 | 켜짐 | 없음 | `rewarded_result_bonus_cooldown_s`, `rewarded_result_bonus_daily_cap`, `rewarded_result_bonus_enabled`, `rewarded_result_bonus_session_cap` | ad_requested, ad_impression, ad_failed, rewarded_earned |
<!-- bm:ads:end -->

<!-- bm:catalog:start -->
| 항목 | SKU | 유형 | USD | Play KRW | App Store KRW | AIT KRW | 동기 | 허들 | 해금 | 복원 | 대전 영향 | 근거 |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |
| 상품 없음 | - | - | - | - | - | - | - | - | - | - | - | - |
<!-- bm:catalog:end -->

## 라이브옵스 캘린더

서버와 운영 인력이 없는 첫 출시이므로 자동으로 도는 것만 둔다.

| 주기 | 내용 | 운영 작업 |
|---|---|---|
| 매일 | 일일 도전(평일 T3, 주말 T4), 출석 | 없음(팩에 포함) |
| 매주 | 연속 기록 7일 보상 | 없음 |
| 수시 | 알림함 공지(새 버전, 범주 추가) | 새 버전에 포함 |
| 출시 뒤 2주 | 지표 확인(D1, 스테이지 10 도달, 등급별 클리어율, 보상형 수락률, 광고 불만 리뷰), 원격 설정으로 광고 빈도 조정 | 에이전트의 지표 점검과 사용자 판단 |
| 출시 뒤 4~6주 | 범주 추가와 난도 재조정을 담은 1.1, 순위표와 푸시 알림 검토 | 새 설계 |

## 시뮬레이션 증거

규칙 프로토타입(무작위 배치 4,000개, 시드 7, 2026-11-21 측정)의 결과다.

| 배치 | 임시 칸 2개로 풀림 | 3번째 칸이 있어야 풀림 | 최소 이동 수 10%·50%·90% | 무작위 선택 성공률 10%·50%·90% |
|---|---|---|---|---|
| open (2,2,2,2 + 8) | 100.0% | 0.0% | 0 / 1 / 2 | 0.67 / 1.00 / 1.00 |
| step (3,3,2,2 + 6) | 97.5% | 2.5% | 1 / 2 / 3 | 0.13 / 0.44 / 0.79 |
| classic (3,3,3,3 + 4) | 65.6% | 33.7% | 2 / 3 / 4 | 0.02 / 0.10 / 0.33 |
| deep (4,3,3,2 + 4) | 57.1% | 40.9% | 2 / 3 / 4 | 0.02 / 0.09 / 0.31 |
| 범주 5개 (4,4,4,4 + 4) | 10.7% | 40.7% | 3 / 5 / 6 | 0.00 / 0.01 / 0.06 |

코인 수지 추정(행동 비율은 가설):

| 플레이 방식 | 하루 코인 수입 | 막힘 횟수 | 부스터 코인 수요 | 코인으로 충당 | 광고로 메우는 횟수 |
|---|---|---|---|---|---|
| 가볍게(하루 2판, T2) | 81 | 0.4 | 62 | 100% | 0 |
| 보통(하루 6판, T3) | 160 | 2.4 | 366 | 44% | 1.8 |
| 열성(하루 16판, T3~T4) | 344 | 8.8 | 1,364 | 25% | 5.0(상한) / 필요 8.9 |

광고 수익 시뮬레이션은 사내 프레임워크 도구의 결과이며 입력의 58%가 가설이라 판정은 WARN이다. 한국 벤치마크 eCPM 기준 광고 ARPDAU 0.070달러, D90 LTV 0.42달러로 나오지만 전면 노출 수(하루 5.4회)는 상한까지 채운다는 가정이라 실제는 더 낮을 것으로 본다. 실측 전에는 수익 근거로 쓰지 않는다.

## 원격 설정

<!-- bm:remote-config:start -->
| 키 | 타입 | 기본값 | 범위 | 용도 |
| --- | --- | --- | --- | --- |
| `interstitial_level_end_cooldown_s` | int | 120 | 0 ~ 600 | interstitial_level_end 쿨다운(초) |
| `interstitial_level_end_daily_cap` | int | 8 | 0 ~ 16 | interstitial_level_end 일 상한 |
| `interstitial_level_end_enabled` | bool | true | 해당 없음 | interstitial_level_end kill-switch |
| `interstitial_level_end_session_cap` | int | 3 | 0 ~ 6 | interstitial_level_end 세션 상한 |
| `interstitial_min_play_seconds` | int | 180 | 180 ~ 1800 | 전면 광고 첫 노출까지 실제 플레이한 시간. 최소 3분. |
| `interstitial_min_stages_between` | int | 2 | 2 ~ 6 | 전면 광고 사이에 끝내야 하는 판 수. 최소 2판. |
| `rewarded_booster_cooldown_s` | int | 30 | 0 ~ 600 | rewarded_booster 쿨다운(초) |
| `rewarded_booster_daily_cap` | int | 5 | 0 ~ 10 | rewarded_booster 일 상한 |
| `rewarded_booster_enabled` | bool | true | 해당 없음 | rewarded_booster kill-switch |
| `rewarded_booster_session_cap` | int | 2 | 0 ~ 4 | rewarded_booster 세션 상한 |
| `rewarded_continue_cooldown_s` | int | 60 | 0 ~ 600 | rewarded_continue 쿨다운(초) |
| `rewarded_continue_daily_cap` | int | 2 | 0 ~ 4 | rewarded_continue 일 상한 |
| `rewarded_continue_enabled` | bool | true | 해당 없음 | rewarded_continue kill-switch |
| `rewarded_continue_session_cap` | int | 1 | 0 ~ 2 | rewarded_continue 세션 상한 |
| `rewarded_result_bonus_cooldown_s` | int | 60 | 0 ~ 600 | rewarded_result_bonus 쿨다운(초) |
| `rewarded_result_bonus_daily_cap` | int | 3 | 0 ~ 6 | rewarded_result_bonus 일 상한 |
| `rewarded_result_bonus_enabled` | bool | true | 해당 없음 | rewarded_result_bonus kill-switch |
| `rewarded_result_bonus_session_cap` | int | 1 | 0 ~ 2 | rewarded_result_bonus 세션 상한 |
<!-- bm:remote-config:end -->
