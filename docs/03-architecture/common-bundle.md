# 공통 묶음

타이틀, 설정, 지원코드, 우편함, 저장 틀, UI 재료(ui_kit)와 검수 도우미는 [game-foundation](https://github.com/seorilabs/game-foundation)의 검수본을 그대로 쓴다. 묶음은 세 폴더다.

- `godot/addons/seorilabs_game`
- `godot/addons/seorilabs_platform`
- `godot/tests/common`

묶음 버전은 1.1.0이고 원본 커밋과 파일별 해시가 `common-bundle.lock.json`에 있다. `python3 tools/bundle.py verify`는 세 폴더의 파일이 바뀌었거나 새 파일이 생기면 실패한다. Godot이 만드는 `.uid`와 `.import`는 세지 않는다.

제품에 맞지 않는 부분이 있어도 묶음 파일을 고치지 않는다. 제품 쪽에서 바꿀 수 있는 것은 [구조 문서](README.md)의 주입 자리로 처리하고, 묶음 자체의 문제는 game-foundation 원본에서 고친 뒤 검수한 묶음을 설치한다.

```sh
python3 tools/bundle.py install --bundle /absolute/common.tar.gz
```

설치는 기존 공통 파일에 수정이 있으면 멈추고, 낮은 버전으로 되돌리지 않는다.

`seorilabs_platform`에는 로그인, 결제, 우편 서버를 쓰는 SDK가 들어 있다. 이 제품은 그 SDK를 연결하지 않는다. 저장 도우미(`godot/addons/seorilabs_platform/core/atomic_json_store.gd`)처럼 서버와 무관한 부분만 공통 흐름을 통해 쓰인다.
