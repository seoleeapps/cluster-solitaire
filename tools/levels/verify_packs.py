#!/usr/bin/env python3
"""레벨 팩의 모든 판을 참고용 Python 탐색기로 다시 검사한다.

    python3 tools/levels/verify_packs.py            # 검사. 불일치가 있으면 종료 코드 1
    python3 tools/levels/verify_packs.py --stats    # 검사한 뒤 core-notes.md에 싣는 생성 통계를 출력

판마다 보는 것: 카드와 범주 id 존재, 배치 모양, 등급의 범주 조건(난도, 대분류, 다른 범주로도 보이는 카드,
판 밖 범주의 후보 한도), 최근 범주 재사용, 묶는 방법의 유일성, 임시 칸 2개 해법 존재,
관대함이 등급 범위 안이고 팩의 f와 반올림 오차 안에서 같은지.
등급표와 배치는 GDD(docs/design/2026-11-21-four-alike-launch/02-gdd.md)에서 따로 옮겨 적어
GDScript 구현(FaDifficulty, FaGenerator)과 독립으로 대조한다.
"""
import argparse
import collections
import datetime
import itertools
import json
import statistics
import sys
from pathlib import Path

from reference_solver import GROUP_SIZE, solve

ROOT = Path(__file__).resolve().parents[2]
PACK_VERSION = 1
GENERATOR_VERSION = 1
HOLD_SLOTS = 2
ROUNDING = 0.005 + 1e-9
BASE_DATE = datetime.date(2026, 12, 1)

LAYOUTS = {
    'open': {'columns': [2, 2, 2, 2], 'reserve': 8},
    'step': {'columns': [3, 3, 2, 2], 'reserve': 6},
    'classic': {'columns': [3, 3, 3, 3], 'reserve': 4},
    'deep': {'columns': [4, 3, 3, 2], 'reserve': 4},
}
GROUPS_PER_LEVEL = 4
# 등급: 배치, 관대함 범위, 범주 난도 상한, 같은 대분류 상한, 다른 범주로도 보이는 카드 상한, 판 밖 범주 후보 상한
TIERS = {
    1: {'layouts': ['open'], 'f': (0.90, 1.0), 'category_tier': 1, 'domain': 1, 'confusable': 0, 'outside': 2},
    2: {'layouts': ['step'], 'f': (0.45, 0.90), 'category_tier': 2, 'domain': 1, 'confusable': 0, 'outside': 2},
    3: {'layouts': ['classic'], 'f': (0.25, 0.60), 'category_tier': 3, 'domain': 2, 'confusable': 0, 'outside': 3},
    4: {'layouts': ['classic', 'deep'], 'f': (0.10, 0.30), 'category_tier': 4, 'domain': 2, 'confusable': 1, 'outside': 3},
    5: {'layouts': ['deep'], 'f': (0.04, 0.12), 'category_tier': 4, 'domain': 2, 'confusable': 2, 'outside': 3},
}
JOURNEY_BANDS = [
    (1, [1]),
    (6, [2, 2, 1, 2, 2]),
    (21, [2, 3, 2, 3, 3]),
    (61, [3, 3, 4, 2, 3, 4, 3, 3, 4, 5]),
    (151, [3, 4, 4, 2, 4, 5, 3, 4, 4, 5]),
]


def journey_tier(stage):
    start, cycle = [band for band in JOURNEY_BANDS if stage >= band[0]][-1]
    return cycle[(stage - start) % len(cycle)]


def daily_tier(number):
    weekend = (BASE_DATE + datetime.timedelta(days=number - 1)).weekday() >= 5
    return 4 if weekend else 3


PACKS = {
    'journey': {'count': 600, 'recent': 3, 'tier': journey_tier},
    'daily': {'count': 1100, 'recent': 21, 'tier': daily_tier},
}


class Content:
    def __init__(self, directory):
        items = json.loads((directory / 'items.json').read_text(encoding='utf-8'))
        categories = json.loads((directory / 'categories.json').read_text(encoding='utf-8'))
        self.version = items['version']
        if categories['version'] != self.version:
            raise ValueError('items.json and categories.json versions differ')
        self.items = {item['id'] for item in items['items']}
        self.categories = {category['id']: category for category in categories['categories']}
        self.candidates = {key: set(value['members']) | set(value['also']) for key, value in self.categories.items()}
        self.owners = collections.defaultdict(set)
        for key, cards in self.candidates.items():
            for card in cards:
                self.owners[card].add(key)


