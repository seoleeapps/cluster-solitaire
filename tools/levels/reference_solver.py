"""참고용 해법 탐색기. 설계 단계의 규칙 프로토타입을 옮긴 것으로, GDScript 탐색기(FaSolver)의 대조 기준이다.

상태는 열(마지막 원소가 맨 앞 카드), 예비 카드, 임시 칸의 카드다. 카드는 묶음 번호로 나타낸다.
한 묶음의 4장이 모두 보이면 묶는 것이 손해가 되지 않으므로 먼저 묶고, 임시 칸 이동만 분기한다.
"""
from functools import lru_cache

GROUP_SIZE = 4


def settle(cols, reserve, held):
    """보이는 묶음을 더 없을 때까지 묶는다."""
    cols = [list(c) for c in cols]
    reserve = list(reserve)
    held = list(held)
    changed = True
    while changed:
        changed = False
        visible = {}
        for index, column in enumerate(cols):
            if column:
                visible.setdefault(column[-1], []).append(index)
        for card in reserve:
            visible.setdefault(card, []).append(None)
        for card in held:
            visible.setdefault(card, []).append(None)
        for group, places in visible.items():
            if len(places) == GROUP_SIZE:
                for index in places:
                    if index is not None:
                        cols[index].pop()
                reserve = [card for card in reserve if card != group]
                held = [card for card in held if card != group]
                changed = True
                break
    return tuple(tuple(c) for c in cols), tuple(sorted(reserve)), tuple(sorted(held))


def solve(cols, reserve, held, slots):
    """(최소 임시 칸 이동 수 또는 None, 관대함, 최소 해법의 첫 이동 열 또는 -1)을 돌려준다.

    관대함은 임시 칸에 넣을 열을 균등 무작위로 고를 때 끝까지 풀리는 확률이다.
    """

    @lru_cache(maxsize=None)
    def best(cols, reserve, held):
        cols, reserve, held = settle(cols, reserve, held)
        if not any(cols) and not reserve and not held:
            return 0, 1.0
        if len(held) >= slots:
            return None, 0.0
        moves = [index for index, column in enumerate(cols) if column]
        if not moves:
            return None, 0.0
        results = [best(*after_hold(cols, reserve, held, index)) for index in moves]
        counts = [count for count, _ in results if count is not None]
        chance = sum(chance for _, chance in results) / len(results)
        return (min(counts) + 1 if counts else None), chance

    def after_hold(cols, reserve, held, index):
        moved = list(cols)
        card = moved[index][-1]
        moved[index] = moved[index][:-1]
        return tuple(moved), reserve, tuple(sorted(held + (card,)))

    start = (tuple(tuple(c) for c in cols), tuple(sorted(reserve)), tuple(sorted(held)))
    count, chance = best(*start)
    next_hold = -1
    if count:
        settled = settle(*start)
        for index, column in enumerate(settled[0]):
            if column and best(*after_hold(*settled, index))[0] == count - 1:
                next_hold = index
                break
    return count, chance, next_hold
