# 리서치 조사서

- 문서 상태: draft
- 제품명: Four Alike / 끼리끼리 (작업 ID `cluster-solitaire`)
- 소유자: 리서치 담당
- 버전/수정일: v0.1 / 2026-11-21
- Source of truth: 경쟁작, 리뷰, 화면 구조, 정책, 라이선스, 제품명에 대해 2026-11-21에 확인한 사실과 그 출처. 제품 결정은 이 문서가 아니라 GDD와 결정 로그가 소유한다.
- Depends on: `seorilabs/planning/docs/cluster-solitaire 최초 기획서.md` (2026-11-20, 읽기 전용 원문)
- Open blockers: RB-01 한국 상표 조회 실패, RB-02 기기 설치 플레이와 영상 관찰 없음, RB-03 한국 국내 규제 조사 범위 밖
- 승인 근거: 없음

## 조사 범위

| 항목 | 내용 |
| --- | --- |
| 조사 날짜 | 2026-11-21. 출처 원장의 확인 날짜는 모두 같은 날이다 |
| 국가와 스토어 | 미국: Google Play(gl=US, hl=en_US), App Store US. 한국: Google Play(gl=KR, hl=ko), App Store KR |
| 플랫폼 | Android, iOS, 웹(Connections 계열 클론 사이트) |
| 조사 방법 | 스토어 공개 페이지와 스토어 스크린샷, App Store 고객 리뷰 RSS, iTunes Search와 Lookup API, 정책 원문, USPTO 상표 검색, 업계 기사 |
| 하지 않은 것 | 기기 설치 플레이, 플레이 영상 시청, 유료 시장 데이터 조회 |

조사가 답하려는 제품 질문은 다섯 가지다.

1. 범주 카드 아래에 단어를 쌓는 정렬형 워드 솔리테어와 견주어, 숨은 범주 4장을 묶고 임시 칸으로 더미를 여는 규칙이 실제로 다른 경험인가.
2. 경쟁작 플레이어가 반복해서 불만을 말하는 지점이 어디이고, 우리 규칙과 광고 배치가 그 지점을 피하는가.
3. 판 종료 뒤 전면 광고와 보상형 광고 4종이 Google과 Apple 정책 안에 드는가.
4. Fluent Emoji를 상용 앱에 넣을 때 지켜야 할 조건은 무엇인가.
5. Four Alike와 끼리끼리라는 이름이 기존 앱이나 등록 상표와 부딪히는가.

경쟁작 선정 기준은 다음과 같다. 직접 경쟁작은 범주 연상을 카드로 푸는 모바일 게임과 숨은 범주 묶기 퍼즐에서 골랐다. 정렬형에서는 설치 수가 가장 큰 Solitaire Associations Journey와 Google Play 검색 "word solitaire" 상위 가운데 범주 정렬 규칙을 쓰고 설치가 100만 이상인 두 작품을 골랐다. 숨은 범주 묶기에서는 NYT Connections, 웹 클론, 그리고 조사 중에 찾은 Tripledot의 Association Match 4 Emoji Game을 넣었다. 마지막 작품은 요청 목록에 없었지만 규칙이 우리와 가장 가까워 추가했다. 인접 경쟁작은 임시 칸 운영이 핵심인 타일 매치 게임 가운데 Triple Tile과 Zen Match를 골랐다.

### 조사한 앱 버전

| 앱 | Android 업데이트 날짜 | iOS 버전과 날짜 | 출처 |
| --- | --- | --- | --- |
| Solitaire Associations Journey | 2026-11-18, 버전 번호 확인 못함 | 1.27.0, 2026-11-19 | SRC-001, SRC-003 |
| Word Solitaire Now! | 2026-11-04 | 2.4.4, 2026-11-04 | SRC-012, SRC-013 |
| Associate Words: Solitaire | 2026-11-18 | 2.5, 2026-09-24 | SRC-015, SRC-021 |
| Association Match 4 Emoji Game | 2026-11-17 | 1.2.2, 2026-10-21 | SRC-023, SRC-024 |
| NYT Games: Wordle & Crossword | 2026-11-18 | 6.50.1, 2026-11-18 | SRC-027, SRC-028 |
| Connect Word: Association Game | 2026-11-17 | 2.21.1, 2026-11-18 | SRC-026, SRC-073 |
| Triple Tile: Match Puzzle Game | 2026-11-10 | 2.75.06, 11월 12일(연도 표기 없음) | SRC-038, SRC-039 |
| Zen Match | 2026-09-11 | 확인 못함 | SRC-040 |

### 근거 표기

문장 앞의 꺾쇠 표시는 다음을 뜻한다. 표 안에서는 출처 번호와 함께 같은 표시를 쓴다.

- `[사실]` 공식 문서나 스토어 페이지에서 직접 확인한 내용
- `[관찰]` 스토어 스크린샷, 리뷰 표본에서 본 내용
- `[보도]` 기사나 백과사전이 전한 내용. 원 출처를 직접 확인하지 못한 2차 근거다
- `[추정치]` 제3자 데이터 업체가 계산한 값. 방법론이 공개되지 않았다
- `[추론]` 여러 근거를 엮어 해석한 내용
- `[가설]` 검증하기 전의 제품 가설

### 접근 제한과 표본 편향

- [사실] 기기에 설치해 플레이하지 않았고 영상도 보지 않았다. 그래서 연출 길이, 첫 10분의 실제 흐름, 홈 화면 구성은 직접 보지 못했다.
- [사실] Google Play 리뷰는 앱마다 페이지에 노출된 3건만 읽었다. 노출 기준은 Google이 정한다.
- [사실] App Store 리뷰는 RSS의 최신순 글 리뷰다. 별점만 남긴 평가는 들어 있지 않아 낮은 별점 쪽으로 치우친다. Solitaire Associations Journey는 전체 평점이 4.66인데 최근 글 리뷰 200건 중 171건이 1~3점이다(SRC-003, SRC-004).
- [사실] 리뷰 주제 빈도는 정규식 키워드 일치로 셌다. "fun" 같은 긍정 단어는 부정 리뷰에도 들어가므로 칭찬 빈도는 실제보다 높게 잡힌다.
- [사실] Sensor Tower, AppGoblin, FoxData, AppGrowing, Ahrefs의 수치는 추정치다. Sensor Tower 블로그 글은 AI 작성자 표기가 있고 방법론 설명이 없다.

### 확인하지 못한 항목

| ID | 항목 | 이유 |
| --- | --- | --- |
| U-01 | 한국 상표(KIPRIS)의 "끼리끼리", "Four Alike" 출원과 등록 | 검색 화면이 스크립트로만 동작해 조회하지 못했다(SRC-071) |
| U-02 | 경쟁작의 판당 실제 소요 시간, 묶음 완성 연출의 길이, 홈 화면 진입점 수 | 설치 플레이와 영상 관찰을 하지 않았다 |
| U-03 | NYT Connections의 공식 규칙 문서(실수 횟수, 무료 범위) | NYT 도메인에 접근하지 못했다. 위키백과, 앱 스토어 설명, 클론 사이트 설명으로 대신했다 |
| U-04 | 웹 클론 사이트의 광고 위치 | 페이지 본문에서 식별하지 못했다 |
| U-05 | Triple Tile의 정확한 트레이 칸 수와 실패 뒤 이어하기 제안 구성 | 공식 도움말을 찾지 못했다 |
| U-06 | Zen Match의 현재 버전 광고 배치 | 근거가 2022년 8월 기사 하나뿐이다(SRC-041) |
| U-07 | "word solitaire", "associations", "category solitaire"의 검색량 | 공개 수치를 찾지 못했다 |
| U-08 | Fluent Emoji를 스토어 스크린샷과 앱 아이콘에 쓰는 것에 대한 Microsoft의 공식 답변 | 저장소 이슈에 답변이 없다(SRC-062) |
| U-09 | 한국 게임물 등급분류, 개인정보 보호법의 맞춤형 광고 조항 | 요청 범위 밖이라 조사하지 않았다 |
| U-10 | 분석 SDK(Firebase 등)의 Data safety 신고 항목 | 광고 SDK만 확인했다 |
| U-11 | Google Year in Search 2025의 게임 순위 | 찾지 못했다 |
| U-12 | Play의 "ALIKE"(Algorythm Inc., 패키지 `com.app.connections`)가 어떤 앱인지 | 검색 결과 목록에서 이름만 확인했다 |

## 출처 원장

종류는 사실 원문, 스토어 페이지, 기사, 리뷰 네 가지로 나눴다. 확인 날짜는 모두 2026-11-21이다.

