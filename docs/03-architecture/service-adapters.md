# 서비스 어댑터

광고와 동의, 분석, 원격 설정의 실제 구현은 `godot/game/adapters`에 있고 규칙 코어의 포트(`godot/game/core/ports`)를 구현한다. 화면과 유스케이스는 포트만 알고, 어느 구현을 끼울지는 `bootstrap`이 정한다. 이 문서는 각 어댑터가 하는 일, 공개 함수와 신호, bootstrap에 끼우는 방법을 적는다. 승인된 방식은 [기술 제작 계획](../design/2026-11-21-four-alike-launch/06-technical-production-plan.md)의 "플랫폼 연동"과 결정 로그 DEC-019, DEC-020이다.

개발 PC와 headless 검수에서는 Android의 AdMob 싱글턴이 없고 주입 값도 읽지 않는다. 그래서 `FaLiveServices`를 그대로 만들어도 광고는 준비되지 않은 것으로, 분석과 원격 설정은 꺼진 것으로 동작하고 네트워크를 쓰지 않는다.

## 파일

| 파일 | 내용 |
|---|---|
| `fa_live_services.gd` | `FaLiveServices`(Node). 아래 어댑터를 만들어 `ads`, `analytics`, `config`로 내놓고 프레임마다 시간을 흘린다. 앱이 백그라운드로 가고 돌아오는 것을 어댑터에 알린다. 새 실행은 bootstrap이 판단해 `begin_session()`을 부른다 |
| `fa_admob_ads.gd` | `FaAdmobAds`. `FaAdsPort` 구현. 동의, 초기화, 미리 불러오기, 보여 주기와 결과 판정의 순서 |
| `fa_ad_show.gd` | `FaAdShow`. 떠 있는 광고 하나의 결과(`earned`, `dismissed`, `failed`)를 알림 순서와 시간으로 한 번 정한다 |
| `fa_ad_sdk.gd` | `FaAdSdk`. 광고와 동의 SDK의 경계. 기본 구현은 SDK가 없는 환경이다 |
| `fa_admob_sdk.gd` | `FaAdmobSdk`. AdMob 플러그인으로 `FaAdSdk`를 구현한다. 플러그인의 클래스를 참조하는 파일은 이것 하나다 |
| `fa_ga4_analytics.gd` | `FaGa4Analytics`. `FaAnalyticsPort` 구현. 대기열, 묶음 전송, 기기 저장, 실행 시작 이벤트 |
| `fa_ga4_events.gd` | `FaGa4Events`. Measurement Protocol의 이름 규칙과 제한, 요청 본문 |
| `fa_remote_config.gd` | `FaRemoteConfig`. `FaConfigPort` 구현. 받기, 캐시, 대체 |
| `fa_remote_config_rules.gd` | `FaRemoteConfigRules`. 수익화 프로필의 `remote_config`로 값의 형과 범위를 검사한다 |
| `fa_service_values.gd` | `FaServiceValues`. 빌드할 때 넣은 서비스 값(광고 단위, 측정 값, 설정 주소) |
| `fa_http.gd`, `fa_json_files.gd` | HTTP 요청과 기기의 작은 JSON 파일 |
| `fa_memory_analytics.gd`, `fa_fixed_config.gd` | 테스트 대역. 받은 이벤트를 메모리에 적는 분석, 넘겨받은 값을 돌려주는 설정 |

## 광고와 동의

`FaAdmobAds`는 `start()`에서 UMP의 동의 정보를 갱신한다. 동의가 필요하면 양식을 띄우고, 광고를 요청해도 되는 상태(동의가 필요 없거나 받았음)일 때만 SDK를 초기화한 뒤 보상형과 전면을 하나씩 불러 둔다. 플러그인이 UMP의 `canRequestAds`를 내보내지 않아서 같은 조건을 동의 상태로 판정한다. 지난 실행에서 받은 동의는 이번 갱신이 끝나기 전에도 유효하다. 동의 상태는 SDK가 기억하고 앱은 저장하지 않는다.

