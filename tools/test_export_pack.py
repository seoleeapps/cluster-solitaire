import json
import unittest
from pathlib import Path

import check_export_pack

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'godot'


class ExportPackTests(unittest.TestCase):
    """묶음 검사의 판정만 본다. 실제 내보내기는 `npm run check:export-pack`이 한다."""

    def complete_names(self):
        names = set(check_export_pack.RAW_FILES)
        names.update(path[len('res://'):] + '.import' for path in check_export_pack.expected_svgs(PROJECT))
        items = json.loads((PROJECT / 'data/content/items.json').read_text(encoding='utf-8'))['items']
        names.update('game/assets/icons/%s.png.import' % item['icon'] for item in items)
        for sound in (PROJECT / 'game/assets/audio').rglob('*'):
            if sound.suffix in ('.wav', '.ogg'):
                names.add(sound.relative_to(PROJECT).as_posix() + '.import')
        return names

    def pack_text(self):
        return (PROJECT / check_export_pack.SVG_PACK).read_text(encoding='utf-8')

    def test_a_complete_export_has_no_problems(self):
        self.assertEqual([], check_export_pack.problems_in(self.complete_names(), self.pack_text(), PROJECT))

    def test_the_source_pack_holds_every_generated_svg(self):
        sources = json.loads(self.pack_text())['sources']
        self.assertEqual(sorted(check_export_pack.expected_svgs(PROJECT)), sorted(sources))

    def test_a_missing_source_pack_is_reported(self):
        names = self.complete_names() - {check_export_pack.SVG_PACK}
        self.assertIn('not in the export: ' + check_export_pack.SVG_PACK, check_export_pack.problems_in(names, None, PROJECT))

    def test_a_stale_source_pack_is_reported(self):
        stale = json.loads(self.pack_text())
        dropped = sorted(stale['sources'])[0]
        del stale['sources'][dropped]
        found = check_export_pack.problems_in(self.complete_names(), json.dumps(stale), PROJECT)
        self.assertIn('the exported SVG pack differs from ' + check_export_pack.SVG_PACK, found)
        self.assertIn('no SVG text for ' + dropped, found)

    def test_a_missing_card_picture_and_level_pack_are_reported(self):
        names = self.complete_names() - {'game/assets/icons/banana.png.import', 'data/levels/tutorial.json'}
        found = check_export_pack.problems_in(names, self.pack_text(), PROJECT)
        self.assertIn('card picture missing: banana', found)
        self.assertIn('not in the export: data/levels/tutorial.json', found)


if __name__ == '__main__':
    unittest.main()
