# Android 실기기 검수 기록 (AND-01 ~ AND-08)

- 최초 검수 일시: 2026-11-21 (`versionCode=1`)
- 중간 재검수 일시: 2026-11-22 (`versionCode=2`)
- 최종 검수 일시: 2026-11-22 (`versionCode=3`, Google Play 내부 테스트)
- 대상 패키지: `com.seoleeapps.fouralike`
- 전체 결과: **CONDITIONAL PASS** (`AND-01`·`AND-02`·`AND-03`·`AND-04`·`AND-07`·`AND-08` **PASS**, `AND-05`·`AND-06`은 KR IP 및 Google 테스트 광고 크리에이티브 제약으로 **CONDITIONAL**, 전 구간 크래시·오류 0건)

## 1. 기기 및 Play 내부 테스트 설치 정보

| 항목 | 확인 값 |
|---|---|
| 기기 모델 (`ro.product.model`) | `Seeker` |
| Android 버전 (`ro.build.version.release`) | `16` |
| 해상도 (`wm size`) | Physical `1200x2670` |
| 상단 컷아웃 (`dumpsys display`) | `Rect(0, 78 - 0, 0)` (`[540, 0 - 660, 78]`) |
| 메인 액티비티 (`pm resolve-activity`) | `com.seoleeapps.fouralike/com.godot.game.GodotAppLauncher` |
| 최신 설치 버전 (`dumpsys package`) | `versionCode=3`, `versionName=1.0.0` (`minSdk=26`, `targetSdk=36`) |
| Play 설치 시각 (`v3`) | `2026-11-22 00:35:22` (`v2`: `00:01:42`, `v1`: `2026-11-21 23:30:31`) |
| `installerPackageName` | `com.android.vending` |
| V3.0 배포 서명 SHA-256 (`v1` 확인) | `830b571840de0fad18ac705094eea60493268a57d91c2d5c82011cd25c653b87` |
| Source Stamp SHA-256 (`v1` 확인) | `3257d599a49d2c961a471ca9843f59d341a405884583fc087df4237b733bbd6d` |

> 참고: Play App Signing이 적용된 `base.apk`에 Android 17+용 v3.2 Hybrid PQC(ML-DSA) 서명 블록이 포함되어 호스트 `apksigner` 기본 호출에서는 알고리즘 미지원 오류가 발생했으나, `--min-sdk-version 26 --max-sdk-version 36` 검증으로 V3.0 Play 배포 인증서 SHA-256을 확인했다. 또한 `v2`에서 `v3`으로 인플레이스 업데이트 시 Play 스토어 `AppState`의 기존 계정 불일치(`INSTALL_ERROR status_code=1010`)가 발생하여 Play 스토어 상세 화면에서 제거 후 `versionCode=3`을 Play 스토어로 신규 설치해 검증했다.

## 2. 항목별 검수 결과