| Source ID | 종류 | 제목과 발행자 | URL | 게시 또는 수정일 | 확인 날짜 | 지역과 버전 | 지지하는 주장 | 신뢰도 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SRC-001 | 스토어 페이지 | Solitaire Associations Journey, Google Play | https://play.google.com/store/apps/details?id=com.hitappsgames.wordsolitaire&hl=en_US&gl=US | 2026-11-18 | 2026-11-21 | US, Android | 설치 수, 평점, 설명, 스크린샷 8장, 노출 리뷰 3건, Data safety | 높음 |
| SRC-002 | 스토어 페이지 | 단어 솔리테어: 카드 퍼즐게임(SRC-001의 한국 등록명), Google Play | https://play.google.com/store/apps/details?id=com.hitappsgames.wordsolitaire&hl=ko&gl=KR | 2026-11-18 | 2026-11-21 | KR, Android | 한국 표시명, 평점, 한국어 설명 | 높음 |
| SRC-003 | 스토어 페이지 | Solitaire Associations Journey, App Store | https://apps.apple.com/us/app/solitaire-associations-journey/id6748950306 | 2026-11-19 | 2026-11-21 | US, iOS 1.27.0 | 평점, 순위, IAP 목록, 개인정보 라벨, 노출 리뷰 4건 | 높음 |
| SRC-004 | 리뷰 | App Store 고객 리뷰 RSS, 앱 id 6748950306, 미국 | https://itunes.apple.com/us/rss/customerreviews/page=1/id=6748950306/sortby=mostrecent/json | 2026-11-05부터 2026-11-18 | 2026-11-21 | US, iOS 1.26.x | 최근 글 리뷰 200건(1~4쪽)의 주제 집계와 요지 | 중간 |
| SRC-005 | 리뷰 | App Store 고객 리뷰 RSS, 앱 id 6748950306, 한국 | https://itunes.apple.com/kr/rss/customerreviews/page=1/id=6748950306/sortby=mostrecent/json | 2026-08-03부터 2026-11-18 | 2026-11-21 | KR, iOS | 최근 글 리뷰 100건의 주제 집계와 요지 | 중간 |
| SRC-006 | 기사 | AppGoblin 앱 프로필 | https://appgoblin.info/apps/com.hitappsgames.wordsolitaire | 2026-11-19 수집 | 2026-11-21 | 전 세계 추정 | 설치 추정, Android 출시일, SDK 탐지, 수익 구성 추정 | 낮음 |
| SRC-007 | 기사 | Sensor Tower 블로그, 2025년 4분기 미국 솔리테어 상위 5(통합, 매출 편) | https://sensortower.com/blog/2025-q4-unified-top-5-solitaire-games-revenue-us-600abc3f241bc16eb850508a | 2026-01 | 2026-11-21 | US, iOS와 Android 통합 | 연말 주간 매출 약 47.8만 달러, 주간 다운로드 최고 약 92.4만 | 중간 |
| SRC-008 | 기사 | Sensor Tower 블로그, 같은 분기(통합, 다운로드 편) | https://sensortower.com/blog/2025-q4-unified-top-5-solitaire-games-units-us-600abc3f241bc16eb850508a | 2026-01 | 2026-11-21 | US, 통합 | 주간 매출 최고 약 57.17만 달러, 주간 활성 사용자 약 400만 | 중간 |
| SRC-009 | 기사 | Sensor Tower 블로그, 같은 분기(iOS, 다운로드 편) | https://sensortower.com/blog/2025-q4-ios-top-5-solitaire-games-units-us-600abc3f241bc16eb850508a | 2025-12 | 2026-11-21 | US, iOS | 주간 매출 최고 약 47만 달러, 주간 다운로드 최고 약 81.2만 | 중간 |
| SRC-010 | 기사 | AppGrowing, Hitapps 신작 분석 | https://appgrowing.net/blog/en/hitapps-games-new-release-ranked-top-2-on-the-us-ios-free-chart-within-two-weeks-of-launch/ | 2025-10-24 | 2026-11-21 | US | 규칙 설명, 광고 의존도 발언, 한 판에 10분 넘게 머물면 강제 광고 | 중간 |
| SRC-011 | 기사 | FoxData 블로그 | https://foxdata.com/en/blogs/when-word-meets-cards-word-solitaire-associations-climbs-to-us-app-store-top-1/ | 2025-10-01 | 2026-11-21 | US, iOS | 순위 변화, 일 설치 추정, 5레벨 뒤 전면 증가 | 낮음 |
| SRC-012 | 스토어 페이지 | Word Solitaire Now!, Google Play | https://play.google.com/store/apps/details?id=com.losttemplegames.wordsolitaire&hl=en_US&gl=US | 2026-11-04 | 2026-11-21 | US, Android | 설치 수, 평점, 설명, 스크린샷, 노출 리뷰 3건 | 높음 |
| SRC-013 | 스토어 페이지 | Word Solitaire Now!, App Store(iTunes Lookup API로 확인) | https://apps.apple.com/us/app/id6753799160 | 2026-11-04 | 2026-11-21 | US, iOS 2.4.4 | 평점, 출시일, 설명 | 높음 |
| SRC-014 | 리뷰 | App Store 고객 리뷰 RSS, 앱 id 6753799160, 미국 | https://itunes.apple.com/us/rss/customerreviews/page=1/id=6753799160/sortby=mostrecent/json | 2026-07-19부터 2026-11-16 | 2026-11-21 | US, iOS | 최근 글 리뷰 100건의 주제 집계와 요지 | 중간 |
| SRC-015 | 스토어 페이지 | Associate Words: Solitaire, Google Play | https://play.google.com/store/apps/details?id=solitaire.word.association.connections.puzzle&hl=en_US&gl=US | 2026-11-18 | 2026-11-21 | US, Android | 설치 수, 평점, 규칙 설명, 노출 리뷰 3건 | 높음 |
| SRC-016 | 스토어 페이지 | Word Solitaire: Match & Play, Google Play | https://play.google.com/store/apps/details?id=com.unicostudio.wordsolitaire&hl=en_US&gl=US | 2026-11-09 | 2026-11-21 | US, Android | 설치 수, 평점, 규칙 설명, 노출 리뷰 3건 | 높음 |
| SRC-017 | 스토어 페이지 | Solitaire Word Association(PlaySimple), Google Play | https://play.google.com/store/apps/details?id=in.playsimple.solitaireassociation&hl=en_US&gl=US | 2026-11-04 | 2026-11-21 | US, Android | 설치 수, 평점, 노출 리뷰 3건, 일일 순위 이벤트 | 높음 |
| SRC-018 | 스토어 페이지 | Wordscapes Solitaire, Google Play | https://play.google.com/store/apps/details?id=com.peoplefun.wordsolitaire&hl=en_US&gl=US | 2026-11-19 | 2026-11-21 | US, Android | 설치 수, 평점, 광고 빈도 리뷰 | 높음 |
| SRC-019 | 스토어 페이지 | Word Solitaire: Categories, App Store(Lookup API) | https://apps.apple.com/us/app/id6756303194 | 2026-10-27 | 2026-11-21 | US, iOS 1.3.3 | 규칙과 도움 기능 설명 | 높음 |
| SRC-020 | 스토어 페이지 | Connections Solitaire, App Store(Lookup API) | https://apps.apple.com/us/app/id6817218966 | 2026-11-14 | 2026-11-21 | US, iOS 1.0.68 | 규칙 설명, 출시일 | 높음 |
| SRC-021 | 스토어 페이지 | iTunes Search API, 검색어 "word solitaire" | https://itunes.apple.com/search?term=word+solitaire&country=us&entity=software&limit=40 | 표기 없음 | 2026-11-21 | US, iOS | 유사작 33건의 이름, 판매자, 평점 수, 출시일 | 높음 |
| SRC-022 | 스토어 페이지 | Google Play 검색, 검색어 "word solitaire" | https://play.google.com/store/search?q=word+solitaire&c=apps&hl=en_US&gl=US | 표기 없음 | 2026-11-21 | US, Android | 검색 결과에 표시된 유사작 21건 | 높음 |
| SRC-023 | 스토어 페이지 | Association Match 4 Emoji Game, Google Play | https://play.google.com/store/apps/details?id=com.zm.ameg&hl=en_US&gl=US | 2026-11-17 | 2026-11-21 | US, Android | 규칙, 설치 수, 평점, 스크린샷 6장, 노출 리뷰 3건 | 높음 |
| SRC-024 | 스토어 페이지 | Association Match 4 Emoji Game, App Store(Lookup API) | https://apps.apple.com/us/app/id6772210932 | 2026-10-21 | 2026-11-21 | US, iOS 1.2.2 | 평점 수, 출시일 2026-08-04 | 높음 |
| SRC-025 | 리뷰 | App Store 고객 리뷰 RSS, 앱 id 6772210932, 미국 | https://itunes.apple.com/us/rss/customerreviews/page=1/id=6772210932/sortby=mostrecent/json | 2026-08-08부터 2026-11-07 | 2026-11-21 | US, iOS | 글 리뷰 30건의 주제 집계 | 중간 |
| SRC-026 | 스토어 페이지 | Connect Word: Association Game, Google Play | https://play.google.com/store/apps/details?id=com.hitappsgames.connectwords&hl=en_US&gl=US | 2026-11-17 | 2026-11-21 | US, Android | 단어 묶기형 선행작의 규모와 광고 불만 | 높음 |
| SRC-027 | 스토어 페이지 | NYT Games: Wordle & Crossword, Google Play | https://play.google.com/store/apps/details?id=com.nytimes.crossword&hl=en_US&gl=US | 2026-11-18 | 2026-11-21 | US, Android | 설치 수, 평점, Connections 설명, 스크린샷 | 높음 |
| SRC-028 | 스토어 페이지 | NYT Games: Wordle & Crossword, App Store | https://apps.apple.com/us/app/nyt-games-wordle-crossword/id307569751 | 2026-11-18 | 2026-11-21 | US, iOS 6.50.1 | 구독 상품, 아카이브 범위, 연령 등급의 광고 표기 | 높음 |
| SRC-029 | 리뷰 | App Store 고객 리뷰 RSS, 앱 id 307569751, 미국 | https://itunes.apple.com/us/rss/customerreviews/page=1/id=307569751/sortby=mostrecent/json | 2026-09-09부터 2026-11-18 | 2026-11-21 | US, iOS | 글 리뷰 300건의 주제 집계 | 중간 |
| SRC-030 | 기사 | The New York Times Connections, Wikipedia | https://en.wikipedia.org/wiki/The_New_York_Times_Connections | 표기 없음 | 2026-11-21 | 전 세계 | 출시일, 색 난이도 4단계, 스포츠판, 1,000번째 퍼즐 | 중간 |
| SRC-031 | 기사 | TechCrunch, Connections 앱 추가 보도 | https://techcrunch.com/2023/08/28/connections-is-the-new-york-times-most-played-game-after-wordle | 2023-08-28 | 2026-11-21 | US | 베타 출시일, NYT 내 인기 순위, 앱 편입 | 중간 |
| SRC-032 | 기사 | NBC New York(TODAY), 2025년 NYT Games 통계 | https://www.nbcnewyork.com/entertainment/entertainment-news/hardest-wordle-connections-games-2025/6436464/ | 2025-12-29 | 2026-11-21 | 전 세계 | 2025년 풀이 수 | 중간 |
| SRC-033 | 기사 | Game Informer, Google Year in Search 2023 | https://www.gameinformer.com/news/2023/12/11/hogwarts-legacy-was-the-top-trending-search-for-games-on-google-this-year | 2023-12-11 | 2026-11-21 | US, 전 세계 | 2023년 급상승 게임 검색 순위 | 중간 |
| SRC-034 | 기사 | Inverse, Google 2024 게임 검색 | https://www.inverse.com/gaming/connections-dominated-2024-top-gaming-google-search-new-york-times | 2024-12-10 | 2026-11-21 | 지역 표기 없음 | 2024년 급상승 게임 검색 순위 | 중간 |
| SRC-035 | 사실 원문 | Connections Unlimited, playwordle.org(connections-games.com에서 이동) | https://playwordle.org/connections/ | 표기 없음 | 2026-11-21 | 웹 | 웹 클론의 규칙과 기능 | 높음 |
| SRC-036 | 사실 원문 | Connections Unlimited, github.io | https://connectionsunlimitedonline.github.io | 2024 표기 | 2026-11-21 | 웹 | 무제한 플레이, 선택 계정 | 높음 |
| SRC-037 | 기사 | Ahrefs 사이트 프로필, connectionsunlimited.org | https://ahrefstop.com/websites/connectionsunlimited.org | 스냅샷 날짜 불명확 | 2026-11-21 | US | 검색어별 검색량과 유입 추정 | 낮음 |
| SRC-038 | 스토어 페이지 | Triple Tile: Match Puzzle Game, Google Play | https://play.google.com/store/apps/details?id=com.tripledot.triple.tile.match.pair.game.three.master.object&hl=en_US&gl=US | 2026-11-10 | 2026-11-21 | US, Android | 설치 수, 평점, 스크린샷, 노출 리뷰 3건 | 높음 |
| SRC-039 | 스토어 페이지 | Triple Tile: Match Puzzle Game, App Store | https://apps.apple.com/us/app/triple-tile-match-puzzle-game/id1572661625 | 표기 불완전 | 2026-11-21 | US, iOS 2.75.06 | 평점, IAP 목록, 노출 리뷰 4건 | 높음 |
| SRC-040 | 스토어 페이지 | Zen Match, Google Play | https://play.google.com/store/apps/details?id=com.exoticmatch.game&hl=en_US&gl=US | 2026-09-11 | 2026-11-21 | US, Android | 설치 수, 평점, 노출 리뷰 3건 | 높음 |
| SRC-041 | 기사 | Naavik, Zen Match 분석 | https://naavik.co/f2p-mobile/zen-match-hypercasual-casual/ | 2022-08-11 | 2026-11-21 | 2022년 버전 | 트레이 7칸, 가득 찼을 때 팝업, 이어하기, 광고 위치 | 중간 |
| SRC-042 | 스토어 페이지 | Tile Explorer - Triple Match, Google Play | https://play.google.com/store/apps/details?id=com.oakever.tiletrip&hl=en_US&gl=US | 2026-11-18 | 2026-11-21 | US, Android | 트레이형 게임의 광고 불만 리뷰 | 높음 |
| SRC-043 | 사실 원문 | AdMob 고객센터, 전면 광고 안내 개요 | https://support.google.com/admob/answer/6066980?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 자연스러운 전환 지점 원칙, 닫기 버튼 지연 시간 | 높음 |
| SRC-044 | 사실 원문 | AdMob 고객센터, Recommended interstitial implementations | https://support.google.com/admob/answer/6201350?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 레벨 사이 배치, 중간 화면 앞 노출 권장, 지연 화면, 미리 불러오기 | 높음 |
| SRC-045 | 사실 원문 | AdMob 고객센터, Disallowed interstitial implementations | https://support.google.com/admob/answer/6201362?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 실행과 종료 시 금지, 행동 2회당 1회 상한, 과업 중 노출 금지 | 높음 |
| SRC-046 | 사실 원문 | AdMob 고객센터, Policies for ad units that offer rewards | https://support.google.com/admob/answer/7313578?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 보상형 광고의 보상과 구현 요건 | 높음 |
| SRC-047 | 사실 원문 | Google Play Console 고객센터, Ads 정책 | https://support.google.com/googleplay/android-developer/answer/9857753?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 예기치 않은 전면 금지, 15초 규칙, 점수 화면 뒤 예외 | 높음 |
| SRC-048 | 사실 원문 | Apple App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ | 2026-10-16 | 2026-11-21 | 전 세계 | 2.3.7, 2.5.18, 3.2.2, 4.1, 4.3, 5.1.1, 5.1.2, 5.2.1 | 높음 |
| SRC-049 | 사실 원문 | Apple, User Privacy and Data Use | https://developer.apple.com/app-store/user-privacy-and-data-use/ | 표기 없음 | 2026-11-21 | 전 세계 | 추적 정의, ATT 요건, 개인정보 라벨 | 높음 |
| SRC-050 | 사실 원문 | Apple, Age ratings values and definitions | https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/ | 표기 없음 | 2026-11-21 | 전 세계 | 연령 등급 값, 광고 항목 신고 | 높음 |
| SRC-051 | 사실 원문 | Google, EU user consent policy | https://www.google.com/about/company/user-consent-policy/ | 표기 없음 | 2026-11-21 | EEA, 영국, 스위스 | 동의 대상과 기록 의무 | 높음 |
| SRC-052 | 사실 원문 | AdMob 고객센터, Google의 CMP 요건 | https://support.google.com/admob/answer/13554116?hl=en | 표기 없음 | 2026-11-21 | EEA, 영국, 스위스 | 인증 CMP 의무와 시행일 | 높음 |
| SRC-053 | 사실 원문 | AdMob 고객센터, GDPR 메시지와 UMP SDK | https://support.google.com/admob/answer/10113207?hl=en | 표기 없음 | 2026-11-21 | EEA, 영국, 스위스 | UMP SDK의 TCF 인증, 동의 없을 때 제한 광고 | 높음 |
| SRC-054 | 사실 원문 | Google Developers, UMP SDK(Android) | https://developers.google.com/admob/android/privacy | 표기 없음 | 2026-11-21 | 전 세계 | 실행마다 동의 정보 갱신, 광고 요청 전 확인, 개인정보 옵션 진입점 | 높음 |
| SRC-055 | 사실 원문 | Google Play Console 고객센터, Target audience and content | https://support.google.com/googleplay/android-developer/answer/9867159?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 대상 연령 선택지, 아동 포함 시 Families 적용, 아동 지향 자산 반려 | 높음 |
| SRC-056 | 사실 원문 | Google Play Console 고객센터, Families 정책 | https://support.google.com/googleplay/android-developer/answer/9893335?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | 적용 조건, 자체 인증 광고 SDK, 광고 ID 전송 금지 | 높음 |
| SRC-057 | 사실 원문 | Google Play Console 고객센터, Data safety 양식 | https://support.google.com/googleplay/android-developer/answer/10787469?hl=en | 2023-12-05 변경 기록 | 2026-11-21 | 전 세계 | SDK 수집분 신고 의무, 수집과 공유 정의, 개인정보처리방침 필수 | 높음 |
| SRC-058 | 사실 원문 | Google Developers, Mobile Ads SDK의 Play 데이터 공개 | https://developers.google.com/admob/android/privacy/play-data-disclosure | SDK 25.5.0 기준 | 2026-11-21 | 전 세계 | 광고 SDK가 자동 수집하고 공유하는 데이터 종류 | 높음 |
| SRC-059 | 사실 원문 | Google Play Console 고객센터, Advertising ID | https://support.google.com/googleplay/android-developer/answer/6048248?hl=en | 표기 없음 | 2026-11-21 | 전 세계 | AD_ID 권한 선언 | 높음 |
| SRC-060 | 사실 원문 | Google Developers, AdMob targeting | https://developers.google.com/admob/android/targeting | 표기 없음 | 2026-11-21 | 전 세계 | 광고 최대 콘텐츠 등급 설정 | 높음 |
| SRC-061 | 사실 원문 | microsoft/fluentui-emoji, LICENSE | https://github.com/microsoft/fluentui-emoji/blob/main/LICENSE | 저장소 마지막 푸시 2026-08-24 | 2026-11-21 | 전 세계 | MIT 조건 전문 | 높음 |
| SRC-062 | 사실 원문 | microsoft/fluentui-emoji, 이슈 94, 103, 106, 136 | https://github.com/microsoft/fluentui-emoji/issues/103 | 2023-03부터 2024-05 | 2026-11-21 | 전 세계 | 라이선스 적용 질문에 관리자 답변이 없음 | 중간 |
| SRC-063 | 사실 원문 | USPTO Trademark Search | https://tmsearch.uspto.gov/search/search-information | 기록 적재 2026-10 | 2026-11-21 | US | 제품명과 유사명의 출원, 등록 상태 | 높음 |
| SRC-064 | 사실 원문 | USPTO TSDR, 일련번호 85180601 | https://tsdr.uspto.gov/statusview/sn85180601 | 2021-12-23 갱신 | 2026-11-21 | US | WORD SOLITAIRE의 보조 등록부 등록 | 높음 |
| SRC-065 | 스토어 페이지 | Google Play 검색, 검색어 "four alike"(US), Four Alike(KR), 끼리끼리(KR), alike(US), four four(US) | https://play.google.com/store/search?q=%22four+alike%22&c=apps&hl=en_US&gl=US | 표기 없음 | 2026-11-21 | US, KR | 같은 이름과 비슷한 이름의 앱 | 높음 |
| SRC-066 | 스토어 페이지 | iTunes Search API, 검색어 Four Alike, 끼리끼리, alike, four four | https://itunes.apple.com/search?term=Four+Alike&country=us&entity=software | 표기 없음 | 2026-11-21 | US, KR | 같은 이름과 비슷한 이름의 앱 | 높음 |
| SRC-067 | 스토어 페이지 | 끼리끼리: 동네친구 찾기, 친구만들기, 수다 떠는 채팅, Google Play | https://play.google.com/store/apps/details?id=com.colorful.yellow&hl=ko&gl=KR | 표기 확인 안 함 | 2026-11-21 | KR, Android | 한국 스토어의 같은 이름 앱 | 높음 |
| SRC-068 | 스토어 페이지 | Alike!, App Store | https://apps.apple.com/us/app/id1477727635 | 2024-01-30 | 2026-11-21 | US, iOS 1.2.1 | 비슷한 이름의 게임 | 높음 |
| SRC-069 | 스토어 페이지 | Four Four!, App Store | https://apps.apple.com/us/app/id6504049547 | 2024-06-10 | 2026-11-21 | US, iOS 1.1 | 비슷한 이름의 게임 | 높음 |
| SRC-070 | 기사 | PocketGamer.biz, Azur Games 기고 | https://www.pocketgamer.biz/puzzle-games-rise-as-mobile-genres-compete-for-attention-in-2026/ | 2026-08-25 | 2026-11-21 | 전 세계 | 2026년 상반기 퍼즐 장르 동향(수치 없음) | 낮음 |
| SRC-071 | 사실 원문 | KIPRIS 특허정보검색서비스 | https://www.kipris.or.kr/khome/main.do | 표기 없음 | 2026-11-21 | KR | 조회 실패 기록 | 해당 없음 |
| SRC-072 | 사실 원문 | 내부 기획 원문 `cluster-solitaire 최초 기획서.md` | 로컬 경로 `seorilabs/planning/docs/` | 2026-11-20 | 2026-11-21 | 내부 | 우리 규칙과 수익화 후보 | 높음 |
| SRC-073 | 스토어 페이지 | Connect Word Association Game, App Store(Lookup API) | https://apps.apple.com/us/app/id6692629257 | 2026-11-18 | 2026-11-21 | US, iOS 2.21.1 | 평가 수, iOS 출시일 | 높음 |

