#!/usr/bin/env python3
"""원격 설정 파일(remote/config.json)을 수익화 프로필의 remote_config와 대조한다.

    python3 tools/check_remote_config.py

앱은 이 파일을 내려받아 열쇠마다 형과 범위를 검사하고, 틀린 값은 버린 뒤 내장 기본값을 쓴다
(godot/game/adapters/fa_remote_config_rules.gd). 그래서 틀린 값을 올려도 앱은 멈추지 않지만 의도한 설정이
조용히 무시된다. 이 검사는 올리기 전에 그런 값을 잡는다.

통과 조건: 형식이 {"version": 1 이상의 정수, "values": {열쇠: 값}}이고, 모든 열쇠가 프로필에 있으며,
값의 형과 범위가 프로필과 맞고, 파일 크기가 앱이 받는 상한보다 작다. 프로필의 열쇠를 빼는 것은 허용한다.
뺀 열쇠는 앱의 내장 기본값을 쓴다.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = 'remote/config.json'
PROFILE = 'godot/data/monetization/bm-profile.json'
# 앱이 받는 응답 크기 상한. godot/game/adapters/fa_remote_config.gd의 MAX_BYTES와 같아야 한다.
MAX_BYTES = 16 * 1024


def is_whole(value):
    """참 거짓이 아닌 정수인지. JSON의 1.0 같은 정수인 실수도 정수로 본다."""
    if isinstance(value, bool):
        return False
    return isinstance(value, int) or (isinstance(value, float) and value.is_integer())


def rules_from(profile):
    """프로필의 remote_config에서 (열쇠별 규칙, 프로필의 문제)를 만든다."""
    rules, errors = {}, []
    for entry in profile.get('remote_config', []):
        key, kind, default = entry.get('key'), entry.get('type'), entry.get('default')
        if not isinstance(key, str) or kind not in ('bool', 'int'):
            errors.append('profile: unsupported remote_config entry: %r' % (key,))
            continue
        rule = {'type': kind, 'default': default}
        if kind == 'bool':
            if not isinstance(default, bool):
                errors.append('profile: %s default must be true or false' % key)
        else:
            limits = entry.get('range') or {}
            if not is_whole(limits.get('min')) or not is_whole(limits.get('max')) or limits['min'] > limits['max']:
                errors.append('profile: %s needs an integer range' % key)
                continue
            rule.update(min=limits['min'], max=limits['max'])
            if not is_whole(default) or not limits['min'] <= default <= limits['max']:
                errors.append('profile: %s default is outside its range' % key)
        rules[key] = rule
    if not rules:
        errors.append('profile: remote_config is empty')
    return rules, errors


def check_document(document, rules):
    """원격 설정 문서의 문제 목록."""
    if not isinstance(document, dict):
        return ['config: must be a JSON object']
    errors = []
    unexpected = sorted(set(document) - {'version', 'values'})
    if unexpected:
        errors.append('config: unexpected top-level keys: ' + ', '.join(unexpected))
    version = document.get('version')
    if not is_whole(version) or version < 1:
        errors.append('config: version must be an integer of 1 or more')
    values = document.get('values')
    if not isinstance(values, dict):
        return errors + ['config: values must be an object']
    for key in sorted(values):
        value = values[key]
        rule = rules.get(key)
        if rule is None:
            errors.append('config: %s is not a remote_config key of the profile' % key)
        elif rule['type'] == 'bool':
            if not isinstance(value, bool):
                errors.append('config: %s must be true or false' % key)
        elif not is_whole(value):
            errors.append('config: %s must be an integer' % key)
        elif not rule['min'] <= value <= rule['max']:
            errors.append('config: %s must be between %d and %d' % (key, rule['min'], rule['max']))
    return errors


def check(root):
    """저장소 root의 원격 설정 파일을 검사해 (문제 목록, 요약)을 돌려준다."""
    try:
        profile = json.loads((root / PROFILE).read_text())
    except (OSError, ValueError) as error:
        return ['profile: cannot read %s: %s' % (PROFILE, type(error).__name__)], {}
    rules, errors = rules_from(profile)
    try:
        raw = (root / CONFIG).read_bytes()
        document = json.loads(raw)
    except (OSError, ValueError) as error:
        return errors + ['config: cannot read %s: %s' % (CONFIG, type(error).__name__)], {}
    if len(raw) >= MAX_BYTES:
        errors.append('config: file is %d bytes, the app accepts less than %d' % (len(raw), MAX_BYTES))
    errors += check_document(document, rules)
    values = document.get('values') if isinstance(document, dict) and isinstance(document.get('values'), dict) else {}
    summary = {
        'version': document.get('version') if isinstance(document, dict) else None,
        'keys': len(values),
        'profileKeys': len(rules),
        'omitted': sorted(set(rules) - set(values)),
        'changedFromDefault': sorted(key for key in values if key in rules and values[key] != rules[key]['default']),
    }
    return errors, summary


def main():
    errors, summary = check(ROOT)
    print(json.dumps({'ok': not errors, 'errors': errors, **summary}, ensure_ascii=False))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
