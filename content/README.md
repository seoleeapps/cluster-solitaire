# 콘텐츠 원본

카드와 범주의 정본은 이 폴더의 표 두 개다. 게임이 읽는 JSON과 레벨 팩은 여기서 도구로 만든다.

| 파일 | 열 | 내용 |
|---|---|---|
| `source/items.tsv` | `id`, `asset`, `en`, `ko` | 카드 801장. `asset`은 Fluent Emoji의 자산 이름, `id`가 아이콘 파일 이름이다 |
| `source/categories.tsv` | `id`, `tier`, `domain`, `en`, `ko`, `members`, `also` | 범주 158개. `tier`는 1(쉬움)~4, `members`는 소속 카드, `also`는 소속은 아니지만 그 범주로 보일 수 있는 카드 |

## 규칙

- 카드 이름은 영어 18자, 한국어 8자 이하이고 언어마다 서로 달라야 한다. 영어 낱말 하나는 13자를 넘지 않는다.
- 범주는 소속이 4장 이상이어야 한다.
- `also`에는 범주 이름(영어든 한국어든)을 보고 "이 카드도 여기 들어가야 한다"고 따질 수 있는 카드만 적는다. 경계에 있는 카드, 이름의 동음이의, 그림이 그 범주의 물건처럼 보이는 카드가 해당한다. 주제만 연상되는 카드(탈것 범주의 새, 가구 범주의 식기)는 넣지 않는다.
- 판 생성기는 한 판에 고른 범주들 사이에서 서로의 소속이나 `also`에 걸리는 카드를 넣지 않고, 판에 없는 범주의 후보가 여러 장 들어간 판도 버린다. 그래서 목록이 모자라면 억지스러운 판이 나가고, 넘치면 멀쩡한 판이 버려진다.
- 발음 말장난, 특정 문화권만 아는 범주, 주류, 정치와 종교 소재는 넣지 않는다.

## 고치는 순서

1. 표를 고친다. 새 카드는 `tools/content/rasterize_icons.py`로 아이콘을 만든다.
2. `python3 tools/content/build_content.py`로 `godot/data/content/*.json`을 다시 만든다. `--check`는 표와 JSON이 맞는지만 본다.
3. 표가 바뀌면 레벨 팩도 다시 만들어 검증한다. 저장소 루트에서 실행한다.

   ```bash
   # 여정 600판과 일일 도전 1,100판을 다시 만들고, 참고용 Python 탐색기로 모든 판을 검사한다
   npm run build:levels

   # 위 명령을 풀어 쓰면 다음 둘이다
   godot --headless --path godot --script res://../tools/levels/generate_packs.gd
   python3 tools/levels/verify_packs.py

   # 통계를 다시 뽑아 docs/design/2026-11-21-four-alike-launch/core-notes.md의 생성 통계에 옮긴다
   python3 tools/levels/verify_packs.py --stats
   ```

   - `generate_packs.gd`는 `godot/data/levels/journey.json`과 `daily.json`을 다시 쓴다. 판을 만들지 못하면 몇 번째 판에서 멈췄는지 알리고 종료 코드 1로 끝난다.
   - `verify_packs.py`는 모든 판의 풀이 가능 여부, 관대함, 묶는 방법의 유일성, 등급의 범주 조건을 다시 본다. 불일치가 있으면 종료 코드 1이다.
   - `npm test`는 이 Python 검증(`npm run check:levels`)과, 실린 팩이 지금 콘텐츠로 다시 만든 결과와 글자까지 같은지(`fa_packs_probe.gd`)를 함께 본다. 표만 고치고 팩을 다시 만들지 않으면 `npm test`가 실패한다.
   - 이미 공개한 버전의 일일 도전 날짜는 바꾸지 않는다. 지금 도구는 1번부터 전부 다시 만들므로, 출시 뒤에 이 규칙을 지키려면 뒤에 이어 붙이는 방식을 도구에 먼저 더해야 한다.

## 만든 과정

초안은 Fluent Emoji 목록에서 범주 168개와 카드 906장으로 시작했다. 이름은 그림을 보면서 영어와 한국어로 붙였고, 그 과정에서 이름을 붙이기 어렵거나 그림이 겹치는 카드를 뺐다. 그다음 범주마다 전체 카드를 훑어 `also` 목록을 만들고, 범주에 맞지 않는 소속 카드와 두 언어의 뜻이 어긋난 이름을 고쳤다. 색 범주는 그림의 픽셀 색 분포를 재고 눈으로 확인했다. 결과는 범주 158개, 카드 801장, `also` 2,342건이었다. 그 뒤 `also`를 한 번 다듬었다. 범주 이름의 뜻에는 들어가지 않고 주제만 함께 떠오르는 카드(탈것 범주의 새, 가구 범주의 식기, 물건 범주에 넣은 그 물건을 쓰는 사람)를 38개 범주에서 261건 빼서 지금은 2,081건이다.

출시 뒤에는 플레이어 신고와 오답 통계(`mistake` 이벤트의 범주별 비율)로 문제 범주를 찾아 표에서 고친다.

## 라이선스

카드 그림은 Microsoft Fluent Emoji(MIT)다. 고지문은 `godot/data/licenses/FluentEmoji-MIT.txt`에 있고 앱의 설정 화면에서 보여 준다.
