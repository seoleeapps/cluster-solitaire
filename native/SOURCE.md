# 네이티브 의존성 출처

이 제품의 네이티브 의존성은 AdMob 플러그인 하나다. 로그인, 결제, Firebase 라이브러리는 쓰지 않는다.

광고는 Poing Studios AdMob 5.1.0 정식 배포본을 고정한다. GDScript 원본과 Godot 4.7.2용 Android native template의 해시는 `dependencies.lock.json`에 있다. 미디에이션 사업자용 native binary는 설치하지 않는다.

배포본에서 두 파일을 고쳤다. 고친 이유와 해시는 잠금 파일의 `localPatches`에 있고 `tools/check_native.py`가 실제 파일과 대조한다.

- `gdscript/src/core/MobileSingletonPlugin.gd`: Editor에서 mock singleton을 자동으로 만드는 동작을 뺐다. 개발 검수는 테스트가 명시적으로 주입하는 대역을 쓴다.
- `admob.gd`: 새 복제본을 import할 때 네이티브 SDK를 자동으로 내려받는 동작을 뺐다. 고정 해시를 확인하는 준비 명령(`tools/prepare_android.sh`)에서만 설치한다.

호출하지 않는 upstream `binary_installer.gd`는 검수한 배포본과 대조할 수 있게 그대로 둔다. Editor 진입점에서 참조하지 않으며, 공급자 업데이트에서 자동 설치 기능이 없어지면 함께 정리한다.

AdMob Editor의 Noto Sans CJK SC는 Adobe의 2014–2021 저작권과 SIL OFL 1.1을 보존한다. 같은 폴더의 `OFL.txt`와 잠금 파일에 원본 해시와 라이선스 출처를 기록한다. Editor 전용 그림, 음악, 이 글꼴, 테스트 대역과 C# 예제는 출시 내보내기에서 제외한다.

AdMob 편집기 플러그인은 `godot/project.godot`에서 켜져 있다. 제품의 AdMob 앱 ID는 저장소에 두지 않고 릴리스 빌드가 `tools/prepare_services.py`로 `[admob]` 절에 넣었다가 지운다. 값이 없는 내보내기에는 플러그인의 기본값인 Google의 테스트 앱 ID가 들어가고, `tools/check_aab.py`가 그런 AAB를 거부한다. UMP 동의 처리와 광고 단위 연결은 제품 어댑터(`godot/game/adapters/fa_admob_ads.gd`, `fa_admob_sdk.gd`)에 있다.

플러그인의 Android 라이브러리는 GMA Next-Gen SDK(`ads-mobile-sdk` 1.4.0)를 쓴다. 플러그인은 UMP의 `canRequestAds`를 내보내지 않아 어댑터가 동의 상태로 같은 조건을 판정한다. 플러그인의 불러오기 객체(`RewardedAdLoader`, `InterstitialAdLoader`)는 답을 받은 뒤 스스로를 놓을 때 다른 참조가 없으면 지워지지 않고 남는다. 벤더 소스는 고치지 않고, 어댑터가 다음 불러오기까지 그 객체를 붙들어 제대로 지워지게 한다.
