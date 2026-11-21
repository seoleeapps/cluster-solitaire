# Android 빌드

## 개발 환경

Godot 4.7.2와 같은 버전의 export templates, Python 3.11 이상이 필요하다. npm 명령에는 Node.js 24가 필요하다. AAB를 만들려면 JDK와 Android SDK가 더 필요하다. 중앙 배포 workflow는 JDK 17, platforms android-35와 android-36, build-tools 36.1.0을 쓴다. 게임 실행과 검사에는 Android SDK와 자격증명이 필요 없다.

```sh
npm test
npm run check:native
npm run build:android
```

## 로컬 빌드

`npm run build:android`는 다음 순서로 동작한다.

1. `tools/check_native.py`로 Android 설정을 검사한다.
2. `tools/install_android_build_template.sh`가 export templates의 Android 소스를 `godot/android/build`에 푼다.
3. `tools/prepare_android.sh`가 AdMob Android 라이브러리를 설치한다.
4. 자원을 import하고 `Android` preset으로 서명 AAB를 내보낸다.

산출물은 `build/android/four-alike.aab`다. `godot/android`와 `build`는 Git에서 제외한다.

서명에는 환경 변수 `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`, `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`가 필요하다. 비밀번호를 명령 인자나 `export_presets.cfg`에 넣지 않는다. preset에 서명 값이 들어 있으면 `check_native.py`가 실패한다.

AdMob 라이브러리는 `tools/install_admob.py`가 고정한 배포본을 내려받아 해시를 확인한 뒤 `godot/addons/admob/android/bin`에 푼다. 출처와 해시는 [native/SOURCE.md](../../native/SOURCE.md)에 있다. AdMob 편집기 플러그인은 지금 꺼져 있다. 광고 어댑터를 붙이는 작업에서 제품의 AdMob 앱 ID와 함께 켠다.

Android preset의 `runnable=false`는 Godot이 연결된 기기를 자동으로 찾는 동작을 막는다. 이름을 지정한 export에는 영향이 없다. 기기 사용은 이 빌드 절차에 포함되지 않는다.

## 검사가 확인하는 것

`npm run check:native`는 다음이 어긋나면 실패한다.

- 세로 390×844, 폭 기준 늘림 설정
- 제품 식별자와 이름이 `product.json`, Android preset, `play-store/google-play.config.json`에서 같은지
- preset의 내보내기 경로와 설정의 `aabPath`가 같은지
- Gradle AAB, target SDK 36 이상, 서명 사용, 서명 값 미포함
- 테스트와 대역의 내보내기 제외, 글꼴과 SDK 라이선스 포함
- AdMob 플러그인에서 고친 두 파일의 해시
- Android와 Web 밖의 export preset이 없는지

## CI 빌드와 배포

`Deploy Google Play` workflow가 같은 준비 스크립트(`tools/prepare_android.sh`)로 AAB를 만든다. 태그와 설정은 [workflow 문서](ci-cd-workflows.md)를 따른다.