| ID | 검수 항목 | 상태 | 관찰 내용 및 근거 |
|---|---|---|---|
| AND-01 | 초기 부팅 및 렌더링, 시작 시간 | **PASS** | `v3` 콜드 부팅 `TotalTime: 317ms`(`WaitTime: 320ms`, `v1`: `316ms`, `v2`: `233ms`). 타이틀 화면 겹침·잘림 없이 정상 렌더링(`and01-v3-boot.png`). Godot `4.7.2` 및 `PoingGodotAdMob*` 플러그인 정상 초기화. |
| AND-02 | 실제 터치 선택, 끌어서 옮기기, 목록 스크롤 | **PASS** | `v1`에서 튜토리얼 카드 4장 선택·묶기, 임시 칸 드래그 이동, 도감·상점 꾸미기 탭 스와이프 스크롤 확인(`and02-select-4cards.png`, `and02-drag-holding.png`, `and02-album-scrolled.png`, `and02-shop-themes-scrolled.png`). `v3`에서도 튜토리얼 3묶음 완료 및 스테이지 1 카드 선택 정상(`v3-play-tap.png`). |
| AND-03 | 강제 종료(`am force-stop`) 뒤 판과 저장 복원 | **PASS** | `v1` 스테이지 1에서 2회 조작 후 `am force-stop`→2초 대기→재실행(`TotalTime: 261ms`) 시 홈 "이어 하기" 복귀 및 판 상태(완료 묶음·임시 칸·남은 카드·코인 `215`·하트 `4`·부스터 `3/3/2`) 100% 일치(`and03-before-stop.png`, `and03-restored-board.png`). `v3` 백그라운드 전환 뒤 HOT 복귀(`TotalTime: 83ms`) 정상(`v3-reopen-home.png`). |
| AND-04 | 시스템 뒤로 가기, 노치·상하단 안전 영역 | **PASS** | `v3`에서 전 항목 통과. 1) **홈 1회 뒤로 가기**: 홈에 머물며 `"한 번 더 누르면 게임을 끝내요"` 토스트 노출(`and04-v3-home-back1-toast.png`), `moveTaskToBack` 미호출. 2) **홈 2회 뒤로 가기**: 크래시 없이 백그라운드 이동(`and04-v3-home-back2-launcher.png`). 3) **재실행 복귀**: `am start` HOT 복귀 시 토스트 잔존 없음(`v3-reopen-home.png`), 다시 1회 뒤로 가기 시 즉시 종료 대신 토스트 재노출(`v3-reopen-back1-toast.png`). 4) **2단 시트(`설정→언어`)**: `KEYCODE_BACK` 1회로 `언어`만 닫혀 `설정`으로 복귀(`v3-lang-before.png`→`v3-after-back1-settings.png`), 다음 1회로 홈 복귀(`v3-after-back2-home.png`), 화면 `‹` 버튼도 즉시 동작(`v3-ui-back-settings.png`). 5) **플레이 화면**: `KEYCODE_BACK` 1회로 "잠깐 멈춤" 열림(`and04-v3-play-back-open.png`), 재입력으로 정상 닫힘(`and04-v3-play-back-closed.png`). 6) **안전 영역**: 상단 `78px` 컷아웃 및 하단 바 침범 없음. |
| AND-05 | UMP 동의 창 표시 및 지역 동작 | **CONDITIONAL** | `v1`에서 `UserMessagingPlatform` 초기화 및 광고 로드 정상. 한국(KR) IP 실기기 환경에서 비EEA 기본 동작으로 동의 창이 뜨지 않으며 설정 하단 개인정보 재설정 항목도 정책대로 미표시됨(`and05-settings-bottom.png`). EEA 지역 동의 창 노출은 KR IP 환경 및 프로덕션 빌드 제약으로 실기기 직접 미확인. |
| AND-06 | AdMob 보상형 광고(로드, 시청 보상, 중도 닫기) | **CONDITIONAL** | `v1`에서 `REWARDED_RESULT_BONUS`, `REWARDED_CONTINUE`, `REWARDED_BOOSTER` 모두 `Test Ad` `AdActivity` 정상 로드·표시 및 5초 시청 완료 후 보상 지급(코인 `+26 -> +52`, 하트 2개 복구, 힌트 1개 지급) 확인(`and06-rewarded-playing.png`, `and06-rewarded-granted.png`). 다만 테스트 광고가 5초 비스킵형이라 카운트다운 중 닫기 UI가 없고 `KEYCODE_BACK`을 무시해(`and06-early-close-check.png`) 실기기 중도 닫기 무보상은 UI로 유발하지 못함. |
| AND-07 | AdMob 전면 광고(표시, 소리·입력 복귀, 앱 전환) | **PASS** | `v1`에서 정책 조건(세션 2·누적 플레이 180초+·2라운드+·보상형 120초 경과) 충족 후 스테이지 3 클리어 시 `INTERSTITIAL_LEVEL_END` `AdActivity` 정상 표시(`and07-interstitial.png`). 광고 중 `KEYCODE_HOME` 전환 뒤 복귀(`HOT`, `TotalTime: 86ms`) 시 스테이지 3 결과 팝업으로 멈춤 없이 복구되며 터치 입력과 OpenSLES 오디오 트랙(`AT::remove` → `AT::add`, `Underruns: 0`) 정상 재개(`and07-after-return.png`, `and07-home-touch-ok.png`). |
| AND-08 | 효과음, 배경음악, 진동 토글 및 오디오 상태 | **PASS** | `v1`에서 설정 내 음악·효과음·진동 토글 전환·복구(`and08-settings.png`, `and08-settings-toggled.png`), `dumpsys media.audio_flinger` `44100 Hz` 활성 트랙(`Active: yes`, `Underruns: 0`), `dumpsys vibrator_manager` `usage: TOUCH` `10ms`/`25ms` 진동(`finished`) 확인. `v3` 스모크에서도 `44100 Hz` 활성 트랙(`Active: yes`, `Underruns: 0`) 및 백그라운드 전환 전후 `AT::remove`/`AT::add` 정상 확인. |

## 3. 버전별 수정 및 검증 이력

1. **`versionCode=1`**: `AND-01`~`AND-08` 전체 실행 중 홈 `KEYCODE_BACK` 종료 시 `get_tree().quit()` 호출로 `GLThread`에서 `SIGABRT`(`FORTIFY: pthread_mutex_lock called on a destroyed mutex`, `libgodot_android.so`)가 2/2회 재현되었다(`build/device-qa/logcat-sanitized.txt`).
2. **`versionCode=2`**: `moveTaskToBack(true)` 전환으로 `SIGABRT` 크래시는 해소되었으나(`build/device-qa/logcat-v2-sanitized.txt`), Android 16에서 `KEYCODE_BACK` 1회 입력 시 `NOTIFICATION_WM_GO_BACK_REQUEST`가 2회 연속 전달되어 홈 토스트가 건너뛰어지고 `설정→언어` 2단 시트가 한 번에 닫히는 중복 전달 결함이 발견되었다.
3. **`versionCode=3`**: `0.18s` 시스템 뒤로 가기 디바운스를 반영한 빌드에서 홈 2회 뒤로 가기 토스트·종료, 재실행 복귀, 2단 시트 1단계씩 닫기, UI `‹` 즉시 복귀, 플레이 화면 일시정지 열기·닫기, 오디오·터치 스모크가 모두 통과했으며 `logcat` 내 크래시·`AndroidRuntime` 예외·Godot `SCRIPT ERROR`/`USER ERROR`는 0건이었다(`build/device-qa/logcat-v3-sanitized.txt`).
