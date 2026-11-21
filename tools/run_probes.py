#!/usr/bin/env python3
"""godot/tests/game의 프로브를 하나씩 headless로 실행한다. 화면 여정 없이 규칙만 빠르게 확인할 때 쓴다.

    python3 tools/run_probes.py              # 전부
    python3 tools/run_probes.py board solver # 이름에 board나 solver가 든 프로브만

통과 기준은 tools/check.py와 같다: 종료 코드 0이고 로그에 SCRIPT ERROR나 ERROR:로 시작하는 줄이 없어야 한다.
"""
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TIMEOUT_SECONDS = 180


def run(godot, probe):
    """프로브 하나를 실행해 (통과 여부, 로그)를 돌려준다."""
    command = [godot, '--headless', '--path', str(ROOT / 'godot'), '--script', 'res://tests/game/' + probe.name]
    try:
        done = subprocess.run(command, capture_output=True, text=True, timeout=TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        return False, 'timed out after %d seconds' % TIMEOUT_SECONDS
    log = done.stdout + done.stderr
    return done.returncode == 0 and not re.search(r'^(?:SCRIPT ERROR|ERROR:)', log, re.M), log


def main():
    wanted = sys.argv[1:]
    probes = [probe for probe in sorted((ROOT / 'godot/tests/game').glob('*_probe.gd'))
              if not wanted or any(word in probe.name for word in wanted)]
    if not probes:
        print('no probe matches ' + ' '.join(wanted))
        return 1
    godot = os.environ.get('GODOT', 'godot')
    failed = []
    for probe in probes:
        started = time.monotonic()
        passed, log = run(godot, probe)
        lines = [line for line in log.splitlines() if line.strip()]
        print('%-4s %-28s %5.1fs  %s' % ('ok' if passed else 'FAIL', probe.name, time.monotonic() - started, lines[-1] if passed and lines else ''))
        if not passed:
            failed.append(probe.name)
            print('\n'.join('    ' + line for line in lines[-25:]))
    print('%d of %d probes passed' % (len(probes) - len(failed), len(probes)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
