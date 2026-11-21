extends RefCounted
## 꾸미기 테마의 모양: 카드 뒷면 그림과 배경 색. 가격과 목록은 코어(FaEconomy.THEMES)가 정본이고 여기서는 그리는 법만 안다.
## 지금 고른 테마는 bootstrap이 저장을 읽은 뒤와 상점에서 고른 뒤에 select()로 알린다. 새로 만드는 카드와 배경이 따른다.

const Art := preload("res://game/features/shared/fa_art.gd")

const CARD_BACK := "card_back"
const BACKGROUND := "background"

## 카드 뒷면: 테마 id → [판 그림, 무늬 그림](features/play/assets의 이름). 기본은 "".
const BACKS := {
	"": ["card_back", "card_back_dots"],
	"card_back_mint": ["card_back_mint", "card_back_mint_pattern"],
	"card_back_sunset": ["card_back_sunset", "card_back_sunset_pattern"],
	"card_back_night": ["card_back_night", "card_back_night_pattern"],
}
## 배경: 테마 id → [위, 가운데(46%), 아래] 색. 기본은 승인된 캔디 팝 배경이다.
const BACKGROUNDS := {
	"": ["58c4ff", "6e8cff", "a56bff"],
	"background_mint": ["5be3c8", "3fb6e6", "5a7bf0"],
	"background_peach": ["ffb980", "ff8fa3", "b580ff"],
	"background_night": ["4a4fc2", "2e2c86", "1d1650"],
}
## 테마 이름(영어, 한국어).
const NAMES := {
	CARD_BACK + ":": ["Candy Dots", "캔디 물방울"],
	BACKGROUND + ":": ["Candy Sky", "캔디 하늘"],
	"card_back_mint": ["Mint Stripes", "민트 줄무늬"],
	"card_back_sunset": ["Sunset Stars", "노을 별"],
	"card_back_night": ["Night Sparkle", "밤하늘 반짝이"],
	"background_mint": ["Mint Lagoon", "민트 바다"],
	"background_peach": ["Peach Sunset", "복숭아 노을"],
	"background_night": ["Starry Night", "별밤"],
}

static var card_back_id: String = ""
static var background_id: String = ""


## 고른 테마를 정한다. 모르는 id는 기본으로 본다.
static func select(card_back: String, background: String) -> void:
	card_back_id = card_back if BACKS.has(card_back) else ""
	background_id = background if BACKGROUNDS.has(background) else ""


## 카드 뒷면의 판과 무늬 그림. id를 주지 않으면 지금 고른 테마다.
static func back_plate(id: String = card_back_id) -> Texture2D:
	return Art.play(BACKS.get(id, BACKS[""])[0])


static func back_pattern(id: String = card_back_id) -> Texture2D:
	return Art.play(BACKS.get(id, BACKS[""])[1])


## 배경의 세 색(위, 가운데, 아래).
static func colors(id: String = background_id) -> PackedColorArray:
	var hexes: Array = BACKGROUNDS.get(id, BACKGROUNDS[""])
	return PackedColorArray([Color(hexes[0]), Color(hexes[1]), Color(hexes[2])])


## 테마 이름. 기본 테마는 종류를 함께 넘긴다.
static func theme_name(kind: String, id: String, language: String) -> String:
	var pair: Array = NAMES.get(id if not id.is_empty() else kind + ":", ["", ""])
	return pair[1] if language == "ko" else pair[0]