## 경쟁작 매트릭스

### 요약 매트릭스

| 항목 | COMP-01 Solitaire Associations Journey | COMP-04 NYT Connections | COMP-06 Association Match 4 | ADJ-01 Triple Tile | 우리 설계에 주는 시사점 |
| --- | --- | --- | --- | --- | --- |
| 포지셔닝 | [사실] "the original word solitaire", 카드와 단어 연상의 결합(SRC-001) | [사실] 16개 낱말을 네 범주로 나누는 일일 퍼즐(SRC-027) | [사실] 숨은 연결로 이어진 그림 타일 4개를 묶는 퍼즐(SRC-023) | [사실] 같은 타일 3개를 맞추는 퍼즐(SRC-038) | [추론] 정렬형과 구분되는 한 줄 설명이 필요하다. "숨은 묶음 찾기"가 차이다 |
| 10초와 3분 루프 | [보도] 카드를 범주 슬롯으로 옮기고 스톡을 넘긴다. 행동마다 이동 수가 줄어든다(SRC-010) | [사실] 매일 새 퍼즐이 나온다(SRC-027). [관찰] 4개를 골라 제출한다(SRC-035) | [사실] 4개를 눌러 묶고 이동 수 안에 보드를 비운다(SRC-023) | [관찰] 타일을 트레이로 보내 3개를 맞춘다(SRC-038) | [추론] 탐색 행동에 비용을 붙이면 불만이 생긴다. 우리 규칙은 실수에만 비용이 있다 |
| 첫 10분 | [보도] 5레벨 뒤부터 전면 광고와 난도가 오른다(SRC-010, SRC-011) | 확인 못함 | 확인 못함 | [관찰] 초반에는 광고가 없다가 나중에 매 판 뒤에 나온다는 리뷰(SRC-038) | [추론] 초반 무광고 뒤 급증하는 구성은 "속았다"는 리뷰로 이어진다 |
| 화면 위계 | [관찰] 위에서부터 자원, 스톡, 범주 슬롯, 태블로, 부스터 줄(SRC-001) | [관찰] 안내 한 줄, 완성 묶음 띠, 남은 낱말 격자(SRC-027) | [관찰] 한 줄 HUD, 그림 격자, 부스터 3개(SRC-023) | [관찰] 보드, 트레이 한 줄, 부스터 3개(SRC-038) | [추론] 남은 자원은 상단, 조작 대상은 가운데, 도움 기능은 맨 아래 한 줄이 공통이다 |
| 경제와 수익화 | [사실] 광고, 코인 팩, 광고 제거 9.99달러(SRC-003) | [사실] 구독 월 5.99달러, 아카이브는 구독자 전용(SRC-028) | [관찰] 이동 수가 떨어지면 광고로 이어하기(SRC-023) | [사실] 광고, 1.99~49.99달러 패키지(SRC-039) | [추론] 광고 전용이면 판당 광고 가치가 경쟁작보다 낮다. 빈도 대신 보상형 수요로 채워야 한다 |
| 아트와 게임 필 | [관찰] 녹색 테이블, 흰 카드, 단어 카드와 그림 카드 혼용(SRC-001) | [관찰] 흰 바탕, 색 띠 4종(SRC-027) | [관찰] 나무 바탕, 인물과 사물 그림 타일(SRC-023) | [관찰] 풍경 배경, 과일 타일(SRC-038) | [추론] 그림 병기는 이미 장르 관행이다. 차별점으로 내세우기 어렵다. 소리는 확인 못함 |
| 콘텐츠와 라이브옵스 | [사실] 선형 레벨, 주말 Corgi Race(SRC-001) | [사실] 일일 퍼즐, 배지와 통계, 기간 한정 테마 묶음(SRC-028) | [사실] 레벨, 보물 상자, 일일 도전(SRC-023) | [사실] 레벨, 지도, 시즌 이벤트(SRC-038) | [추론] 일일 도전과 연속 기록은 최소 구성이다 |

### 직접 경쟁작 1: 정렬형 워드 솔리테어

| 항목 | COMP-01 Solitaire Associations Journey | COMP-02 Word Solitaire Now! | COMP-03 Associate Words: Solitaire |
| --- | --- | --- | --- |
| 개발사 | [사실] Hitapps Games LTD. Play 개발자 주소는 키프로스(SRC-001). 기사 두 곳은 미국 회사로 적었다(SRC-010, SRC-011) | [사실] Play 표기 MAXX GAMES, 법인 LOST TEMPLE TECH LIMITED(홍콩). App Store 판매자는 GRAND LINE TECHNOLOGY LIMITED(SRC-012, SRC-013) | [사실] Astrasen Global, 법인 ASTRASEN PTE. LTD.(싱가포르)(SRC-015) |
| 플랫폼 | [사실] Android, iOS, iPadOS. Play 페이지에 Windows도 표기(SRC-001, SRC-003) | [사실] Android, iOS(SRC-012, SRC-013) | [사실] Android, iOS(SRC-015, SRC-021) |
| 설치 수와 평점(2026-11-21) | [사실] Play US 1,000만 이상, 4.4점, 리뷰 48.5만. App Store US 4.66점, 평가 233,964건, Word 무료 2위. Play 페이지에 "#1 top grossing word" 표기(SRC-001, SRC-003). Play KR 표시명은 "단어 솔리테어: 카드 퍼즐게임"이고 4.4점, 리뷰 48.5만개다(SRC-002). [추정치] 누적 설치 3,680만, 월 활성 200만(SRC-006) | [사실] Play US 100만 이상, 4.6점, 리뷰 6.49만. App Store US 4.70점, 평가 30,537건(SRC-012, SRC-013) | [사실] Play US 100만 이상, 4.8점, 리뷰 4.27만. App Store US 4.94점, 평가 7,580건(SRC-015, SRC-021) |
| 출시 | [사실] iOS 2025-09-11(SRC-021). [추정치] Android 2025-08-28(SRC-006) | [사실] iOS 2025-12-01(SRC-021) | [사실] iOS 2025-11-26(SRC-021) |
| 핵심 규칙 | [사실] 단어 카드를 정렬해 맞는 범주로 묶는다(SRC-001). [보도] 왕관 표시가 있는 범주 카드를 슬롯에 놓고 그 범주의 단어나 그림 카드를 모은다. 범주를 다 모으면 슬롯이 빈다. 스톡에서 카드를 넘긴다(SRC-010). [관찰] 잠금과 열쇠 장애물이 있다(SRC-001). 순서 맞추기, 쪼개진 카드 합치기도 있다는 리뷰(SRC-005) | [사실] 단어 카드를 맞는 범주에 놓아 보드를 비운다. "as few moves as possible", 시간 제한 없음(SRC-012) | [사실] Crown Card와 Regular Card 두 종류를 끌어 범주를 나눈다. 이동 수가 빠듯하다고 스스로 설명한다(SRC-015) |
| 한 판 길이 | [관찰] 스크린샷의 남은 이동 수는 25에서 107, 스톡은 7에서 26장(SRC-001). 소요 시간은 확인 못함 | [관찰] 스크린샷에 진행 4/10일 때 04:28, 10/13일 때 03:59가 표시된다. 지난 시간인지 남은 시간인지 확인 못함(SRC-012) | 확인 못함 |
| 실수와 이동 제한 | [보도] 카드 이동과 스톡 넘기기 모두 이동 수 1을 쓴다. 이동 수가 떨어지거나 둘 곳이 없으면 실패(SRC-010). [관찰] 넘기기에도 이동 수가 든다는 리뷰가 미국과 한국에 있다(SRC-001, SRC-005). [관찰] 하트 5개 제한이 있다는 리뷰(SRC-004, SRC-005) | [관찰] 일일 모드 스크린샷에 Moves 200과 Target 5/13 표시(SRC-012). 일반 레벨의 제한은 확인 못함 | [사실] 이동 수 제한. 설명문은 이동 수를 다 쓰면 "synonym-matching challenge"가 된다고 적었는데 뜻이 분명하지 않다(SRC-015) |
| 힌트와 부스터 | [관찰] 하단에 힌트 3, 되돌리기 3, 조커 1. 다 쓰면 코인 800과 1,200 가격이 표시된다(SRC-001). 추가 이동은 광고나 코인(SRC-001의 개발사 답변) | [관찰] 스크린샷에 부스터 버튼이 없다. 단어를 길게 누르면 뜻을 보여 준다는 리뷰(SRC-012) | 확인 못함 |
| 광고 배치 | [관찰] 레벨 사이 전면, 레벨 도중 "ad break", 추가 이동용 보상형(SRC-001, SRC-004). 개발사가 답변에서 "mid-game interruptions"를 언급했다(SRC-001). [보도] 한 판에 10분 넘게 머물면 강제 광고(SRC-010). 배너는 확인 못함 | [관찰] 리뷰가 엇갈린다. 시도 2번마다 전면, 매 판과 실패 뒤 전면, 판 도중 4~5회라는 리뷰와 판 도중 광고가 없다는 리뷰가 같은 달에 있다(SRC-012, SRC-014) | [관찰] 레벨당 광고 1회, 이동 수를 더 원하면 추가 시청이라는 리뷰. 몇 레벨 뒤부터 광고가 많다는 리뷰(SRC-015) |
| IAP | [사실] 코인 팩 1.99~29.99달러, No Ads 9.99달러, No Ads Pack 19.99달러, Starter Pack 4.99달러, Revive offer 1.99달러(SRC-003) | [사실] 있음(SRC-012). [관찰] 광고 제거 10달러라는 리뷰(SRC-014) | [사실] 있음(SRC-015). 상품 목록 확인 못함 |
| 메타 구조 | [사실] 선형 레벨, 주말 Corgi Race(SRC-001). [관찰] Hard와 Super Hard 표시, 300레벨 이상 진행한 리뷰, 결과 화면에서 열쇠 지급(SRC-001, SRC-004, SRC-005) | [관찰] Easy와 Hard 표시가 붙은 레벨, Daily Challenges 달력, 할로윈과 추수감사절 이벤트(SRC-012) | [사실] 추수감사절 이벤트 카드(SRC-015) |
| 최근 업데이트 | [사실] Android 2026-11-18, iOS 1.27.0 2026-11-19(SRC-001, SRC-003) | [사실] 2026-11-04(SRC-012) | [사실] Android 2026-11-18(SRC-015) |

### 직접 경쟁작 2: 숨은 범주 묶기

