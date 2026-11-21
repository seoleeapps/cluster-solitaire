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
| `deploy-godot-pages.yml` | 수동 | Godot Web 내보내기를 GitHub Pages에 올린다. 웹은 앱 출시 뒤의 범위다(결정 로그 DEC-001). 그 전에는 실행하지 않는다 |
| `cleanup-actions-storage.yml` | 수동 | 아티팩트와 캐시를 지운다 |

main과 PR에서는 검사만 돈다. 마켓으로 나가는 workflow는 사람이 태그를 지정해 수동으로 실행할 때만 돈다.

## Google Play 배포에 필요한 설정

`deploy-google-play.yml`은 GitHub environment `google-play`에서 다음 이름의 값을 읽는다. 값은 저장소에 넣지 않는다.

| 종류 | 이름 |
|---|---|
| Secret | `GOOGLE_PLAY_UPLOAD_KEYSTORE_BASE64`, `GOOGLE_PLAY_UPLOAD_KEYSTORE_PASSWORD`, `GOOGLE_PLAY_UPLOAD_KEY_PASSWORD` |
| Variable | `GOOGLE_PLAY_UPLOAD_KEY_ALIAS`, `GOOGLE_WORKLOAD_IDENTITY_PROVIDER`, `GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL` |

호출자는 패키지 `com.seoleeapps.fouralike`, AAB 이름 `four-alike`, 트랙 `internal`을 넘긴다. 버전 이름과 versionCode는 중앙 workflow가 태그에서 정해 export preset에 주입하고, 만든 AAB의 값을 다시 읽어 태그와 다르면 멈춘다.

중앙 workflow는 빌드 전과 업로드 전에 개발 근거 검증 단계를 실행한다. 이 저장소에서 `google-play` environment와 그 검증이 실제로 통과하는지는 아직 실행해 확인하지 않았다. 첫 배포 전에 `upload=false`로 먼저 확인한다.
