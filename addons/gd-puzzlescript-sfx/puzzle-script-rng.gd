# implementation derived from the RC4-based PRNG used in PuzzleScript by increpare https://github.com/increpare/PuzzleScript
class_name PuzzleScriptRNG
extends RefCounted

const DENOMINATOR: float = pow(2, 56) - 1

class RC4:
	extends RefCounted

	var s: Array[int] = []
	var i: int = 0
	var j: int = 0

	func _init(seed: String) -> void:
		s.resize(256)
		for n in range(256):
			s[n] = n
		mix(seed)

	func _swap(a: int, b: int) -> void:
		var tmp := s[a]
		s[a] = s[b]
		s[b] = tmp

	static func string_get_bytes_js_style(text: String) -> Array[int]:
		var output: Array[int] = []

		for idx in range(text.length()):
			var c := text.unicode_at(idx)
			var bytes: Array[int] = []

			while true:
				bytes.append(c & 0xFF)
				c >>= 8
				if c <= 0:
					break

			bytes.reverse()
			output.append_array(bytes)

		return output

	func mix(seed: String) -> void:
		var input := string_get_bytes_js_style(seed)
		var local_j := 0

		for idx in range(256):
			local_j += s[idx] + input[idx % input.size()]
			local_j %= 256
			_swap(idx, local_j)

	func next_byte() -> int:
		i = (i + 1) % 256
		j = (j + s[i]) % 256
		_swap(i, j)
		return s[(s[i] + s[j]) % 256]


var _state: RC4


## PuzzleScript generates numerical strings as seeds, so pass in the seed number as a string
func _init(seed: String) -> void:
	_state = RC4.new(seed)


func _next_byte() -> int:
	return _state.next_byte()


func uniform() -> float:
	var output := 0.0

	for _n in range(7):
		output *= 256.0
		output += float(_next_byte())

	return output / DENOMINATOR

static func test_example() -> void:
	var rng = PuzzleScriptRNG.new("Example")
	var _discard: float = rng.uniform()

	var example_result: float = 0.7972798995050903
	var second_out: float = rng.uniform()
	assert(second_out == example_result, "first output of 'Example' seed should be %s, got %s" % [String.num(example_result, 18), String.num(second_out, 18)])