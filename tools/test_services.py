"""서비스 값 주입, 원격 설정 검사, 릴리스 AAB 검사, 서명 값 읽기의 단위 테스트.

실제 자격증명과 빌드 결과물을 쓰지 않는다. 값은 테스트가 임시 폴더에 만든 가짜다.
"""
import http.server
import json
import os
import re
import shutil
import socketserver
import stat
import subprocess
import tempfile
import threading
import time
import unittest
from pathlib import Path

import check_aab
import check_ga4_payload
import check_remote_config
import export_native
import prepare_services

ROOT = Path(__file__).resolve().parents[1]
PUBLISHER = '1234567890123456'
ADMOB = {
    'ADMOB_APP_ID': 'ca-app-pub-%s~1111111111' % PUBLISHER,
    'ADMOB_REWARDED_AD_UNIT_ID': 'ca-app-pub-%s/2222222222' % PUBLISHER,
    'ADMOB_INTERSTITIAL_AD_UNIT_ID': 'ca-app-pub-%s/3333333333' % PUBLISHER,
}
ANALYTICS = {'GA4_MEASUREMENT_ID': 'G-TEST123456', 'GA4_MP_API_SECRET': 'unit_test_secret_value'}
TEST_APP_ID = 'ca-app-pub-3940256099942544~3347511713'
TEST_REWARDED = 'ca-app-pub-3940256099942544/5224354917'