광고 요청에는 최대 콘텐츠 등급 PG를 지정하고 어린이 대상 처리 태그는 지정하지 않는다. 광고 단위는 주입 값이 없거나 디버그 빌드면 Google의 공개 테스트 단위다.

| 함수와 신호 | 내용 |
|---|---|
| `is_ready(format)`, `request(format)`, `show(format, on_result)` | 포트의 함수. `format`은 `rewarded`, `interstitial`. `show`는 결과를 한 번 돌려준다. 준비되지 않았거나 다른 광고가 떠 있으면 바로 `failed`다 |
| `privacy_choice_required()`, `open_privacy_choice()` | UMP의 개인정보 옵션 요건과 양식 |
| `analytics_allowed()` | 이번 실행의 동의 갱신이 끝났고 동의가 필요 없는 지역일 때만 참. 규제 지역이거나 아직 모르면 거짓(DEC-020) |
| `consent_pending()` | 동의 상태를 아직 모르는지. 분석이 버릴지 기다릴지를 정하는 데 쓴다 |
| `can_request_ads()` | 광고를 요청해도 되는 동의 상태인지 |
| `start()`, `advance(seconds)`, `resume()`, `stop()` | `FaLiveServices`가 부른다 |
| `set_consent_debug(geography, device_ids)` | 기기 검수용. 아래 "기기에서 동의 양식 확인하기"에 적었다 |
| `consent_settled()` | 이번 실행의 동의 갱신이 한 번 끝났는지(양식을 띄웠다면 닫혔는지). SDK가 없으면 참. 타이틀이 기다린다 |
| `presenting_changed(active)` | 광고가 화면을 덮기 직전에 `true`, 결과가 정해진 직후(`on_result`보다 먼저)에 `false`. 화면은 쓰지 않는다 |
| `availability_changed`, `consent_changed` | 준비 여부, 동의 상태나 개인정보 선택 요건이 바뀌었을 수 있음. `consent_changed`는 포트(`FaAdsPort`)의 신호다 |

결과 판정은 `FaAdShow`가 맡는다. 보상 알림과 닫힘 알림은 어느 쪽이 먼저 와도 `earned`다. 보상형이 보상 없이 닫히면 늦은 보상 알림을 1.5초 기다린 뒤 `dismissed`로 정한다. 떴다는 알림 없이 10초가 지나면 `failed`, 뜬 뒤 90초 동안 아무 알림이 없으면 받은 알림만으로 정한다. 이 시간은 게임이 화면 앞에서 돌아간 시간만 센다. 광고가 화면을 덮는 동안에는 게임이 멈춰 있어 흐르지 않고, 돌아온 첫 프레임의 긴 간격은 0.25초로만 센다.

불러오기에 실패하면 10, 30, 60, 120, 300초 간격으로 다시 시도하고 300초에서 더 늘지 않는다. 불러오기 답이 60초 안에 오지 않으면 실패로 본다. 동의 갱신이 실패했고 상태를 모르면 같은 간격으로 다시 갱신하며, 앱이 화면으로 돌아오면 기다리지 않고 다시 갱신한다.

### 기기에서 동의 양식 확인하기

동의 양식은 규제 지역(EEA, 영국, 스위스)에서만 뜬다. 다른 지역의 기기에서 기기 확인 항목 AND-05를 보려면 UMP의 디버그 지역 설정을 써야 하고, `FaLiveServices`는 디버그 빌드에서만 그 설정을 실행 인자로 받는다. 순서는 다음과 같다. 이 경로는 프로브로 플러그인의 요청 값까지 확인했고 기기에서는 아직 실행하지 않았다.

