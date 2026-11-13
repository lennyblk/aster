extends CanvasLayer
## In-game controls reminder (top left). Shows keyboard keys or controller buttons depending on the
## last device used. Fully visible when a run starts, then dims.

const KEYBOARD := [
	["Z Q S D", "DRIVE"],
	["SPACE", "HANDBRAKE"],
	["SHIFT", "BOOST"],
	["MOUSE", "CAMERA"],
	["R", "RESET CAR"],
	["N", "NEXT TRACK"],
	["ESC", "MENU  /  SETTINGS"],
]
const GAMEPAD := [
	["RT", "ACCELERATE"],
	["X", "REVERSE"],
	["LT", "HANDBRAKE"],
	["A", "BOOST"],
	["L STICK", "STEER"],
	["R STICK", "CAMERA"],
	["Y", "RESET CAR"],
	["RB", "NEXT TRACK"],
	["START", "MENU  /  SETTINGS"],
]

var _box: VBoxContainer
var _tween: Tween


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = VBoxContainer.new()
	_box.position = Vector2(12, 10)
	_box.add_theme_constant_override("separation", 3)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_fill(Game.using_gamepad)
	visible = false
	Game.state_changed.connect(_on_state)
	Game.input_device_changed.connect(_on_device)
	Game.ghost_changed.connect(func(): _fill(Game.using_gamepad))
	_on_state(Game.state)


func _fill(gamepad: bool) -> void:
	for child in _box.get_children():
		child.queue_free()
	var controls: Array = (GAMEPAD if gamepad else KEYBOARD).duplicate()
	if not Game.ghost.is_empty():
		controls.insert(controls.size() - 1, ["LB" if gamepad else "E", "REMOVE GHOST"])
	for c in controls:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(UIStyle.keycap(c[0]))
		var l := Label.new()
		l.text = c[1]
		l.label_settings = UIStyle.label(7, UIStyle.DIM, 0.0, 400, 1)
		row.add_child(l)
		_box.add_child(row)


func _on_device(gamepad: bool) -> void:
	_fill(gamepad)
	if visible:
		_reveal()


func _on_state(state: Game.State) -> void:
	var was_hidden := not visible
	visible = state == Game.State.PLAYING
	if visible and was_hidden:
		_reveal()


func _reveal() -> void:
	if _tween:
		_tween.kill()
	_box.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(6.0)
	_tween.tween_property(_box, "modulate:a", 0.35, 2.0)
