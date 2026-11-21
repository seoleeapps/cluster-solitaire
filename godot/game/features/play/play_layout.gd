extends RefCounted
## 플레이 화면의 배치 계산. 화면 크기와 안전 영역, 판의 모양을 받아 각 구역의 자리를 돌려준다. 노드를 만들지 않는다.
##
## 세로는 위에서 아래로 상단 줄, 메달 줄, 더미, 받침(임시 칸 줄과 예비 카드 줄), 아래 버튼 줄이다.
## 카드 높이는 고정 구역을 뺀 높이를 카드 줄 수로 나눠 84~122에서 정한다. 122로도 남는 높이는 먼저 받침과 아래 버튼
## 사이를 기준 그림만큼 벌리고, 그래도 남으면 위 여백, 더미와 받침 사이, 아래쪽에 나눈다. 84도 안 나오면 간격과
## 메달을 좁히고, 그래도 모자라면 화면 전체를 같은 비율로 줄인다(scale).
## 수치는 기준 그림(390×844, 위 34와 아래 16의 안전 영역)에서 잰 값이다.

const DESIGN_WIDTH := 390.0
const SIDE := 14.0
const GUTTER := 8.0
const COLUMNS := 4
const CARD_MIN := 84.0
const CARD_MAX := 122.0
## 뒤집힌 카드가 한 장마다 위로 어긋나 보이는 높이.
const STACK_STEP := 22.0
const HUD_HEIGHT := 44.0
const ACTION_HEIGHT := 74.0
const LABEL_HEIGHT := 16.0
const TRAY_PAD := 9.0
const RESERVE_PER_ROW := 4
## 메달 원 아래 이름표까지의 높이(원 아래 8에서 시작하는 18짜리 이름표).
const TAG_OFFSET := 8.0
const TAG_HEIGHT := 18.0
const BOOSTER_WIDTH := 58.0
const BOOSTER_DISC := 52.0
const PRIMARY_HEIGHT := 58.0
const ACTION_GUTTER := 12.0
## 기준 그림에서 받침과 아래 버튼 줄 사이의 간격. 남는 높이는 먼저 여기까지 채운다.
const ACTION_GAP_ROOMY := 41.0
const ICON_RATIO := 0.44
const ICON_MIN := 38.0
const ICON_MAX := 54.0
## 남는 높이를 나누는 비율: 위 여백, 더미와 받침 사이, 받침과 버튼 사이, 아래 여백.
const SPARE_SHARE := {"top": 0.3, "tray_gap": 0.3, "action_gap": 0.2, "bottom": 0.2}
## 간격과 메달 크기: [좁힌 값, 넉넉한 값].
const FLEX := {
	"top": [8.0, 16.0], "hud_gap": [6.0, 12.0], "disc": [46.0, 58.0], "shelf_gap": [8.0, 18.0],
	"tray_gap": [10.0, 12.0], "tray_top": [7.0, 9.0], "label_gap": [3.0, 5.0], "row_gap": [7.0, 9.0],
	"reserve_gap": [6.0, 8.0], "tray_bottom": [9.0, 10.0], "action_gap": [8.0, 14.0], "bottom": [8.0, 13.0],
}


