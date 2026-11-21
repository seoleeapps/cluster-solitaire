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

광고와 동의, 분석, 원격 설정의 어댑터가 `godot/game/adapters`에 있고 AdMob 편집기 플러그인이 켜져 있다. 릴리스 빌드에는 AdMob SDK와 UMP, 제품의 AdMob 앱 ID가 들어간다. 시작 장면에 어댑터를 연결하는 일은 남아 있고, 연결 전의 빌드는 광고를 요청하지 않는다. 연결 방법은 [서비스 어댑터](../03-architecture/service-adapters.md)에 있다. Play Console 등록, 내부 테스트 업로드, 심사와 공개의 기록은 아직 없다. 진행하면 출시별 상태와 근거 위치를 `release/` 아래에 남긴다.

## Play Console 등록 상태 (2026-11-21 기준)

앱은 Play Console에 만들어져 있고(이름 Four Alike, 기본 언어 en-US, 게임, 무료) 아직 아무 트랙에도 버전이 없다. 앱 콘텐츠 신고는 아래처럼 저장했다.

| 항목 | 저장한 값 |
|---|---|
| 개인정보처리방침 | 위 주소 |
| 광고 | 앱에 광고가 있음 |
| 로그인 세부정보 | 제한된 부분 없음 |
| 콘텐츠 등급(IARC) | 14문항 모두 "아니요". ESRB 전체이용가, PEGI 3, GRAC 전체이용가, USK 전체이용가, ACB 일반, ClassInd 전체이용가, 그 밖의 지역 3세 이상 |
| 타겟층 | 13~15세, 16~17세, 18세 이상 |
| 데이터 보안 | 수집과 공유 있음(대략적인 위치, 앱 상호작용, 진단, 기기 또는 기타 ID), 전송 중 암호화, 계정 만들기 없음. 삭제 요청 문항은 비워 둠(계정이 없고 전용 삭제 페이지가 없다) |
| 광고 ID | 사용함. 목적은 광고 또는 마케팅, 분석 |
| 정부, 금융, 건강 앱 | 해당 없음 |
| 스토어 연락처 | 위 문의 값 |

남은 Console 항목은 앱 수준 판매자 상태 선언(개발자 계정은 판매자로 선언돼 있다), 앱 카테고리, 스토어 등록정보, 출시 국가, 내부 테스트 테스터 목록이다. 비공개 테스트 12명 14일 요건은 이 계정의 Console에 나오지 않는다.

## 스토어 등록정보

문구는 `play-store/google-play.config.json`의 `storeListing`이 정본이다(en-US, ko-KR). 그림은 `play-store/assets/`에 있다. 앱 아이콘은 `python3 tools/art/build_store_art.py`, 대표 이미지(1024x500, 언어별)는 `python3 tools/art/build_feature_graphic.py`로 만들고 둘 다 `npm run check:generated`가 원본과 맞는지 본다. 대표 이미지는 아이콘의 배경과 게임 글꼴, 카드 그림만 쓴다. 휴대전화 스크린숏은 실제 화면 캡처로 만들 예정이고 아직 없다. 한국어 그림은 등록 도구가 기본 언어 그림만 올리므로 `localizedAssets`에 따로 적어 둔다.

## 저장소 설정

Android 16(API 36)을 대상으로 하고 최소 API는 26, 아키텍처는 arm64-v8a, 산출물은 Gradle AAB다. 식별자와 산출물 경로는 `godot/config/product.json`, `godot/export_presets.cfg`의 Android preset, `play-store/google-play.config.json`에 있고, 세 곳이 어긋나면 `npm run check:native`가 실패한다. 서명 값과 AdMob, GA4의 값은 환경 변수나 로컬 자격증명 파일에서 읽고 저장소에 넣지 않는다. 저장소의 버전 `1.0.0`과 versionCode `1`은 기본값이다.

빌드, 업로드, 심사 제출, 승인, 공개는 서로 다른 상태다. 빌드 성공이나 업로드 응답을 공개 출시로 적지 않고, 트랙의 실제 versionCode와 상태를 콘솔이나 API에서 다시 읽어 기록한다.

빌드 방법은 [Android 빌드](../06-release/android-build.md), 업로드 경로는 [workflow 문서](../06-release/ci-cd-workflows.md)에 있다.
