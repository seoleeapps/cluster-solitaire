# Google Play

## 앱 정보

| 항목 | 값 |
|---|---|
| 이름 | Four Alike (영어), 끼리끼리 (한국어) |
| 패키지 | `com.seoleeapps.fouralike` |
| 언어 | 앱은 영어와 한국어를 지원한다. 마켓 기본 언어는 en-US |
| 가격 | 무료 |
| 수익 | AdMob 보상형과 전면 광고. 인앱결제 없음 |
| 계정과 서버 | 없음. 진행은 기기에 저장한다 |
| 개인정보 처리방침 주소 | https://www.seorilabs.com/en/apps/four-alike/privacy/ |
| 문의 | cs@seorilabs.com, https://www.seorilabs.com (전화번호는 싣지 않음) |

등록 정보, 정책 신고 내용, 출시 관문의 정본은 [QA 론칭 계획](../design/2026-11-21-four-alike-launch/07-qa-launch-plan.md)이다. 마켓 문구의 상표 제약은 [결정 로그](../design/2026-11-21-four-alike-launch/decision-log.md) DEC-018을 따른다. 이 문서에는 저장소 설정과 실제 등록 상태만 적는다.

## 현재 상태

광고와 동의, 분석, 원격 설정의 어댑터가 `godot/game/adapters`에 있고 시작 장면에 연결되어 있으며, 원격 설정은 GitHub Pages(`https://seoleeapps.github.io/cluster-solitaire/config.json`)에 배포되어 HTTP 200을 반환한다. Android 서명 AAB(`build/android/four-alike.aab`, `1.0.0`, versionCode 3)를 빌드해 `check_aab.py`를 통과시켰고, Google Play 내부 테스트 설치 기준 실기기 검수(AND-01~08, [실기기 검수 기록](../07-qa/device-and01-08.md))를 마친 뒤 프로덕션 트랙 `1.0.0 (3)`을 178개 전체 국가 대상으로 제출해 `검토 중` 상태를 재조회로 확인했다. 남은 관문은 Google Play 심사 승인·자동 공개(`관리형 게시 사용 중지됨`), 스토어 공개 라이브 스모크 확인, 공개 후 AdMob 스토어 연결이다. 출시별 상태와 근거는 [출시 원장](../../release/market-launch-state.json)에 남긴다.

## Play Console 등록 상태 (2026-11-22 기준)

앱은 Play Console(`Seori Apps`, 계정 ID `5547060480954653351`, 앱 ID `4975800442388222513`)에 만들어져 있고, 앱 설정 12/12와 내부 테스트 3/3(`1.0.0 (3)` 활성, `Seorilabs Testers`·`내부테스트 그룹` 선택, 참여 URL `https://play.google.com/apps/internaltest/4700231235037871892`)을 마쳤다. 프로덕션 트랙은 178개 전체 국가/지역에 `1.0.0 (3)` 전체 출시를 제출해 현재 `검토 중`이며 관리형 게시가 꺼져 있어 승인 시 자동 공개된다.

| 항목 | 저장한 값 |
|---|---|
| 개인정보처리방침 | 위 주소 (`HTTP 200` 확인) |
| 광고 | 앱에 광고가 있음 |
| 로그인 세부정보 | 제한된 부분 없음 |
| 콘텐츠 등급(IARC) | 14문항 모두 "아니요". ESRB 전체이용가, PEGI 3, GRAC 전체이용가, USK 전체이용가, ACB 일반, ClassInd 전체이용가, 그 밖의 지역 3세 이상 |
| 타겟층 | 13~15세, 16~17세, 18세 이상 |
| 데이터 보안 | 수집과 공유 있음(대략적인 위치, 앱 상호작용, 진단, 기기 또는 기타 ID), 전송 중 암호화, 계정 만들기 없음. 삭제 요청 문항은 비워 둠(계정이 없고 전용 삭제 페이지가 없다) |
| 광고 ID | 사용함. 목적은 광고 또는 마케팅, 분석 |
| 정부, 금융, 건강 앱 | 해당 없음 |
| 판매자 상태 | 앱 수준 판매자 상태 적용("예") |
| 앱 카테고리와 연락처 | 게임 > 퍼즐, 위 문의 값 |
| 스토어 등록정보 | `en-US`, `ko-KR` 제목·설명, 아이콘, 한/영 대표 이미지, 한/영 휴대전화 스크린숏 각 6장(API 재조회 완료) |

