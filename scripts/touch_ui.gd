extends CanvasLayer
class_name TouchUI
## On-screen controls: floating move stick (left), drag-to-look (right), action buttons.

signal jump_pressed
signal reload_pressed
signal swap_pressed

var move_vec: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var fire_held: bool = false
var aim_held: bool = false

const STICK_RADIUS := 110.0

var _canvas: Control
var _buttons: Dictionary = {}
var _finger_button: Dictionary = {}   # finger index -> button name
var _move_finger: int = -1
var _look_finger: int = -1
var _stick_origin: Vector2 = Vector2.ZERO
var _stick_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_buttons = {
		"FIRE": {"c": Vector2(s.x - 170, s.y - 170), "r": 85.0},
		"AIM": {"c": Vector2(s.x - 330, s.y - 110), "r": 55.0},
		"JUMP": {"c": Vector2(s.x - 90, s.y - 330), "r": 50.0},
		"RELOAD": {"c": Vector2(s.x - 300, s.y - 260), "r": 48.0},
		"SWAP": {"c": Vector2(s.x - 440, s.y - 190), "r": 48.0},
	}


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


func consume_look() -> Vector2:
	var d: Vector2 = look_delta
	look_delta = Vector2.ZERO
	return d


func _button_at(p: Vector2) -> String:
	for b in _buttons:
		var info: Dictionary = _buttons[b]
		if p.distance_to(info["c"]) <= float(info["r"]) + 12.0:
			return b
	return ""


func _press_button(b: String, finger: int) -> void:
	_finger_button[finger] = b
	match b:
		"FIRE": fire_held = true
		"AIM": aim_held = true
		"JUMP": jump_pressed.emit()
		"RELOAD": reload_pressed.emit()
		"SWAP": swap_pressed.emit()


func _release_finger(finger: int) -> void:
	if _finger_button.has(finger):
		var b: String = _finger_button[finger]
		_finger_button.erase(finger)
		if b == "FIRE":
			fire_held = false
		elif b == "AIM":
			aim_held = false
	if finger == _move_finger:
		_move_finger = -1
		move_vec = Vector2.ZERO
	if finger == _look_finger:
		_look_finger = -1


func _input(event: InputEvent) -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var b: String = _button_at(t.position)
			if b != "":
				_press_button(b, t.index)
			elif t.position.x < w * 0.4 and _move_finger == -1:
				_move_finger = t.index
				_stick_origin = t.position
				_stick_pos = t.position
			elif t.position.x >= w * 0.4 and _look_finger == -1:
				_look_finger = t.index
		else:
			_release_finger(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _move_finger:
			_stick_pos = d.position
			move_vec = ((d.position - _stick_origin) / STICK_RADIUS).limit_length(1.0)
		elif d.index == _look_finger:
			look_delta += d.relative
		elif _finger_button.get(d.index, "") == "FIRE":
			look_delta += d.relative


func _on_draw() -> void:
	var white := Color(1, 1, 1, 0.35)
	var fill := Color(1, 1, 1, 0.08)
	if _move_finger != -1:
		_canvas.draw_circle(_stick_origin, STICK_RADIUS, fill)
		_canvas.draw_arc(_stick_origin, STICK_RADIUS, 0.0, TAU, 48, white, 3.0)
		_canvas.draw_circle(_stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS), 36.0, Color(1, 1, 1, 0.3))
	else:
		var s: Vector2 = get_viewport().get_visible_rect().size
		_canvas.draw_arc(Vector2(190, s.y - 190), STICK_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.15), 3.0)
	var font: Font = ThemeDB.fallback_font
	for b in _buttons:
		var info: Dictionary = _buttons[b]
		var c: Vector2 = info["c"]
		var r: float = info["r"]
		var active: bool = (b == "FIRE" and fire_held) or (b == "AIM" and aim_held)
		var col: Color = Color(1.0, 0.5, 0.1, 0.55) if active else Color(1, 1, 1, 0.12)
		_canvas.draw_circle(c, r, col)
		_canvas.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0)
		var fs: int = 26 if b == "FIRE" else 18
		var ts: Vector2 = font.get_string_size(b, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_canvas.draw_string(font, c + Vector2(-ts.x / 2.0, fs * 0.35), b, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.85))
