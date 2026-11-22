# Apple App Store 운영

## 앱 정보

- 이름: `Four Alike: Card Group Puzzle` (`en-US`) / `끼리끼리: 연상 카드 퍼즐` (`ko`)
- Bundle ID: `com.seoleeapps.fouralike`
- Apple ID: `6837877091`
- SKU: `four-alike`
- Team ID: `HCDUXX4Z3X`
- 카테고리: `GAMES` (`GAMES_PUZZLE`, `GAMES_CARD`)
- 가격 및 출시 지역: 무료, `174`개 국가 및 지역(중국 본토 제외)
- 연령 등급: `4+`(대한민국 `ALL`, 브라질 `L`; 광고 포함 `true`)
- 비추적·동의 구성: ATT 미사용(`NSUserTrackingUsageDescription` 제외), Google UMP 미호출(`privacy_choice_required() == false`), 비개인화 문맥 광고(`npa=1`)만 사용, 비면제 암호화 미사용(`ITSAppUsesNonExemptEncryption=false`)
- 설정 소스: [app-store.config.json](../../app-store/app-store.config.json), [앱스토어 6.9인치 스크린샷](../../app-store/screenshots/en-US/01-group.png), [실행 원장](../../release/market-launch-state.json)

## 현재 상태

UI 개선(`v4`)과 iOS 출시 범위 추가 승인(`DEC-027`)을 반영한 `1.0.0` 빌드 `1`(`build/ios/FourAlike.ipa`, `Apple Distribution`, `four-alike-appstore` 프로파일)을 `xcrun altool`로 업로드해 `VALID` 처리를 확인했다. 로컬 검증(`npm test` 76개 단위 테스트·22개 E2E 시나리오·24장 스토어 스크린샷, `check:architecture`, `bundle.py verify`, `check_monetization.sh`, `run_probes.py` 18/18)과 `1320x2868` 6.9인치 스크린샷 `12`장(`en-US`·`ko` 각 `6`장) 시각 검수를 마쳤고, 연결된 실기기 `iPhone 12 Pro`(`1170x2532`)에 동일 `.xcarchive` 바이너리를 개발 서명으로 재내보내기해 설치·실행(ATT/UMP 미노출, 안전 영역, AdMob SDK 초기화·광고 요청 `No ad to show` 응답 및 사용자 확인)까지 확인했다. TestFlight 내부 그룹 `Seorilabs Internal`에 `1.0.0 (1)`(`READY_FOR_BETA_TESTING`)을 배정했고, App Store 심사 제출(`reviewSubmission` ID `ae82c331-fb64-43e9-9446-fdb560d44101`, `appStoreVersion` `1.0.0`, `AFTER_APPROVAL`)을 완료해 API 재조회 기준 `WAITING_FOR_REVIEW` 상태를 확인했다. 남은 관문은 App Review 승인·자동 공개(`AFTER_APPROVAL`), App Store 공개 페이지 라이브 스모크 확인, 공개 후 AdMob 콘솔의 App Store 앱 연결이다.

## App Store Connect 등록 상태 (2026-11-22 기준)

- **앱 생성·권한**: Bundle ID `com.seoleeapps.fouralike`(`BXA97KACA4`) 및 App Store 프로파일 `four-alike-appstore`(`8828V2QT59`) 등록, 앱 `6837877091` 생성, 콘텐츠 권한 `USES_THIRD_PARTY_CONTENT` 설정 완료.
- **메타데이터·자산**: `en-US`·`ko` 제목, 부제, 프로모션 문구, 키워드, 설명, 지원 URL(`https://www.seorilabs.com/support/`), 개인정보 처리방침 URL(`https://www.seorilabs.com/en/apps/four-alike/privacy/`), 마케팅 URL(`https://www.seorilabs.com`), 저작권(`2026 Seori Labs`), `1024x1024` 불투명 RGB 아이콘, `1320x2868` (`APP_IPHONE_67`) 스크린샷 `12`장 업로드 및 `COMPLETE` 확인 완료.
- **개인정보(App Privacy)**: 게시 완료(`Coarse Location`, `Device ID`, `Product Interaction`, `Advertising Data`, `Performance Data`, `Other Diagnostic Data` 6개 항목, 모두 사용자 신원 미연결·추적 미사용).
- **가격·출시 지역**: 무료(`$0.00`), 중국 본토를 제외한 `174`개 국가 및 지역 활성화.
- **심사 제출**: 빌드 `1.0.0 (1)`(`3eb1f1ee-acf3-4fd8-a51a-3d85cb9c935a`) 연결 및 심사 제출 ID `ae82c331-fb64-43e9-9446-fdb560d44101` 접수 완료(`2026-11-22T07:29:26.517Z`), 현재 상태 `WAITING_FOR_REVIEW`.

## 저장소 설정

iOS `15.0` 이상 iPhone 세로 모드를 대상으로 하며 export 설정은 [godot/export_presets.cfg](../../godot/export_presets.cfg)의 `[preset.2]`(`iOS`), 패키징 스크립트는 [tools/export_ios.py](../../tools/export_ios.py), 검증은 [tools/check_native.py](../../tools/check_native.py)와 [tools/test_native.py](../../tools/test_native.py)에 있다. AdMob iOS 앱·광고 단위 ID와 서명 자격증명은 로컬 자격증명 저장소 및 환경 변수에서 주입하며 저장소에 넣지 않는다.

빌드, 업로드, `VALID`, TestFlight 내부 배포, 심사 제출(`WAITING_FOR_REVIEW`), 승인, 공개는 서로 다른 상태다. `WAITING_FOR_REVIEW`는 승인이나 공개를 뜻하지 않는다.
