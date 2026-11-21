# workflow

`.github/workflows`의 파일은 대부분 `seorilabs/.github`의 재사용 workflow를 `@main`으로 부르는 얇은 호출자다. 공개 저장소라 GitHub 제공 러너에서 돈다.

| 파일 | 실행 조건 | 하는 일 |
|---|---|---|
| `godot-checks.yml` | main 대상 PR, main과 `feat/**` push, 수동 | `npm test`를 실행하고 390x844로 여정을 렌더링한다. 결과를 `build/e2e`에서 올린다 |
| `release-tag.yml` | 수동 | SemVer 태그를 만든다 |
| `init-release-version-ledger.yml` | 수동 | 버전 원장을 처음 만든다. 기본은 dry run |
| `deploy-google-play.yml` | 수동, 다른 workflow의 호출 | 지정한 태그로 서명 AAB를 만든다. `upload=true`면 internal 트랙에 올린다 |
| `promote-google-play.yml` | 수동, 다른 workflow의 호출 | internal 트랙의 빌드를 다시 빌드하지 않고 production으로 올린다 |
| `release-inventory.yml` | 수동 | `scripts/check_release_readiness.sh`로 Android 빌드 입력을 확인한다 |
| `deploy-remote-config.yml` | main의 `remote/**` 변경, 수동 | `remote/config.json`을 프로필과 대조한 뒤 `remote/` 폴더를 GitHub Pages에 올린다 |
| `deploy-godot-pages.yml` | 수동 | Godot Web 내보내기를 GitHub Pages에 올린다. 웹은 앱 출시 뒤의 범위다(결정 로그 DEC-001). 그 전에는 실행하지 않는다. 실행하면 원격 설정 배포를 덮어쓴다 |
| `cleanup-actions-storage.yml` | 수동 | 아티팩트와 캐시를 지운다 |

main과 PR에서는 검사만 돈다. 마켓으로 나가는 workflow는 사람이 태그를 지정해 수동으로 실행할 때만 돈다. 원격 설정 배포만 main에 `remote/**`가 바뀌면 스스로 돈다.

## 원격 설정 배포

앱은 시작할 때 `https://seoleeapps.github.io/cluster-solitaire/config.json`을 받는다(결정 로그 DEC-019). 이 파일의 원본은 저장소의 `remote/config.json`이고, `deploy-remote-config.yml`이 `remote/` 폴더를 통째로 Pages 사이트의 루트로 올린다. 올리기 전에 `python3 tools/check_remote_config.py`가 열쇠, 형, 범위를 수익화 프로필과 대조하며, 같은 검사가 `npm test`에도 들어 있다. 쓰는 액션은 `actions/checkout`, `actions/upload-pages-artifact`, `actions/deploy-pages` 셋이고 조직의 Pages workflow와 같은 커밋으로 고정했다. 권한은 `contents: read`가 기본이고 배포 작업에만 `pages: write`와 `id-token: write`를 준다.

이 workflow는 아직 실행된 적이 없다. 저장소 설정에서 Pages의 배포 방식을 GitHub Actions로 켠 뒤에야 동작한다. 켜기 전에 나간 앱은 주소에서 설정을 받지 못해 내장 기본값으로 동작한다.

설정을 바꾸는 순서는 이렇다. `remote/config.json`의 값을 고치고 `version`을 올린다. `npm run check:remote-config`를 통과시킨다. PR로 main에 넣으면 배포된다. 앱은 다음 실행에서 새 값을 받고, GitHub Pages의 캐시 때문에 몇 분 늦을 수 있다. 범위를 벗어난 값은 앱이 버리고 내장 기본값을 쓴다.

GitHub Pages 사이트는 저장소당 하나다. `deploy-godot-pages.yml`은 웹 빌드를 같은 사이트의 루트에 올리므로, 실행하면 `config.json`이 사라지고 다음 원격 설정 배포가 웹 빌드를 지운다. 웹을 내기로 하면 두 산출물을 한 아티팩트로 합치거나 원격 설정의 주소를 옮기는 설계가 먼저 필요하다. 그 전에는 `deploy-godot-pages.yml`을 실행하지 않는다.

[기술 제작 계획](../design/2026-11-21-four-alike-launch/06-technical-production-plan.md)은 마켓 업로드를 로컬에서 실행하고 결과를 `release/`에 기록하는 것으로 정했다. `deploy-google-play.yml`과 `promote-google-play.yml`은 템플릿에서 물려받은 CI 경로이고 이 저장소에서 실행해 본 적이 없다. CI 경로를 쓰려면 아래 설정이 먼저 필요하다.

## Google Play CI 배포에 필요한 설정

`deploy-google-play.yml`은 GitHub environment `google-play`에서 다음 이름의 값을 읽는다. 값은 저장소에 넣지 않는다.

| 종류 | 이름 |
|---|---|
| Secret | `GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64`, `GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD`, `GOOGLE_PLAY_UPLOAD_KEY_PASSWORD` |
| Variable | `GOOGLE_PLAY_UPLOAD_KEY_ALIAS`, `GOOGLE_WORKLOAD_IDENTITY_PROVIDER`, `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` |

호출자는 패키지 `com.seoleeapps.fouralike`, AAB 이름 `four-alike`, 트랙 `internal`을 넘긴다. 버전 이름과 versionCode는 중앙 workflow가 태그에서 정해 export preset에 주입하고, 만든 AAB의 값을 다시 읽어 태그와 다르면 멈춘다.

`tools/prepare_android.sh`는 AdMob 라이브러리를 설치한 뒤 서비스 값(AdMob 앱 ID와 광고 단위, GA4 측정 값)을 주입하고, 값이 없으면 멈춘다. 중앙 workflow는 이 값들을 준비 단계에 넘기지 않으므로 지금의 CI 경로는 준비 단계에서 실패한다. 테스트 광고 ID가 든 AAB가 만들어져 올라가는 것을 막기 위한 동작이다. CI 경로를 쓰려면 위 서명 값에 더해 `ADMOB_APP_ID`, `ADMOB_REWARDED_AD_UNIT_ID`, `ADMOB_INTERSTITIAL_AD_UNIT_ID`, `GA4_MEASUREMENT_ID`, `GA4_MP_API_SECRET`을 준비 단계의 환경 변수로 넘기는 길이 중앙 workflow에 있어야 한다.

중앙 workflow는 빌드 전과 업로드 전에 개발 근거 검증 단계를 실행한다. 이 저장소에서 그 검증과 `google-play` environment가 통과하는지는 확인하지 않았다. CI 경로를 쓰기로 하면 `upload=false`로 먼저 확인한다.
