class_name FaRandom
extends RefCounted
## 시드로 정해지는 난수열(Mulberry32). 엔진 난수기에 기대지 않고 32비트 정수 연산만 써서
## 기기와 엔진 버전이 달라도 같은 시드에서 같은 값이 나온다.

const MASK := 0xFFFFFFFF

var _state: int = 0


func _init(seed_value: int) -> void:
	_state = (seed_value ^ (seed_value >> 32)) & MASK


## 0 이상 2^32 미만의 다음 값.
func next_u32() -> int:
	_state = (_state + 0x6D2B79F5) & MASK
	var mixed: int = _multiply(_state ^ (_state >> 15), _state | 1)
	mixed = (mixed ^ (mixed + _multiply(mixed ^ (mixed >> 7), mixed | 61))) & MASK
	return mixed ^ (mixed >> 14)


## 0 이상 bound 미만의 정수. bound는 1 이상 2^31 미만이다.
func below(bound: int) -> int:
	return (next_u32() * bound) >> 32


## 배열을 제자리에서 섞는다(피셔-예이츠).
func shuffle(list: Array) -> void:
	for index: int in range(list.size() - 1, 0, -1):
		var other: int = below(index + 1)
		var kept: Variant = list[index]
		list[index] = list[other]
		list[other] = kept


## 32비트 곱의 아래 32비트. 64비트 정수가 넘치지 않게 위아래 16비트로 나눠 곱한다.
static func _multiply(a: int, b: int) -> int:
	return ((a & 0xFFFF) * b + ((((a >> 16) * b) & 0xFFFF) << 16)) & MASK
