class_name DetRng
extends RefCounted
## Deterministic pseudo-random numbers keyed by (seed, purpose, number).
## Pure function: no global RNG and no state. The same inputs give the same
## output on every run and every platform, because the value comes from the
## SHA-256 of a fixed text key.

const _SCALE: float = 4503599627370496.0  # 2^52 (size of a 13-hex-digit prefix)


## Returns a float in [0, 1).
static func unit(seed_value: int, purpose: String, number: int) -> float:
	var key: String = "%d|%s|%d" % [seed_value, purpose, number]
	var prefix: String = key.sha256_text().substr(0, 13)
	return float(prefix.hex_to_int()) / _SCALE
