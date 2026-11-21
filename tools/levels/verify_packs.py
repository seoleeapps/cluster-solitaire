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
# 합을 구하는 순서와 방식이 달라 생기는 마지막 자리 차이(Python 3.12부터 sum은 보정 합산이다)를 봐준다.
FLOAT_SLACK = 1e-9
ROUNDING = 0.005 + FLOAT_SLACK
BASE_DATE = datetime.date(2026, 12, 1)

LAYOUTS = {
    'open': {'columns': [2, 2, 2, 2], 'reserve': 8},
    'step': {'columns': [3, 3, 2, 2], 'reserve': 6},
    'classic': {'columns': [3, 3, 3, 3], 'reserve': 4},
    'deep': {'columns': [4, 3, 3, 2], 'reserve': 4},
}
GROUPS_PER_LEVEL = 4
# 판에 없는 범주의 후보가 두 묶음 이상에 걸쳐 있으면 그 전체 장수를 센다. 어느 등급에서도 3장까지다
# (여러 묶음에 걸친 4장이면 판에 없는 범주로 읽히는 가짜 묶음이 생긴다). 한 묶음 안에만 있으면 세지 않는다.
# 색 범주는 이 한도만 쓰고, 그 밖의 범주는 등급표의 outside가 더 좁으면 그것을 쓴다.
OUTSIDE_LIMIT = 3
COLOR_DOMAIN = 'color'
# 등급: 배치, 관대함 범위, 범주 난도 상한, 같은 대분류 상한, 다른 범주로도 보이는 카드 상한,
# 색이 아닌 판 밖 범주의 후보 상한
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
    outside = collections.defaultdict(list)
    for card, index in group_of.items():
        others = content.owners[card] - {categories[index]}
        confusable += bool(others & set(categories))
        for key in others - set(categories):
            outside[key].append(index)
    if confusable > rule['confusable']:
        problems.append('%d confusable cards' % confusable)
    for key, groups_hit in outside.items():
        limit = OUTSIDE_LIMIT if content.categories[key]['domain'] == COLOR_DOMAIN else rule['outside']
        if len(set(groups_hit)) >= 2 and len(groups_hit) > limit:
            problems.append('outside category %s matches %d cards across %d groups (limit %d)' % (
                key, len(groups_hit), len(set(groups_hit)), limit))
    if count_groupings(content, categories, list(group_of)) != 1:
        problems.append('grouping is not unique')

    count, chance, _ = solve([[group_of[card] for card in column] for column in cols],
                             [group_of[card] for card in reserve], (), HOLD_SLOTS)
    if count is None:
        problems.append('not solvable with %d slots' % HOLD_SLOTS)
    elif not rule['f'][0] - FLOAT_SLACK <= chance <= rule['f'][1] + FLOAT_SLACK:
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


def closest(content, key):
    """소속 카드를 가장 많이 후보로 품는 다른 범주와 그 장수. 안 쓰인 범주의 원인을 볼 때 쓴다."""
    members = set(content.categories[key]['members'])
    return max(((len(members & cards), other) for other, cards in content.candidates.items() if other != key),
               key=lambda pair: (pair[0], pair[1]))


def reuse_gaps(records):
    """같은 범주가 다시 나오기까지 몇 판이 지났는지의 목록."""
    last_seen = {}
    gaps = []
    for index, record in enumerate(records):
        for key in record['categories']:
            if key in last_seen:
                gaps.append(index - last_seen[key])
            last_seen[key] = index
    return gaps


WIDE_CANDIDATES = 35


