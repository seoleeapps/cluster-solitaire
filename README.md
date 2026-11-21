# Four Alike / 끼리끼리

숨은 범주를 추리해 카드 4장을 묶는 세로형 모바일 카드 퍼즐이다. Godot 4.7.2로 만들고 Google Play(Android)에 낸다. 패키지는 `com.seoleeapps.fouralike`다. 수익은 AdMob 보상형과 전면 광고이며 인앱결제, 로그인, 서버가 없다. 진행은 기기에 저장하고 영어와 한국어를 지원한다.

승인된 범위와 근거는 [첫 출시 설계](docs/design/2026-11-21-four-alike-launch/design.md)에 있다.

## 현재 상태

규칙 코어, 레벨 팩, 플레이 화면과 바깥 화면이 들어간 단계다. 타이틀(실제 준비 단계 막대와 동의 확인), 홈, 일일 도전, 도감, 코인 상점(부스터와 꾸미기, 결제 없음), 출석, 알림함, 설정(개인정보 선택과 오픈소스 고지)이 플레이 화면과 같은 캔디 팝 스킨으로 돌아간다. 튜토리얼 판부터 여정 스테이지, 부스터, 이어하기, 결과와 2배 보상까지 한 판의 흐름과 판 도중의 상태가 저장된다. 광고(AdMob과 UMP 동의), 분석(GA4 Measurement Protocol), 원격 설정 어댑터가 시작 장면에 연결돼 있고, 주입 값과 네이티브 SDK가 없는 개발 실행과 검수에서는 광고가 준비되지 않고 분석과 원격 설정이 꺼진 채로 동작한다. 기기에서의 동의 양식, 광고 표시, 분석 수신은 아직 확인하지 않았다(설계의 기기 확인 항목 AND-05~07).

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

`npm test`는 실제 시작 장면을 띄워 화면 좌표 입력으로 타이틀, 튜토리얼, 스테이지 클리어, 오답과 실패, 부스터와 광고 보상, 일시정지, 재실행 뒤 판 복원, 일일 도전, 도감, 상점과 꾸미기, 출석, 알림함, 설정까지 확인하고 추적 파일을 바꾸지 않는다. `--capture`는 같은 여정을 렌더링해 장면별 PNG를 남긴다. PNG는 직접 열어 본다. 개발 실행, 기기 확인, 마켓 검증은 서로 다른 근거이고 미실행은 통과가 아니다.

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