1. `python3 tools/prepare_services.py`로 제품의 AdMob 앱 ID를 넣는다. 동의 메시지는 앱 ID에 딸려 있어서, 플러그인 기본값인 Google의 테스트 앱 ID로는 이 제품의 양식이 오지 않는다. 디버그 빌드의 광고 단위는 이때도 테스트 단위다.
2. 디버그로 내보내 기기에서 한 번 실행하고, 로그에서 UMP가 알려 주는 기기 해시를 읽는다(`addTestDeviceHashedId`가 든 줄).
3. Android preset의 `command_line/extra_args`에 `-- --fa-consent-geography=eea --fa-consent-device=<기기 해시>`를 넣고 디버그로 다시 내보낸다. `not_eea`를 주면 규제 지역이 아닌 것으로 다룬다.
4. 앱 데이터를 지우고 실행하면 동의 양식이 뜬다. 선택을 마친 뒤 다시 실행해 양식이 다시 뜨지 않는지, 설정의 개인정보 선택 항목으로 다시 열 수 있는지 본다.
5. 확인이 끝나면 preset을 되돌리고 `python3 tools/prepare_services.py --restore`를 실행한다. preset에 인자가 남아 있으면 `npm run check:native`가 실패한다.

릴리스 빌드는 이 인자를 듣지 않는다. `tools/check_aab.py`도 인자가 든 AAB를 거부한다.

## 분석

`FaGa4Analytics`는 GA4 Measurement Protocol의 웹 스트림 주소로 보낸다. 한 요청에 25개까지 싣고, 대기열에 이벤트가 있으면 15초마다, 25개가 차면 바로 보낸다. 모든 이벤트에 `runtime_platform`(`android`), `app_market`(`google_play`), `release_version`(`application/config/version`), `session_id`(실행을 시작한 유닉스 초), `engagement_time_msec`(지난 이벤트 뒤 화면 앞에서 흐른 시간)을 붙인다. 참 거짓 값은 1과 0으로 보낸다. 디버그 빌드는 `debug_mode`를 함께 싣는다.

보내는 조건은 셋이 모두 맞을 때다.

| 조건 | 맞지 않으면 |
|---|---|
| 주입된 측정 ID와 API 비밀값이 있다 | 모으지 않는다 |
| 설정에서 분석이 켜져 있다(`set_enabled`) | 모으지 않고, 대기 중인 이벤트와 기기의 대기열을 버린다 |
| 동의 상태가 "필요 없음"이다 | 아직 모르면 메모리에만 들고 기기에 쓰지 않는다. 규제 지역으로 확정되면 버린다 |

이름 40자, 매개변수 25개, 값 100자 제한이나 예약된 이름을 어긴 이벤트는 버리고 디버그 빌드에서 경고를 남긴다. 전송에 실패하면 이벤트를 남겨 15, 60, 300초 뒤에 다시 보낸다. 대기열은 200개까지이고 넘으면 오래된 것부터 버린다. 못 보낸 이벤트는 기기에 저장해 다음 실행에 보내고, 일어난 지 72시간이 지난 것은 버린다. 요청 주소에는 비밀값이 들어가므로 어디에도 출력하지 않는다.

`app_first_run`과 `app_session`은 어댑터가 보낸다. 매개변수는 `session_index`와 `days_since_install`이다. 이 값은 기기의 식별자 파일에서 나오는데, 그 파일은 동의 상태가 "필요 없음"으로 확인된 뒤에만 읽고 쓸 수 있기 때문이다. 화면이나 bootstrap에서 같은 이벤트를 또 보내지 않는다.

코어와 수익화 프로필이 쓰는 `ad_impression`은 `ad_shown`으로 바꿔 보낸다. Measurement Protocol 문서가 `ad_impression`, `in_app_purchase`, `screen_view`를 앱 스트림에서만 받는다고 적었고 이 제품은 웹 스트림을 쓴다. GA4 보고서와 BigQuery에서는 `ad_shown`으로 찾는다.

| 함수 | 내용 |
|---|---|
| `log_event(name, params)` | 포트의 함수 |
| `set_enabled(enabled) -> bool`, `discard_pending()` | 공통 흐름의 분석 선택(`analytics_preference.gd`)이 부르는 함수. 그 `port` 자리에 그대로 끼운다 |
| `begin_session()`, `advance(seconds)`, `flush()` | `FaLiveServices`가 부른다 |
| `pending_count()` | 아직 보내지 않은 이벤트 수(검수용) |

