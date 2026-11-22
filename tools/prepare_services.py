#!/usr/bin/env python3
"""릴리스 빌드에 넣을 서비스 값을 로컬 자격증명에서 읽어 프로젝트에 채운다.

    python3 tools/prepare_services.py            # 채운다
    python3 tools/prepare_services.py --restore  # 채운 것을 지운다

채우는 곳은 둘이다. 둘 다 Git이 추적하는 내용에 값이 남지 않게 빌드가 끝나면 --restore로 지운다.
tools/export_native.py는 이 과정을 스스로 한다.

  godot/data/services/release.json   앱이 실행 중에 읽는 값(.gitignore로 추적하지 않는다)
  godot/project.godot의 [admob] 절   AdMob 플러그인이 Android 매니페스트에 넣는 앱 ID

값은 아래 파일에서 읽는다. 같은 이름의 환경 변수가 있으면 그 값을 먼저 쓴다.

  FA_ADMOB_ENV      기본 ~/.config/seorilabs/admob/four-alike/public-identifiers.env
                    ADMOB_APP_ID, ADMOB_REWARDED_AD_UNIT_ID, ADMOB_INTERSTITIAL_AD_UNIT_ID
  FA_ANALYTICS_ENV  기본 ~/.config/seorilabs/analytics-four-alike.env
                    GA4_MEASUREMENT_ID, GA4_MP_API_SECRET
  FA_REMOTE_CONFIG_URL  원격 설정 JSON의 주소. 기본은 이 저장소의 GitHub Pages 주소

값이 없거나 형식이 틀리거나 Google의 테스트 광고 ID이면 아무것도 쓰지 않고 멈춘다. 값은 출력하지 않는다.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RELEASE_FILE = 'godot/data/services/release.json'
PROJECT_FILE = 'godot/project.godot'
DEFAULT_REMOTE_CONFIG_URL = 'https://seoleeapps.github.io/cluster-solitaire/config.json'
DEFAULT_ENV_FILES = {
    'FA_ADMOB_ENV': '~/.config/seorilabs/admob/four-alike/public-identifiers.env',
    'FA_ANALYTICS_ENV': '~/.config/seorilabs/analytics-four-alike.env',
}
# Google이 공개한 테스트 광고의 게시자 ID. 이 게시자의 앱 ID와 광고 단위는 릴리스에 넣지 않는다.
TEST_PUBLISHER = '3940256099942544'
# 형식은 앱이 읽을 때 쓰는 것과 같아야 한다(godot/game/adapters/fa_service_values.gd). tools/test_services.py가 대조한다.
PATTERNS = {
    'ADMOB_APP_ID': r'ca-app-pub-([0-9]{16})~[0-9]{10}',
    'ADMOB_REWARDED_AD_UNIT_ID': r'ca-app-pub-([0-9]{16})/[0-9]{10}',
    'ADMOB_INTERSTITIAL_AD_UNIT_ID': r'ca-app-pub-([0-9]{16})/[0-9]{10}',
    'GA4_MEASUREMENT_ID': r'G-[A-Z0-9]{4,20}',
    'GA4_MP_API_SECRET': r'[A-Za-z0-9_-]{8,64}',
    'FA_REMOTE_CONFIG_URL': r'https://[A-Za-z0-9.-]+/[A-Za-z0-9._~/-]*',
}
SOURCES = {
    'FA_ADMOB_ENV': ['ADMOB_APP_ID', 'ADMOB_REWARDED_AD_UNIT_ID', 'ADMOB_INTERSTITIAL_AD_UNIT_ID'],
    'FA_ANALYTICS_ENV': ['GA4_MEASUREMENT_ID', 'GA4_MP_API_SECRET'],
}
PLATFORM_ADMOB = {
    'android': ('ADMOB_APP_ID', 'ADMOB_REWARDED_AD_UNIT_ID', 'ADMOB_INTERSTITIAL_AD_UNIT_ID', 'general/android/app_id'),
    'ios': ('ADMOB_IOS_APP_ID', 'ADMOB_IOS_REWARDED_AD_UNIT_ID', 'ADMOB_IOS_INTERSTITIAL_AD_UNIT_ID', 'general/ios/app_id'),
}
ADMOB_SECTION = 'admob'
ADMOB_SETTING = 'general/android/app_id'


class ServiceValueError(Exception):
    """값을 채울 수 없는 이유. 메시지에 값을 넣지 않는다."""


def read_env_file(path):
    """KEY=VALUE 줄로 된 파일을 읽는다. export 접두어와 따옴표를 뗀다."""
    values = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        key = key.strip()
        if key.startswith('export '):
            key = key[len('export '):].strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in '"\'':
            value = value[1:-1]
        values[key] = value
    return values


def collect(environ, home, platform='android'):
    """환경과 자격증명 파일에서 값을 모아 검사한다. 문제가 있으면 ServiceValueError를 낸다."""
    if platform not in PLATFORM_ADMOB:
        raise ServiceValueError('unsupported platform: %s' % platform)
    app_key, rew_key, int_key, _setting = PLATFORM_ADMOB[platform]
    sources = {
        'FA_ADMOB_ENV': [app_key, rew_key, int_key],
        'FA_ANALYTICS_ENV': ['GA4_MEASUREMENT_ID', 'GA4_MP_API_SECRET'],
    }
    values, problems = {}, []
    for variable, names in sources.items():
        missing = [name for name in names if not environ.get(name)]
        from_file, file_problem = {}, ''
        if missing:
            configured = environ.get(variable)
            path = Path(configured) if configured else Path(DEFAULT_ENV_FILES[variable].replace('~', str(home), 1))
            # 환경 변수로 바꾼 경로는 로컬 경로일 수 있으므로 변수 이름만 보인다.
            shown = '$' + variable if configured else DEFAULT_ENV_FILES[variable]
            if not path.is_file():
                file_problem = 'credential file not found: %s (needed for %s)' % (shown, ', '.join(missing))
            else:
                try:
                    from_file = read_env_file(path)
                except (OSError, UnicodeDecodeError) as error:
                    file_problem = 'credential file unreadable: %s (%s)' % (shown, type(error).__name__)
        if file_problem:
            problems.append(file_problem)
        for name in names:
            value = environ.get(name) or from_file.get(name) or ''
            if value:
                values[name] = value
            elif not file_problem:
                problems.append('%s is missing' % name)
    if platform != 'android':
        values['ADMOB_APP_ID'] = values.pop(app_key, '')
        values['ADMOB_REWARDED_AD_UNIT_ID'] = values.pop(rew_key, '')
        values['ADMOB_INTERSTITIAL_AD_UNIT_ID'] = values.pop(int_key, '')
    values['FA_REMOTE_CONFIG_URL'] = environ.get('FA_REMOTE_CONFIG_URL') or DEFAULT_REMOTE_CONFIG_URL
    publishers = set()
    for name, pattern in PATTERNS.items():
        if name not in values:
            continue
        match = re.fullmatch(pattern, values[name])
        if not match:
            problems.append('%s does not have the expected format' % name)
        elif name.startswith('ADMOB_'):
            if match.group(1) == TEST_PUBLISHER:
                problems.append("%s is one of Google's test IDs; a release needs this app's own ID" % name)
            publishers.add(match.group(1))
    if len(publishers) > 1:
        problems.append('the AdMob app ID and ad units belong to different publishers')
    if values.get('ADMOB_REWARDED_AD_UNIT_ID') and values.get('ADMOB_REWARDED_AD_UNIT_ID') == values.get('ADMOB_INTERSTITIAL_AD_UNIT_ID'):
        problems.append('the rewarded and interstitial ad units are the same')
    if problems:
        raise ServiceValueError('; '.join(problems))
    return values


def release_document(values):
    """앱이 읽는 주입 파일의 내용."""
    return {
        'admob_app_id': values['ADMOB_APP_ID'],
        'admob_rewarded_unit': values['ADMOB_REWARDED_AD_UNIT_ID'],
        'admob_interstitial_unit': values['ADMOB_INTERSTITIAL_AD_UNIT_ID'],
        'ga4_measurement_id': values['GA4_MEASUREMENT_ID'],
        'ga4_api_secret': values['GA4_MP_API_SECRET'],
        'remote_config_url': values['FA_REMOTE_CONFIG_URL'],
    }


def strip_app_id(text):
    """project.godot 글자에서 주입한 [admob] 절을 뺀다. 없으면 그대로 돌려준다."""
    pattern = re.compile(r'^\[%s\]\n(?:(?!\[).*\n?)*' % re.escape(ADMOB_SECTION), re.M)
    return pattern.sub('', text, count=1)


def has_app_id(text):
    """project.godot 글자에 [admob] 절이 있는지."""
    return re.search(r'^\[%s\]$' % re.escape(ADMOB_SECTION), text, re.M) is not None


def with_app_id(text, app_id, setting=ADMOB_SETTING):
    """project.godot 글자에 AdMob 앱 ID를 넣는다. Godot이 저장하는 자리(첫 절 앞)에 둔다."""
    text = strip_app_id(text)
    first = re.search(r'^\[', text, re.M)
    if first is None:
        raise ServiceValueError('project.godot has no sections')
    section = '[%s]\n\n%s="%s"\n\n' % (ADMOB_SECTION, setting, app_id)
    return text[:first.start()] + section + text[first.start():]


def inject(root, values, platform='android'):
    """값을 프로젝트에 쓴다."""
    if platform not in PLATFORM_ADMOB:
        raise ServiceValueError('unsupported platform: %s' % platform)
    setting = PLATFORM_ADMOB[platform][3]
    project = root / PROJECT_FILE
    patched = with_app_id(project.read_text(), values['ADMOB_APP_ID'], setting)
    release = root / RELEASE_FILE
    release.parent.mkdir(parents=True, exist_ok=True)
    release.touch(mode=0o600, exist_ok=True)
    release.chmod(0o600)
    release.write_text(json.dumps(release_document(values), indent=2) + '\n')
    project.write_text(patched)


def restore(root):
    """채운 것을 지운다. 지운 것이 있으면 True."""
    changed = False
    release = root / RELEASE_FILE
    if release.exists():
        release.unlink()
        changed = True
    if release.parent.is_dir() and not any(release.parent.iterdir()):
        release.parent.rmdir()
    project = root / PROJECT_FILE
    text = project.read_text()
    if has_app_id(text):
        project.write_text(strip_app_id(text))
        changed = True
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--restore', action='store_true', help='채운 값을 지운다')
    parser.add_argument('--platform', choices=sorted(PLATFORM_ADMOB), default='android', help='대상 플랫폼(android 또는 ios)')
    arguments = parser.parse_args()
    if arguments.restore:
        print('service values removed' if restore(ROOT) else 'no injected service values')
        return 0
    try:
        inject(ROOT, collect(os.environ, Path.home(), arguments.platform), arguments.platform)
    except ServiceValueError as error:
        print('service values not prepared: %s. Values are never printed.' % error, file=sys.stderr)
        return 1
    print('service values prepared: %s and the [admob] section of %s' % (RELEASE_FILE, PROJECT_FILE))
    return 0


if __name__ == '__main__':
    sys.exit(main())
