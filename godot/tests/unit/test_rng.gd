extends "res://tests/TestCase.gd"
## Rng must reproduce the TypeScript prototype's mulberry32 stream bit-for-bit — the whole
## replay-from-seed guarantee rests on it.

func test_matches_reference_stream() -> void:
	var r := Rng.create(1)
	var expected := [0.6270739405881613, 0.002735721180215478, 0.5274470399599522,
		0.9810509674716741, 0.9683778982143849, 0.281103502959013]
	for i in expected.size():
		assert_almost(r.next(), float(expected[i]), 1e-12, "seed 1 draw %d" % i)
	var r2 := Rng.create(12345)
	var expected2 := [0.9797282677609473, 0.3067522644996643, 0.484205421525985]
	for i in expected2.size():
		assert_almost(r2.next(), float(expected2[i]), 1e-12, "seed 12345 draw %d" % i)

func test_state_round_trip() -> void:
	var a := Rng.create(7)
	for i in 5:
		a.next()
	var b := Rng.from_state(a.state())
	for i in 5:
		assert_almost(a.next(), b.next(), 1e-15, "resumed stream matches")

func test_range_and_pick_in_bounds() -> void:
	var r := Rng.create(99)
	for i in 200:
		var v := r.range(2.0, 5.0)
		assert_true(v >= 2.0 and v < 5.0, "range in bounds")
	var arr := ["a", "b", "c"]
	var seen := {}
	for i in 200:
		seen[r.pick(arr)] = true
	assert_eq(seen.size(), 3, "pick reaches every element")

func test_weighted_index_distribution() -> void:
	var r := Rng.create(4242)
	var counts := [0, 0, 0]
	for i in 3000:
		counts[r.weighted_index([0.0, 1.0, 3.0])] += 1
	assert_eq(counts[0], 0, "zero weight never picked")
	# 1:3 split — allow generous slack, this is a sanity check not a statistics exam.
	assert_true(counts[1] > 500 and counts[1] < 1000, "1:3 split lower bucket, got %d" % counts[1])
	assert_true(counts[2] > 2000, "1:3 split upper bucket, got %d" % counts[2])
	assert_eq(r.weighted_index([0.0, 0.0]), 0, "all-zero weights falls back to 0")
