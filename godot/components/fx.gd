class_name Fx
extends Control
## The feedback layer: the Session event stream turned into one-frame-cheap, code-drawn pops.
## Session.event fires for every new log entry in order (docs/05 §7, kinds: open · arrive · serve ·
## tip · balk · pfand · ethics · beat · check · upgrade · ordnungsamt · raid · close); a screen connects the
## signal straight to `on_event`. Everything here is a ColorRect on the pixel grid — no texture, no
## audio yet, so it works before the art and the sound passes land (docs/04 rule 3).
##
## Nothing in here reads or writes game state: an FX that failed to play must never change a night.

## Where a kind pops when the caller does not say (base pixels, 480×270).
const ANCHORS := {
	"serve": Vector2(250, 196),      # over the counter, where the goods land
	"tip": Vector2(268, 192),
	"pfand": Vector2(150, 198),      # the crate side of the counter
	"arrive": Vector2(250, 120),     # over the customer's head
	"balk": Vector2(250, 120),
	"ethics": Vector2(250, 150),
	"upgrade": Vector2(240, 150),
	"raid": Vector2(240, 150),
	"ordnungsamt": Vector2(240, 150),
	# A stat check (docs/06 section 2): under the d20 pop's own plate, so the burst and the number
	# that explains it are the same place on the screen.
	"check": Vector2(407, 88),
}

const LIFE := 0.55
const RISE := 12.0

var _rng := RandomNumberGenerator.new()
## The `data` of the entry currently being played. A check's burst is green or red, and the only place
## that verdict exists is the log row — `play(kind, at)` on its own can still be called without it.
var _last_data: Dictionary = {}

func _ready() -> void:
	Palette.prepare()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 90210

## `entry` is one `log` row: {ts, kind, text, data}.
func on_event(entry: Dictionary) -> void:
	_last_data = entry.get("data", {})
	play(String(entry.get("kind", "")), Vector2.ZERO)
	_last_data = {}

## `at == Vector2.ZERO` uses the kind's anchor. Unknown kinds are silently ignored — the log grows
## faster than this layer does, and a missing pop is never a bug worth a crash.
func play(kind: String, at: Vector2 = Vector2.ZERO) -> void:
	if not is_inside_tree() or Palette.reduce_motion:
		return
	var origin: Vector2 = at if at != Vector2.ZERO else ANCHORS.get(kind, Vector2.ZERO)
	if origin == Vector2.ZERO:
		return
	match kind:
		"serve":
			_coin(origin)
		"tip":
			_coin(origin + Vector2(6, -4))
			_coin(origin - Vector2(6, 0))
		"pfand":
			_clink(origin)
		"arrive":
			_chime(origin)
		"balk":
			_puff(origin)
		"ethics", "raid", "ordnungsamt":
			_puff(origin)
		"upgrade":
			_chime(origin)
		"check":
			_dice(origin, bool((_last_data.get("success", false))))

# ── the four pops ─────────────────────────────────────────────────────────────────────────────

## A coin: a 3-px amber square that hops up and fades — the "money landed" tick.
func _coin(at: Vector2) -> void:
	_dot(at, Vector2(3, 3), Palette.AMBER_SOFT, -RISE, LIFE)
	_dot(at + Vector2(2, -3), Vector2(1, 1), Palette.TEXT_WHITE, -RISE * 0.7, LIFE * 0.8)

## A bottle clink: two cyan ticks that spread sideways — the Pfand crate answering back.
func _clink(at: Vector2) -> void:
	_dot(at + Vector2(-3, 0), Vector2(2, 2), Palette.PFAND, -4.0, LIFE * 0.7, -7.0)
	_dot(at + Vector2(3, 0), Vector2(2, 2), Palette.PFAND, -4.0, LIFE * 0.7, 7.0)

## A soft chime: three 1-px motes drifting up — someone stepped to the counter.
func _chime(at: Vector2) -> void:
	for i in 3:
		var dx := float(i - 1) * 4.0
		_dot(at + Vector2(dx, float(i) * 2.0), Vector2(1, 1), Palette.AMBER, -RISE - float(i) * 3.0, LIFE + float(i) * 0.1)

## A d20 landing: four accent ticks thrown outward from the die, tinted by the verdict. The NUMBER is
## the DiceResult component's job — this is only the "something was rolled" jolt.
func _dice(at: Vector2, success: bool) -> void:
	var colour := Palette.GOOD if success else Palette.BAD
	_dot(at, Vector2(3, 3), Palette.ACCENT, -RISE * 0.8, LIFE)
	_dot(at + Vector2(-5, 1), Vector2(2, 2), colour, -5.0, LIFE * 0.8, -8.0)
	_dot(at + Vector2(5, 1), Vector2(2, 2), colour, -5.0, LIFE * 0.8, 8.0)
	_dot(at + Vector2(0, 3), Vector2(1, 1), Palette.TEXT_WHITE, -RISE, LIFE * 0.7)

## A grey puff: something went wrong (a balk, a fine, a raid).
func _puff(at: Vector2) -> void:
	_dot(at, Vector2(3, 3), Palette.TEXT_DIM, -6.0, LIFE * 0.8)
	_dot(at + Vector2(-4, 2), Vector2(2, 2), Palette.TEXT_DIM, -4.0, LIFE * 0.6, -5.0)

## One mote: an integer-positioned ColorRect that rises, drifts and fades, then frees itself.
func _dot(at: Vector2, dot_size: Vector2, colour: Color, rise: float, life: float, drift: float = 0.0) -> void:
	var r := ColorRect.new()
	r.color = colour
	r.size = dot_size
	r.custom_minimum_size = dot_size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Palette.snap(at)
	add_child(r)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(_move_dot.bind(r, r.position, Vector2(drift, rise)), 0.0, 1.0, life)
	tw.tween_property(r, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(_kill.bind(r))

## Motes stay on whole pixels: the grid survives the animation (docs/01 pixel discipline).
func _move_dot(t: float, r: ColorRect, from: Vector2, delta: Vector2) -> void:
	if is_instance_valid(r):
		r.position = Palette.snap(from + delta * t)

func _kill(r: Node) -> void:
	if is_instance_valid(r):
		r.queue_free()
