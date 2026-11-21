#!/usr/bin/env python3
"""분석 어댑터가 만드는 요청 본문을 GA4 Measurement Protocol의 검증 주소에 대어 본다.

    python3 tools/check_ga4_payload.py

검증 주소(/debug/mp/collect)는 형식만 검사하고 아무것도 기록하지 않는다. 실제 수집 주소로는 보내지 않는다.
본문은 godot/tests/game/fa_analytics_payload_dump.gd가 실제 어댑터로 만든다.
네트워크와 측정 값이 필요하므로 npm test에는 들어 있지 않다. 분석 이벤트나 어댑터를 고친 뒤 직접 실행한다.

측정 값은 tools/prepare_services.py와 같은 곳에서 읽는다(FA_ANALYTICS_ENV 또는 환경 변수). 주소와 값은 출력하지 않는다.
검증 주소는 이름 규칙, 예약된 이름, 매개변수 수와 길이, 시각을 본다. 스트림 종류에 따른 제한
(웹 스트림이 받지 않는 ad_impression 등)은 보지 않으므로 그 규칙은 어댑터의 프로브가 맡는다.
"""
import json
import os
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import prepare_services

ROOT = Path(__file__).resolve().parents[1]
ENDPOINT = 'https://www.google-analytics.com/debug/mp/collect'
DUMP_SCRIPT = 'res://tests/game/fa_analytics_payload_dump.gd'


def measurement_values(environ, home):
    """측정 ID와 API 비밀값. 없으면 ServiceValueError."""
    names = prepare_services.SOURCES['FA_ANALYTICS_ENV']
    values = {name: environ.get(name, '') for name in names}
    if not all(values.values()):
        configured = environ.get('FA_ANALYTICS_ENV')
        path = Path(configured) if configured else Path(prepare_services.DEFAULT_ENV_FILES['FA_ANALYTICS_ENV'].replace('~', str(home), 1))
        if not path.is_file():
            raise prepare_services.ServiceValueError('analytics credential file not found')
        stored = prepare_services.read_env_file(path)
        values = {name: values[name] or stored.get(name, '') for name in names}
    missing = [name for name in names if not values[name]]
    if missing:
        raise prepare_services.ServiceValueError(', '.join(missing) + ' missing')
    return values


def dump_bodies(godot):
    """실제 어댑터로 만든 요청 본문들."""
    with tempfile.TemporaryDirectory() as folder:
        out = Path(folder) / 'payload.json'
        done = subprocess.run([godot, '--headless', '--path', str(ROOT / 'godot'), '--script', DUMP_SCRIPT, '--', '--out', str(out)],
                              capture_output=True, text=True, timeout=180)
        if done.returncode or not out.is_file():
            raise RuntimeError('payload dump failed: ' + (done.stdout + done.stderr).strip()[-400:])
        return json.loads(out.read_text())


def validate(body, values):
    """본문 하나를 검증 주소에 보내고 validationMessages를 돌려준다."""
    url = ENDPOINT + '?' + urllib.parse.urlencode({'measurement_id': values['GA4_MEASUREMENT_ID'], 'api_secret': values['GA4_MP_API_SECRET']})
    payload = json.dumps({**body, 'validation_behavior': 'ENFORCE_RECOMMENDATIONS'}).encode()
    request = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read().decode()).get('validationMessages', [])
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        # 오류 글자에는 주소가 들어갈 수 있으므로 종류만 알린다.
        raise RuntimeError('validation request failed: ' + type(error).__name__) from None


def main():
    try:
        values = measurement_values(os.environ, Path.home())
        bodies = dump_bodies(os.environ.get('GODOT', 'godot'))
        messages = []
        for body in bodies:
            messages += validate(body, values)
    except (prepare_services.ServiceValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'errors': [str(error)]}, ensure_ascii=False))
        return 1
    names = [event['name'] for body in bodies for event in body['events']]
    print(json.dumps({'ok': not messages, 'requests': len(bodies), 'events': len(names), 'names': names, 'validationMessages': messages}, ensure_ascii=False, indent=2))
    return 1 if messages else 0


if __name__ == '__main__':
    sys.exit(main())