| 항목 | COMP-04 NYT Connections | COMP-05 Connections Unlimited 계열 웹 클론 | COMP-06 Association Match 4 Emoji Game |
| --- | --- | --- | --- |
| 개발사 | [사실] The New York Times Company(SRC-027) | [사실] 운영 주체 표기 없는 팬 사이트 여러 곳(SRC-035, SRC-036) | [사실] Tripledot Studios Limited(런던)(SRC-023) |
| 플랫폼 | [사실] NYT Games 앱(iOS, Android)(SRC-027, SRC-028). [보도] 웹에서 먼저 나왔다(SRC-031) | [사실] 웹(SRC-035) | [사실] Android, iOS(SRC-023, SRC-024) |
| 설치 수와 평점(2026-11-21) | [사실] NYT Games 앱 기준 Play US 1,000만 이상, 4.8점, 리뷰 15.2만. App Store US 4.80점, 평가 301,890건, Word 무료 3위(SRC-027, SRC-028). [보도] 2025년 Connections 풀이 16억 회(SRC-032) | [추정치] connectionsunlimited.org의 미국 검색 유입 월 5.13만(SRC-037) | [사실] Play US 10만 이상, 4.7점, 리뷰 약 5,130건. App Store US 4.77점, 평가 1,086건(SRC-023, SRC-024) |
| 출시 | [보도] 베타 2023-06-12, 앱 편입 2023-08(SRC-030, SRC-031) | 확인 못함 | [사실] iOS 2026-08-04(SRC-024) |
| 핵심 규칙 | [사실] 16개 낱말을 네 범주로 나눈다(SRC-027). [보도] 묶음마다 노랑, 초록, 파랑, 보라 난이도가 있고 말장난과 미끼가 흔하다(SRC-030) | [사실] 16개 낱말, 4묶음. 4개를 골라 Submit(SRC-035) | [사실] 그림 타일 가운데 숨은 범주가 같은 4개를 눌러 묶는다. 이동 수 안에 보드를 비운다. 시계는 없다(SRC-023) |
| 한 판 길이 | [보도] 날마다 퍼즐 하나가 공개된다(SRC-031). 소요 시간은 확인 못함 | [사실] New Game으로 무제한, 날짜별 Archive(SRC-035) | [관찰] 스크린샷의 이동 수는 20에서 50, 보드는 4열 5~6행(SRC-023) |
| 실수와 이동 제한 | [관찰] 실수 4회로 끝난다. 공식 문서는 확인 못함, 클론 설명과 기사로 확인(SRC-035) | [사실] 실수 4회. 3개가 맞으면 "One away" 표시(SRC-035) | [사실] 이동 수 제한(SRC-023) |
| 힌트와 부스터 | [사실] 앱 설명에 Hints와 Connections Bot이 있다(SRC-028) | [사실] Shuffle, Deselect All, 타일 위치 바꾸기, 범주와 낱말을 단계별로 여는 힌트 페이지(SRC-035) | [사실] 힌트, 섞기, 추가 이동(SRC-023). [관찰] 하단 버튼 3개(SRC-023) |
| 광고 배치 | [사실] App Store 연령 등급 항목에 Advertising 표기(SRC-028). 위치는 확인 못함 | 확인 못함 | [관찰] 이동 수가 떨어지면 보상형으로 이어한다. 광고가 적다는 칭찬. 로딩 화면 아래에 광고가 돈다는 리뷰(SRC-023, SRC-025) |
| IAP | [사실] Games 구독 월 5.99달러 등(SRC-028) | [사실] 무료, 계정 선택(SRC-036) | [사실] Play에 인앱 구매 표기(SRC-023). [관찰] 광고 제거 상점이 없다는 리뷰(SRC-023). 상품 구성 확인 못함 |
| 메타 구조 | [사실] 일일 퍼즐, 통계와 배지와 리더보드, 구독자용 아카이브, 기간 한정 테마 묶음(SRC-028). [보도] 스포츠판(SRC-030) | [사실] 통계, 아카이브(SRC-035) | [사실] 레벨, 보물 상자, 일일 도전(SRC-023). [관찰] 묶인 타일과 큰 타일 장애물(SRC-023) |
| 최근 업데이트 | [사실] 2026-11-18(SRC-028). [보도] 2026-03-07에 1,000번째 퍼즐(SRC-030) | 확인 못함 | [사실] Android 2026-11-17(SRC-023) |

### 그 밖에 확인한 유사작

| 앱 | 개발사 | 수치(2026-11-21) | 메모 | 출처 |
| --- | --- | --- | --- | --- |
| Connect Word: Association Game | Hitapps Games | Play US 500만 이상, 4.5점, 리뷰 35.8만. App Store US 4.66점, 평가 177,730건, iOS 출시 2024-10-21 | [사실] 무작위로 보이는 낱말을 뜻과 범주로 묶는 레벨형 게임. [관찰] 레벨 사이와 레벨 도중 광고 불만 | SRC-026, SRC-073 |
| Wordscapes Solitaire | PeopleFun | Play US 100만 이상, 4.7점, 리뷰 26.7만 | [사실] 글자 카드로 낱말을 만드는 방식이라 범주 정렬과 다르다. [관찰] 75레벨 무렵부터 매 레벨 뒤 광고라는 리뷰 | SRC-018 |
| Solitaire Word Association | PlaySimple Games | Play US 5만 이상, 4.9점, 리뷰 약 1,680건 | [사실] 일일 순위 이벤트 Target Rush. [관찰] 드문 단어와 오탈자, 진행 초기화 불만 | SRC-017 |
| Word Solitaire: Match & Play | Unico Studio | Play US 10만 이상, 4.8점, 리뷰 약 6,910건 | [사실] 범주 카드를 먼저 놓고 제한된 이동 수 안에 정리한다. [관찰] 스톡을 넘기는 데 1수, 옮기는 데 1수가 든다는 불만 | SRC-016 |
| Word Solitaire: Categories | AI GAMES FZ LLC | App Store US 4.65점, 평가 628건 | [사실] 도움 기능이 Hint, Undo, Wildcard, Shuffle, Dictionary 다섯 가지 | SRC-019 |
| Connections Solitaire | Gamojo LLC | App Store US 평가 1건, 2026-10-21 출시 | [사실] 범주를 찾아 낱말과 그림을 모으고 이동 수 안에 테이블을 비운다. 캠페인 300레벨, 일일 퍼즐, Hint와 Undo와 Place | SRC-020 |

[사실] App Store US에서 "word solitaire"를 검색하면 33건이 나오고, 그 가운데 28건이 Solitaire Associations Journey의 iOS 출시일인 2025-09-11보다 뒤에 나왔다(SRC-021). 33건이 모두 정렬형인지는 일부만 설명을 읽어 확인했다. [사실] Google Play US 검색 결과에는 21건이 표시됐다(SRC-022).

### 게임별 관찰

**Solitaire Associations Journey.** [사실] 요청서에 적힌 "평점 4.6, 리뷰 약 31.8만"은 이전 시점 값이다. 2026-11-21의 Play US 표기는 4.4점, 리뷰 48.5만이다(SRC-001). [추정치] Sensor Tower 블로그는 2025년 4분기 미국 주간 매출 최고치를 iOS만 약 47만 달러(SRC-009), iOS와 Android 통합 약 57.17만 달러(SRC-008)로 적었고, 통합 매출 편은 연말 값을 47.8만 달러로 적었다(SRC-007). 요청서의 "47만~57만 달러"는 이 두 집계의 차이다. 수익 구성은 근거마다 다르다. [보도] 2025년 10월 기사는 회사 수익화 책임자의 말로 약 90%가 광고라고 전했다(SRC-010). [추정치] 2026년 11월의 AppGoblin 추정은 인앱 구매 66%, 광고 34%다(SRC-006). [관찰] 2026년 11월 리뷰에는 하루 한 번 광고를 보고 코인을 받던 기능이 사라졌다는 글과 하트 제한, 코인 가격 불만이 몰려 있다(SRC-004, SRC-005). [추론] 광고 중심에서 인앱 구매 중심으로 옮기는 중이고, 그 과정에서 무료 플레이어의 불만이 커지고 있다.

**Word Solitaire Now!** [관찰] 이동 수에 쫓기지 않아 편하다는 칭찬과 광고가 플레이보다 길다는 불만이 함께 있다(SRC-012). [관찰] 광고가 바이러스 경고 웹페이지를 강제로 연다는 리뷰가 2026-03과 2026-11에 한 건씩 있다(SRC-012, SRC-014). [추론] 광고 빈도뿐 아니라 광고 소재의 품질도 평점에 영향을 준다.

**Associate Words: Solitaire.** [관찰] 284레벨 무렵에 오탈자, 말이 안 되는 범주, egg와 eggs가 같은 묶음에 들어가는 중복이 거슬린다는 리뷰가 있고 개발사가 답변에서 이를 인정했다(SRC-015). [관찰] 그림이 AI 생성물로 보여 싫다는 리뷰도 있다(SRC-015).

**NYT Connections.** [보도] 날마다 퍼즐 하나가 공개된다(SRC-031). [사실] 지난 퍼즐 아카이브는 구독자용이다(SRC-028). [관찰] 2026-11-10 리뷰 한 건은 Wordle과 Connections까지 유료가 됐다고 주장한다. 사실 여부는 확인 못함(SRC-029). [사실] 미국에서 CONNECTIONS는 NYT의 등록 상표다. 자세한 내용은 제품명 절에 있다(SRC-063).

**Connections Unlimited 계열.** [사실] 규칙은 NYT Connections와 같고 무제한 플레이, 단계별 힌트, 아카이브를 더했다. NYT와 관계가 없다고 스스로 밝힌다(SRC-035). [추론] 판이 16장 전부 공개된 격자 하나라서 막혔을 때 할 수 있는 행동이 섞기와 힌트뿐이다.

**Association Match 4 Emoji Game.** [사실] 숨은 범주 4개 묶기를 레벨형 모바일 게임으로 만든 작품이고, 대형 퍼블리셔가 2026년 8월에 냈다(SRC-023, SRC-024). [관찰] 타일은 그림만 쓰고 낱말이 없다. 완성한 묶음에는 범주 이름이 붙는다. 범주 예시는 "Pet owners", "Athletes", "Straight Hair", "Fish collection"이다(SRC-023). [관찰] 모든 타일이 처음부터 보이고 임시 칸이나 뒤집힌 더미는 없다(SRC-023). [관찰] iOS 글 리뷰 30건 중 14건이 로딩 멈춤이나 진행 손실을 말한다(SRC-025).

### 인접 경쟁작

| 항목 | ADJ-01 Triple Tile: Match Puzzle Game | ADJ-02 Zen Match |
| --- | --- | --- |
| 개발사 | [사실] Tripledot Studios Limited(SRC-038) | [사실] Play 표기 Moon Active(SRC-040) |
| 설치 수와 평점(2026-11-21) | [사실] Play US 5,000만 이상, 4.8점, 리뷰 106만. App Store US 4.9점, 평가 27.3만(SRC-038, SRC-039) | [사실] Play US 1,000만 이상, 4.6점, 리뷰 58.7만(SRC-040) |
| 트레이 규칙 | [관찰] 보드 아래에 트레이가 한 줄 있고 같은 타일 3개가 모이면 사라진다. 스크린샷에는 6칸이 보인다. 정확한 칸 수는 확인 못함(SRC-038) | [보도] 2022년 기준 트레이는 7칸 고정이다. 가득 찼는데 맞는 3개가 없으면 "out of space" 팝업이 뜬다(SRC-041) |
| 칸이 찼을 때의 이어하기 | 확인 못함. [관찰] 도우미를 고르려고 광고를 본다는 리뷰, 175레벨 뒤에는 부스터 여러 개가 필요해 광고를 보게 된다는 리뷰(SRC-039) | [보도] 2022년 기준 코인을 내면 마지막 타일 3개를 보드로 되돌려 이어한다. 포기하면 라이프 1개를 잃는다. 라이프는 5개, 30분에 1개 회복(SRC-041) |
| 부스터 | [관찰] 되돌리기, 마술봉, 섞기. 스크린샷의 보유 수는 12, 7, 7(SRC-038) | [보도] 2022년 기준 Super-Undo(마지막 3개 되돌림), Undo, Shuffle(SRC-041) |
| 광고 | [관찰] 초반에는 없다가 나중에 매 판 뒤 전면이 나온다는 2026-11-03 리뷰. 끝나지 않는 광고 불만(SRC-038) | [보도] 2022년 기준 레벨 종료와 재시작 시 전면, 화면 배너, 놓친 일일 퍼즐을 여는 보상형, 광고 제거 5.99달러(SRC-041). 현재 버전은 확인 못함 |
| IAP | [사실] 1.99~49.99달러 패키지 10종(SRC-039) | [보도] 2022년 기준 1.99~99.99달러(SRC-041) |
| 메타 | [사실] 레벨 지도, 주간 신규 레벨, 시즌 이벤트(SRC-038) | [사실] 방 꾸미기, 일일 퍼즐과 식물 수집(SRC-040, SRC-041). [관찰] 방이 사라졌다는 2026-11-13 리뷰(SRC-040) |

[관찰] 같은 트레이형인 Tile Explorer(Play US 1억 이상, 4.9점, 리뷰 237만)에는 "파워업용 광고는 버퍼링으로 안 나오는데 판을 지면 바로 광고가 나온다"는 2025-10-02 리뷰가 있고 3,309명이 도움이 됐다고 눌렀다(SRC-042).

[추론] 트레이형 게임에서 칸이 가득 차는 것은 곧 실패이고, 이어하기는 최근 타일을 되돌리거나 재화를 쓰는 형태다. 우리 임시 칸은 2칸으로 훨씬 작고, 칸이 차도 실패가 아니라 묶기로 풀어야 하는 상태다. 그래서 세 번째 칸 보상형은 "실패 뒤 구제"가 아니라 "막히기 전에 여유를 사는" 제안이 된다. [가설] 실패가 걸려 있지 않으므로 트레이형의 이어하기보다 수락률이 낮을 수 있다.

### 첫 10분 비교

직접 플레이하지 않았으므로 아래는 기사와 리뷰로 본 간접 근거다.

| 게임 | 초반 광고 | 근거 |
| --- | --- | --- |
| Solitaire Associations Journey | [보도] 5레벨 뒤부터 전면 광고가 늘고 난도가 오른다 | SRC-010, SRC-011 |
| Wordscapes Solitaire | [관찰] 초반에는 거의 없다가 75레벨 무렵부터 매 레벨 뒤 | SRC-018 |
| Solitaire Word Association | [관찰] 꽤 진행한 뒤에야 광고가 본격적으로 나온다 | SRC-017 |
| Triple Tile | [관찰] 처음에는 없고 나중에 매 판 뒤 | SRC-038 |

[추론] 초반 무광고 구간을 둔 뒤 빈도를 올리는 방식이 흔하고, 빈도가 오른 시점에 별점을 깎는 리뷰가 달린다.

## 리뷰와 플레이어 문제 종합

### 표본

