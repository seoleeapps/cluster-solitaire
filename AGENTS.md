# Four Alike 작업 지침

한국어로 간결하게 보고한다. 공개 저장소이므로 비밀값, 개인 정보, 로컬 절대 경로를 커밋하지 않는다.

제품은 세로형 모바일 게임이고 출시 마켓은 Google Play와 Apple App Store(2026-11-22 추가 승인)다. 승인 범위는 [첫 출시 설계](docs/design/2026-11-21-four-alike-launch/design.md)와 같은 폴더의 test-plan.json을 따른다. iOS는 비추적(No-ATT, 비개인화 `npa=1` 광고, UMP 미호출) 구성을 쓴다. 앱인토스, 인앱결제, 로그인, 서버는 범위에 없다. 다시 넣으려면 새 설계 승인이 필요하다.

제품 규칙은 GDScript의 godot/game/core, 장면과 전용 그림은 features, 저장과 SDK 연결은 adapters, 공통 흐름과의 연결은 bootstrap에 둔다. 공통 묶음 세 폴더(godot/addons/seorilabs_game, godot/addons/seorilabs_platform, godot/tests/common)는 common-bundle.lock.json으로 고정돼 있으므로 직접 고치거나 파일을 더하지 않는다. 공통 수정은 game-foundation 원본에서 하고 검수한 묶음을 설치한다.

로컬 실행은 서버, 자격증명과 스킬 설치 없이 동작해야 한다. 변경 뒤에는 `npm test`, `npm run check:architecture`, `python3 tools/bundle.py verify`를 실행한다. 화면을 바꿨으면 `python3 tools/check.py --capture`를 390x844와 360x640으로 돌려 PNG를 직접 본다. 미실행을 통과로 기록하지 않는다. 출력은 build에 둔다.

기능을 더하거나 빼면 docs/qa/feature-inventory.json과 godot/data/outgame/outgame-profile.json을 함께 고친다. 방법은 [검수 문서](docs/07-qa/test-strategy.md)에 있다.

PR은 한국어 Ready로 작성한다. 사용자 수정은 보존한다. 기기 사용은 설계에 적힌 기기 확인 항목(AND-01~08) 범위만 승인돼 있고 그 밖은 별도의 명시적 승인이 필요하다.
