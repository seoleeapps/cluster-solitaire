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
| 수집 | 광고 SDK와 분석 이벤트뿐이다. 13세 미만 대상이 아니다 |
| 개인정보 처리방침 주소, 문의 메일 | 확정 필요 |

근거는 [첫 출시 설계](../design/2026-11-21-four-alike-launch/design.md)와 [결정 로그](../design/2026-11-21-four-alike-launch/decision-log.md)다. 마켓 문구에 쓸 설명어의 상표 제약은 결정 로그 DEC-018을 따른다.

## 현재 상태

저장소에는 Play Console 앱 등록 기록, 업로드 서명 키 연결, AdMob 앱 ID와 광고 단위가 아직 없다. 만드는 것은 승인돼 있다(DEC-016). 광고 어댑터도 아직 없어서 지금 빌드에는 광고가 들어가지 않는다. 스토어 이미지와 문구, 콘텐츠 등급, 데이터 보안 양식의 기록도 아직 없다.

## 빌드와 배포 설정

Android 16(API 36)을 대상으로 하고 최소 API는 26, 아키텍처는 arm64-v8a, 산출물은 Gradle AAB다. 식별자와 산출물 경로의 정본은 `godot/config/product.json`, `godot/export_presets.cfg`의 Android preset, `play-store/google-play.config.json`이고 `npm run check:native`가 세 곳이 어긋나면 실패한다. 서명 값은 환경 변수로만 받는다.

`Deploy Google Play` workflow는 명시한 태그만 받고 기본값은 업로드 없는 빌드다. `upload=true`일 때 internal 트랙에 올린다. `Promote Google Play` workflow는 internal의 빌드를 다시 빌드하지 않고 production으로 올린다. 버전 이름과 versionCode는 태그에서 정해져 빌드 때 주입되므로 저장소의 `1.0.0`과 `1`은 기본값일 뿐이다.

빌드, 업로드, 심사 제출, 승인, 공개는 서로 다른 상태다. workflow 성공이나 업로드 응답을 공개 출시로 적지 않고, 트랙의 실제 versionCode와 상태를 콘솔이나 API에서 다시 읽어 기록한다.