## 원격 설정

`FaRemoteConfig`는 `start()`에서 캐시를 먼저 읽고, 주입된 주소가 있으면 `{"version", "values"}` 문서를 받는다(8초, 16KB 제한). 받은 값은 수익화 프로필의 `remote_config`에 대어 형과 범위를 검사하고, 틀린 값과 모르는 열쇠는 뺀다. 검사를 통과한 값만 캐시에 쓴다. 받지 못하면 캐시를, 캐시도 없으면 `null`을 돌려주고 `FaAdPolicy.config_from`이 내장 기본값을 쓴다.

배포하는 파일은 저장소의 `remote/config.json`이다. `npm run check:remote-config`가 프로필과 대조하고, main에 올라가면 `deploy-remote-config.yml`이 GitHub Pages에 올린다. 주소와 workflow는 [workflow 문서](../06-release/ci-cd-workflows.md)에 있다.

| 함수와 신호 | 내용 |
|---|---|
| `value(key)` | 포트의 함수 |
| `version()`, `source()` | 쓰고 있는 문서의 번호와 출처(`""`, `cache`, `remote`) |
| `start()` | `FaLiveServices`가 부른다 |
| `changed` | 쓰는 값이 바뀌었다 |

## 기기에 두는 파일

`user://services/` 아래에 둔다. 제품 저장 파일과 공통 흐름의 저장 파일과는 따로다.

| 파일 | 내용 | 쓰는 때 |
|---|---|---|
| `analytics-client.json` | 임의 식별자, 만든 시각, 실행 횟수 | 동의 상태가 "필요 없음"으로 확인되고 분석이 켜져 있을 때 |
| `analytics-queue.json` | 못 보낸 이벤트 | 위와 같음. 분석을 끄거나 규제 지역이 되면 지운다 |
| `remote-config.json` | 마지막으로 받은 설정 | 새 문서를 받았을 때 |

## 주입 값

AdMob 앱 ID와 광고 단위, GA4 측정 값, 원격 설정 주소는 저장소에 없다. 릴리스 빌드가 로컬 자격증명에서 읽어 `godot/data/services/release.json`과 `godot/project.godot`의 `[admob]` 절에 넣었다가 빌드가 끝나면 지운다. 방법은 [Android 빌드](../06-release/android-build.md)에 있다. 앱은 내보낸 빌드에서만 이 파일을 읽는다.

## bootstrap에 끼운 방법

`godot/game/bootstrap/main.gd`가 연결한다. 순서와 조건은 다음과 같다.

| 순서 | 하는 일 |
|---|---|
| `_init` | 로컬 묶음(`FaServices.local`: 파일 저장, 기기 시계)을 만들고 `use_live_services()`로 `FaLiveServices`를 만들어 `ads`, `analytics`, `config`에 끼운다. 여정은 장면을 트리에 넣기 전에 이 필드를 대역으로 바꾼다 |
| `_ready`, `super._ready()` 전 | 포트 묶음이 실제 어댑터를 하나라도 쓰면 `FaLiveServices`를 시작 장면의 직접 자식으로 넣고, 아니면 버린다. 분석 포트가 `set_enabled`와 `discard_pending`을 가지면 공통 흐름의 분석 선택(`analytics.port`)에 끼우고 `analytics_policy_allowed`를 켠다. 광고 포트의 `consent_changed`를 받는다 |
| 타이틀 | 준비 단계의 마지막이 동의 확인이다. 광고 포트의 `consent_settled()`가 참이 되거나 5초가 지나면 시작 버튼을 보인다. 규제 지역에서는 그동안 UMP 동의 양식이 먼저 뜬다(SCR-001의 동의 필요 상태) |
| 동의가 바뀜 | `consent_changed`를 받으면 분석 선택을 다시 적용하고(`analytics.apply`), 타이틀이나 설정 화면이 떠 있으면 다시 그린다. 설정의 개인정보 선택 줄은 `privacy_choice_required()`가 참일 때만 보인다 |
| 앱 복귀 | `main.gd`의 `_notification`이 백그라운드에 있던 시간을 시계 포트로 재고, 수익화 프로필의 `caps.interstitial_session_reset_s`(1,800초)를 넘으면 `FaSession.begin_session()`과 `FaLiveServices.begin_session()`을 부른다. 광고 어댑터의 다시 갱신(`resume`)과 분석의 보내기(`flush`)는 `FaLiveServices`가 스스로 한다 |