def write_env(path, values, exported=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(''.join('%s%s="%s"\n' % ('export ' if exported else '', key, value) for key, value in values.items()))


class Home:
    """가짜 자격증명 폴더. 기본 위치에 두 파일을 만든다."""

    def __init__(self, folder, admob=ADMOB, analytics=ANALYTICS):
        self.path = Path(folder)
        if admob is not None:
            write_env(self.path / '.config/seorilabs/admob/four-alike/public-identifiers.env', admob)
        if analytics is not None:
            write_env(self.path / '.config/seorilabs/analytics-four-alike.env', analytics, exported=True)


class PrepareServicesTests(unittest.TestCase):
    def collect(self, home, environ=None):
        return prepare_services.collect(environ or {}, home.path)

    def test_values_come_from_the_default_credential_files(self):
        with tempfile.TemporaryDirectory() as folder:
            values = self.collect(Home(folder))
            self.assertEqual({**ADMOB, **ANALYTICS, 'FA_REMOTE_CONFIG_URL': prepare_services.DEFAULT_REMOTE_CONFIG_URL}, values)
            self.assertEqual('https://seoleeapps.github.io/cluster-solitaire/config.json', values['FA_REMOTE_CONFIG_URL'])

    def test_paths_and_values_can_be_overridden_by_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Home(folder, admob=None, analytics=None)
            write_env(home.path / 'elsewhere/admob.env', ADMOB)
            environ = {'FA_ADMOB_ENV': str(home.path / 'elsewhere/admob.env'), **ANALYTICS,
                       'FA_REMOTE_CONFIG_URL': 'https://example.com/other/config.json'}
            values = self.collect(home, environ)
            self.assertEqual(ADMOB['ADMOB_APP_ID'], values['ADMOB_APP_ID'])
            self.assertEqual(ANALYTICS['GA4_MP_API_SECRET'], values['GA4_MP_API_SECRET'])
            self.assertEqual('https://example.com/other/config.json', values['FA_REMOTE_CONFIG_URL'])
            override = {**environ, 'ADMOB_APP_ID': 'ca-app-pub-%s~9999999999' % PUBLISHER}
            self.assertEqual(override['ADMOB_APP_ID'], self.collect(home, override)['ADMOB_APP_ID'])

    def assert_rejected(self, home, expected, environ=None):
        with self.assertRaises(prepare_services.ServiceValueError) as raised:
            self.collect(home, environ)
        message = str(raised.exception)
        self.assertIn(expected, message)
        for value in [*ADMOB.values(), *ANALYTICS.values(), str(home.path)]:
            self.assertNotIn(value, message, 'errors must not echo values or local paths')
        return message

    def test_missing_credential_files_stop_with_a_clear_error(self):
        with tempfile.TemporaryDirectory() as folder:
            message = self.assert_rejected(Home(folder, admob=None), 'credential file not found: ~/.config/seorilabs/admob/four-alike/public-identifiers.env')
            self.assertIn('ADMOB_APP_ID', message)
            self.assert_rejected(Home(folder + '/b', analytics=None), 'credential file not found: ~/.config/seorilabs/analytics-four-alike.env')
            environ = {'FA_ADMOB_ENV': folder + '/nowhere.env'}
            self.assert_rejected(Home(folder + '/c'), 'credential file not found: $FA_ADMOB_ENV', environ)

    def test_missing_and_malformed_values_are_rejected_without_echo(self):
        cases = [
            ({**ADMOB, 'ADMOB_REWARDED_AD_UNIT_ID': ''}, ANALYTICS, 'ADMOB_REWARDED_AD_UNIT_ID is missing'),
            ({**ADMOB, 'ADMOB_APP_ID': 'ca-app-pub-123~456'}, ANALYTICS, 'ADMOB_APP_ID does not have the expected format'),
            ({**ADMOB, 'ADMOB_APP_ID': ADMOB['ADMOB_REWARDED_AD_UNIT_ID']}, ANALYTICS, 'ADMOB_APP_ID does not have the expected format'),
            (ADMOB, {**ANALYTICS, 'GA4_MEASUREMENT_ID': 'UA-12345-1'}, 'GA4_MEASUREMENT_ID does not have the expected format'),
            (ADMOB, {**ANALYTICS, 'GA4_MP_API_SECRET': 'short'}, 'GA4_MP_API_SECRET does not have the expected format'),
            (ADMOB, {'GA4_MEASUREMENT_ID': ANALYTICS['GA4_MEASUREMENT_ID']}, 'GA4_MP_API_SECRET is missing'),
        ]
        for index, (admob, analytics, expected) in enumerate(cases):
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as folder:
                with self.assertRaises(prepare_services.ServiceValueError) as raised:
                    self.collect(Home(folder, admob, analytics))
                self.assertIn(expected, str(raised.exception))
                self.assertNotIn(str(folder), str(raised.exception))
                for value in [*admob.values(), *analytics.values()]:
                    if value:
                        self.assertNotIn(value, str(raised.exception))
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(prepare_services.ServiceValueError) as raised:
                self.collect(Home(folder), {'FA_REMOTE_CONFIG_URL': 'http://example.com/config.json'})
            self.assertIn('FA_REMOTE_CONFIG_URL does not have the expected format', str(raised.exception))

    def test_test_ads_and_inconsistent_units_are_rejected(self):
        cases = [
            ({**ADMOB, 'ADMOB_APP_ID': TEST_APP_ID}, "ADMOB_APP_ID is one of Google's test IDs"),
            ({**ADMOB, 'ADMOB_REWARDED_AD_UNIT_ID': TEST_REWARDED}, "ADMOB_REWARDED_AD_UNIT_ID is one of Google's test IDs"),
            ({**ADMOB, 'ADMOB_INTERSTITIAL_AD_UNIT_ID': 'ca-app-pub-6543210987654321/3333333333'}, 'belong to different publishers'),
            ({**ADMOB, 'ADMOB_INTERSTITIAL_AD_UNIT_ID': ADMOB['ADMOB_REWARDED_AD_UNIT_ID']}, 'the rewarded and interstitial ad units are the same'),
        ]
        for admob, expected in cases:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as folder:
                with self.assertRaises(prepare_services.ServiceValueError) as raised:
                    self.collect(Home(folder, admob))
                self.assertIn(expected, str(raised.exception))

    def project_copy(self, folder):
        root = Path(folder) / 'repo'
        (root / 'godot').mkdir(parents=True)
        shutil.copyfile(ROOT / prepare_services.PROJECT_FILE, root / prepare_services.PROJECT_FILE)
        return root

    def test_inject_then_restore_leaves_the_project_untouched(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.project_copy(folder)
            original = (root / prepare_services.PROJECT_FILE).read_text()
            self.assertFalse(prepare_services.has_app_id(original), 'the tracked project must not carry an app ID')
            values = self.collect(Home(folder + '/home'))
            prepare_services.inject(root, values)
            release = root / prepare_services.RELEASE_FILE
            document = json.loads(release.read_text())
            self.assertEqual({
                'admob_app_id': ADMOB['ADMOB_APP_ID'], 'admob_rewarded_unit': ADMOB['ADMOB_REWARDED_AD_UNIT_ID'],
                'admob_interstitial_unit': ADMOB['ADMOB_INTERSTITIAL_AD_UNIT_ID'],
                'ga4_measurement_id': ANALYTICS['GA4_MEASUREMENT_ID'], 'ga4_api_secret': ANALYTICS['GA4_MP_API_SECRET'],
                'remote_config_url': prepare_services.DEFAULT_REMOTE_CONFIG_URL,
            }, document)
            self.assertEqual(0o600, stat.S_IMODE(release.stat().st_mode))
            injected = (root / prepare_services.PROJECT_FILE).read_text()
            self.assertIn('[admob]\n\ngeneral/android/app_id="%s"\n\n[application]' % ADMOB['ADMOB_APP_ID'], injected)
            self.assertLess(injected.index('[admob]'), injected.index('[application]'))
            prepare_services.inject(root, values)
            self.assertEqual(injected, (root / prepare_services.PROJECT_FILE).read_text(), 'injecting twice must not add a second section')
            self.assertTrue(prepare_services.restore(root))
            self.assertEqual(original, (root / prepare_services.PROJECT_FILE).read_text())
            self.assertFalse(release.exists())
            self.assertFalse(release.parent.exists())
            self.assertFalse(prepare_services.restore(root), 'restoring twice changes nothing')

    def test_nothing_is_written_when_values_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.project_copy(folder)
            original = (root / prepare_services.PROJECT_FILE).read_text()
            with self.assertRaises(prepare_services.ServiceValueError):
                prepare_services.inject(root, self.collect(Home(folder + '/home', {**ADMOB, 'ADMOB_APP_ID': TEST_APP_ID})))
            self.assertEqual(original, (root / prepare_services.PROJECT_FILE).read_text())
            self.assertFalse((root / prepare_services.RELEASE_FILE).exists())

    def test_app_id_section_handling(self):
        text = 'config_version=5\n\n[application]\n\nconfig/name="X"\n\n[rendering]\n\nmethod="a"\n'
        injected = prepare_services.with_app_id(text, ADMOB['ADMOB_APP_ID'])
        self.assertTrue(prepare_services.has_app_id(injected))
        self.assertEqual(text, prepare_services.strip_app_id(injected))
        self.assertEqual(text, prepare_services.strip_app_id(text))
        # Godot이 저장하면서 같은 절에 다른 설정을 더해도 절 전체를 뺀다.
        saved = injected.replace('general/android/app_id', 'general/android/enabled=true\ngeneral/android/app_id')
        self.assertEqual(text, prepare_services.strip_app_id(saved))
        with self.assertRaises(prepare_services.ServiceValueError):
            prepare_services.with_app_id('config_version=5\n', ADMOB['ADMOB_APP_ID'])

    def test_formats_match_what_the_app_accepts(self):
        source = (ROOT / 'godot/game/adapters/fa_service_values.gd').read_text()
        app = dict(re.findall(r'^const (\w+_PATTERN) := "\^(.*)\$"$', source, re.M))
        tool = {name: pattern.replace('(', '').replace(')', '') for name, pattern in prepare_services.PATTERNS.items()}
        self.assertEqual(app['UNIT_PATTERN'], tool['ADMOB_REWARDED_AD_UNIT_ID'])
        self.assertEqual(app['UNIT_PATTERN'], tool['ADMOB_INTERSTITIAL_AD_UNIT_ID'])
        self.assertEqual(app['MEASUREMENT_PATTERN'], tool['GA4_MEASUREMENT_ID'])
        self.assertEqual(app['SECRET_PATTERN'], tool['GA4_MP_API_SECRET'])
        self.assertEqual(app['URL_PATTERN'], tool['FA_REMOTE_CONFIG_URL'])
        test_units = re.findall(r'"(ca-app-pub-\d{16}/\d{10})"', source)
        self.assertEqual(2, len(test_units))
        for unit in test_units:
            self.assertIn(prepare_services.TEST_PUBLISHER, unit)
        keys = set(re.findall(r'document\.get\("(\w+)"\)', source)) | set(re.findall(r'"(admob_\w+_unit)"', source))
        self.assertEqual(set(prepare_services.release_document({**ADMOB, **ANALYTICS, 'FA_REMOTE_CONFIG_URL': 'x'})) - {'admob_app_id'}, keys)


class RemoteConfigTests(unittest.TestCase):
    def setUp(self):
        self.profile = json.loads((ROOT / check_remote_config.PROFILE).read_text())
        self.rules, self.profile_errors = check_remote_config.rules_from(self.profile)
        self.defaults = {key: rule['default'] for key, rule in self.rules.items()}

    def test_repository_config_passes_and_equals_the_profile_defaults(self):
        errors, summary = check_remote_config.check(ROOT)
        self.assertEqual([], errors)
        self.assertEqual([], self.profile_errors)
        document = json.loads((ROOT / check_remote_config.CONFIG).read_text())
        self.assertEqual(self.defaults, document['values'])
        self.assertEqual({'version': 1, 'keys': 18, 'profileKeys': 18, 'omitted': [], 'changedFromDefault': []}, summary)

    def errors_for(self, values, version=1, extra=None):
        return check_remote_config.check_document({'version': version, 'values': values, **(extra or {})}, self.rules)

    def test_values_outside_the_profile_are_rejected(self):
        self.assertEqual([], self.errors_for(self.defaults))
        self.assertEqual([], self.errors_for({}), 'omitted keys fall back to the built-in defaults')
        self.assertEqual([], self.errors_for({'rewarded_booster_cooldown_s': 0, 'interstitial_min_stages_between': 6.0}))
        cases = [
            ({'rewarded_booster_cooldown_s': 601}, 'rewarded_booster_cooldown_s must be between 0 and 600'),
            ({'interstitial_min_play_seconds': 60}, 'interstitial_min_play_seconds must be between 180 and 1800'),
            ({'rewarded_booster_daily_cap': -1}, 'rewarded_booster_daily_cap must be between 0 and 10'),
            ({'rewarded_booster_cooldown_s': '30'}, 'rewarded_booster_cooldown_s must be an integer'),
            ({'rewarded_booster_cooldown_s': 30.5}, 'rewarded_booster_cooldown_s must be an integer'),
            ({'rewarded_booster_cooldown_s': True}, 'rewarded_booster_cooldown_s must be an integer'),
            ({'rewarded_booster_enabled': 1}, 'rewarded_booster_enabled must be true or false'),
            ({'rewarded_booster_enabled': 'true'}, 'rewarded_booster_enabled must be true or false'),
            ({'rewarded_boster_enabled': True}, 'rewarded_boster_enabled is not a remote_config key of the profile'),
        ]
        for values, expected in cases:
            with self.subTest(expected=expected):
                self.assertEqual(['config: ' + expected], self.errors_for(values))

    def test_malformed_documents_are_rejected(self):
        for version in [0, -1, '1', 1.5, True, None]:
            with self.subTest(version=version):
                self.assertIn('config: version must be an integer of 1 or more', self.errors_for({}, version))
        self.assertIn('config: unexpected top-level keys: comment', self.errors_for({}, extra={'comment': 'x'}))
        self.assertEqual(['config: must be a JSON object'], check_remote_config.check_document([], self.rules))
        self.assertIn('config: values must be an object', check_remote_config.check_document({'version': 1, 'values': []}, self.rules))

    def test_broken_files_and_profiles_are_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'godot/data/monetization').mkdir(parents=True)
            (root / 'remote').mkdir()
            shutil.copyfile(ROOT / check_remote_config.PROFILE, root / check_remote_config.PROFILE)
            self.assertEqual(['config: cannot read remote/config.json: FileNotFoundError'], check_remote_config.check(root)[0])
            (root / check_remote_config.CONFIG).write_text('{broken')
            self.assertIn('config: cannot read remote/config.json: JSONDecodeError', check_remote_config.check(root)[0])
            padded = {'version': 1, 'values': dict(self.defaults)}
            (root / check_remote_config.CONFIG).write_text(json.dumps(padded) + ' ' * check_remote_config.MAX_BYTES)
            self.assertTrue(any('the app accepts less than' in error for error in check_remote_config.check(root)[0]))
            (root / check_remote_config.CONFIG).write_text(json.dumps({'version': 2, 'values': {'rewarded_booster_cooldown_s': 45}}))
            errors, summary = check_remote_config.check(root)
            self.assertEqual([], errors)
            self.assertEqual(['rewarded_booster_cooldown_s'], summary['changedFromDefault'])
            self.assertEqual(17, len(summary['omitted']))
            (root / check_remote_config.PROFILE).write_text('{broken')
            self.assertEqual(['profile: cannot read godot/data/monetization/bm-profile.json: JSONDecodeError'], check_remote_config.check(root)[0])
        broken = {'remote_config': [
            {'key': 'a', 'type': 'text', 'default': 'x'}, {'key': 'b', 'type': 'bool', 'default': 1},
            {'key': 'c', 'type': 'int', 'default': 5, 'range': {}}, {'key': 'd', 'type': 'int', 'default': 9, 'range': {'min': 0, 'max': 5}},
        ]}
        self.assertEqual([
            "profile: unsupported remote_config entry: 'a'", 'profile: b default must be true or false',
            'profile: c needs an integer range', 'profile: d default is outside its range',
        ], check_remote_config.rules_from(broken)[1])
        self.assertEqual(['profile: remote_config is empty'], check_remote_config.rules_from({})[1])

    def test_size_limit_matches_the_app(self):
        source = (ROOT / 'godot/game/adapters/fa_remote_config.gd').read_text()
        self.assertIn('const MAX_BYTES := 16 * 1024', source)
        self.assertEqual(16 * 1024, check_remote_config.MAX_BYTES)

    def test_pages_workflow_deploys_only_the_config_folder_with_minimal_permissions(self):
        text = (ROOT / '.github/workflows/deploy-remote-config.yml').read_text()
        self.assertRegex(text, r"(?m)^  push:\n    branches: \[main\]\n    paths:\n      - 'remote/\*\*'$")
        self.assertIn('workflow_dispatch:', text)
        self.assertRegex(text, r'(?m)^permissions:\n  contents: read\n\n')
        self.assertEqual(1, text.count('pages: write'))
        self.assertEqual(1, text.count('id-token: write'))
        self.assertIn('python3 tools/check_remote_config.py', text)
        self.assertRegex(text, r'(?m)^          path: remote$')
        for action in ['actions/checkout', 'actions/upload-pages-artifact', 'actions/deploy-pages']:
            self.assertRegex(text, r'uses: %s@[0-9a-f]{40} # v\d' % re.escape(action))
        self.assertEqual(3, len(re.findall(r'(?m)^\s+uses: ', text)), 'only the three official actions are used')
        url = prepare_services.DEFAULT_REMOTE_CONFIG_URL
        self.assertIn(url, text)
        self.assertTrue(url.endswith('/' + Path(check_remote_config.CONFIG).name))


MANIFEST = '''<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:versionCode="7" android:versionName="1.2.3" package="com.seoleeapps.fouralike">
  <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
  <uses-permission android:name="android.permission.INTERNET"/>
  <application android:label="@string/godot_project_name_string">
    <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>
    <activity android:name="com.godot.game.GodotApp" android:screenOrientation="1"/>
    <activity android:name="com.google.android.libraries.ads.mobile.sdk.common.AdActivity"/>
    <meta-data android:name="org.godotengine.plugin.v2.PoingGodotAdMob" android:value="a"/>
    <meta-data android:name="org.godotengine.plugin.v2.PoingGodotAdMobRewardedAd" android:value="b"/>
    <meta-data android:name="org.godotengine.plugin.v2.PoingGodotAdMobInterstitialAd" android:value="c"/>
    <meta-data android:name="org.godotengine.plugin.v2.PoingGodotAdMobConsentInformation" android:value="d"/>
    <meta-data android:name="org.godotengine.plugin.v2.PoingGodotAdMobUserMessagingPlatform" android:value="e"/>
  </application>
</manifest>'''
ADAPTIVE_ICON_BYTES = b'adaptive-icon background @mipmap/icon_background foreground @mipmap/icon_foreground monochrome @mipmap/icon_monochrome'


class BundleCheckTests(unittest.TestCase):
    def manifest(self, app_id=ADMOB['ADMOB_APP_ID']):
        return check_aab.read_manifest(MANIFEST % app_id)

    def release(self, **changes):
        document = prepare_services.release_document({**ADMOB, **ANALYTICS, 'FA_REMOTE_CONFIG_URL': prepare_services.DEFAULT_REMOTE_CONFIG_URL})
        document.update(changes)
        return json.dumps({key: value for key, value in document.items() if value is not None})

    def test_manifest_fields_are_read(self):
        manifest = self.manifest()
        self.assertEqual('com.seoleeapps.fouralike', manifest['package'])
        self.assertEqual(('7', '1.2.3', 26, 36), (manifest['versionCode'], manifest['versionName'], manifest['minSdk'], manifest['targetSdk']))
        self.assertEqual(['android.permission.INTERNET', 'android.permission.VIBRATE', 'com.google.android.gms.permission.AD_ID'], manifest['permissions'])
        self.assertFalse(manifest['debuggable'])
        self.assertEqual(ADMOB['ADMOB_APP_ID'], manifest['metadata'][check_aab.ADMOB_APP_ID_KEY])
        self.assertEqual('1', manifest['orientation'])
        debuggable = check_aab.read_manifest((MANIFEST % 'x').replace('<application ', '<application android:debuggable="true" '))
        self.assertTrue(debuggable['debuggable'])

    def test_complete_service_values_pass(self):
        self.assertEqual([], check_aab.check_values(self.manifest(), self.release()))

    def test_missing_or_test_values_fail_the_release(self):
        cases = [
            (self.manifest(), None, 'The bundle has no injected service values'),
            (self.manifest(), '{broken', 'The injected service values are not valid JSON'),
            (self.manifest(), '[]', 'The injected service values are not an object'),
            (self.manifest(TEST_APP_ID), self.release(admob_app_id=TEST_APP_ID), "The manifest carries Google's test AdMob app ID"),
            (self.manifest(''), self.release(), 'The manifest has no valid AdMob app ID'),
            (self.manifest(), self.release(admob_rewarded_unit=TEST_REWARDED), "The injected admob_rewarded_unit is one of Google's test ad units"),
            (self.manifest(), self.release(admob_interstitial_unit=None), 'The injected admob_interstitial_unit is missing or malformed'),
            (self.manifest(), self.release(admob_interstitial_unit='ca-app-pub-6543210987654321/3333333333'), 'The AdMob app ID and the ad units belong to different publishers'),
            (self.manifest(), self.release(admob_interstitial_unit=ADMOB['ADMOB_REWARDED_AD_UNIT_ID']), 'The rewarded and interstitial ad units are the same'),
            (self.manifest(), self.release(admob_app_id='ca-app-pub-%s~9999999999' % PUBLISHER), 'The injected AdMob app ID differs from the manifest'),
            (self.manifest(), self.release(ga4_measurement_id=None), 'The injected ga4_measurement_id is missing or malformed'),
            (self.manifest(), self.release(ga4_api_secret=''), 'The injected ga4_api_secret is missing or malformed'),
            (self.manifest(), self.release(remote_config_url='http://example.com/x.json'), 'The injected remote_config_url is missing or malformed'),
        ]
        for manifest, release, expected in cases:
            with self.subTest(expected=expected):
                errors = check_aab.check_values(manifest, release)
                self.assertTrue(any(expected in error for error in errors), errors)
                for value in [*ADMOB.values(), *ANALYTICS.values()]:
                    self.assertNotIn(value, ' '.join(errors), 'errors must not echo identifiers or secrets')

    def test_manifest_requirements(self):
        expected = {'package': 'com.seoleeapps.fouralike', 'versionCode': '7', 'versionName': '1.2.3', 'projectVersion': '1.2.3'}
        self.assertEqual([], check_aab.check_manifest(self.manifest(), expected))
        text = MANIFEST % ADMOB['ADMOB_APP_ID']
        cases = [
            (text, {**expected, 'package': 'com.other.app'}, 'Package is com.seoleeapps.fouralike, expected com.other.app'),
            (text, {**expected, 'versionCode': '8'}, 'Version is 1.2.3 (7), the Android preset says 1.2.3 (8)'),
            (text, {**expected, 'projectVersion': '1.2.4'}, 'Version name 1.2.3 differs from application/config/version 1.2.4'),
            (text.replace('android.permission.VIBRATE', 'android.permission.CAMERA'), expected, 'Missing permission: android.permission.VIBRATE'),
            (text.replace('com.google.android.gms.permission.AD_ID', 'android.permission.AD_ID'), expected, 'Missing permission: com.google.android.gms.permission.AD_ID'),
            (text.replace('android:targetSdkVersion="36"', 'android:targetSdkVersion="35"'), expected, 'Target SDK 35 is below the Google Play requirement 36'),
            (text.replace('<application ', '<application android:debuggable="true" '), expected, 'The bundle is debuggable'),
            (text.replace('android:screenOrientation="1"', 'android:screenOrientation="0"'), expected, 'The game activity is not locked to portrait'),
            (text.replace(' android:screenOrientation="1"', ''), expected, 'The game activity is not locked to portrait'),
            (text.replace('PoingGodotAdMobUserMessagingPlatform', 'Other'), expected, 'The AdMob Android plugin is not in the build: PoingGodotAdMobUserMessagingPlatform'),
        ]
        for xml, identity, message in cases:
            with self.subTest(message=message):
                self.assertEqual([message], check_aab.check_manifest(check_aab.read_manifest(xml), identity))
        source = (ROOT / 'godot/game/adapters/fa_admob_sdk.gd').read_text()
        declared = re.search(r'const SINGLETONS: Array\[String\] = \[(.*?)\]', source, re.S).group(1)
        self.assertEqual(check_aab.ADMOB_SINGLETONS, re.findall(r'"(\w+)"', declared), 'the build check and the adapter must look for the same singletons')

    def test_bundle_contents(self):
        names = {
            'base/manifest/AndroidManifest.xml', 'base/lib/arm64-v8a/libgodot_android.so', check_aab.ADAPTIVE_ICON,
            'base/res/mipmap-xxxhdpi-v4/icon_foreground.webp', 'base/res/mipmap-xxxhdpi-v4/icon_background.webp',
            'base/res/mipmap-xxxhdpi-v4/icon_monochrome.webp', 'base/res/mipmap/icon_monochrome.png',
            check_aab.RELEASE_VALUES, 'assetPackInstallTime/assets/game/adapters/fa_admob_ads.gdc',
        }
        errors, summary = check_aab.check_contents(names, ADAPTIVE_ICON_BYTES)
        self.assertEqual([], errors)
        self.assertEqual({'abis': ['arm64-v8a'], 'iconLayers': {'icon_foreground': 1, 'icon_background': 1, 'icon_monochrome': 2}}, summary)
        self.assertIn('The launcher icon layer is missing: icon_monochrome',
                      check_aab.check_contents({name for name in names if 'monochrome' not in name}, ADAPTIVE_ICON_BYTES)[0])
        self.assertIn('The adaptive launcher icon is missing (%s)' % check_aab.ADAPTIVE_ICON, check_aab.check_contents(names - {check_aab.ADAPTIVE_ICON})[0])
        self.assertIn('The adaptive launcher icon does not use the layer: icon_monochrome',
                      check_aab.check_contents(names, ADAPTIVE_ICON_BYTES.replace(b'@mipmap/icon_monochrome', b''))[0])
        self.assertIn('The launcher icon is not an adaptive icon', check_aab.check_contents(names, ADAPTIVE_ICON_BYTES.replace(b'adaptive-icon', b'bitmap'))[0])
        self.assertTrue(any('Native libraries must be exactly' in error for error in check_aab.check_contents(names | {'base/lib/x86_64/libgodot_android.so'}, ADAPTIVE_ICON_BYTES)[0]))
        self.assertTrue(any('Native libraries must be exactly' in error for error in check_aab.check_contents(names - {'base/lib/arm64-v8a/libgodot_android.so'}, ADAPTIVE_ICON_BYTES)[0]))
        self.assertIn('Test files were exported: 1 files under assets/tests',
                      check_aab.check_contents(names | {'assetPackInstallTime/assets/tests/game/x.gdc'}, ADAPTIVE_ICON_BYTES)[0])
        self.assertEqual([], check_aab.check_contents(names, ADAPTIVE_ICON_BYTES, b'\x02\x00\x00\x00--xr-mode\x03off')[0])
        self.assertEqual(['The bundle carries device-check command line arguments'],
                         check_aab.check_contents(names, ADAPTIVE_ICON_BYTES, b'--xr-mode\x1a--fa-consent-geography=eea')[0])
        live = (ROOT / 'godot/game/adapters/fa_live_services.gd').read_text()
        for argument in re.findall(r'const CONSENT_\w+_ARGUMENT := "([^"]+)"', live):
            self.assertTrue(argument.encode().startswith(check_aab.DEVICE_CHECK_ARGUMENT), argument)
        self.assertEqual(2, len(re.findall(r'const CONSENT_\w+_ARGUMENT := ', live)))

    def test_signer_fingerprints_are_parsed_from_keytool_output(self):
        output = 'Signer #1:\n\nCertificate #1:\nOwner: CN=Test\nCertificate fingerprints:\n\t SHA1: 01:02\n\t SHA256: %s\nSignature algorithm name: SHA256withRSA\n' % check_aab.UPLOAD_CERTIFICATE_SHA256.lower()
        self.assertEqual([check_aab.UPLOAD_CERTIFICATE_SHA256], check_aab.parse_fingerprints(output))
        self.assertEqual([], check_aab.parse_fingerprints('Not a signed jar file\n'))
        self.assertEqual(2, len(check_aab.parse_fingerprints(output + output)))
        self.assertRegex(check_aab.UPLOAD_CERTIFICATE_SHA256, r'^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$')

    def test_requirements_follow_the_approved_plan(self):
        self.assertGreaterEqual(check_aab.PLAY_MIN_TARGET_SDK, 36)
        self.assertEqual({'android.permission.INTERNET', 'com.google.android.gms.permission.AD_ID', 'android.permission.VIBRATE'}, set(check_aab.REQUIRED_PERMISSIONS))
        plan = (ROOT / 'docs/design/2026-11-21-four-alike-launch/06-technical-production-plan.md').read_text()
        self.assertIn(check_aab.UPLOAD_CERTIFICATE_SHA256, plan)
        expected = check_aab.expected_identity(ROOT)
        self.assertEqual('com.seoleeapps.fouralike', expected['package'])
        self.assertEqual(expected['versionName'], expected['projectVersion'], 'the Android version name and application/config/version must match')

    def test_missing_bundle_is_reported(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual((['Bundle not found: missing.aab'], {}), check_aab.check(ROOT, Path(folder) / 'missing.aab'))


class PayloadCheckTests(unittest.TestCase):
    def test_measurement_values_are_read_like_the_build_reads_them(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Home(folder)
            self.assertEqual(ANALYTICS, check_ga4_payload.measurement_values({}, home.path))
            self.assertEqual(ANALYTICS, check_ga4_payload.measurement_values(dict(ANALYTICS), Path(folder) / 'empty'))
            override = {'GA4_MEASUREMENT_ID': 'G-OTHER00000'}
            self.assertEqual({**ANALYTICS, **override}, check_ga4_payload.measurement_values(override, home.path))
            for home_path, expected in [(Path(folder) / 'empty', 'analytics credential file not found'),
                                        (Home(folder + '/partial', analytics={'GA4_MEASUREMENT_ID': 'G-ONLY000000'}).path, 'GA4_MP_API_SECRET missing')]:
                with self.assertRaises(prepare_services.ServiceValueError) as raised:
                    check_ga4_payload.measurement_values({}, home_path)
                self.assertEqual(expected, str(raised.exception))

    def test_only_the_validation_endpoint_is_used(self):
        self.assertEqual('https://www.google-analytics.com/debug/mp/collect', check_ga4_payload.ENDPOINT)
        source = (ROOT / 'tools/check_ga4_payload.py').read_text()
        self.assertEqual(1, source.count("'https://"), 'the tool must not know any other address')
        adapter = (ROOT / 'godot/game/adapters/fa_ga4_analytics.gd').read_text()
        self.assertIn('const ENDPOINT := "https://www.google-analytics.com/mp/collect"', adapter)
        dump = (ROOT / 'godot/tests/game/fa_analytics_payload_dump.gd').read_text()
        self.assertNotIn('HTTPRequest', dump)
        self.assertNotIn('fa_http.gd', dump)


class LoopbackHandler(http.server.BaseHTTPRequestHandler):
    """godot/tests/game/fa_http_check.gd가 붙는 서버. 이 기기 안에서만 듣는다."""
    config = b''

    def log_message(self, *arguments):
        pass

    def reply(self, status, body, content_type='application/json'):
        try:
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass  # 크기나 시간 제한으로 앱이 먼저 끊은 요청

    def do_GET(self):
        if self.path == '/config.json':
            self.reply(200, self.config)
        elif self.path == '/big':
            self.reply(200, b'x' * 200000, 'text/plain')
        elif self.path == '/slow':
            time.sleep(3)
            self.reply(200, b'{}')
        else:
            self.reply(404, b'{}')

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get('Content-Length', '0')))
        self.reply(200, json.dumps({'body': body.decode(), 'content_type': self.headers.get('Content-Type'), 'path': self.path}).encode())


class LoopbackServer(socketserver.ThreadingTCPServer):
    # http.server의 서버는 묶을 때 주소의 호스트 이름을 찾는데, 그 조회가 수십 초 걸리는 환경이 있어 쓰지 않는다.
    allow_reuse_address = True
    daemon_threads = True


class HttpTransportTests(unittest.TestCase):
    def test_http_adapter_talks_to_a_loopback_server(self):
        LoopbackHandler.config = (ROOT / check_remote_config.CONFIG).read_bytes()
        server = LoopbackServer(('127.0.0.1', 0), LoopbackHandler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            done = subprocess.run(
                [os.environ.get('GODOT', 'godot'), '--headless', '--path', str(ROOT / 'godot'), '--script', 'res://tests/game/fa_http_check.gd',
                 '--', '--base', 'http://127.0.0.1:%d' % server.server_address[1]],
                capture_output=True, text=True, timeout=120)
        finally:
            server.shutdown()
            server.server_close()
        log = done.stdout + done.stderr
        self.assertEqual(0, done.returncode, log[-3000:])
        self.assertNotRegex(log, r'(?m)^(?:SCRIPT ERROR|ERROR:)')
        self.assertRegex(log, r'Fa http check: \d+ checks, 0 failed')
        self.assertNotIn('api_secret', log, 'request addresses must not reach the log')


class SigningEnvironmentTests(unittest.TestCase):
    STORED = {'ANDROID_KEYSTORE_ALIAS': 'upload', 'ANDROID_KEYSTORE_PASSWORD': 'unit-test-password', 'ANDROID_KEY_PASSWORD': 'unit-test-password'}

    def home(self, folder, **changes):
        home = Path(folder)
        keystore = home / 'keys/upload.jks'
        keystore.parent.mkdir(parents=True)
        keystore.write_bytes(b'not a real keystore')
        values = {'ANDROID_KEYSTORE_FILE': str(keystore), **self.STORED, **changes}
        write_env(home / '.config/seorilabs/play-store/four-alike-keystore.env', {key: value for key, value in values.items() if value is not None})
        return home

    def test_complete_environment_is_used_as_is(self):
        environ = {name: 'value-' + name for name in export_native.SIGNING}
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(environ, export_native.signing_environment({**environ, 'OTHER': 'x'}, Path(folder)))

    def test_values_come_from_the_keystore_file(self):
        with tempfile.TemporaryDirectory() as folder:
            home = self.home(folder)
            signing = export_native.signing_environment({}, home)
            self.assertEqual({
                'GODOT_ANDROID_KEYSTORE_RELEASE_PATH': str(home / 'keys/upload.jks'),
                'GODOT_ANDROID_KEYSTORE_RELEASE_USER': 'upload',
                'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD': 'unit-test-password',
            }, signing)
            moved = home / 'moved.env'
            shutil.copyfile(home / '.config/seorilabs/play-store/four-alike-keystore.env', moved)
            self.assertEqual(signing, export_native.signing_environment({'FA_KEYSTORE_ENV': str(moved)}, Path(folder) / 'empty'))

    def test_incomplete_signing_values_stop_without_echo(self):
        cases = [
            ({'ANDROID_KEYSTORE_PASSWORD': None}, 'Signing values missing in ~/.config/seorilabs/play-store/four-alike-keystore.env: ANDROID_KEYSTORE_PASSWORD'),
            ({'ANDROID_KEY_PASSWORD': 'another-password'}, 'Godot signs with one password'),
            ({'ANDROID_KEYSTORE_FILE': '/nonexistent/upload.jks'}, 'The keystore named in ~/.config/seorilabs/play-store/four-alike-keystore.env does not exist'),
        ]
        for changes, expected in cases:
            with self.subTest(expected=expected), tempfile.TemporaryDirectory() as folder:
                with self.assertRaises(ValueError) as raised:
                    export_native.signing_environment({}, self.home(folder, **changes))
                self.assertIn(expected, str(raised.exception))
                self.assertNotIn('unit-test-password', str(raised.exception))
                self.assertNotIn('another-password', str(raised.exception))
                self.assertNotIn(str(folder), str(raised.exception))
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(ValueError) as raised:
                export_native.signing_environment({'GODOT_ANDROID_KEYSTORE_RELEASE_USER': 'only-one'}, Path(folder))
            self.assertIn('Signing values not found', str(raised.exception))
            self.assertNotIn(str(folder), str(raised.exception))


if __name__ == '__main__':
    unittest.main()
