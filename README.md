# Four Alike / 끼리끼리

숨은 범주를 추리해 카드 4장을 묶는 세로형 모바일 카드 퍼즐이다. Godot 4.7.2로 만들고 Google Play(Android)에 낸다. 패키지는 `com.seoleeapps.fouralike`다. 수익은 AdMob 보상형과 전면 광고이며 인앱결제, 로그인, 서버가 없다. 진행은 기기에 저장하고 영어와 한국어를 지원한다.

승인된 범위와 근거는 [첫 출시 설계](docs/design/2026-11-21-four-alike-launch/design.md)에 있다.

## 현재 상태

규칙 코어, 레벨 팩과 플레이 화면이 들어간 단계다. 튜토리얼 판, 여정 스테이지, 부스터, 임시 칸 추가, 이어하기, 결과와 2배 보상까지 한 판의 흐름이 캔디 팝 스킨으로 돌아가고 판 도중의 상태가 저장된다. 타이틀, 설정, 지원코드, 우편함은 공통 묶음의 화면이 그대로 동작하고, 홈에는 스테이지 번호와 시작 버튼만 있다. 광고와 분석, 원격 설정의 실제 어댑터는 만들어져 있지만 시작 장면에는 아직 연결하지 않아 로컬 구성(광고 없음)으로 실행된다. 타이틀과 홈의 제품 화면, 일일 도전의 진입 화면, 도감, 상점, 출석은 아직 없다.

## 실행과 검사

Godot 4.7.2, Python 3.11 이상, Node.js 24가 필요하다. 복제한 뒤 네트워크나 자격증명 없이 실행된다. 생성 캐시와 검사 출력은 Git에 넣지 않는다.

```sh
npm start                     # 자원을 가져온 뒤 게임을 실행한다. python3 tools/run.py와 같다
npm test                      # 도구 단위 테스트, Android 설정 검사, headless 여정
npm run check:architecture    # core 경계와 기능 목록 형식
npm run check:bundle          # 공통 묶음 해시
python3 tools/check.py --capture --size 390x844 --out build/render-390
python3 tools/check.py --capture --size 390x693 --out build/render-693
```

`npm test`는 실제 시작 장면을 띄워 화면 좌표 입력으로 튜토리얼, 스테이지 클리어, 오답과 실패, 부스터와 광고 보상, 일시정지, 재실행 뒤 판 복원까지 확인하고 추적 파일을 바꾸지 않는다. `--capture`는 같은 여정을 렌더링해 장면별 PNG를 남긴다. PNG는 직접 열어 본다. 개발 실행, 기기 확인, 마켓 검증은 서로 다른 근거이고 미실행은 통과가 아니다.

## 구조

| 위치 | 내용 |
|---|---|
| `godot/game` | 제품 코드. 규칙은 `core`, 화면은 `features`, 저장과 SDK 연결은 `adapters`, 공통 흐름과의 연결은 `bootstrap` |
| `godot/addons/seorilabs_game`, `godot/addons/seorilabs_platform`, `godot/tests/common` | 공통 묶음. [game-foundation](https://github.com/seorilabs/game-foundation)의 검수본이며 `common-bundle.lock.json`으로 고정한다. 직접 고치지 않는다 |
| `godot/addons/admob` | AdMob 플러그인. 편집기 플러그인으로 켜져 있고 제품의 광고 어댑터(`godot/game/adapters`)가 쓴다 |
| `godot/tests/game` | 제품 여정과 프로브 |
| `tools`, `scripts` | 검사와 빌드 도구 |
| `docs` | 설계, 구조, 마켓, 출시, 검수 문서 |

화면은 세로 고정이고 논리 해상도는 390×844다. 더 긴 화면에서는 세로만 늘어난다. 자세한 구조와 제품 화면을 공통 흐름에 넣는 방법은 [구조 문서](docs/03-architecture/README.md)에 있다.

## 빌드와 출시

Android AAB 빌드는 [Android 빌드](docs/06-release/android-build.md)를, Google Play 정보는 [Google Play](docs/05-markets/google-play.md)를 따른다. 기본 CI는 검사만 실행하고 마켓 workflow는 수동으로만 실행한다. 빌드, 업로드, 심사, 공개는 서로 다른 상태로 기록한다.