| 앱 | 출처 | 건수와 기간 | 별점 분포(1, 2, 3, 4, 5점) |
| --- | --- | --- | --- |
| Solitaire Associations Journey, App Store US | SRC-004 | 200건, 2026-11-05~2026-11-18 | 88, 43, 40, 16, 13 |
| Solitaire Associations Journey, App Store KR | SRC-005 | 100건, 2026-08-03~2026-11-18 | 51, 9, 18, 10, 12 |
| Word Solitaire Now!, App Store US | SRC-014 | 100건, 2026-07-19~2026-11-16 | 31, 15, 17, 11, 26 |
| Association Match 4, App Store US | SRC-025 | 30건, 2026-08-08~2026-11-07 | 7, 5, 10, 4, 4 |
| NYT Games, App Store US | SRC-029 | 300건, 2026-09-09~2026-11-18 | 97, 26, 27, 33, 117 |
| Google Play 노출 리뷰 | SRC-001, SRC-012, SRC-015~SRC-018, SRC-023, SRC-026, SRC-038, SRC-040, SRC-042 | 앱마다 3건 | 별점은 수집하지 못함 |

### 주제별 정리

빈도는 키워드 일치 건수다. 심각도는 높음, 중간, 낮음으로 적었다.

| Theme ID | 문제 또는 칭찬 | 빈도와 표본 | 심각도 | 최근 버전 확인 | 기회 또는 비기회 |
| --- | --- | --- | --- | --- | --- |
| REV-01 | 광고가 너무 잦다 | SAJ US 119/200, SAJ KR 75/100, Word Solitaire Now! 61/100 | 높음 | 예, 2026-11 리뷰 | [추론] 기회. 광고 빈도를 낮추고 그 사실을 스토어 설명 첫 줄에 쓰면 차이가 된다 |
| REV-02 | 판을 푸는 도중에 전면 광고가 끼어든다 | SAJ US 37/200. Play 노출 리뷰에도 있고 개발사가 답변에서 인정(SRC-001) | 높음 | 예 | [추론] 기회. 플레이 중 광고 0회는 정책 요건이면서 차별점이다 |
| REV-03 | 이동 수가 모자라고, 카드를 넘기는 탐색에도 이동 수가 든다 | SAJ US에서 이동 수 언급 66/200, 넘기기 비용 언급 10/200. SAJ KR 16/100 | 높음 | 예 | [추론] 기회. 우리 규칙은 임시 칸으로 옮기는 행동에 횟수 비용이 없다 |
| REV-04 | 재화가 비싸고 무료 수급이 줄었다 | SAJ US 70/200, SAJ KR 31/100 | 중간 | 예, 2026-11-18에 무료 코인 제거 불만 집중 | [추론] 부분 기회. 인앱 구매가 없으니 가격 불만은 없지만 코인 수급 설계는 같은 눈으로 평가받는다 |
| REV-05 | 운에 따라 풀 수 없는 판이 나온다 | SAJ US 39/200. Association Match 4는 다시 시작해도 같은 배치라는 리뷰 | 높음 | 예 | [추론] 기회. 모든 판을 2칸으로 풀리게 사전 검증한다는 기획과 맞는다. 다만 숨은 카드 때문에 생기는 운은 남는다 |
| REV-06 | 억지스러운 범주, 낯선 단어, 오탈자, 단어 반복 | SAJ US 최근 표본에서는 범주 2건, 낯선 단어 2건, 철자 1건(200건 중). Play에서 도움 173표를 받은 오탈자 리뷰, Associate Words와 PlaySimple 리뷰, 한국 리뷰의 "단어 재탕 40%" | 중간. 빈도는 낮지만 장르 신뢰를 깬다 | 예 | [추론] 위험이 더 크다. 범주를 숨기는 규칙은 범주 품질에 더 민감하다 |
| REV-07 | 닫히지 않는 광고, 악성 웹페이지로 넘어가는 광고 | Word Solitaire Now!, Word Solitaire: Match & Play, Triple Tile, SAJ에서 각 1건 이상 | 높음 | 예 | [추론] 비기회. 광고망 품질 문제라 우리도 겪는다. 차단 설정과 신고 경로로 줄인다 |
| REV-08 | 광고 제거를 샀는데도 광고나 제한이 남는다 | SAJ US 8/200, 한국 리뷰 1건 | 중간 | 예 | [추론] 해당 없음. 광고 제거 상품이 없다 |
| REV-09 | 로딩이 멈추고 진행이 사라진다 | Association Match 4 14/30, PlaySimple 리뷰, 한국 리뷰의 언어 변경 시 레벨 초기화 | 높음 | 예 | [추론] 기회. 로컬 저장을 깨지지 않게 만들고 언어를 바꿔도 진행을 지킨다 |
| REV-10 | 개념이 새롭고 중독성이 있다, 어휘를 배운다, 시계가 없어 편하다 | SAJ US에서 긍정 단어 116/200(과대 집계), 어휘 학습 6/200. Association Match 4의 "타이머 대신 이동 수" 칭찬 | 해당 없음 | 예 | [추론] 지킬 것. 시계 없음, 큰 그림, 배우는 느낌 |
| REV-11 | 오프라인 플레이 | SAJ US 1/200, SAJ KR 0/100 | 낮음 | 예 | [추론] 불만 주제가 아니다. 스토어 태그와 설명에는 다들 Offline을 내세운다 |
| REV-12 | NYT의 구독 전환과 유료 범위 | NYT Games 300건 중 구독이나 결제 언급 42건, Connections 언급 16건 | 중간 | 예 | [추론] 기회. 하루 한 판과 유료 아카이브에 막힌 사람에게 무제한 무료 판을 준다 |
| REV-13 | 번역 품질 | SAJ KR 100건 중 번역이나 단어 어색함 언급 5건(거친 집계). 업데이트 뒤 언어가 영어로 바뀌었다는 리뷰 1건 | 낮음 | 예 | [추론] 근거가 약하다. 한국어 범주 검수는 REV-06과 묶어 다룬다 |

### 리뷰 원문 요지

작성자 이름은 옮기지 않았다. 요지는 번역해 줄였다.

| 번호 | 앱과 스토어 | 날짜 | 평가 | 요지 | 출처 |
| --- | --- | --- | --- | --- | --- |
| 1 | SAJ, Play US | 2026-09-15 | 도움 91표 | 레벨 사이 광고는 참을 만했지만 진행 중인 판을 끊는 광고가 여러 번 나와 삭제했다. 비슷한 게임이 수없이 많은데 10달러를 내거나 광고 100개를 볼 사람은 없다 | SRC-001 |
| 2 | SAJ, Play US | 2026-09-17 | 도움 118표 | 290레벨이다. 카드 한 장을 넘기는 데도 이동 수가 든다. 150수를 받아도 절반이 넘기기에 쓰인다. 보상이 노력과 코인 비용에 못 미친다 | SRC-001 |
| 3 | SAJ, Play US | 2026-09-16 | 도움 173표 | 광고가 많고 요즘은 철자가 틀린 단어가 몰입을 깬다 | SRC-001 |
| 4 | SAJ, App Store US | 2026-11-18 | 2점 | 26레벨 Super Hard를 50번 넘게 해도 주어진 이동 수로는 못 풀었다. 구매를 유도한다고 느낀다 | SRC-004 |
| 5 | SAJ, App Store US | 2026-11-18 | 1점 | 24시간마다 무료 코인을 받던 기능이 사라졌다. 돈은 쓰지 않을 것이고 추천하지 않는다 | SRC-004 |
| 6 | SAJ, App Store US | 2026-11-18 | 3점 | 단어를 다 알아도 잠금과 열쇠 때문에 같은 판을 5번 넘게 다시 했다 | SRC-004 |
| 7 | SAJ, App Store KR | 2026-11-05 | 1점 | 카드를 뒤집는 것과 옆으로 옮기는 것이 모두 턴에 들어간다. 되돌리기 800, 조커 1,200, 10턴 추가 1,500 코인은 비싸다 | SRC-005 |
| 8 | SAJ, App Store KR | 2026-10-22 | 5점 | 300레벨까지 했다. 뒤로 갈수록 나왔던 단어가 40% 정도 다시 나온다. 힌트는 쓸모가 없고 조커만 좋다 | SRC-005 |
| 9 | Associate Words, Play US | 2026-10-11 | 도움 4표 | 레벨당 광고 한 번이라 괜찮았다. 284레벨쯤에서 오탈자, 말이 안 되는 범주, 한 묶음 안의 egg와 eggs가 거슬려 덜 하게 됐다 | SRC-015 |
| 10 | Solitaire Word Association, Play US | 2026-11-02 | 도움 5표 | 드문 단어가 많아 사전이 필요하다. 광고는 꽤 진행한 뒤에 나온다. 덱에서 둘 카드가 안 나오는 판이 답답하다 | SRC-017 |
| 11 | Word Solitaire Now!, Play US | 2026-11-13 | 표기 없음 | 시도 두 번마다 광고다. 판은 10초에 끝나기도 하는데 광고를 닫는 데 30초가 넘게 걸린다 | SRC-012 |
| 12 | Word Solitaire Now!, Play US | 2026-11-12 | 도움 3표 | 이동 수 제한과 싸우지 않아도 되고 판 도중 광고가 없어서 편하다 | SRC-012 |
| 13 | Association Match 4, Play US | 2026-09-26 | 도움 4표 | 시계 대신 이동 수라 압박이 없다. 이동 수가 떨어지면 짧은 광고로 이어갈 수 있고 광고가 적다 | SRC-023 |
| 14 | Association Match 4, Play US | 2026-10-25 | 표기 없음 | 다시 시작해도 같은 배치가 나와 풀 수 없는 판이 되풀이된다 | SRC-023 |
| 15 | Tile Explorer, Play US | 2025-10-02 | 도움 3,309표 | 파워업용 광고는 버퍼링으로 안 나오는데 판을 지면 바로 광고가 나온다. 판 도중에도 광고가 뜬다 | SRC-042 |
| 16 | NYT Games, App Store US | 2026-11-03 | 4점 | Connections는 다 푼 퍼즐을 볼 시간을 충분히 주지 않아 다시 들어가야 한다 | SRC-029 |

## 화면 구조 관찰

근거는 모두 2026-11-21에 받은 Google Play US 스토어 스크린샷이다. 스토어 스크린샷은 홍보용으로 다듬은 그림이라 실제 화면과 다를 수 있다. 아래는 배치와 순서의 원리만 적었고 그림 자산을 따라 만들라는 뜻이 아니다.

| 게임과 근거 | 구역 배치(위에서 아래) | HUD 구성 | 묶음 완성 표현 | 결과 화면 |
| --- | --- | --- | --- | --- |
| Solitaire Associations Journey, Android, SRC-001의 스크린샷 1~8 | [관찰] 재화와 메뉴 줄, 그 아래 왼쪽에 남은 이동 수와 가운데에 넘긴 카드와 오른쪽에 스톡, 범주 슬롯 한 줄, 태블로 4~5열, 맨 아래 부스터 3개 | [관찰] 남은 이동 수가 가장 큰 숫자다. 상단 가운데에 레벨 안 단계 체크 표시 5칸. 스톡에 남은 장수. 범주 슬롯마다 "3/4" 같은 진행도. 부스터에 보유 수 배지, 다 쓰면 코인 가격 | [관찰] 맞게 놓으면 초록 체크, 틀리면 빨간 X가 카드 위에 뜬다. 완성된 범주는 슬롯이 빈다 | [관찰] 레벨 번호와 "Perfect!" 한 줄, 보상 2칸(코인과 열쇠), Continue 버튼 하나 |
| Word Solitaire Now!, Android, SRC-012의 스크린샷 1~4 | [관찰] HUD 한 줄, 범주 슬롯 한 줄, 태블로, 맨 아래 왼쪽에 스톡과 넘긴 카드 | [관찰] 왼쪽에 난이도와 레벨, 가운데에 진행 막대, 오른쪽에 시간. 일일 모드는 날짜, 이동 수, 목표 | [관찰] 범주 슬롯 아래 점으로 채운 진행 표시 | 확인 못함 |
| Association Match 4, Android, SRC-023의 스크린샷 1~6 | [관찰] HUD 한 줄, 그림 타일 격자 4열, 맨 아래 부스터 3개 | [관찰] 왼쪽에 별 진행 "0/6", 가운데에 가장 크게 남은 이동 수, 오른쪽에 레벨과 설정 | [관찰] 고른 타일은 떠오르고 테두리가 밝아진다. 완성한 묶음은 범주 이름이 붙은 색 띠가 되어 보드 위쪽부터 쌓인다 | [관찰] 보물 상자가 열리는 보상 화면 |
| NYT Connections, Android, SRC-027의 스크린샷 6 | [관찰] 뒤로와 설정과 통계와 도움말, 안내 한 줄, 완성 묶음 띠, 남은 낱말 4열 격자, 결과 보기 버튼 | [관찰] 스크린샷에는 남은 실수 표시와 섞기 버튼이 없다. 확인 못함 | [관찰] 범주 이름과 구성 낱말 4개가 적힌 색 띠가 위에서부터 쌓인다 | [관찰] "View Results" 버튼으로 따로 들어간다 |
| Triple Tile, Android, SRC-038의 스크린샷 6 | [관찰] 겹친 타일 보드, 트레이 한 줄, 맨 아래 부스터 3개 | [관찰] 부스터에 보유 수 배지 | [관찰] 같은 타일 3개가 금색으로 빛난다 | 확인 못함 |

[추론] 다섯 게임에서 공통으로 읽히는 원리는 네 가지다.

1. 지금 얼마나 남았는지 알려 주는 숫자 하나를 상단에서 가장 크게 둔다. 정렬형과 Association Match 4는 이동 수다. 우리 게임에서는 남은 실수가 그 자리에 온다.
2. 이미 이룬 것은 위쪽에, 지금 만질 것은 가운데와 엄지가 닿는 아래쪽에 둔다. 완성 묶음이 위로 올라가 쌓이면 남은 카드가 줄어드는 것이 한눈에 보인다.
3. 도움 기능은 맨 아래 한 줄에 3개를 둔다. 보유 수는 배지로, 다 썼을 때의 대가는 버튼 바로 아래에 적는다.
4. 결과 화면의 주 버튼은 하나다.

