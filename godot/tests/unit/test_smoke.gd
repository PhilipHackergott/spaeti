extends "res://tests/TestCase.gd"
## Proves the runner itself works. Keep.

func test_runner_alive() -> void:
	assert_eq(2 + 2, 4, "arithmetic")
	assert_true(Engine.get_version_info()["major"] == 4, "godot 4")