def print_stats(content, records_by_pack):
    tiers = collections.Counter(category['tier'] for category in content.categories.values())
    print('\n콘텐츠: 카드 %d장, 범주 %d개(난도별 %s)' % (
        len(content.items), len(content.categories), ', '.join('%d: %d' % pair for pair in sorted(tiers.items()))))
    for name, records in records_by_pack.items():
        gaps = reuse_gaps(records)
        print('\n### %s (%d판)\n' % (name, len(records)))
        print('같은 범주를 다시 쓰기까지의 간격: 최소 %d판, 중앙값 %d판(재사용 금지 구간은 직전 %d판)\n' % (
            min(gaps), statistics.median(gaps), PACKS[name]['recent']))
        print('| 등급 | 판 수 | 배치 | 관대함 최소 | 중앙값 | 최대 | 다른 범주로도 보이는 카드가 든 판 | 대분류가 모두 다른 판 | 같은 대분류 2개가 든 판 |')
        print('|---|---|---|---|---|---|---|---|---|')
        for tier in sorted(TIERS):
            rows = [record for record in records if record['tier'] == tier]
            if not rows:
                continue
            layouts = collections.Counter(record['layout'] for record in rows)
            values = [record['f'] for record in rows]
            # 한 판에서 같은 대분류에 속한 범주가 가장 많이 몇 개인지
            shared = collections.Counter(
                max(collections.Counter(content.categories[key]['domain'] for key in record['categories']).values())
                for record in rows)
            print('| T%d | %d | %s | %.3f | %.3f | %.3f | %d | %d | %d |' % (
                tier, len(rows), ', '.join('%s %d' % pair for pair in sorted(layouts.items())),
                min(values), statistics.median(values), max(values), sum(1 for record in rows if record['confusable']),
                shared[1], sum(count for most, count in shared.items() if most >= 2)))

    usage = collections.Counter()
    for records in records_by_pack.values():
        for record in records:
            usage.update(record['categories'])
    levels = sum(len(records) for records in records_by_pack.values())
    print('\n### 범주 사용 (두 팩 합계 %d판, %d회. 범주 %d개 중 %d개 사용)\n' % (
        levels, sum(usage.values()), len(content.categories), len(usage)))
    print('| 범주 난도 | 범주 수 | 가장 많이 쓰인 범주 | 가장 적게 쓰인 범주 | 중앙값 | 안 쓰인 범주 수 |')
    print('|---|---|---|---|---|---|')
    for tier in sorted(tiers):
        counts = sorted((usage[key], key) for key, category in content.categories.items() if category['tier'] == tier)
        print('| %d | %d | `%s` %d회 | `%s` %d회 | %d회 | %d |' % (
            tier, len(counts), counts[-1][1], counts[-1][0], counts[0][1], counts[0][0],
            statistics.median(count for count, _ in counts), sum(1 for count, _ in counts if count == 0)))
    print('\n가장 많이 쓰인 범주 10개: ' + ', '.join('`%s` %d' % pair for pair in usage.most_common(10)))
    print('\n가장 적게 쓰인 범주 10개: ' + ', '.join(
        '`%s` %d' % (key, usage[key]) for key in sorted(content.categories, key=lambda key: (usage[key], key))[:10]))

    print('\n색 범주와 후보가 넓은 범주(후보 %d장 이상). 비율은 전체 %d판 가운데 그 범주가 나온 판이다.\n' % (WIDE_CANDIDATES, levels))
    print('| 범주 | 대분류 | 난도 | 후보 수 | 쓰인 횟수 | 비율 |')
    print('|---|---|---|---|---|---|')
    wide = [key for key, category in content.categories.items()
            if category['domain'] == COLOR_DOMAIN or len(content.candidates[key]) >= WIDE_CANDIDATES]
    for key in sorted(wide, key=lambda key: -len(content.candidates[key])):
        category = content.categories[key]
        print('| `%s` | %s | %d | %d | %d | %.2f%% |' % (
            key, category['domain'], category['tier'], len(content.candidates[key]), usage[key], usage[key] * 100 / levels))

    print('\n| 한 번도 안 쓰인 범주 | 난도 | 소속 수 | 소속을 가장 많이 품는 다른 범주 | 그 범주의 후보인 소속 수 |')
    print('|---|---|---|---|---|')
    for key, category in content.categories.items():
        if key not in usage:
            overlap, other = closest(content, key)
            print('| `%s` | %d | %d | `%s` | %d장 |' % (key, category['tier'], len(category['members']), other, overlap))


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
