# 의존성

| 대상 | 버전 | 고정하는 곳 |
|---|---|---|
| Godot | 4.7.2 stable | `.github/workflows`의 `godot_version`, `native/dependencies.lock.json` |
| Node.js | 24 | `package.json`의 `engines`. npm 패키지 의존성은 없다 |
| Python | 3.11 이상 | 도구 스크립트. 표준 라이브러리만 쓴다 |
| 공통 묶음 | 1.1.0 | `common-bundle.lock.json`(원본 커밋과 파일 해시) |
| AdMob 플러그인 | 5.1.0 | `native/dependencies.lock.json`, `tools/install_admob.py`의 배포본 해시 |
| Android | target API 36, 최소 API 26 | `godot/export_presets.cfg` |

`tools/upload_google_play_internal.py`만 Google API 클라이언트 패키지가 필요하다. Google Play 승격 workflow가 쓰는 도구이고 로컬 검사에는 쓰이지 않는다.

검증하지 않은 SDK 버전을 고정하지 않는다. 버전을 올릴 때는 공식 배포본의 해시를 잠금 파일에 함께 적고 `npm test`와 렌더 여정을 다시 실행한다.