def count_groupings(content, categories, cards, limit=2):
    """cards를 categories의 후보 기준으로 범주마다 4장씩 나누는 방법의 수(limit에서 멈춘다)."""
    options = [[index for index, key in enumerate(categories) if card in content.candidates[key]] for card in cards]
    sizes = [0] * len(categories)

    def walk(position):
        if position == len(cards):
            return 1
        total = 0
        for index in options[position]:
            if sizes[index] < GROUP_SIZE:
                sizes[index] += 1
                total += walk(position + 1)
                sizes[index] -= 1
                if total >= limit:
                    break
        return total

    return walk(0)


def check_level(content, level, number, tier, recent):
    """한 판의 문제 목록과 측정값 {f: 참고 탐색기의 관대함, confusable: 다른 범주로도 보이는 카드 수}를 돌려준다.

    형식이 틀려 끝까지 보지 못한 판은 측정값이 None이다.
    """
    if level.get('n') != number or level.get('tier') != tier:
        return ['n or tier (expected n %d, tier %d)' % (number, tier)], None
    rule = TIERS[tier]
    if level.get('layout') not in rule['layouts']:
        return ['layout %r not allowed for tier %d' % (level.get('layout'), tier)], None
    layout = LAYOUTS[level['layout']]
    problems = []
    cols, reserve, groups = level['cols'], level['reserve'], level['groups']
    if [len(column) for column in cols] != layout['columns'] or len(reserve) != layout['reserve']:
        problems.append('layout shape')
    categories = [group['cat'] for group in groups]
    if len(groups) != GROUPS_PER_LEVEL or len(set(categories)) != len(categories):
        problems.append('group count or duplicate category')
    unknown = [key for key in categories if key not in content.categories]
    if unknown:
        return problems + ['unknown category %s' % unknown], None
    group_of = {}
    for index, group in enumerate(groups):
        if len(group['items']) != GROUP_SIZE:
            problems.append('%s does not have %d cards' % (group['cat'], GROUP_SIZE))
        for card in group['items']:
            if card not in content.items:
                problems.append('unknown card %s' % card)
            elif card not in content.categories[group['cat']]['members']:
                problems.append('%s is not a member of %s' % (card, group['cat']))
            if card in group_of:
                problems.append('card %s appears twice' % card)
            group_of[card] = index
    placed = list(itertools.chain(*cols, reserve))
    if sorted(placed) != sorted(group_of):
        return problems + ['placed cards differ from group cards'], None

    reused = sorted(set(categories) & recent)
    if reused:
        problems.append('recent category reused %s' % reused)
    if any(content.categories[key]['tier'] > rule['category_tier'] for key in categories):
        problems.append('category tier above %d' % rule['category_tier'])
    domains = collections.Counter(content.categories[key]['domain'] for key in categories)
    if max(domains.values()) > rule['domain']:
        problems.append('more than %d categories from one domain' % rule['domain'])
    confusable = 0
    outside = collections.Counter()
    for card, index in group_of.items():
        others = content.owners[card] - {categories[index]}
        confusable += bool(others & set(categories))
        outside.update(others - set(categories))
    if confusable > rule['confusable']:
        problems.append('%d confusable cards' % confusable)
    if outside and max(outside.values()) > rule['outside']:
        problems.append('outside category %s matches %d cards' % outside.most_common(1)[0])
    if count_groupings(content, categories, list(group_of)) != 1:
        problems.append('grouping is not unique')

    count, chance, _ = solve([[group_of[card] for card in column] for column in cols],
                             [group_of[card] for card in reserve], (), HOLD_SLOTS)
    if count is None:
        problems.append('not solvable with %d slots' % HOLD_SLOTS)
    elif not rule['f'][0] <= chance <= rule['f'][1]:
        problems.append('forgiveness %.4f outside tier range' % chance)
    elif not isinstance(level.get('f'), (int, float)) or abs(level['f'] - chance) > ROUNDING:
        problems.append('f %r differs from reference %.4f' % (level.get('f'), chance))
    return problems, {'f': chance, 'confusable': confusable}


