extends RefCounted
## 제품의 SVG 그림을 화면 배율에 맞춰 다시 그려지는 DPITexture로 만든다.
## 기본 가져오기는 SVG를 1배 비트맵으로 바꿔서 2.5~3배 화면에서 가장자리가 흐려진다(docs/game-design/ui/notes/hidpi-art.md).
## 원문은 생성 도구(tools/art/build_candy_pop.py)가 만든 묶음에서 읽는다. 내보낸 앱에는 .svg 원본이 들어가지 않기 때문이다.

const PACK_PATH := "res://game/features/shared/svg_sources.json"
const PLAY := "res://game/features/play/assets/"
const OUTGAME := "res://game/features/outgame/assets/"
const SKIN := "res://game/skins/candy_pop/"

static var _sources: Dictionary = {}
static var _textures: Dictionary = {}


## 경로의 SVG로 만든 텍스처. 같은 경로는 한 번만 만든다. 묶음에 없는 경로면 오류를 남기고 가져온 텍스처를 돌려준다.
static func texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var made: Texture2D = null
	var source: String = _source(path)
	if not source.is_empty():
		made = DPITexture.create_from_string(source, 1.0)
	if made == null:
		push_error("SVG source is not in the pack: " + path)
		made = load(path)
	_textures[path] = made
	return made


## 플레이 화면 그림(features/play/assets)의 이름으로 찾는다.
static func play(name: String) -> Texture2D:
	return texture(PLAY + name + ".svg")


## 바깥 화면 그림(features/outgame/assets)의 이름으로 찾는다.
static func outgame(name: String) -> Texture2D:
	return texture(OUTGAME + name + ".svg")


## 스킨 그림(skins/candy_pop)의 이름으로 찾는다.
static func skin(name: String) -> Texture2D:
	return texture(SKIN + name + ".svg")


static func has_source(path: String) -> bool:
	return not _source(path).is_empty()


## 테마의 그림 판(StyleBoxTexture)을 같은 SVG의 DPITexture로 바꿔 끼운다. 테마가 다시 만들어질 때마다 부른다.
static func sharpen(theme: Theme) -> void:
	for type: String in theme.get_stylebox_type_list():
		for name: String in theme.get_stylebox_list(type):
			var box: StyleBoxTexture = theme.get_stylebox(name, type) as StyleBoxTexture
			if box == null or box.texture == null:
				continue
			var path: String = box.texture.resource_path
			if path.ends_with(".svg") and has_source(path):
				box.texture = texture(path)


## 그림 판 하나로 된 StyleBoxTexture. margins와 content는 좌, 상, 우, 하다.
static func box(tex: Texture2D, margins: Array, content: Array) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = float(margins[0])
	style.texture_margin_top = float(margins[1])
	style.texture_margin_right = float(margins[2])
	style.texture_margin_bottom = float(margins[3])
	style.content_margin_left = float(content[0])
	style.content_margin_top = float(content[1])
	style.content_margin_right = float(content[2])
	style.content_margin_bottom = float(content[3])
	return style


## 9분할 판. margins는 좌, 상, 우, 하(그림의 논리 픽셀)다. 입력은 받지 않는다.
static func plate(tex: Texture2D, margins: Array) -> NinePatchRect:
	var node := NinePatchRect.new()
	node.texture = tex
	node.patch_margin_left = int(margins[0])
	node.patch_margin_top = int(margins[1])
	node.patch_margin_right = int(margins[2])
	node.patch_margin_bottom = int(margins[3])
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## 고정 크기 그림. 크기를 주지 않으면 그림의 크기다. 입력은 받지 않는다.
static func picture(tex: Texture2D, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var node := TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = size if size != Vector2.ZERO else tex.get_size()
	return node


static func _source(path: String) -> String:
	if _sources.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_PATH))
		if parsed is Dictionary and parsed.get("sources") is Dictionary:
			_sources = parsed["sources"]
	return _sources.get(path, "")