[추론] 시선 순서는 상단의 남은 자원, 가운데의 열린 카드, 아래의 임시 칸과 부스터로 내려간다. 우리 화면은 더미 4열, 예비 줄, 임시 칸, 묶기 버튼이 모두 엄지 영역에 들어가야 해서 Solitaire Associations Journey보다 한 화면에 놓을 구역이 많다.

연출 길이, 소리, 홈 화면의 진입점 수는 확인 못함(U-02).

## 정책 확인

### 조항별 요지

| ID | 정책 | 원문 요지 | 출처 | 우리 설계에 주는 제약 |
| --- | --- | --- | --- | --- |
| POL-01 | AdMob 전면 광고 권장 구현 | [사실] 레벨이 있는 게임은 레벨 사이에 둔다. "It is recommended that interstitial ads appear before the break page rather than after." Next나 Continue 버튼 뒤에 나오는 광고는 놀랄 수 있으니 버튼 앞에 내기를 강하게 권한다. 연타를 유도하는 앱은 레벨 종료와 광고 사이에 지연 화면을 둔다. 미리 불러와 지연을 줄인다. 행동마다 내지 않는다 | SRC-044 | 전면을 "다음 판" 버튼을 누른 뒤에 내면 권장과 어긋난다. 아래 대조표 참고 |
| POL-02 | AdMob 전면 광고 금지 구현 | [사실] 앱을 열 때와 나갈 때 금지. "no more than one interstitial ad after every two user actions", 뒤로 가기도 행동으로 센다. 전면을 닫은 직후 또 내지 않는다. 플레이, 입력, 읽기처럼 과업에 집중한 동안 내지 않는다. 내비게이션을 막지 않는다 | SRC-045 | 실행 직후, 백그라운드 복귀, 종료 시점, 판 도중은 금지 구간이다 |
| POL-03 | AdMob 전면 광고 닫기 지연 | [사실] 닫기 버튼이 최대 5초 뒤에 나올 수 있다. 고참여 광고를 켜면 동영상 전면은 최대 12초, 일부 제3자 입찰 동영상은 최대 30초 | SRC-043 | 판이 2~4분이면 전면 한 번이 판 길이의 2~25%를 차지한다. 빈도 계산에 넣는다 |
| POL-04 | AdMob 보상형 정책 | [사실] "Direct monetary items may not be offered as rewards under any circumstance." 보상은 앱 안에서만 쓰이고 양도할 수 없어야 한다. 광고를 보여 주기 전마다 해야 할 행동과 보상을 분명하고 눈에 띄게 알린다. 사용자가 명확히 선택한 뒤에만 보여 준다. 광고는 건너뛰거나 닫을 수 있어야 한다. 거절해도 정상 이용에 지장이 없어야 한다. 문구와 아이콘으로 특정 선택을 유도하지 않는다. 약속한 보상을 지급한다. 무작위 보상은 확률을 미리 알린다 | SRC-046 | 보상형 버튼마다 "광고 보고 무엇을 얻는지"를 적는다. 거절 버튼을 숨기거나 작게 만들지 않는다. 광고를 보지 않아도 판을 계속할 수 있어야 한다 |
| POL-05 | Google Play 광고 정책, 예기치 않은 전면 | [사실] 사용자가 다른 일을 하려고 선택했을 때 뜨는 전면은 금지. 레벨 시작 시점과 콘텐츠 구간 시작 시점의 광고 금지. 스플래시 앞 동영상 전면 금지. 15초 뒤에도 닫을 수 없는 전면 금지. 예외는 사용자가 선택한 전면과 행동을 끊지 않는 전면이고 예시가 "after the score screen in a game app"이다. 선택형 보상형은 예외. 위반 예시는 레벨 시작을 누른 뒤 그 행동이 반영되기 전에 뜨는 광고 | SRC-047 | 결과 화면 뒤 전면은 허용 예시에 든다. "다음 판 시작"을 누른 직후에 뜨면 위반 예시와 닮는다 |
| POL-06 | Google Play 광고 정책, 그 밖 | [사실] 연속된 사용자 행동마다 전면을 내면 Made for Ads 위반. 홈 버튼이나 종료 흐름에서 광고 금지. 광고는 앱의 콘텐츠 등급에 맞아야 한다. 닫기에 불이익이 없어야 한다. 광고를 앱 UI나 시스템 알림처럼 꾸미지 않는다 | SRC-047 | 광고 최대 콘텐츠 등급을 앱 등급에 맞춰 설정한다(POL-14) |
| POL-07 | Apple 2.5.18 | [사실] 전면 광고는 광고임을 분명히 밝히고, 누르도록 속이지 않고, 쉽게 닫을 수 있는 크기의 닫기 버튼을 둔다. 광고가 있는 앱은 부적절한 광고를 신고할 수단을 넣어야 한다. 민감 정보에 기반한 맞춤 광고 금지 | SRC-048 | 설정 화면에 광고 신고 경로가 필요하다 |
| POL-08 | Apple 3.2.2 | [사실] (iii) 광고 노출과 클릭을 인위적으로 늘리거나 광고 표시가 주목적인 앱은 금지. (x) 스토어 평가나 다른 앱 설치를 강요하지 못하지만 "Apps may otherwise incentivize users to take specific actions within apps (such as by completing a level or watching an ad)" | SRC-048 | 광고 시청의 대가로 칸, 힌트, 실수 복구를 주는 것은 허용 문구 안에 든다 |
| POL-09 | Apple 5.1.1과 5.1.2 | [사실] 개인정보처리방침 링크를 App Store Connect와 앱 안에 둔다. 수집에는 동의가 필요하고 철회 수단을 준다. 핵심 기능에 필요한 데이터만 요청한다. 계정 기능이 핵심이 아니면 로그인 없이 쓰게 한다. 추적하려면 App Tracking Transparency로 명시적 허락을 받는다 | SRC-048 | 계정 없이 플레이. 설정에 개인정보처리방침과 동의 변경 진입점 |
| POL-10 | Apple 추적 동의(ATT) | [사실] 추적은 다른 회사의 데이터와 연결해 맞춤 광고나 광고 측정에 쓰거나 데이터 브로커에 넘기는 것이다. 허락이 없으면 광고 식별자는 0으로 채워진다. 추적 허용을 조건으로 기능을 막거나 보상을 주지 못한다. 시스템 알림 앞에 설명 화면을 두는 것은 투명하게 쓰면 허용된다. 제3자 SDK의 수집도 개발자 책임이고 개인정보 라벨에 적는다 | SRC-049 | 추적을 허용하면 코인을 주는 식의 제안은 금지. 광고 SDK가 수집하는 항목을 개인정보 라벨에 신고 |
| POL-11 | Google의 EU 동의 요건 | [사실] EEA, 영국, 스위스 사용자에게 기기 저장소 사용과 광고 개인화를 위한 개인정보 사용에 동의를 받고 기록을 남기며 철회 방법을 알린다(SRC-051). AdMob으로 개인화 광고를 내려면 Google 인증 CMP와 IAB TCF 연동이 필요하다. EEA와 영국은 2024-01-16, 스위스는 2024-07-31부터다. 인증 CMP가 아니면 비개인화 광고나 제한 광고만 가능하다(SRC-052). UMP SDK는 TCF v2.3 인증을 받았다(SRC-053) | SRC-051, SRC-052, SRC-053 | 글로벌 출시이므로 UMP SDK가 필요하다 |
| POL-12 | UMP SDK 구현 요건 | [사실] 앱을 실행할 때마다 동의 정보를 갱신한다. 광고를 요청하기 전에 `canRequestAds()`를 확인한다. 개인정보 옵션이 필요한 지역에서는 눈에 보이는 진입점을 둔다. 동의 상태를 앱이 따로 저장해 쓰지 않는다 | SRC-054 | 첫 실행 흐름에 동의 화면이 들어간다. 설정에 "개인정보 옵션" 항목이 조건부로 보인다 |
| POL-13 | Play 대상 연령과 Families | [사실] 대상 연령은 5세 이하, 6~8, 9~12, 13~15, 16~17, 18세 이상에서 고른다. 아동 연령대를 하나라도 넣으면 Families 정책이 적용되고 자체 인증 광고 SDK만 쓸 수 있다(SRC-055, SRC-056). 아동 대상이 아니라고 선언해도 스토어 등록 자산에 어린 캐릭터나 유아풍 그림이 있으면 반려될 수 있고, 그때는 그 요소를 빼거나 아동을 대상에 넣어야 한다(SRC-055) | SRC-055, SRC-056 | 13세 이상만 선택한다. 스토어 그림이 유아용으로 보이지 않게 한다 |
| POL-14 | 광고 콘텐츠 등급 | [사실] 광고는 앱 콘텐츠 등급에 맞아야 하고, AdMob은 광고 최대 콘텐츠 등급을 G, PG, T, MA로 제한하는 설정을 제공한다. 기존 아동 지정 태그는 지원 중단 표기가 있고 `setAgeRestrictedTreatment()`를 쓰라고 안내한다 | SRC-047, SRC-060 | 앱 등급에 맞춰 최대 등급을 설정한다 |
| POL-15 | Play Data safety | [사실] 모든 공개 앱이 양식을 낸다. 앱에 넣은 SDK가 기기 밖으로 보내는 데이터도 개발자가 신고한다. 개인정보처리방침 링크는 필수다. 전송 중 암호화 여부와 삭제 요청 수단을 밝힌다. 신고와 실제 동작이 다르면 업데이트 차단이나 삭제까지 간다(SRC-057). Google Mobile Ads SDK는 IP 주소(대략적 위치 추정), 앱 실행과 탭과 동영상 시청 같은 상호작용, 진단 정보, 광고 ID와 앱 세트 ID를 광고, 분석, 사기 방지 목적으로 자동 수집하고 공유하며 TLS로 암호화한다(SRC-058) | SRC-057, SRC-058 | 신고 항목은 대략적 위치, 앱 상호작용, 진단, 기기 또는 기타 ID다. 수집과 공유 모두 예로 답한다 |
| POL-16 | 광고 ID 권한 | [사실] Android 13 이상을 대상으로 하는 앱은 매니페스트에 `com.google.android.gms.permission.AD_ID` 권한이 필요하다. 광고 SDK의 매니페스트에서 합쳐질 수 있다 | SRC-059 | 빌드 결과물의 매니페스트에 권한이 들어갔는지 확인한다 |
| POL-17 | Apple 연령 등급 | [사실] 등급은 4+, 9+, 13+, 16+, 18+다. 광고는 Capabilities 항목으로 신고하고 4+ 등급에서도 가능하다 | SRC-050 | 등급 설문에서 Advertising을 예로 답한다 |

[사실] SRC-058 페이지는 제목에 "Legacy" 표기가 붙은 SDK 문서였고 기준 버전은 25.5.0이다. 다른 계열 SDK를 쓰면 그 문서로 다시 확인해야 한다.

### 우리 설계와의 대조

같은 폴더의 GDD 초안(2026-11-21 작성본) 수익화 표를 기준으로 봤다.

| 설계 요소 | 판정 | 조건과 근거 |
| --- | --- | --- |
| 판 종료 전면, "결과 창을 닫고 다음 판으로 넘어갈 때" | [추론] 조건부 허용 | [사실] Play는 점수 화면 뒤 전면을 허용 예시로 든다(POL-05). [사실] AdMob은 Next 버튼 뒤보다 중간 화면 앞을 권한다(POL-01). [추론] 버튼 이름이 "다음 판"이고 누른 직후 광고가 뜨면 Play 위반 예시인 "레벨 시작을 누른 뒤 뜨는 광고"와 구분이 흐려진다. 광고가 닫힌 뒤에야 다음 판을 불러오고, 판이 시작된 뒤에는 절대 뜨지 않게 미리 불러오며, 준비되지 않았으면 건너뛴다 |
| 전면 빈도, 두 번째 실행부터, 누적 3분 뒤, 2판에 1번 이하, 120초 간격 | [추론] 허용 | [사실] 상한은 사용자 행동 2회당 1회이고 닫은 직후 재노출 금지다(POL-02). 초안 값은 이보다 훨씬 느슨하다 |
| 튜토리얼, 플레이 중, 실행과 종료 시점에 전면 없음 | [사실] 요건과 일치 | POL-02, POL-05 |
| 보상형 직후와 거절 직후에 전면 없음 | [추론] 유지 권고 | [사실] 거절이 정상 이용을 방해하면 안 된다(POL-04). 거절 직후 전면을 금지하는 명문 조항은 찾지 못했다 |
| 보상형 칸 추가 | [추론] 허용 | 버튼에 보상과 광고 시청을 함께 적는다. 누르기 전에는 광고가 뜨지 않는다. 거절해도 2칸으로 풀 수 있어야 한다(POL-04, POL-08) |
| 보상형 부스터 충전(힌트, 되돌리기) | [추론] 허용 | 위와 같다 |
| 보상형 이어하기(실수 복구) | [추론] 허용 | 실패 창에서 거절하면 불이익 없이 다시 시작하거나 나갈 수 있어야 한다(POL-04) |
| 보상형 결과 2배 | [추론] 허용 | 보상이 앱 안 재화이고 양도할 수 없다(POL-04). 2배 버튼만 크게 하고 그냥 받기를 숨기면 "선택 유도 금지"에 걸린다 |
| 시청 완료 콜백에서만 보상 지급 | [추론] 허용 | [사실] 광고는 건너뛰거나 닫을 수 있어야 한다(POL-04). 닫으면 보상이 없다는 점을 미리 알린다 |
| 인앱 구매 없음 | [사실] 문제 없음 | [사실] 기능 해제는 인앱 구매가 원칙이지만 광고 시청 유도는 3.2.2(x)가 허용한다(POL-08) |

## 라이선스와 제품명

### Fluent Emoji

- [사실] `microsoft/fluentui-emoji` 저장소의 LICENSE는 MIT이고 저작권 표시는 "Copyright (c) Microsoft Corporation."이다. GitHub가 인식한 라이선스도 MIT다. 저장소는 보관 처리되지 않았고 마지막 푸시는 2026-08-24다(SRC-061).
- [사실] 조건은 한 문장이다. "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software." 사용, 복제, 수정, 병합, 게시, 배포, 재허락, 판매를 제한 없이 허용한다(SRC-061).
- [사실] 자산 폴더에는 이모지마다 3D, Color, Flat, High Contrast 네 가지 스타일이 있다(SRC-061).
- [사실] 라이선스 문언에는 상표 사용을 허락하는 내용이 없다(SRC-061).