def check_pack(content, name, path):
    """팩의 문제 목록과 판별 기록(등급, 배치, 관대함, 범주)을 돌려준다."""
    spec = PACKS[name]
    try:
        pack = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, ValueError) as error:
        return ['%s: cannot read (%s)' % (name, error)], []
    problems = []
    header = (pack.get('version'), pack.get('content_version'), pack.get('generator'))
    if header != (PACK_VERSION, content.version, GENERATOR_VERSION):
        problems.append('%s: header %r' % (name, header))
    levels = pack.get('levels', [])
    if len(levels) != spec['count']:
        problems.append('%s: %d levels, expected %d' % (name, len(levels), spec['count']))
    records = []
    history = collections.deque(maxlen=spec['recent'])
    for number, level in enumerate(levels, start=1):
        tier = spec['tier'](number)
        try:
            found, measured = check_level(content, level, number, tier, set(itertools.chain(*history)))
        except (KeyError, TypeError, IndexError) as error:
            found, measured = ['malformed level (%r)' % error], None
        problems.extend('%s %d: %s' % (name, number, problem) for problem in found)
        if measured is not None:
            categories = [group['cat'] for group in level['groups']]
            history.append(categories)
            records.append(dict(measured, tier=tier, layout=level['layout'], categories=categories))
    return problems, records


def blocker(content, key):
    """범주 하나만으로도 판 밖 범주 한도를 넘기는 경우, 그 판 밖 범주와 겹치는 장수를 돌려준다."""
    members = content.categories[key]['members']
    worst = None
    for other, cards in content.candidates.items():
        if other == key:
            continue
        overlap = len(set(members) & cards)
        spare = len(members) - overlap
        # 겹치지 않는 카드로 채우고 남는 자리에 들어가는, 피할 수 없는 겹침 장수
        forced = max(0, GROUP_SIZE - spare)
        if worst is None or forced > worst[1]:
            worst = (other, forced)
    return worst


def print_stats(content, records_by_pack):
    for name, records in records_by_pack.items():
        print('\n### %s (%d판)\n' % (name, len(records)))
        print('| 등급 | 판 수 | 배치 | 관대함 최소 | 중앙값 | 최대 | 다른 범주로도 보이는 카드가 든 판 |')
        print('|---|---|---|---|---|---|---|')
        for tier in sorted(TIERS):
            rows = [record for record in records if record['tier'] == tier]
            if not rows:
                continue
            layouts = collections.Counter(record['layout'] for record in rows)
            values = [record['f'] for record in rows]
            print('| T%d | %d | %s | %.3f | %.3f | %.3f | %d |' % (
                tier, len(rows), ', '.join('%s %d' % pair for pair in sorted(layouts.items())),
                min(values), statistics.median(values), max(values), sum(1 for record in rows if record['confusable'])))
    usage = collections.Counter()
    for records in records_by_pack.values():
        for record in records:
            usage.update(record['categories'])
    total = sum(usage.values())
    print('\n### 범주 사용 (두 팩 합계 %d회, 범주 %d개 중 %d개 사용)\n' % (total, len(content.categories), len(usage)))
    print('| 순위 | 범주 | 난도 | 대분류 | 횟수 |')
    print('|---|---|---|---|---|')
    for rank, (key, count) in enumerate(usage.most_common(10), start=1):
        category = content.categories[key]
        print('| %d | `%s` | %d | %s | %d |' % (rank, key, category['tier'], category['domain'], count))
    print('\n가장 적게 쓰인 범주 10개: ' + ', '.join('`%s` %d' % pair for pair in sorted(usage.items(), key=lambda pair: (pair[1], pair[0]))[:10]))
    print('\n| 한 번도 안 쓰인 범주 | 난도 | 소속 수 | 가장 많이 겹치는 판 밖 범주 | 피할 수 없는 겹침 |')
    print('|---|---|---|---|---|')
    for key, category in content.categories.items():
        if key not in usage:
            other, forced = blocker(content, key)
            print('| `%s` | %d | %d | `%s` | %d장 |' % (key, category['tier'], len(category['members']), other, forced))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--content', type=Path, default=ROOT / 'godot/data/content')
    parser.add_argument('--levels', type=Path, default=ROOT / 'godot/data/levels')
    parser.add_argument('--stats', action='store_true', help='검사 뒤 생성 통계를 마크다운으로 출력')
    args = parser.parse_args()
    content = Content(args.content)
    problems = []
    records_by_pack = {}
    for name in PACKS:
        found, records = check_pack(content, name, args.levels / (name + '.json'))
        problems.extend(found)
        records_by_pack[name] = records
        print('%s: %d levels checked, %d problems' % (name, len(records), len(found)))
    for problem in problems[:50]:
        print('  ' + problem)
    if len(problems) > 50:
        print('  (%d more)' % (len(problems) - 50))
    if args.stats and not problems:
        print_stats(content, records_by_pack)
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
