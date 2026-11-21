# Android 빌드

## 개발 환경

Godot 4.7.2와 같은 버전의 export templates, Python 3.11 이상이 필요하다. npm 명령에는 Node.js 24가 필요하다. AAB를 만들려면 JDK와 Android SDK가 더 필요하다. 중앙 배포 workflow는 JDK 17, platforms android-35와 android-36, build-tools 36.1.0을 쓴다. 2026-11-21의 로컬 빌드는 Godot 편집기 설정(`export/android/java_sdk_path`, `export/android/android_sdk_path`)에 적힌 JDK 17과 Android SDK로 했다. 만든 AAB를 검사하는 데는 `bundletool`과 JDK의 `keytool`, `jarsigner`를 쓴다. 게임 실행과 `npm test`에는 Android SDK와 자격증명이 필요 없다.

```sh
npm test
npm run check:native
npm run build:android     # 서명 AAB를 만들고 결과물을 검사한다
npm run check:aab         # 이미 만든 AAB만 다시 검사한다
```

## 로컬 빌드

`npm run build:android`(`tools/export_native.py`)는 다음 순서로 동작한다.

1. `tools/check_native.py`로 Android 설정을 검사한다.
2. `tools/install_android_build_template.sh`가 export templates의 Android 소스를 `godot/android/build`에 푼다.
3. `tools/prepare_android.sh`가 AdMob Android 라이브러리를 설치하고 서비스 값을 주입한다.
4. 자원을 import하고 `Android` preset으로 서명 AAB를 내보낸다.
5. 주입한 값을 지우고 `godot/project.godot`을 빌드 전의 내용으로 되돌린다. 빌드가 실패해도 한다.
6. `tools/check_aab.py`로 결과물을 검사한다. 문제가 있으면 실패로 끝난다.

산출물은 `build/android/four-alike.aab`다. `godot/android`와 `build`는 Git에서 제외한다. 2026-11-21에 이 순서로 만든 AAB는 53.5MB였다.

Android preset의 `runnable=false`는 Godot이 연결된 기기를 자동으로 찾는 동작을 막는다. 이름을 지정한 export에는 영향이 없다. 기기 사용은 이 빌드 절차에 포함되지 않는다.

## 서명 값

서명에는 환경 변수 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`를 쓴다. 셋이 다 있지 않으면 `tools/export_native.py`가 `FA_KEYSTORE_ENV`가 가리키는 파일(기본 `~/.config/seorilabs/play-store/four-alike-keystore.env`)의 `ANDROID_KEYSTORE_FILE`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`를 읽어 Godot에 환경 변수로 넘긴다. Godot은 키 저장소와 키에 같은 비밀번호를 쓰므로 `ANDROID_KEY_PASSWORD`가 다르면 멈춘다.

비밀번호를 명령 인자나 `export_presets.cfg`에 넣지 않는다. preset에 서명 값이 들어 있으면 `check_native.py`가 실패한다. 빌드 출력에서는 서명 값과 주입한 식별자를 가린다.

## 서비스 값 주입

AdMob 앱 ID와 광고 단위, GA4 측정 ID와 API 비밀값, 원격 설정 주소는 저장소에 넣지 않는다. `tools/prepare_services.py`가 빌드할 때 로컬 자격증명에서 읽어 두 곳에 쓴다.

| 쓰는 곳 | 내용 | 읽는 쪽 |
|---|---|---|
| `godot/data/services/release.json` | 광고 단위, 측정 값, 원격 설정 주소 | 앱(`FaServiceValues`). 내보낸 빌드에서만 읽는다 |
| `godot/project.godot`의 `[admob]` 절 | AdMob 앱 ID | AdMob 플러그인이 Android 매니페스트의 `com.google.android.gms.ads.APPLICATION_ID`로 넣는다 |

| 환경 변수 | 기본값 | 들어 있는 값 |
|---|---|---|
| `FA_ADMOB_ENV` | `~/.config/seorilabs/admob/four-alike/public-identifiers.env` | `ADMOB_APP_ID`, `ADMOB_REWARDED_AD_UNIT_ID`, `ADMOB_INTERSTITIAL_AD_UNIT_ID` |
| `FA_ANALYTICS_ENV` | `~/.config/seorilabs/analytics-four-alike.env` | `GA4_MEASUREMENT_ID`, `GA4_MP_API_SECRET` |
| `FA_REMOTE_CONFIG_URL` | `https://seoleeapps.github.io/cluster-solitaire/config.json` | 원격 설정 JSON의 주소 |

