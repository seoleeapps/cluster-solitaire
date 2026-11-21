import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/levels'))
import verify_packs  # noqa: E402  (tools/levels의 검증 도구)


class TutorialLevelTests(unittest.TestCase):
    """튜토리얼 판 검증이 안내 순서대로 풀리지 않는 판을 걸러 내는지 본다."""

    @classmethod
    def setUpClass(cls):
        cls.content = verify_packs.Content(ROOT / 'godot/data/content')
        cls.pack = json.loads((ROOT / 'godot/data/levels/tutorial.json').read_text(encoding='utf-8'))

    def problems(self, change=None):
        pack = copy.deepcopy(self.pack)
        if change:
            change(pack)
        return verify_packs.check_tutorial_level(self.content, pack['levels'][0], pack.get('guide'))

    def test_the_shipped_level_passes(self):
        self.assertEqual([], verify_packs.check_tutorial(self.content, ROOT / 'godot/data/levels/tutorial.json'))

    def test_a_guide_card_that_is_not_a_front_card_is_rejected(self):
        def change(pack):
            pack['guide']['hold'] = pack['levels'][0]['cols'][0][0]
        self.assertTrue(any('guide step 2' in problem for problem in self.problems(change)))

    def test_reserve_cards_must_be_the_first_group(self):
        def change(pack):
            level = pack['levels'][0]
            level['reserve'][0], level['cols'][1][1] = level['cols'][1][1], level['reserve'][0]
        self.assertTrue(any('guide step 1' in problem for problem in self.problems(change)))

    def test_holding_the_card_must_open_the_second_group(self):
        def change(pack):
            level = pack['levels'][0]
            level['cols'][0][0], level['cols'][1][0] = level['cols'][1][0], level['cols'][0][0]
        self.assertTrue(any('guide step 2' in problem for problem in self.problems(change)))

    def test_a_missing_guide_is_rejected(self):
        def change(pack):
            del pack['guide']
        self.assertEqual(['guide must name every category in order and one card to hold'], self.problems(change))

    def test_a_card_from_another_category_is_rejected(self):
        def change(pack):
            level = pack['levels'][0]
            level['groups'][0]['items'][0] = 'tomato'
            level['reserve'][0] = 'tomato'
        self.assertTrue(any('tomato is not a member of fruits' in problem for problem in self.problems(change)))

    def test_the_stored_forgiveness_must_match_the_solver(self):
        def change(pack):
            pack['levels'][0]['f'] = 0.9
        self.assertTrue(any(problem.startswith('f 0.9 differs') for problem in self.problems(change)))


if __name__ == '__main__':
    unittest.main()
