extends RefCounted
## Base class for unit tests. Put tests in tests/unit/test_*.gd:
##   extends "res://tests/TestCase.gd"
##   func test_something() -> void: assert_eq(2 + 2, 4, "arithmetic")
## Run: node tools/godot/test.mjs   (or: godot --headless --path godot --script res://tests/run.gd)

var _fails: Array[String] = []
var _asserts: int = 0

func assert_true(cond: bool, msg: String = "") -> void:
	_asserts += 1
	if not cond:
		_fails.append("assert_true failed: " + msg)

func assert_false(cond: bool, msg: String = "") -> void:
	_asserts += 1
	if cond:
		_fails.append("assert_false failed: " + msg)

func assert_eq(a, b, msg: String = "") -> void:
	_asserts += 1
	if a != b:
		_fails.append("assert_eq failed: %s | got %s expected %s" % [msg, str(a), str(b)])

func assert_ne(a, b, msg: String = "") -> void:
	_asserts += 1
	if a == b:
		_fails.append("assert_ne failed: %s | both %s" % [msg, str(a)])

func assert_almost(a: float, b: float, eps: float = 0.000001, msg: String = "") -> void:
	_asserts += 1
	if absf(a - b) > eps:
		_fails.append("assert_almost failed: %s | got %f expected %f" % [msg, a, b])

func fail(msg: String) -> void:
	_asserts += 1
	_fails.append("fail: " + msg)
