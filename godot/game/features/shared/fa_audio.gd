extends Node
## 제품 효과음과 배경음악, 진동. 효과음은 SFX 버스, 음악은 Music 버스로 내보내고 끄기는 버스 음소거(공통 설정)가 맡는다.
## 오디오 장치가 없는 headless 검수에서는 요청만 세고 재생하지 않는다.

const SFX_DIR := "res://game/assets/audio/sfx/"
const BGM_PATH := "res://game/assets/audio/bgm_main.ogg"
## 음악은 효과음보다 8dB 낮게 둔다.
const MUSIC_DB := -8.0
## 오답의 진동 두 번 사이 간격(초).
const DOUBLE_PULSE_GAP := 0.09

## 이름별 재생 요청 수와 요청한 진동 길이(ms). 여정이 소리와 진동이 불렸는지 볼 때 쓴다.
var plays: Dictionary = {}
var haptics: Array[int] = []
## 설정의 진동. 꺼져 있으면 진동을 요청하지 않는다.
var vibration: bool = true
var enabled: bool = true

var _players: Dictionary = {}
var _music: AudioStreamPlayer
var _music_holds: Dictionary = {}


func _ready() -> void:
	enabled = AudioServer.get_driver_name() != "Dummy"


## 효과음을 낸다. name은 sfx 폴더의 파일 이름(확장자 없이), pitch는 음높이 배율이다.
func play(sfx_name: String, pitch: float = 1.0) -> void:
	plays[sfx_name] = int(plays.get(sfx_name, 0)) + 1
	if not enabled:
		return
	var player: AudioStreamPlayer = _players.get(sfx_name)
	if player == null:
		var stream: AudioStream = load(SFX_DIR + sfx_name + ".wav")
		if stream == null:
			return
		player = AudioStreamPlayer.new()
		player.stream = stream
		player.bus = _bus("SFX")
		add_child(player)
		_players[sfx_name] = player
	player.pitch_scale = pitch
	player.play()


func play_count(sfx_name: String) -> int:
	return int(plays.get(sfx_name, 0))


## 진동 한 번(ms). 설정에서 껐으면 아무 일도 하지 않는다.
func vibrate(milliseconds: int) -> void:
	if not vibration:
		return
	haptics.append(milliseconds)
	Input.vibrate_handheld(milliseconds)


## 짧은 진동 두 번(오답).
func vibrate_twice(milliseconds: int) -> void:
	vibrate(milliseconds)
	if vibration and is_inside_tree():
		get_tree().create_timer(DOUBLE_PULSE_GAP).timeout.connect(vibrate.bind(milliseconds))


## 배경음악을 반복 재생한다. 반복은 가져오기 설정에 기대지 않고 재생 전에 켠다.
func start_music() -> void:
	plays["bgm_main"] = int(plays.get("bgm_main", 0)) + 1
	if not enabled or (_music != null and _music.playing):
		return
	if _music == null:
		var stream: AudioStreamOggVorbis = load(BGM_PATH)
		if stream == null:
			return
		stream.loop = true
		_music = AudioStreamPlayer.new()
		_music.stream = stream
		_music.bus = _bus("Music")
		_music.volume_db = MUSIC_DB
		add_child(_music)
	_music.play()
	_music.stream_paused = not _music_holds.is_empty()


## 음악을 잠시 멈추거나 다시 잇는다. reason별로 따로 세어, 광고와 앱 전환이 겹쳐도 모두 풀려야 다시 나온다.
func hold_music(reason: String, held: bool) -> void:
	if held:
		_music_holds[reason] = true
	else:
		_music_holds.erase(reason)
	if _music != null:
		_music.stream_paused = not _music_holds.is_empty()


func music_held() -> bool:
	return not _music_holds.is_empty()


func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
	if _music != null:
		_music.stop()


func _bus(bus_name: String) -> String:
	return bus_name if AudioServer.get_bus_index(bus_name) != -1 else "Master"