같은 일을 두 곳에서 하지 않도록 정리한 것:

- 광고 중 소리: 플레이 화면이 광고를 보여 달라고 할 때 음악을 멈추고 결과를 받으면 되돌린다. 광고 어댑터의 `presenting_changed`는 화면 쪽에서 쓰지 않는다(프로브만 순서를 본다). `FaLiveServices`가 넘겨주던 `ad_presenting_changed`, `ad_availability_changed`, `consent_changed`, `session_restarted` 신호는 없앴다. 동의 변화는 광고 포트(`FaAdsPort`)의 `consent_changed`로 받는다.
- 새 실행 판단: `FaLiveServices`는 더 이상 백그라운드 시간을 재지 않는다. bootstrap 한곳에서 판단하고 `begin_session()`을 부른다.
- `app_first_run`, `app_session`: 분석 어댑터만 보낸다. 03 문서의 타이틀 분석 `app_open`은 같은 시점의 `app_session`과 겹쳐 보내지 않고, 타이틀이 준비되는 데 걸린 시간은 `title_ready`(`ms`)로 한 번 보낸다. 홈의 `screen_view`는 웹 스트림이 받지 않는 예약 이름이라 보내지 않는다.

개발 PC와 headless에서는 SDK가 없어 `consent_settled()`가 곧바로 참이고 광고는 준비되지 않는다. 여정의 `live-services-offline` 시나리오가 이 기본 구성으로 시작 장면을 띄워 확인한다.

## 검수

| 프로브와 도구 | 확인하는 것 |
|---|---|
| `fa_ads_adapter_probe.gd` | 결과 판정(알림 순서, 시간 제한, 한 번만), 다시 시도 간격, 동의 뒤에만 초기화, 보여 주기와 다시 불러오기, 개인정보 선택, 주입 값과 테스트 단위 |
| `fa_admob_sdk_probe.gd` | `FaLiveServices`와 플러그인의 GDScript 층을 그대로 쓰고 Android 싱글턴 다섯 개만 대역으로 바꿔, 동의부터 광고 결과까지 따라간다 |
| `fa_analytics_adapter_probe.gd` | 제한 검사, 공통 값, 25개 묶음, 보내지 않는 조건, 대기열 상한과 만료, 실패와 다시 시도, 기기 저장, 실행 시작 이벤트, 공통 흐름의 분석 선택 |
| `fa_remote_config_probe.gd` | 프로필에서 만든 규칙, 형과 범위, 받기와 캐시, 대체, `remote/config.json`, 광고 정책과의 연결 |
| `tools/test_services.py`의 HTTP 검사 | `FaHttp`와 `FaRemoteConfig`를 이 기기 안의 서버(127.0.0.1)에 붙여 실제 GET과 POST, 크기 제한과 시간 제한, 연결 실패를 본다. 바깥 네트워크는 쓰지 않는다 |
| `python3 tools/check_ga4_payload.py` | 어댑터가 만든 실제 본문을 GA4의 검증 주소에 대어 본다. 기록되지 않는 주소이고 네트워크와 측정 값이 필요해 `npm test`에는 없다 |

프로브는 `npm test`가 실행한다. 네이티브 SDK의 실제 동작(동의 양식 표시, 광고 표시와 보상, 닫은 뒤 복귀, GA4 수신)은 프로브로 확인할 수 없고 설계의 기기 확인 항목 AND-05~07에서 본다.