비공개 테스트 12명 14일 요건은 이 계정의 Console에 나오지 않는다. 실기기 검수(AND-01~08) 통과 후 프로덕션 `1.0.0 (3)`을 검토 제출했다.

## 스토어 등록정보

문구는 `play-store/google-play.config.json`의 `storeListing`이 정본이다(en-US, ko-KR). 그림은 `play-store/assets/`에 있다. 앱 아이콘은 `python3 tools/art/build_store_art.py`, 대표 이미지(1024x500, 언어별)는 `python3 tools/art/build_feature_graphic.py`로 만들고 둘 다 `npm run check:generated`가 원본과 맞는지 본다. 대표 이미지는 아이콘의 배경과 게임 글꼴, 카드 그림만 쓴다. 한국어 그림은 등록 도구가 기본 언어 그림만 올리므로 `localizedAssets`에 따로 적어 둔다.

휴대전화 스크린숏은 언어마다 6장(1080x1920)이고 `play-store/screenshots/phone/<언어>/`에 있다. 순서는 묶기 4/4, 범주 공개, 임시 칸, 일일 도전, 도감, 꾸미기다. 실제 게임 화면을 렌더링으로 찍고 그 위에 문구 띠를 얹는다. 게임 화면은 기기 틀 없이 아이콘과 같은 그라데이션 위에 놓는다. 화면 안의 언어는 스크린숏의 언어와 같다. 문구는 `tools/store/build_screenshots.py`의 `SHOTS` 표가 정본이다. 다시 만들 때는 창을 띄울 수 있는 개발 PC에서 아래를 실행한다.

```bash
python3 tools/store/build_screenshots.py
```

이 명령은 Godot을 렌더링 모드(`--audio-driver Dummy --fixed-fps 60`, headless 아님)로 띄워 `godot/tests/game/store_capture.gd`를 돌린다. 원본 화면은 `build/store-capture/<언어>/`에 남고 커밋하지 않는다. 시계, 난수, 프레임 시간을 고정했으므로 같은 커밋에서는 같은 그림이 나온다. 다른 창이 초점을 가져가 탭이 빠지면 로그의 `The window lost focus` 줄을 보고 두 번까지 다시 찍는다. 문구만 고쳤으면 `--no-capture`로 원본을 다시 찍지 않고 그림만 새로 그린다. 새로 만든 12장은 커밋하기 전에 모두 직접 열어 문구 잘림, 화면 상태와 문구의 일치, 한국어 화면에 섞인 영어가 없는지 본다. CI에는 창이 없으므로 `npm test`는 `--check`로 파일 수, 크기, 용량과 설정의 경로 목록만 확인한다.

## 저장소 설정

Android 16(API 36)을 대상으로 하고 최소 API는 26, 아키텍처는 arm64-v8a, 산출물은 Gradle AAB다. 식별자와 산출물 경로는 `godot/config/product.json`, `godot/export_presets.cfg`의 Android preset, `play-store/google-play.config.json`에 있고, 세 곳이 어긋나면 `npm run check:native`가 실패한다. 서명 값과 AdMob, GA4의 값은 환경 변수나 로컬 자격증명 파일에서 읽고 저장소에 넣지 않는다. 저장소의 버전 `1.0.0`과 versionCode `1`은 기본값이다.

빌드, 업로드, 심사 제출, 승인, 공개는 서로 다른 상태다. 빌드 성공이나 업로드 응답을 공개 출시로 적지 않고, 트랙의 실제 versionCode와 상태를 콘솔이나 API에서 다시 읽어 기록한다.

빌드 방법은 [Android 빌드](../06-release/android-build.md), 업로드 경로는 [workflow 문서](../06-release/ci-cd-workflows.md)에 있다.