상용 앱에 넣을 때 할 일은 다음과 같다.

| 할 일 | 구분 | 근거 |
| --- | --- | --- |
| 앱 안에 오픈소스 고지 화면을 두고 저작권 표시와 MIT 허가문 전문을 싣는다 | [추론] 앱 패키지가 이모지 사본을 담으므로 고지 조건이 적용된다 | SRC-061 |
| 저장소에 제3자 고지 파일을 두고 가져온 커밋과 스타일(Flat)을 적는다 | [추론] 출처를 추적하기 위한 관리 | SRC-061 |
| 색을 바꾸거나 잘라 쓰는 수정은 해도 된다 | [사실] 수정 허용 | SRC-061 |
| Microsoft 이름과 로고를 홍보에 쓰지 않는다 | [추론] 상표 허락이 없다 | SRC-061 |
| 브랜드나 특정 상품을 떠올리게 하는 이모지는 범주 원장에서 뺀다 | [추론] 상표가 걸린 이모지의 일반 대체물이 없다는 이슈가 답 없이 열려 있다 | SRC-062 |

스토어 스크린샷과 아이콘에 대해서는 다음과 같다. [추론] MIT 문언이 사용과 게시를 제한 없이 허용하므로 이모지가 보이는 게임 화면을 스크린샷으로 올리는 것을 막는 조항은 없다. [사실] 다만 실물 상품, 영상, SNS 게시물에서 고지를 어떻게 하느냐는 질문 두 건(이슈 94, 103)에 저장소 관리자의 답이 없다(SRC-062). 공식 근거는 확인 못함(U-08). [추론] 앱 아이콘은 Fluent Emoji 한 개를 그대로 쓰지 말고 따로 만드는 편이 안전하다. 누구나 같은 그림을 쓸 수 있어 다른 앱과 구별되지 않고, Apple 4.1(c)와 5.2.1의 혼동 판단에서도 불리하다(SRC-048). [관찰] 이슈 103의 작성자는 Figma 배포본이 CC BY 4.0이라고 적었다. 확인 못함. GitHub 저장소본만 쓰는 것이 조건이 분명하다(SRC-062).

### 제품명 충돌

| 이름 | 찾은 곳 | 결과 | 출처 |
| --- | --- | --- | --- |
| Four Alike | Google Play US, 따옴표 검색 | [사실] 같은 이름 없음. 결과는 관련 없는 주사위 게임 1건 | SRC-065 |
| Four Alike | Google Play KR | [사실] 같은 이름 없음. Alike(여행), alike(쇼핑 검색), Four In A Line 등이 나온다 | SRC-065 |
| Four Alike | App Store US와 KR(iTunes Search API) | [사실] 같은 이름 없음 | SRC-066 |
| Four Alike | USPTO, 검색어 "four alike", "4 alike", "fouralike" | [사실] 0건 | SRC-063 |
| Four Alike | 일반 웹 검색 | [관찰] 같은 이름의 게임 없음. 가까운 이름은 Four Match(itch.io), Any4, Flip Four, Match Four. 검색 요약으로만 확인했다 | 검색 도구 결과 |
| 끼리끼리 | Google Play KR | [사실] "끼리끼리: 동네친구 찾기, 친구만들기, 수다 떠는 채팅"(컬러풀)이 있다. 5천 이상 다운로드, 4.4점, 리뷰 248개, 청소년이용불가 등급의 채팅 앱이다 | SRC-065, SRC-067 |
| 끼리끼리 | App Store KR | [사실] 같은 이름으로 시작하는 앱 3종이 있다. 플리마켓, 궁합형 소셜, 가계부 비교 앱이고 2026-07에서 2026-11 사이에 나왔으며 평가는 0~1건이다. 게임은 없다 | SRC-066 |
| 끼리끼리 | 한국 상표 | 확인 못함(U-01) | SRC-071 |

비슷한 이름과 관련 상표는 다음과 같다.

| 이름 | 내용 | 혼동 위험 | 출처 |
| --- | --- | --- | --- |
| Alike! | [사실] App Store 게임, 개인 개발자, 평가 0건, 마지막 업데이트 2024-01-30. 규칙이 바뀌는 빠른 짝 맞추기 | [추론] 낮음. 이용자가 거의 없고 이름 앞부분이 다르다 | SRC-068 |
| Four Four! | [사실] App Store 게임, 개인 개발자, 평가 0건, 2024-06 뒤 업데이트 없음. 4x4 캡슐 색 맞추기 | [추론] 낮음 | SRC-069 |
| Alike, ALIKE, Match Alike, Tresilo: Collect 3 Alike | [사실] Play에 여행 앱, 사진 앱, 소규모 퍼즐 등 "Alike"가 든 앱이 여럿 있다 | [추론] 낮음~보통. "Alike" 한 단어만으로는 검색에서 우리 앱을 찾기 어렵다 | SRC-065 |
| LINK ALIKE | [사실] 미국 등록 상표, 등록번호 6261265, 주 등록부, 28류 카드 게임과 교육용 카드 게임, 2021-02-02 등록 | [추론] 보통. 뒷단어가 같고 카드 게임이다. 분류가 실물 게임이고 앞단어가 다르다. 전문가 판단이 필요하다 | SRC-063 |
| WORD SOLITAIRE | [사실] 미국 등록 상표, 등록번호 4072139, 보조 등록부, 9류 모바일 게임 소프트웨어, 2011-12-13 등록, 2021-12-23 갱신, "SOLITAIRE"는 권리 불요구 | [추론] 보통. 보조 등록부는 기술적 표장에 쓰이고 이 말을 제목에 넣은 앱이 수십 종이다. 그래도 마켓 표기 `Four Alike: Word Solitaire`는 이 등록과 글자가 같다 | SRC-064, SRC-021 |
| CONNECTIONS | [사실] The New York Times Company의 미국 등록 상표. 표준 문자 등록번호 7811308(2025-05-27), 도형 결합 등록번호 7612938(2024-12-17), 주 등록부, 9류 퍼즐과 단어 게임 모바일 앱과 41류 | [추론] 높음. 제품명, 부제, 키워드, 웹 페이지 제목에 쓰지 않는다 | SRC-063 |
| SOLITAIRE ASSOCIATIONS JOURNEY | [사실] Hitapps Games Ltd의 미국 등록 상표, 등록번호 8377500, 2026-08-04 등록, 9류와 41류 | [추론] 낮음. 우리 이름과 겹치는 낱말이 없다. 설명문에 경쟁작 이름을 쓰지 않는다 | SRC-063 |

평가는 다음과 같다. 법률 의견이 아니고 조사 범위 안의 판단이다.

- [추론] Four Alike는 미국과 한국의 두 스토어, 미국 상표 기록에서 같은 이름이 나오지 않았다. 충돌 위험은 낮다. 출원 전에는 전문가의 유사 검색이 필요하고 LINK ALIKE를 함께 검토해야 한다.
- [추론] 끼리끼리는 한국 스토어에 같은 이름의 비게임 앱이 4종 있다. 게임 분류에서는 겹치지 않지만 검색 결과가 섞이고, 일상어라 이름만으로 구별하기 어렵다. `끼리끼리: 연상 카드 퍼즐`처럼 설명어를 붙인 표기는 구별에 도움이 된다. 한국 상표 상태는 확인 못함.
- [추론] 최초 기획서 5절이 검색 유입 목표로 든 "connections unlimited"는 NYT 등록 상표를 포함한다. 웹 페이지 제목이나 앱 메타데이터에 쓰면 Apple 2.3.7(상표나 인기 앱 이름으로 메타데이터를 채우지 말 것)과 5.2.1에도 걸린다(SRC-048).
- [추론] 우리 규칙은 범주 카드 아래에 쌓는 정렬형이 아니다. 부제에 Word Solitaire를 쓰면 정렬형을 기대하고 들어온 사람이 다른 게임이라고 느낄 수 있다.

## 검색 수요 정황

| 키워드 또는 지표 | 내용 | 출처 |
| --- | --- | --- |
| Connections, Google 연간 급상승 검색 | [보도] 2023년 게임 부문에서 미국 2위, 전 세계 3위(SRC-033). 2024년 목록에서 1위이고 2위가 같은 회사의 Strands. 기사에 지역 범위 표기가 없다(SRC-034). 2025년은 확인 못함 | SRC-033, SRC-034 |
| NYT Connections 풀이 수 | [보도] 2025년 16억 회, NYT Games 전체는 112억 회. NYT 발표를 전한 기사다(SRC-032). 2024년 값은 원문을 열지 못해 확인 못함 | SRC-032 |
| "connections unlimited" | [추정치] 미국 월 검색량 14.8만. 같은 사이트 프로필에서 "connections"는 1,600만 이상, "connections game"은 200만, "connections nyt unlimited"는 3.9만. 스냅샷 날짜가 불명확하다 | SRC-037 |
| "word solitaire" | 검색량 수치는 확인 못함. [사실] App Store US 검색 결과 33건 가운데 28건이 2025-09-11보다 뒤에 나왔다(SRC-021) | SRC-021 |
| "associations" | 검색량 수치는 확인 못함. [사실] 이 말을 이름에 넣은 Solitaire Associations Journey가 Play에서 "#1 top grossing word", App Store Word 무료 2위다(SRC-001, SRC-003) | SRC-001, SRC-003 |
| "category solitaire" | 수치도 정황도 찾지 못했다 | 없음 |
| Solitaire Associations Journey의 유입 규모 | [추정치] 2025년 4분기 미국 주간 다운로드 최고 약 92.4만(통합), 약 81.2만(iOS)(SRC-007, SRC-009). 2026년 11월 주간 설치 약 33.1만(SRC-006). 2025-09-27 하루 미국 App Store 설치 21,486건(SRC-011) | SRC-006, SRC-007, SRC-009, SRC-011 |
| 퍼즐 장르 전반 | [보도] 2026년 상반기 상위 타이틀은 설치가 줄고 매출이 늘었으며 설치 상위 300위 가운데 신작 비중이 2023년 중반 8%에서 2026년 2%로 줄었다는 업계 기고. 수치의 원자료는 공개되지 않았다 | SRC-070 |

[추론] Connections 계열 검색 수요는 크지만 그 말 자체가 등록 상표다. 정렬형 워드 솔리테어는 2025년 9월 이후 1년 남짓 사이에 수십 종이 나와 스토어 검색이 붐빈다. 수요는 확인되지만 새 이름이 검색으로 발견될 여지는 좁다.

## 기회와 위험

### 우리 규칙이 기존작과 다른 지점

| 축 | 정렬형 워드 솔리테어(COMP-01~03) | 숨은 범주 묶기(COMP-04~06) | Four Alike |
| --- | --- | --- | --- |
| 범주 공개 | [관찰] 범주 이름이 슬롯에 보인다. 과제는 어느 범주에 놓을지와 놓는 순서다 | [사실] 범주가 숨어 있다. 과제는 어떤 4개가 한 묶음인지 추리하는 것이다 | 범주가 숨어 있다 |
| 카드 공개 | [관찰] 스톡과 뒤집힌 카드가 있다 | [관찰] 처음부터 전부 보인다 | 16장 중 8장만 보이고 8장은 더미 뒤에 있다 |
| 제약 자원 | [관찰] 이동 수. 탐색에도 든다 | [관찰] 실수 4회(COMP-04, 05) 또는 이동 수(COMP-06) | 실수 4회와 임시 칸 2개 |
| 막혔을 때 할 수 있는 일 | [관찰] 스톡 넘기기, 조커, 되돌리기 | [사실] 섞기와 힌트 | 더미 맨 앞 카드를 임시 칸으로 옮겨 뒤 카드를 연다 |
| 한 판 규모 | [관찰] 범주 4~5개가 동시에 열리고 스톡 7~26장 | [사실] 16개(COMP-04, 05), [관찰] 20~24개(COMP-06) | 16장 |

[추론] 조사한 범위에서는 숨은 범주 추리, 가려진 더미, 적은 수의 임시 칸을 함께 쓰는 게임을 찾지 못했다. 범위는 Play 검색 상위 21건, App Store 검색 상위 33건, 그리고 설명을 읽은 작품들이다. 스토어 전체를 훑은 것이 아니다. 이름이 가장 가까운 Connections Solitaire는 설명으로 보면 범주를 찾아 카드를 모으고 이동 수 안에 비우는 방식이다(SRC-020).

### 채워지지 않은 경험

| 기회 | 근거 | 우리 대응 | 검증 비용 | 우선순위 |
| --- | --- | --- | --- | --- |
| 탐색이 벌이 되지 않는 판 | REV-03. 넘기기에 이동 수가 드는 것이 정렬형의 대표 불만이다 | [추론] 임시 칸 이동에 횟수 비용을 두지 않는 현재 규칙을 지킨다 | 낮음. 플레이테스트 | 1 |
| 판 도중 광고가 없는 워드 카드 게임 | REV-01, REV-02 | [추론] 플레이 중 전면 0회를 지키고 스토어 설명에 밝힌다 | 중간. 소프트론칭 지표 | 1 |
| 광고 없이도 풀리는 판 | REV-05. 운이나 구매 없이는 못 푼다는 불만 | [추론] 2칸 해법을 전수 검증한다. 숨은 카드 때문에 생기는 운을 판마다 계산해 난도에 반영한다 | 중간. 생성기 검증 | 1 |
| 하루 한 판에 묶이지 않는 범주 추리 | REV-12, 검색 수요 정황 | [추론] 무제한 스테이지와 일일 도전을 함께 둔다 | 낮음 | 2 |
| 전부 보이는 격자에는 없는 "한 장만 더 열면" 순간 | COMP-04~06의 화면 구조 | [가설] 가려진 8장과 임시 칸이 이 순간을 만든다 | 중간. 플레이테스트 | 2 |

[관찰] 단어와 그림을 함께 쓰는 것은 차별점이 아니다. Solitaire Associations Journey와 Word Solitaire Now!는 단어 카드와 그림 카드를 섞어 쓰고 Association Match 4는 그림만 쓴다(SRC-001, SRC-012, SRC-023).

