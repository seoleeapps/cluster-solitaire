import json
import shutil
import tempfile
import unittest
from pathlib import Path
import check_local_mode

ROOT = Path(__file__).resolve().parents[1]
PROFILE = 'godot/data/outgame/outgame-profile.json'

class LocalModeTests(unittest.TestCase):
    def clone(self, folder):
        root = Path(folder)
        (root / PROFILE).parent.mkdir(parents=True)
        shutil.copyfile(ROOT / PROFILE, root / PROFILE)
        shutil.copytree(ROOT / 'godot/game', root / 'godot/game', ignore=shutil.ignore_patterns('*.uid', '*.import'))
        return root

    def test_repository_is_local_only(self):
        self.assertEqual([], check_local_mode.check(ROOT))

    def test_server_mode_and_exposed_account_services_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.clone(folder)
            profile = json.loads((root / PROFILE).read_text())
            profile['mode'] = 'server'
            profile['services']['auth'] = {'status': 'wired', 'exposed': True, 'binding': 'godot/game/bootstrap/main.gd'}
            (root / PROFILE).write_text(json.dumps(profile))
            errors = check_local_mode.check(root)
            self.assertIn('outgame profile must stay in local mode', errors)
            self.assertIn('auth must stay unsupported and hidden', errors)

    def test_platform_client_wiring_in_product_code_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = self.clone(folder)
            script = root / 'godot/game/bootstrap/main.gd'
            script.write_text(script.read_text() + '\nfunc _connect() -> void:\n configure_platform(null, Callable(), {})\n')
            self.assertEqual(['godot/game/bootstrap/main.gd: product code connects the platform client'], check_local_mode.check(root))

if __name__ == '__main__': unittest.main()
