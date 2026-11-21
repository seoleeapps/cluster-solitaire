#!/usr/bin/env python3
"""릴리스 AAB가 출시할 수 있는 내용인지 결과물을 다시 읽어 검사한다.

    python3 tools/check_aab.py [build/android/four-alike.aab]

확인하는 것:
  - 패키지 이름과 버전이 저장소의 설정(product.json, Android preset, project.godot)과 같다
  - 서명이 온전하고 서명 인증서의 SHA-256이 Google Play에 등록한 업로드 키와 같다
  - 매니페스트에 INTERNET, 광고 ID, VIBRATE 권한이 있고 세로 고정이며 디버그 빌드가 아니다
  - 대상 SDK가 Google Play의 요구 이상이다
  - AdMob 플러그인의 네이티브 싱글턴이 등록돼 있고, AdMob 앱 ID가 매니페스트에 있으며 테스트 ID가 아니다
  - 앱이 읽는 서비스 값(release.json)이 들어 있고, 광고 단위가 테스트 단위가 아니며 앱 ID와 같은 게시자다
  - 적응형 아이콘이 전경, 배경, 단색 층을 가리키고 그 그림들이 들어 있다
  - arm64 라이브러리만 들어 있고 테스트 파일이 없으며 크기가 예산 안이다

매니페스트는 bundletool로, 서명은 JDK의 jarsigner와 keytool로 읽는다. 하나라도 없으면 검사하지 못한 것으로 실패한다.
BUNDLETOOL과 JAVA_HOME으로 위치를 바꿀 수 있다. 식별자와 비밀값은 출력하지 않는다.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree

import check_native
import prepare_services

ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'
# Google Play에 등록한 업로드 키의 인증서(기술 제작 계획의 "백엔드와 보안 경계").
UPLOAD_CERTIFICATE_SHA256 = 'C0:18:B0:2A:93:02:19:8A:15:0B:75:E8:1D:7A:2A:86:E1:D4:48:82:7B:F9:BC:C7:01:6C:EB:A4:A3:A2:3C:9F'
# 2026-08-31부터 새 앱과 업데이트는 Android 16(API 36) 이상을 대상으로 해야 한다.
# https://support.google.com/googleplay/android-developer/answer/11926878
PLAY_MIN_TARGET_SDK = 36
REQUIRED_PERMISSIONS = [
    'android.permission.INTERNET',
    'com.google.android.gms.permission.AD_ID',
    'android.permission.VIBRATE',
]
ADMOB_APP_ID_KEY = 'com.google.android.gms.ads.APPLICATION_ID'
# Godot이 등록하는 Android 플러그인의 매니페스트 표식. 이름은 godot/game/adapters/fa_admob_sdk.gd의 SINGLETONS와 같다.
PLUGIN_KEY_PREFIX = 'org.godotengine.plugin.v2.'
ADMOB_SINGLETONS = [
    'PoingGodotAdMob', 'PoingGodotAdMobRewardedAd', 'PoingGodotAdMobInterstitialAd',
    'PoingGodotAdMobConsentInformation', 'PoingGodotAdMobUserMessagingPlatform',
]
LAUNCH_ACTIVITY = 'com.godot.game.GodotApp'
# android:screenOrientation의 portrait.
PORTRAIT = '1'
# Godot의 Gradle AAB는 프로젝트 파일을 설치 시점 자산 팩에 넣는다.
ASSETS = 'assetPackInstallTime/assets/'
RELEASE_VALUES = ASSETS + 'data/services/release.json'
ADAPTIVE_ICON = 'base/res/mipmap-anydpi-v26/icon.xml'
ICON_LAYERS = ['icon_foreground', 'icon_background', 'icon_monochrome']
LIBRARY_PREFIX = 'base/lib/'
EXPECTED_ABIS = {'arm64-v8a'}
# 성능 예산의 AAB 크기 상한(기술 제작 계획).
MAX_BYTES = 60 * 1024 * 1024


class ToolMissing(Exception):
    pass


def tool(name, env_name=None):
    """실행할 도구의 경로. JDK 도구는 JAVA_HOME 아래를 먼저 본다."""
    if env_name and os.environ.get(env_name):
        return os.environ[env_name]
    if name in ('keytool', 'jarsigner') and os.environ.get('JAVA_HOME'):
        candidate = Path(os.environ['JAVA_HOME']) / 'bin' / name
        if candidate.is_file():
            return str(candidate)
    found = shutil.which(name)
    if not found:
        raise ToolMissing(name + ' is required to read the bundle but was not found')
    return found


def dump_manifest(bundle):
    """bundletool로 읽은 매니페스트 XML."""
    done = subprocess.run([tool('bundletool', 'BUNDLETOOL'), 'dump', 'manifest', '--bundle=' + str(bundle)],
                          capture_output=True, text=True, timeout=120)
    if done.returncode:
        raise ToolMissing('bundletool could not read the manifest')
    return done.stdout


def parse_fingerprints(text):
    """keytool 출력에서 인증서들의 SHA-256(대문자, 쌍점 구분)을 뽑는다."""
    return re.findall(r'SHA-?256:\s*((?:[0-9A-F]{2}:){31}[0-9A-F]{2})', text.upper())


def signer_fingerprints(bundle):
    """서명 인증서들의 SHA-256. keytool은 인증서를 찍은 뒤에도 기본 키 저장소가 없으면 오류로 끝나므로 종료 코드는 보지 않는다."""
    done = subprocess.run([tool('keytool'), '-printcert', '-jarfile', str(bundle)], capture_output=True, text=True, timeout=120)
    return parse_fingerprints(done.stdout)


def signature_intact(bundle):
    """jarsigner가 모든 항목의 서명을 확인했는지."""
    done = subprocess.run([tool('jarsigner'), '-verify', str(bundle)], capture_output=True, text=True, timeout=300)
    return done.returncode == 0 and 'jar verified' in done.stdout


def read_manifest(xml):
    """매니페스트에서 검사에 쓰는 값만 뽑는다."""
    root = ElementTree.fromstring(xml)
    application = root.find('application')
    uses_sdk = root.find('uses-sdk')
    metadata, orientation = {}, None
    if application is not None:
        for item in application.iter('meta-data'):
            metadata[item.get(ANDROID + 'name')] = item.get(ANDROID + 'value')
        for activity in application.findall('activity'):
            if activity.get(ANDROID + 'name') == LAUNCH_ACTIVITY:
                orientation = activity.get(ANDROID + 'screenOrientation')
    return {
        'package': root.get('package'),
        'versionCode': root.get(ANDROID + 'versionCode'),
        'versionName': root.get(ANDROID + 'versionName'),
        'permissions': sorted({item.get(ANDROID + 'name') for item in root.findall('uses-permission')}),
        'targetSdk': int(uses_sdk.get(ANDROID + 'targetSdkVersion', '0')) if uses_sdk is not None else 0,
        'minSdk': int(uses_sdk.get(ANDROID + 'minSdkVersion', '0')) if uses_sdk is not None else 0,
        'debuggable': application is not None and application.get(ANDROID + 'debuggable') == 'true',
        'orientation': orientation,
        'metadata': metadata,
    }


def expected_identity(root):
    """저장소의 설정이 말하는 패키지와 버전."""
    presets = check_native.load_presets(root)
    base = next(section for section in presets.sections()
                if not section.endswith('.options') and check_native.value(presets, section, 'name') == 'Android')
    options = base + '.options'
    project = check_native.load_project(root)
    return {
        'package': json.loads((root / 'godot/config/product.json').read_text())['id'],
        'versionCode': str(check_native.value(presets, options, 'version/code')),
        'versionName': check_native.value(presets, options, 'version/name'),
        'projectVersion': check_native.project_value(project, 'application', 'config/version'),
    }


def check_manifest(manifest, expected):
    """매니페스트의 문제 목록. expected는 expected_identity의 값이다."""
    errors = []
    if manifest['package'] != expected['package']:
        errors.append('Package is %s, expected %s' % (manifest['package'], expected['package']))
    if manifest['versionCode'] != expected['versionCode'] or manifest['versionName'] != expected['versionName']:
        errors.append('Version is %s (%s), the Android preset says %s (%s)' % (
            manifest['versionName'], manifest['versionCode'], expected['versionName'], expected['versionCode']))
    if manifest['versionName'] != expected['projectVersion']:
        # 앱이 화면과 분석의 release_version에 쓰는 값은 project.godot의 application/config/version이다.
        errors.append('Version name %s differs from application/config/version %s' % (manifest['versionName'], expected['projectVersion']))
    for permission in REQUIRED_PERMISSIONS:
        if permission not in manifest['permissions']:
            errors.append('Missing permission: ' + permission)
    if manifest['targetSdk'] < PLAY_MIN_TARGET_SDK:
        errors.append('Target SDK %d is below the Google Play requirement %d' % (manifest['targetSdk'], PLAY_MIN_TARGET_SDK))
    if manifest['debuggable']:
        errors.append('The bundle is debuggable')
    if manifest['orientation'] != PORTRAIT:
        errors.append('The game activity is not locked to portrait')
    missing = [name for name in ADMOB_SINGLETONS if PLUGIN_KEY_PREFIX + name not in manifest['metadata']]
    if missing:
        errors.append('The AdMob Android plugin is not in the build: ' + ', '.join(missing))
    return errors


def publisher(value, pattern):
    """AdMob ID의 게시자 번호. 형식이 틀리면 None."""
    match = re.fullmatch(pattern, value) if isinstance(value, str) else None
    return match.group(1) if match else None


def check_values(manifest, release_text):
    """AdMob 앱 ID와 앱이 읽는 서비스 값의 문제 목록."""
    errors = []
    app_publisher = publisher(manifest['metadata'].get(ADMOB_APP_ID_KEY), prepare_services.PATTERNS['ADMOB_APP_ID'])
    if app_publisher is None:
        errors.append('The manifest has no valid AdMob app ID')
    elif app_publisher == prepare_services.TEST_PUBLISHER:
        errors.append("The manifest carries Google's test AdMob app ID")
    if release_text is None:
        return errors + ['The bundle has no injected service values (%s)' % RELEASE_VALUES]
    try:
        release = json.loads(release_text)
    except ValueError:
        return errors + ['The injected service values are not valid JSON']
    if not isinstance(release, dict):
        return errors + ['The injected service values are not an object']
    publishers = {app_publisher}
    for key, source in [('admob_rewarded_unit', 'ADMOB_REWARDED_AD_UNIT_ID'), ('admob_interstitial_unit', 'ADMOB_INTERSTITIAL_AD_UNIT_ID')]:
        unit_publisher = publisher(release.get(key), prepare_services.PATTERNS[source])
        if unit_publisher is None:
            errors.append('The injected %s is missing or malformed' % key)
        elif unit_publisher == prepare_services.TEST_PUBLISHER:
            errors.append("The injected %s is one of Google's test ad units" % key)
        publishers.add(unit_publisher)
    if not errors and len(publishers) != 1:
        errors.append('The AdMob app ID and the ad units belong to different publishers')
    if release.get('admob_rewarded_unit') and release.get('admob_rewarded_unit') == release.get('admob_interstitial_unit'):
        errors.append('The rewarded and interstitial ad units are the same')
    if publisher(release.get('admob_app_id'), prepare_services.PATTERNS['ADMOB_APP_ID']) != app_publisher \
            or release.get('admob_app_id') != manifest['metadata'].get(ADMOB_APP_ID_KEY):
        errors.append('The injected AdMob app ID differs from the manifest')
    for key, source in [('ga4_measurement_id', 'GA4_MEASUREMENT_ID'), ('ga4_api_secret', 'GA4_MP_API_SECRET'), ('remote_config_url', 'FA_REMOTE_CONFIG_URL')]:
        if not isinstance(release.get(key), str) or not re.fullmatch(prepare_services.PATTERNS[source], release[key]):
            errors.append('The injected %s is missing or malformed' % key)
    return errors


def check_contents(names, adaptive_icon=b''):
    """AAB 안의 파일 이름과 적응형 아이콘 정의로 보는 문제 목록과 요약."""
    errors = []
    abis = {name[len(LIBRARY_PREFIX):].split('/')[0] for name in names if name.startswith(LIBRARY_PREFIX)}
    if abis != EXPECTED_ABIS:
        errors.append('Native libraries must be exactly %s, found %s' % (sorted(EXPECTED_ABIS), sorted(abis)))
    if ADAPTIVE_ICON not in names:
        errors.append('The adaptive launcher icon is missing (%s)' % ADAPTIVE_ICON)
    layers = {}
    for layer in ICON_LAYERS:
        layers[layer] = sum(1 for name in names if re.fullmatch(r'base/res/mipmap[a-z0-9-]*/%s\.(?:png|webp)' % layer, name))
        if not layers[layer]:
            errors.append('The launcher icon layer is missing: ' + layer)
        elif ADAPTIVE_ICON in names and ('@mipmap/' + layer).encode() not in adaptive_icon:
            errors.append('The adaptive launcher icon does not use the layer: ' + layer)
    if ADAPTIVE_ICON in names and b'adaptive-icon' not in adaptive_icon:
        errors.append('The launcher icon is not an adaptive icon')
    tests = [name for name in names if name.startswith(ASSETS + 'tests/')]
    if tests:
        errors.append('Test files were exported: %d files under assets/tests' % len(tests))
    return errors, {'abis': sorted(abis), 'iconLayers': layers}


def check(root, bundle):
    """AAB를 검사해 (문제 목록, 요약)을 돌려준다. 요약에는 식별자와 비밀값을 넣지 않는다."""
    bundle = Path(bundle)
    if not bundle.is_file():
        return ['Bundle not found: ' + bundle.name], {}
    errors = []
    try:
        manifest = read_manifest(dump_manifest(bundle))
        fingerprints = signer_fingerprints(bundle)
        intact = signature_intact(bundle)
    except ToolMissing as error:
        return [str(error)], {}
    except ElementTree.ParseError:
        return ['The manifest could not be parsed'], {}
    errors += check_manifest(manifest, expected_identity(root))
    if not intact:
        errors.append('The bundle signature could not be verified')
    if fingerprints != [UPLOAD_CERTIFICATE_SHA256]:
        errors.append('The bundle is not signed by the registered upload key alone (%d signer certificates)' % len(fingerprints))
    with zipfile.ZipFile(bundle) as archive:
        names = set(archive.namelist())
        release_text = archive.read(RELEASE_VALUES).decode('utf-8', 'replace') if RELEASE_VALUES in names else None
        adaptive_icon = archive.read(ADAPTIVE_ICON) if ADAPTIVE_ICON in names else b''
    errors += check_values(manifest, release_text)
    content_errors, contents = check_contents(names, adaptive_icon)
    errors += content_errors
    size = bundle.stat().st_size
    if size > MAX_BYTES:
        errors.append('The bundle is %d bytes, over the %d byte budget' % (size, MAX_BYTES))
    summary = {
        'bundle': bundle.name,
        'bytes': size,
        'package': manifest['package'],
        'versionCode': manifest['versionCode'],
        'versionName': manifest['versionName'],
        'minSdk': manifest['minSdk'],
        'targetSdk': manifest['targetSdk'],
        'signerSha256': fingerprints,
        'signatureVerified': intact,
        'signedByUploadKey': fingerprints == [UPLOAD_CERTIFICATE_SHA256],
        'portrait': manifest['orientation'] == PORTRAIT,
        'admobPlugin': all(PLUGIN_KEY_PREFIX + name in manifest['metadata'] for name in ADMOB_SINGLETONS),
        'permissions': manifest['permissions'],
        'admobAppId': 'app-specific' if not any('AdMob app ID' in error for error in errors) else 'invalid',
        'serviceValues': 'present' if release_text is not None else 'missing',
        **contents,
    }
    return errors, summary


def main():
    config = json.loads((ROOT / 'play-store/google-play.config.json').read_text())
    bundle = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / config['aabPath']
    errors, summary = check(ROOT, bundle)
    print(json.dumps({'ok': not errors, 'errors': errors, **summary}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
