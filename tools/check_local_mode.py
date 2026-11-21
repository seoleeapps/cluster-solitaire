#!/usr/bin/env python3
"""로컬 전용 구성을 검사한다. 이 제품에는 로그인, 결제와 서버 연결이 없다."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# 공통 흐름을 서버 모드로 바꾸는 연결이다. 제품 코드가 쓰면 로컬 모드가 아니다.
SERVER_WIRING = re.compile(r'configure_platform\s*\(|platform_client\.gd')


def check(root):
    errors = []
    profile = json.loads((root / 'godot/data/outgame/outgame-profile.json').read_text())
    if profile.get('mode') != 'local':
        errors.append('outgame profile must stay in local mode')
    for name in ('auth', 'payments'):
        service = profile.get('services', {}).get(name, {})
        if service.get('status') != 'unsupported' or service.get('exposed') is not False:
            errors.append(name + ' must stay unsupported and hidden')
    for path in sorted((root / 'godot/game').rglob('*.gd')):
        if SERVER_WIRING.search(path.read_text()):
            errors.append(path.relative_to(root).as_posix() + ': product code connects the platform client')
    return errors


if __name__ == '__main__':
    errors = check(ROOT)
    print('\n'.join(errors) if errors else 'Local mode verified')
    raise SystemExit(bool(errors))
