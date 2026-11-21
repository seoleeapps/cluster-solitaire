#!/usr/bin/env python3
"""fa_solver_probe.gd에 박아 넣는 기대값 표를 참고 탐색기로 만든다.

    python3 tools/levels/solver_fixtures.py

출력한 줄을 프로브의 FIXTURES 상수에 그대로 붙인다. 시드가 고정이라 다시 돌려도 같은 표가 나온다.
"""
import json
import random

from reference_solver import solve

LAYOUTS = {
    'intro': ([2, 2, 2, 2], 4, 3),
    'open': ([2, 2, 2, 2], 8, 4),
    'step': ([3, 3, 2, 2], 6, 4),
    'classic': ([3, 3, 3, 3], 4, 4),
    'deep': ([4, 3, 3, 2], 4, 4),
}
DEALS_PER_LAYOUT = 4
MIDGAME_STATES = 8


def deal(layout, rng):
    depths, reserve_count, groups = LAYOUTS[layout]
    cards = [group for group in range(groups) for _ in range(4)]
    rng.shuffle(cards)
    cols, used = [], 0
    for depth in depths:
        cols.append(cards[used:used + depth])
        used += depth
    return cols, cards[used:used + reserve_count]


def fixture(cols, reserve, held, slots):
    count, chance, next_hold = solve(cols, reserve, held, slots)
    return {'cols': cols, 'reserve': reserve, 'held': list(held), 'slots': slots,
            'min_holds': -1 if count is None else count, 'forgiveness': chance, 'next_hold': next_hold}


def main():
    rng = random.Random(20261121)
    rows = []
    for layout in LAYOUTS:
        for _ in range(DEALS_PER_LAYOUT):
            cols, reserve = deal(layout, rng)
            rows.append(fixture(cols, reserve, (), 2))
    # 임시 칸 2개로는 안 풀리고 3개로는 풀리는 판 하나를 두 칸 수로 모두 싣는다.
    while True:
        cols, reserve = deal('deep', rng)
        if solve(cols, reserve, (), 2)[0] is None and solve(cols, reserve, (), 3)[0] is not None:
            rows.append(fixture(cols, reserve, (), 2))
            rows.append(fixture(cols, reserve, (), 3))
            break
    # 진행 중인 판: 묶지 않은 채 임시 칸에 카드를 한두 장 넣은 상태.
    for index in range(MIDGAME_STATES):
        cols, reserve = deal('classic' if index % 2 == 0 else 'deep', rng)
        held = []
        for _ in range(1 + index % 2):
            column = rng.choice([c for c in cols if c])
            held.append(column.pop())
        rows.append(fixture(cols, reserve, tuple(held), 2 + index // 4))
    for row in rows:
        print('\t' + json.dumps(row) + ',')


if __name__ == '__main__':
    main()
