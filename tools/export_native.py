#!/usr/bin/env python3
"""서명한 Android 릴리스 AAB를 만들고 결과물을 검사한다.

    python3 tools/export_native.py

순서: Android 설정 검사, 빌드 템플릿과 AdMob 라이브러리 준비, 서비스 값 주입(tools/prepare_services.py),
자원 가져오기, Android preset 내보내기, 주입한 값 지우기, 결과물 검사(tools/check_aab.py).
주입한 값은 성공하든 실패하든 지우고 godot/project.godot을 빌드 전의 내용으로 되돌린다.

서명 값은 환경 변수 GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER, _PASSWORD에서 읽는다. 셋이 다 있지 않으면
FA_KEYSTORE_ENV(기본 ~/.config/seorilabs/play-store/four-alike-keystore.env)의 ANDROID_KEYSTORE_FILE,
ANDROID_KEYSTORE_ALIAS, ANDROID_KEYSTORE_PASSWORD를 쓴다. 값은 명령 인자로 넘기지 않고 출력에서 가린다.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import check_aab
import check_native
import prepare_services

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_KEYSTORE_ENV = '~/.config/seorilabs/play-store/four-alike-keystore.env'
SIGNING = {
    'GODOT_ANDROID_KEYSTORE_RELEASE_PATH': 'ANDROID_KEYSTORE_FILE',
    'GODOT_ANDROID_KEYSTORE_RELEASE_USER': 'ANDROID_KEYSTORE_ALIAS',
    'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD': 'ANDROID_KEYSTORE_PASSWORD',
}


def signing_environment(environ, home):
    """Godot이 읽는 서명 환경 변수 셋을 돌려준다. 값이 없으면 ValueError."""
    if all(environ.get(name) for name in SIGNING):
        return {name: environ[name] for name in SIGNING}
    configured = environ.get('FA_KEYSTORE_ENV')
    path = Path(configured) if configured else Path(DEFAULT_KEYSTORE_ENV.replace('~', str(home), 1))
    shown = '$FA_KEYSTORE_ENV' if configured else DEFAULT_KEYSTORE_ENV
    if not path.is_file():
        raise ValueError('Signing values not found: set %s or provide %s' % (', '.join(SIGNING), shown))
    stored = prepare_services.read_env_file(path)
    missing = [source for source in SIGNING.values() if not stored.get(source)]
    if missing:
        raise ValueError('Signing values missing in %s: %s' % (shown, ', '.join(missing)))
    if stored.get('ANDROID_KEY_PASSWORD') and stored['ANDROID_KEY_PASSWORD'] != stored['ANDROID_KEYSTORE_PASSWORD']:
        # Godot의 내보내기는 저장소와 키에 같은 비밀번호를 쓴다.
        raise ValueError('Godot signs with one password; the keystore and key passwords in %s differ' % shown)
    if not Path(stored['ANDROID_KEYSTORE_FILE']).is_file():
        raise ValueError('The keystore named in %s does not exist' % shown)
    return {name: stored[source] for name, source in SIGNING.items()}


def run(command, timeout, env, secrets):
    """명령을 실행하고 비밀값을 가린 출력을 보여 준다. 실패하거나 Godot이 오류를 찍으면 RuntimeError."""
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=timeout, env=env)
    log = result.stdout + result.stderr
    visible = log
    for value in secrets:
        if value:
            visible = visible.replace(value, '[redacted]')
    print(visible, end='')
    log = re.sub(r'\x1b\[[0-9;]*m', '', log)
    if result.returncode or re.search(r'^(?:SCRIPT ERROR|ERROR:)', log, re.M):
        raise RuntimeError('Command failed; inspect the preceding output: ' + Path(command[0]).name)


def main():
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    errors = check_native.validate(ROOT)
    if errors:
        raise ValueError('\n'.join(errors))
    signing = signing_environment(os.environ, Path.home())
    env = {**os.environ, **signing}
    secrets = [signing['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']]
    secrets += [value for name, value in os.environ.items() if value and any(word in name.upper() for word in ['PASSWORD', 'TOKEN', 'PRIVATE_KEY', 'SECRET'])]
    godot = os.environ.get('GODOT', 'godot')
    # check_native가 이 경로와 Android preset의 내보내기 경로가 같은지 확인했다.
    output = ROOT / json.loads((ROOT / 'play-store/google-play.config.json').read_text())['aabPath']
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    project = ROOT / prepare_services.PROJECT_FILE
    original = project.read_bytes()
    try:
        run(['bash', str(ROOT / 'tools/install_android_build_template.sh')], 300, env, secrets)
        run(['bash', str(ROOT / 'tools/prepare_android.sh')], 300, env, secrets)
        injected = json.loads((ROOT / prepare_services.RELEASE_FILE).read_text())
        secrets += [value for value in injected.values() if isinstance(value, str) and not value.startswith('https://')]
        run([godot, '--headless', '--path', str(ROOT / 'godot'), '--import'], 300, env, secrets)
        run([godot, '--headless', '--path', str(ROOT / 'godot'), '--export-release', 'Android', str(output)], 1800, env, secrets)
    finally:
        prepare_services.restore(ROOT)
        project.write_bytes(original)
    if not output.exists():
        raise RuntimeError('Godot did not create the expected output')
    errors, summary = check_aab.check(ROOT, output)
    print(json.dumps({'ok': not errors, 'errors': errors, **summary}, ensure_ascii=False, indent=2))
    if errors:
        raise RuntimeError('The release bundle failed its checks')
    print(output.relative_to(ROOT))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
