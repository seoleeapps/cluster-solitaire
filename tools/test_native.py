import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
import check_native
ROOT=Path(__file__).resolve().parents[1]
class NativeExportTests(unittest.TestCase):
    def test_native_export_contract(self):
        self.assertEqual([],check_native.validate(ROOT))
    def clone_config(self,folder):
        root=Path(folder)
        patches=json.loads((ROOT/'native/dependencies.lock.json').read_text())['sources']['admob']['localPatches']
        for name in ['.gitignore','native/dependencies.lock.json','godot/project.godot','godot/export_presets.cfg','godot/config/product.json','play-store/google-play.config.json',*[entry['file'] for entry in patches]]:
            target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
        return root
    def test_changed_vendor_patch_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/addons/admob/admob.gd';p.write_text(p.read_text()+'\n# changed\n')
            self.assertIn('Native source patch hash mismatch: godot/addons/admob/admob.gd',check_native.validate(root))
    def test_mismatched_store_identity_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'play-store/google-play.config.json';data=json.loads(p.read_text());data['packageName']='com.other.wrong';p.write_text(json.dumps(data))
            self.assertIn('Android package identity mismatch',check_native.validate(root))
    def test_mismatched_store_name_and_bundle_path_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'play-store/google-play.config.json';data=json.loads(p.read_text());data.update(appName='Other Game',aabPath='build/android/other.aab');p.write_text(json.dumps(data))
            errors=check_native.validate(root)
            self.assertIn('Android display name mismatch',errors)
            self.assertIn('Android bundle path mismatch',errors)
    def test_embedded_signing_secret_is_rejected_without_echo(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg';p.write_text(p.read_text().replace('keystore/release_password=""','keystore/release_password="do-not-copy-this-value"'))
            errors=check_native.validate(root)
            self.assertTrue(any('Signing values must come from the environment' in x for x in errors))
            self.assertNotIn('do-not-copy-this-value',' '.join(errors))
    def test_native_presets_do_not_enable_device_discovery(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg';text=p.read_text();index=text.index('[preset.1]');p.write_text(text[:index]+text[index:].replace('runnable=false','runnable=true',1))
            self.assertIn('Native automatic device discovery must stay disabled',check_native.validate(root))
    def test_missing_mobile_texture_import_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/project.godot';p.write_text(p.read_text().replace('textures/vram_compression/import_etc2_astc=true','textures/vram_compression/import_etc2_astc=false'))
            self.assertIn('Mobile texture import must be enabled for native exports',check_native.validate(root))
    def test_landscape_display_is_rejected(self):
        for old,new in [('window/handheld/orientation=1','window/handheld/orientation=0'),('window/size/viewport_width=390\nwindow/size/viewport_height=844','window/size/viewport_width=1280\nwindow/size/viewport_height=720'),('window/stretch/aspect="keep_width"','window/stretch/aspect="expand"')]:
            with self.subTest(old=old),tempfile.TemporaryDirectory() as folder:
                root=self.clone_config(folder);p=root/'godot/project.godot';text=p.read_text()
                self.assertIn(old,text);p.write_text(text.replace(old,new))
                self.assertIn('Display must be portrait 390x844 stretched by width',check_native.validate(root))
    def test_project_written_by_the_editor_is_read(self):
        # Godot rewrites project.godot with multi-line dictionaries once the AdMob editor plugin registers its settings.
        project=check_native.load_project(ROOT)
        self.assertEqual(390,check_native.project_value(project,'display','window/size/viewport_width'))
        self.assertEqual({'mipmaps/generate':True},check_native.project_value(project,'importer_defaults','texture'))
        self.assertIsNone(check_native.project_value(project,'display','missing'))
    def test_disabled_admob_plugin_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/project.godot';text=p.read_text()
            self.assertIn('enabled=PackedStringArray("res://addons/admob/plugin.cfg")',text)
            p.write_text(text.replace('enabled=PackedStringArray("res://addons/admob/plugin.cfg")','enabled=PackedStringArray()'))
            self.assertIn('The AdMob editor plugin must be enabled in project.godot',check_native.validate(root))
    def test_missing_android_permissions_are_rejected(self):
        for permission in ['internet','vibrate']:
            with self.subTest(permission=permission),tempfile.TemporaryDirectory() as folder:
                root=self.clone_config(folder);p=root/'godot/export_presets.cfg';text=p.read_text()
                self.assertIn('permissions/'+permission+'=true',text);p.write_text(text.replace('permissions/'+permission+'=true','permissions/'+permission+'=false'))
                self.assertIn('Android must request the '+permission+' permission',check_native.validate(root))
    def test_device_check_arguments_in_the_preset_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg'
            p.write_text(p.read_text().replace('permissions/vibrate=true','permissions/vibrate=true\ncommand_line/extra_args="-- --fa-consent-geography=eea"'))
            self.assertIn('Android preset must not carry extra command line arguments',check_native.validate(root))
    def test_left_over_injected_service_values_are_rejected_without_echo(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/project.godot'
            p.write_text(p.read_text().replace('[application]','[admob]\n\ngeneral/android/app_id="ca-app-pub-1234567890123456~1234567890"\n\n[application]',1))
            errors=check_native.validate(root)
            self.assertIn('project.godot carries an injected AdMob app ID; run python3 tools/prepare_services.py --restore',errors)
            self.assertNotIn('1234567890123456',' '.join(errors))
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/data/services/release.json';p.parent.mkdir(parents=True);p.write_text('{"ga4_api_secret":"do-not-copy-this-value"}')
            errors=check_native.validate(root)
            self.assertIn('Injected service values were left behind; run python3 tools/prepare_services.py --restore',errors)
            self.assertNotIn('do-not-copy-this-value',' '.join(errors))
    def test_service_values_must_stay_untracked(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'.gitignore';p.write_text(p.read_text().replace('godot/data/services/\n',''))
            self.assertIn('.gitignore must exclude godot/data/services/',check_native.validate(root))
        tracked=subprocess.check_output(['git','-C',str(ROOT),'ls-files','godot/data/services'],text=True)
        self.assertEqual('',tracked)
    def test_unvalidated_platform_preset_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root=self.clone_config(folder);p=root/'godot/export_presets.cfg';p.write_text(p.read_text()+'\n[preset.2]\nname="iOS"\nplatform="iOS"\nrunnable=false\n\n[preset.2.options]\n')
            self.assertIn('Unsupported export preset platform: iOS',check_native.validate(root))
if __name__=='__main__':unittest.main()