## 배치를 계산한다.
##   size: 화면의 논리 크기. safe_top, safe_bottom: 노치와 제스처 바만큼 비울 높이.
##   columns: 열별 장수(판을 시작할 때). reserve_count: 예비 카드 자리 수. groups: 범주 수. hold_cells: 보여 줄 임시 칸 수.
## 결과의 자리는 모두 scale을 곱하기 전(stage) 좌표다.
static func compute(size: Vector2, safe_top: float, safe_bottom: float, columns: Array, reserve_count: int,
		groups: int, hold_cells: int) -> Dictionary:
	var reserve_rows: int = maxi(1, ceili(float(reserve_count) / RESERVE_PER_ROW))
	var card_rows: int = 2 + reserve_rows
	var deepest: int = 0
	for count: int in columns:
		deepest = maxi(deepest, count - 1)
	var roomy: float = _fixed_height(1.0, deepest, reserve_rows)
	var tight: float = _fixed_height(0.0, deepest, reserve_rows)

	# 안전 영역을 뺀 높이가 좁힌 배치에도 모자라면 통째로 줄인다.
	var scale: float = 1.0
	var needed: float = safe_top + safe_bottom + tight + card_rows * CARD_MIN
	if size.y < needed:
		scale = size.y / needed
	var stage: Vector2 = size / scale
	var height: float = stage.y - safe_top - safe_bottom

	var comfort: float = 1.0
	var spare: float = 0.0
	var card_height: float = (height - roomy) / card_rows
	if card_height > CARD_MAX:
		spare = height - roomy - card_rows * CARD_MAX
		card_height = CARD_MAX
	elif card_height < CARD_MIN:
		card_height = CARD_MIN
		comfort = clampf((height - tight - card_rows * CARD_MIN) / (roomy - tight), 0.0, 1.0)

	var gap: Dictionary = {}
	for key: String in FLEX:
		gap[key] = lerpf(FLEX[key][0], FLEX[key][1], comfort)
	var to_actions: float = minf(spare, ACTION_GAP_ROOMY - float(gap["action_gap"]))
	var rest: float = spare - to_actions
	gap["action_gap"] += to_actions
	for key: String in SPARE_SHARE:
		gap[key] += rest * float(SPARE_SHARE[key])

	var content_width: float = minf(stage.x, DESIGN_WIDTH) - SIDE * 2.0
	var left: float = (stage.x - content_width) / 2.0
	var card_width: float = (content_width - GUTTER * (COLUMNS - 1)) / COLUMNS
	var cell_width: float = (content_width - TRAY_PAD * 2.0 - GUTTER * (RESERVE_PER_ROW - 1)) / RESERVE_PER_ROW
	var disc: float = gap["disc"]

	var y: float = safe_top + float(gap["top"])
	var hud := Rect2(left, y, content_width, HUD_HEIGHT)
	y += HUD_HEIGHT + float(gap["hud_gap"])

	var medals: Array[Rect2] = []
	var shelf_width: float = groups * card_width + (groups - 1) * GUTTER
	var shelf_left: float = left + (content_width - shelf_width) / 2.0
	for index: int in groups:
		medals.append(Rect2(shelf_left + index * (card_width + GUTTER) + (card_width - disc) / 2.0, y, disc, disc))
	y += disc + TAG_OFFSET + TAG_HEIGHT

	y += float(gap["shelf_gap"])
	var tableau := Rect2(left, y, content_width, deepest * STACK_STEP + card_height)
	var column_x: Array[float] = []
	for index: int in columns.size():
		column_x.append(left + index * (card_width + GUTTER))
	y += tableau.size.y + float(gap["tray_gap"])

	var tray_top: float = y
	y += float(gap["tray_top"])
	var hold_label := Vector2(left + TRAY_PAD, y)
	y += LABEL_HEIGHT + float(gap["label_gap"])
	var holds: Array[Rect2] = []
	var hold_width: float = hold_cells * cell_width + (hold_cells - 1) * GUTTER
	for index: int in hold_cells:
		holds.append(Rect2(left + (content_width - hold_width) / 2.0 + index * (cell_width + GUTTER), y, cell_width, card_height))
	y += card_height + float(gap["row_gap"])
	var reserve_label := Vector2(left + TRAY_PAD, y)
	y += LABEL_HEIGHT + float(gap["label_gap"])
	var reserve: Array[Rect2] = []
	for row: int in reserve_rows:
		var in_row: int = mini(RESERVE_PER_ROW, reserve_count - row * RESERVE_PER_ROW)
		var row_width: float = in_row * cell_width + (in_row - 1) * GUTTER
		for index: int in in_row:
			reserve.append(Rect2(left + (content_width - row_width) / 2.0 + index * (cell_width + GUTTER), y, cell_width, card_height))
		y += card_height + (float(gap["reserve_gap"]) if row < reserve_rows - 1 else 0.0)
	y += float(gap["tray_bottom"])
	var tray := Rect2(left, tray_top, content_width, y - tray_top)

	y += float(gap["action_gap"])
	var actions := Rect2(left, y, content_width, ACTION_HEIGHT)
	var primary_left: float = left + BOOSTER_WIDTH + ACTION_GUTTER
	var primary := Rect2(primary_left, y + (ACTION_HEIGHT - PRIMARY_HEIGHT) / 2.0,
		content_width - (BOOSTER_WIDTH + ACTION_GUTTER) * 2.0, PRIMARY_HEIGHT)
	y += ACTION_HEIGHT + float(gap["bottom"])

	return {
		"scale": scale, "stage": stage, "comfort": comfort, "bottom": y + safe_bottom,
		"card": Vector2(card_width, card_height), "cell": Vector2(cell_width, card_height),
		"icon": clampf(card_height * ICON_RATIO, ICON_MIN, ICON_MAX),
		"hud": hud, "medals": medals, "disc": disc, "tag_room": TAG_HEIGHT + maxf(0.0, float(gap["shelf_gap"]) - 6.0),
		"tableau": tableau, "column_x": column_x,
		"tray": tray, "hold_label": hold_label, "holds": holds, "reserve_label": reserve_label, "reserve": reserve,
		"label_width": content_width - TRAY_PAD * 2.0,
		"actions": actions, "primary": primary,
		"hint": Rect2(left, actions.position.y, BOOSTER_WIDTH, ACTION_HEIGHT),
		"undo": Rect2(left + content_width - BOOSTER_WIDTH, actions.position.y, BOOSTER_WIDTH, ACTION_HEIGHT),
	}


## 기기의 안전 영역을 논리 화면의 위아래 여백(위, 아래)으로 바꾼다.
##   safe: 가려지지 않는 영역(기기 픽셀). window: 창의 크기(기기 픽셀). logical_height: 논리 화면의 높이.
static func safe_insets(safe: Rect2i, window: Vector2i, logical_height: float) -> Vector2:
	if window.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var per_pixel: float = logical_height / float(window.y)
	return Vector2(maxf(0.0, safe.position.y) * per_pixel, maxf(0.0, window.y - safe.end.y) * per_pixel)


## 열에서 depth번째(0이 맨 뒤) 카드의 위쪽 y. 뒤집힌 카드가 줄면 맨 앞 카드가 그만큼 올라온다.
static func stack_y(layout: Dictionary, depth: int) -> float:
	return (layout["tableau"] as Rect2).position.y + depth * STACK_STEP


## 카드 줄을 뺀 고정 구역의 높이. comfort 0은 좁힌 값, 1은 넉넉한 값이다.
static func _fixed_height(comfort: float, deepest: int, reserve_rows: int) -> float:
	var total: float = HUD_HEIGHT + ACTION_HEIGHT + TAG_OFFSET + TAG_HEIGHT + LABEL_HEIGHT * 2.0 + deepest * STACK_STEP
	for key: String in FLEX:
		var value: float = lerpf(FLEX[key][0], FLEX[key][1], comfort)
		match key:
			"label_gap":
				total += value * 2.0
			"reserve_gap":
				total += value * (reserve_rows - 1)
			_:
				total += value
	return total