### 가장 큰 위험 세 가지

| 위험 | 근거 | 우리 대응 | 검증 비용 | 우선순위 |
| --- | --- | --- | --- | --- |
| RISK-R1 포화된 장르에서 발견되지 않는다 | [사실] App Store US의 "word solitaire" 검색 결과가 33건이고 그 가운데 28건이 2025-09-11보다 뒤에 나왔다(SRC-021). [사실] 숨은 범주 묶기에는 Tripledot이 2026-08에 4개 묶기로, Hitapps가 2024-10에 낱말 묶기로 이미 들어와 있다(SRC-024, SRC-026, SRC-073). [사실] Apple 4.3(b)는 기존 인기 앱의 변형을 기회주의적으로 내는 것을 스팸으로 본다(SRC-048). [보도] 설치 상위권에서 신작 비중이 줄고 있다는 기고(SRC-070) | [추론] 심사 메모와 스토어 첫 스크린샷에서 규칙 차이를 먼저 보여 준다. 유료 광고 없이 검색 유입에 기댄다면 목표 설치 수를 낮게 잡는다 | 높음. 출시 뒤에야 알 수 있다 | 1 |
| RISK-R2 범주 품질 사고가 평점으로 이어진다 | [관찰] 오탈자, 말이 안 되는 범주, 단어 반복이 장르 공통 불만이다(REV-06). [추론] 범주를 숨기면 틀렸을 때 "억지"라고 느끼기 쉽고, 실수 4회 제한과 겹치면 한 번의 모호한 카드가 판 실패로 이어진다. [사실] 기획은 범주 조합을 생성기로 만든다(SRC-072) | [추론] 언어별 사람 검수를 출시 조건으로 둔다. 묶음을 완성하면 범주 이름을 보여 주고, 실패한 판에서는 정답 묶음과 범주 이름을 모두 보여 준다. 신고 버튼을 둔다 | 중간. 판 표본 검수 | 1 |
| RISK-R3 광고 전용 수익이 판 구조와 맞지 않는다 | [추정치] 선두작은 광고와 인앱 구매를 함께 쓰고 최근 추정으로는 인앱 구매 비중이 더 크다(SRC-006). [관찰] 경쟁작은 판 도중과 매 판 뒤에 전면을 낸다(REV-01, REV-02). 우리는 판 뒤에만, 2판에 1번 이하다. [가설] 2칸으로 항상 풀리면 세 번째 칸 보상형을 볼 이유가 약하다. [관찰] 돈을 내고라도 광고를 없애고 싶다는 리뷰가 있는데 우리는 그 수단이 없다(SRC-017) | [추론] 보상형 수락률과 판당 전면 노출을 소프트론칭의 첫 지표로 본다. 광고 제거 상품이 없다는 결정을 소프트론칭 뒤에 다시 본다 | 높음. 실제 광고 지표가 필요하다 | 1 |

그 밖의 위험은 다음과 같다.

- [추론] 16장 판은 경쟁작보다 작다. 판이 90초 안에 끝나면 전면 간격 120초와 2판 1회 조건이 겹쳐 세션당 전면이 1회에 못 미칠 수 있다.
- [추론] 임시 칸이 가득 찼는데 보이는 카드로 묶을 수 있는 4장이 없으면 더 진행할 수 없다. 초기 배치가 풀린다는 검증과 플레이 도중 막힌 상태는 다른 문제다. GDD의 막힘 안내와 되돌리기가 이 상태를 반드시 벗어나게 하는지 규칙으로 적어야 한다.
- [추론] 제품명과 부제의 상표 문제(제품명 절).
- [추론] 스토어 그림이 이모지 위주이면 Play가 아동 지향으로 볼 여지가 있다(POL-13).

## 검증할 가설

성공과 폐기 기준의 숫자는 외부 벤치마크가 아니라 제품 가설이다. 소프트론칭에서 고친다.

| Hypothesis ID | 가설 | 선행 근거 | 검증 방법 | 성공 | 폐기 기준 | 시점 |
| --- | --- | --- | --- | --- | --- | --- |
| H-01 | 처음 보는 사람이 튜토리얼 한 판으로 숨은 범주 묶기와 임시 칸의 쓰임을 이해한다 | 정렬형과 규칙이 달라 기존 학습이 통하지 않는다(경쟁작 매트릭스) | 개발 빌드로 5~8명 관찰. 설명 없이 두 번째 판을 풀게 한다 | 80% 이상이 도움 없이 두 번째 판을 끝낸다 | 절반 이상이 임시 칸을 왜 쓰는지 말하지 못한다. 그러면 튜토리얼과 칸 표현을 다시 만든다 | 프로토타입 |
| H-02 | 판을 푸는 동안 임시 칸이 모자란 순간이 생기고, 그때 세 번째 칸 보상형을 고른다 | 트레이형의 이어하기 구조(인접 경쟁작), RISK-R3 | 프로토타입 로그로 칸이 가득 찬 판의 비율을 재고, 소프트론칭에서 보상형 수락률을 잰다 | 칸이 가득 찬 판이 전체의 30% 이상이고 그 가운데 15% 이상에서 수락 | 수락이 5% 미만이다. 그러면 칸 추가를 보상형 주력에서 내리고 힌트와 이어하기 중심으로 바꾼다 | 소프트론칭 |
| H-03 | 생성한 판에서 사람이 "억지"라고 보는 범주 조합이 드물다 | REV-06, RISK-R2 | 생성한 판 200개를 영어와 한국어 검수자 2명씩이 범주 이름을 가린 채 풀고 모호한 카드를 표시한다 | 모호 판정을 받은 판이 2% 이하 | 5%를 넘는다. 그러면 자동 조합을 멈추고 사람이 검수한 덱만 싣는다 | 콘텐츠 제작 |
| H-04 | 플레이 중 광고가 없으면 광고 불만 리뷰 비율이 경쟁작보다 뚜렷이 낮다 | SAJ 최근 글 리뷰의 60%가 광고를 말한다(REV-01) | 소프트론칭 리뷰와 설문에서 광고 언급 비율을 센다 | 글 리뷰의 광고 언급이 20% 이하 | 40%를 넘는다. 그러면 전면 간격과 시작 조건을 다시 잡는다 | 소프트론칭 |
| H-05 | 16장 판이 2~4분 걸린다 | 기획의 세션 길이 가정(SRC-072) | 플레이테스트와 소프트론칭에서 판 길이 중앙값을 잰다 | 중앙값 2~4분 | 중앙값이 90초 미만이다. 그러면 전면 조건을 판 수가 아니라 시간 기준으로 바꾸거나 판 구성을 다시 본다 | 프로토타입 |
| H-06 | 단어와 그림을 함께 보여 주면 모국어가 아닌 언어에서도 정답률이 유지된다 | 장르 관행(SRC-001, SRC-023), 기획의 글로벌 가정 | 같은 판을 그림 있음과 없음으로 나눠 묶기 성공률과 실수 수를 비교한다 | 그림이 있을 때 실수가 20% 이상 줄어든다 | 차이가 없다. 그러면 그림 제작과 검수 비용을 줄인다 | 프로토타입 |
| H-07 | Four Alike라는 이름과 현재 부제로 스토어 검색에서 발견된다 | RISK-R1, 제품명 절 | 출시 뒤 30일 동안 Play Console과 App Store Connect의 검색 유입 설치를 본다 | 검색 유입이 전체 설치의 30% 이상 | 10% 미만이다. 그러면 부제와 키워드, 첫 스크린샷을 바꾼다 | 출시 뒤 30일 |

## 결정 반영

조사 결과가 반영돼야 할 설계 항목이다. 결정 자체는 결정 로그가 소유하고, 여기에는 근거와 권고만 적는다.

| ID | 결정 항목 | 반영 위치 | 근거 | 권고 | 다시 볼 시점 |
| --- | --- | --- | --- | --- | --- |
| REC-01 | 전면 광고가 뜨는 정확한 시점 | GDD 수익화, 기술 계획의 광고 흐름 | SRC-044, SRC-045, SRC-047 | 결과 창을 닫은 뒤에 내되 광고가 닫힌 다음에 다음 판을 불러온다. 판이 시작된 뒤에는 뜨지 않게 미리 불러오고 준비되지 않았으면 건너뛴다. 결과 창 버튼은 판을 바로 시작하는 문구보다 창을 닫는 문구가 안전하다 | 스토어 심사 전 |
| REC-02 | 플레이 중, 실행 시, 복귀 시, 종료 시 전면 0회 | GDD 수익화, 인수 시나리오 | SRC-045, SRC-047, SRC-001, SRC-004 | 현재 초안을 유지한다. 타이머로 끼어드는 "ad break"는 넣지 않는다 | 바꾸지 않는다 |
| REC-03 | 보상형 제안 화면의 문구와 거절 경로 | UI 명세의 보상형 버튼, GDD 수익화 | SRC-046, SRC-048 | 버튼마다 광고 시청과 보상을 함께 적는다. 거절 버튼을 같은 크기로 둔다. 광고가 없을 때의 대체 길을 남긴다. 추적 허용에 보상을 걸지 않는다 | 스토어 심사 전 |
| REC-04 | 실패 조건은 실수, 탐색은 무비용 | GDD 규칙 | SRC-001, SRC-004, SRC-005, SRC-016 | 임시 칸 이동에 횟수 제한이나 비용을 붙이지 않는다 | 수직 슬라이스 |
| REC-05 | 범주 품질 게이트와 오답 뒤 설명 | GDD 콘텐츠, 경제와 콘텐츠 문서 | SRC-001, SRC-005, SRC-015, SRC-017 | 언어별 사람 검수, 맞춤법 검사, 단수와 복수 중복 금지, 최근 사용 범주 재사용 제한을 출시 조건으로 둔다. 실패한 판에서 정답 묶음과 범주 이름을 보여 준다 | 콘텐츠 제작 |
| REC-06 | 동의와 개인정보 흐름 | 기술 계획의 플랫폼 연동, QA 문서의 개인정보 절 | SRC-048, SRC-049, SRC-052, SRC-054, SRC-057, SRC-058, SRC-059 | UMP SDK로 동의를 받고 실행마다 갱신한다. iOS는 ATT 알림 앞에 설명을 둔다. 설정에 개인정보처리방침, 개인정보 옵션, 광고 신고 경로를 둔다. Data safety와 App Privacy에 광고 SDK 수집 항목을 신고한다 | 스토어 등록 전 |
| REC-07 | 대상 연령과 광고 등급 | QA 문서의 연령등급 절, 스토어 등록 자산 | SRC-055, SRC-056, SRC-060, SRC-047 | Play 대상 연령은 13세 이상만 고른다. 스토어 그림을 유아용처럼 보이지 않게 만든다. 광고 최대 콘텐츠 등급을 앱 등급에 맞춘다 | 스토어 등록 전 |
| REC-08 | Fluent Emoji 고지와 아이콘 | 아트 바이블의 생성과 라이선스 절, 설정 화면 | SRC-061, SRC-062 | 앱 안 오픈소스 고지 화면과 저장소 고지 파일을 만든다. 앱 아이콘은 따로 만든다. 브랜드를 떠올리게 하는 이모지는 뺀다 | 아트 승인 전 |
| REC-09 | 제품명과 마켓 표기 | 제품 브리프의 제품 계약, 결정 로그 DEC-004 | SRC-063, SRC-064, SRC-065, SRC-066, SRC-067 | Four Alike는 유지할 수 있다. 부제 "Word Solitaire"는 미국 보조 등록부 상표와 글자가 같고 규칙 기대도 어긋나므로 다른 설명어를 검토한다. 끼리끼리는 설명어를 붙인 표기를 유지한다. 한국 상표는 출원 전에 따로 조회한다 | 스토어 등록 전 |
| REC-10 | "Connections" 낱말 사용 금지 | 스토어 문구, 웹 페이지 계획 | SRC-063, SRC-048 | 제품명, 부제, 키워드, 설명, 웹 페이지 제목에 쓰지 않는다. 최초 기획서의 검색 유입 목표 키워드를 다시 정한다 | 스토어 등록 전 |
| REC-11 | 스토어 포지셔닝 | QA 문서의 출시 포지셔닝 절 | SRC-021, SRC-022, SRC-023, SRC-048 | 첫 스크린샷과 설명 첫 줄에서 "범주가 숨어 있다"와 "플레이 중 광고 없음"을 보여 준다. 심사 메모에 정렬형과의 규칙 차이를 적는다 | 스토어 등록 전 |
| REC-12 | 진행 저장과 언어 변경 | GDD 저장과 리셋 계약 | SRC-025, SRC-017, SRC-005 | 업데이트와 언어 변경에서 진행이 지워지지 않게 하고 불러오기 실패 때 복구 경로를 둔다 | 수직 슬라이스 |
| REC-13 | 광고 제거 수단이 없다는 결정의 재검토 조건 | 결정 로그 DEC-002 | SRC-003, SRC-006, SRC-017 | 첫 출시는 초안대로 간다. 소프트론칭에서 광고 불만 비율과 보상형 수락률을 본 뒤 다시 판단한다 | 소프트론칭 뒤 |
| REC-14 | 광고 소재 품질 관리 | 기술 계획의 광고 설정, 운영 문서 | SRC-012, SRC-014, SRC-016, SRC-048 | 광고망에서 민감 분류와 문제 광고주를 막고, 이용자 신고를 받아 차단하는 절차를 둔다 | 출시 전 |
| REC-15 | 화면 배치 원리 | UI 명세의 화면 계약 | SRC-001, SRC-023, SRC-027, SRC-038 | 남은 실수를 상단에서 가장 크게, 완성 묶음은 위로, 열린 카드와 임시 칸은 엄지 영역에, 부스터는 맨 아래 한 줄에 둔다. 다 푼 판을 다시 볼 수 있게 한다 | UI 승인 전 |
| REC-16 | 플레이 도중 막힌 상태의 규칙 | GDD 규칙과 상태 머신 | SRC-023, SRC-004 | 임시 칸이 차고 묶을 4장이 없을 때 벗어나는 길(되돌리기, 칸 추가, 다시 시작)을 규칙으로 적고 광고 없이도 한 가지는 쓸 수 있게 한다 | 수직 슬라이스 |
