class_name Rng
extends RefCounted
## Deterministic PRNG (mulberry32) — the ONLY source of randomness in the engine, so a season is fully
## reproducible from { config, seed, action-log }. The state is a single uint32 kept *in* SpatiState
## (`rng_state`) and threaded through every action; an Rng instance is a short-lived view over it.
## Port of app/src/engine/rng.ts — the bit arithmetic below reproduces JS semantics exactly:
## GDScript ints are 64-bit, so every intermediate is masked back to 32 bits and multiplication is
## split into halves (a full 32x32 product would overflow int64).

const MASK: int = 0xFFFFFFFF
const TWO32: float = 4294967296.0

var _a: int = 0

static func create(seed_value: int) -> Rng:
	var r := Rng.new()
	r._a = seed_value & MASK
	return r

## Re-open a generator on a stored state (SpatiState.rng_state).
static func from_state(state_value: int) -> Rng:
	return Rng.create(state_value)

## 32-bit multiply with JS `Math.imul` semantics (mod 2^32), split to dodge int64 overflow.
static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := (a & 0xFFFF) * b
	var hi := ((a >> 16) * b) & 0xFFFF
	return (lo + (hi << 16)) & MASK

func next() -> float:
	_a = (_a + 0x6d2b79f5) & MASK
	var t := Rng.imul(_a ^ (_a >> 15), 1 | _a)
	t = ((t + Rng.imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
	t &= MASK
	return float(t ^ (t >> 14)) / TWO32

## Integer in [0, max_exclusive).
func randi_below(max_exclusive: int) -> int:
	return int(next() * float(max_exclusive))

## Float in [min_value, max_value).
func range(min_value: float, max_value: float) -> float:
	return min_value + next() * (max_value - min_value)

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[int(next() * float(arr.size()))]

## Weighted pick: the index chosen proportional to `weights` (negatives count as 0).
func weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += maxf(0.0, float(w))
	if total <= 0.0:
		return 0
	var r := next() * total
	for i in weights.size():
		r -= maxf(0.0, float(weights[i]))
		if r < 0.0:
			return i
	return weights.size() - 1

## Current serializable state (uint32).
func state() -> int:
	return _a & MASK