값의 이름과 같은 환경 변수가 있으면 파일보다 먼저 쓴다. 파일이 없거나 값이 빠졌거나 형식이 틀리면, 또는 Google의 테스트 광고 ID이면 아무것도 쓰지 않고 멈춘다. 값은 출력하지 않는다.

`release.json`은 `.gitignore`로 추적하지 않는다. 빌드가 강제로 끊겨 주입한 값이 남으면 `check_native.py`(`npm test`)가 실패로 알린다. 그때는 `python3 tools/prepare_services.py --restore`로 지운다.

주입 값이 없는 실행(에디터, `npm start`, `npm test`)에서는 광고가 Google의 공개 테스트 단위를 쓰고 분석과 원격 설정은 꺼진다. 디버그 빌드는 주입 값이 있어도 테스트 단위를 쓴다.

## AdMob 플러그인

AdMob 편집기 플러그인은 `godot/project.godot`의 `[editor_plugins]`에서 켜져 있다. 내보낼 때 이 플러그인이 Android 라이브러리와 의존성, 앱 ID를 빌드에 넣는다. 라이브러리는 `tools/install_admob.py`가 고정한 배포본을 내려받아 해시를 확인한 뒤 `godot/addons/admob/android/bin`에 푼다. 출처와 해시는 [native/SOURCE.md](../../native/SOURCE.md)에 있다.

플러그인이 켜져 있으면 Godot 편집기와 import가 시작할 때마다 `project.godot`을 Godot의 저장 형식으로 다시 쓴다. 그래서 `project.godot`은 Godot이 쓴 형식 그대로 커밋한다. 손으로 고친 뒤 `npm test`가 "verification changed tracked source files"로 실패하면 Godot이 다시 쓴 내용을 커밋한다.

## 검사가 확인하는 것

`npm run check:native`는 저장소의 설정을 본다. 다음이 어긋나면 실패한다.

- 세로 390×844, 폭 기준 늘림 설정
- 제품 식별자와 이름이 `product.json`, Android preset, `play-store/google-play.config.json`에서 같은지
- preset의 내보내기 경로와 설정의 `aabPath`가 같은지
- Gradle AAB, target SDK 36 이상, 서명 사용, 서명 값 미포함
- INTERNET과 VIBRATE 권한, AdMob 편집기 플러그인 사용
- 테스트와 대역의 내보내기 제외, 글꼴과 SDK 라이선스 포함
- AdMob 플러그인에서 고친 두 파일의 해시
- 주입한 서비스 값이 남아 있지 않은지, `godot/data/services/`가 `.gitignore`에 있는지
- Android와 Web 밖의 export preset이 없는지

`npm run check:aab`(`tools/check_aab.py`)는 만든 AAB를 다시 읽는다. 다음이 어긋나면 실패한다.

- 패키지 `com.seoleeapps.fouralike`, versionCode와 versionName이 Android preset과 같고 versionName이 `application/config/version`과 같은지
- 서명이 온전하고 서명 인증서의 SHA-256이 등록한 업로드 키와 같은지
- `INTERNET`, `com.google.android.gms.permission.AD_ID`, `VIBRATE` 권한
- 대상 SDK가 Google Play의 요구(2026-08-31부터 API 36) 이상인지
- 세로 고정, 디버그 빌드가 아님
- AdMob 플러그인의 네이티브 싱글턴 등록, 매니페스트의 AdMob 앱 ID(테스트 ID가 아님)
- 주입한 서비스 값이 들어 있고 광고 단위가 테스트 단위가 아니며 앱 ID와 같은 게시자인지
- 적응형 아이콘이 전경, 배경, 단색 층을 가리키고 그 그림이 들어 있는지
- arm64-v8a 라이브러리만 있는지, 테스트 파일이 없는지, 크기가 60MB 이하인지

2026-11-21에 만든 AAB의 매니페스트에는 위 세 권한 말고도 라이브러리가 넣은 `ACCESS_NETWORK_STATE`, `READ_BASIC_PHONE_STATE`, `WAKE_LOCK`, `FOREGROUND_SERVICE`, `android.permission.AD_ID`가 있었다. Play Console의 권한과 Data safety 신고를 쓸 때 이 목록을 다시 읽어 맞춘다.

## 업로드

[기술 제작 계획](../design/2026-11-21-four-alike-launch/06-technical-production-plan.md)은 마켓 업로드를 로컬에서 실행하고 결과를 `release/`에 기록하는 것으로 정했다. 저장소에는 같은 준비 스크립트(`tools/prepare_android.sh`)로 AAB를 만드는 `Deploy Google Play` workflow도 남아 있다. 그 경로의 설정과 확인되지 않은 점은 [workflow 문서](ci-cd-workflows.md)에 있다.
