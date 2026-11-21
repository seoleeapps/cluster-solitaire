# 문서

Four Alike의 설계, 구조, 마켓, 출시, 검수 기록을 둔다. 승인 범위는 설계 문서가 정본이고, 나머지 문서는 그 범위 안에서 저장소의 현재 상태를 적는다.

| 위치 | 내용 |
|---|---|
| [design/](design/README.md) | 승인된 설계와 테스트 계획 |
| [game-design/ui/direction/](game-design/ui/direction/README.md) | 고른 시각 방향의 기준 그림 |
| [02-decisions/](02-decisions/README.md) | 저장소 운영에 관한 장기 결정(ADR) |
| [03-architecture/](03-architecture/README.md) | 코드 구조, 공통 묶음, 제품 화면을 넣는 방법 |
| [05-markets/](05-markets/README.md) | Google Play 정보 |
| [06-release/](06-release/README.md) | Android 빌드, workflow, 출시 체크리스트 |
| [07-qa/](07-qa/README.md) | 검수 방법과 기능 목록을 고치는 방법 |
| `qa/feature-inventory.json` | 기능 목록(v2). 검사 도구가 읽는다 |
| [08-ops/](08-ops/README.md) | 도구와 의존성 버전 |
| [09-knowledge/](09-knowledge/README.md) | 저장소에 남길 프로젝트 지식 |

## 문서 규칙

- 확인한 사실과 추정을 구분한다.
- 정해지지 않은 값은 `확정 필요`로 적는다.
- 콘솔에서 바꾼 값은 관련 문서와 저장소 설정에 반영한다.
- `npm run check:docs`는 필수 문서가 있는지만 확인한다. 내용의 정확성은 사람이 읽고 확인한다.
