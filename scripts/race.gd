extends Node
## Lap timing on a looped track (added by track.gd in game). Only one lap counts: the clock starts with the first input
## after the spawn or a reset (the lap also covers the short run-up to the line) and stops at the line. The lap only
## counts if the car went through the checkpoints at 25 %, 50 % and 75 % of the loop. Afterwards the player drives
## freely until the next reset. The lap is recorded for the ghost (see ghost.gd).

const CHECKPOINTS := [0.25, 0.5, 0.75]
const START_ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "boost"]
const GHOST_RATE := 0.05        # seconds between two recorded frames
const GHOST_STRIDE := 7         # floats per frame: position x y z, rotation quaternion x y z w
const GHOST_MAX_TIME := 600.0   # keeps the upload small: a longer lap is only recorded up to here

var track: Node          # track.gd
var line_index := 0      # road sample of the finish line
var running := false
var finished := false    # the lap is done: nothing is timed until the next reset
var lap_time := 0.0
var ghost_frames := PackedFloat32Array()

var _car: VehicleBody3D
var _passed: Array[bool] = []
var _last_rel := -1
var _track_half_width := 10.0
var _next_frame := 0.0


func setup(owner_track: Node, finish_index: int) -> void:
	track = owner_track
	line_index = finish_index
	_track_half_width = track.road_width * 0.5 + track.verge_width


func _ready() -> void:
	_car = track.get_node_or_null("Car/Car")
	if _car:
		_car.car_reset.connect(_reset)
	_passed.resize(CHECKPOINTS.size())
	Game.race = self
	if _car and not Game.ghost.is_empty() and Game.ghost.map == Game.current_map:
		var ghost: Node3D = load("res://scripts/car/ghost.gd").new()
		ghost.setup(_car, self, Game.ghost)
		track.add_child(ghost)


func _exit_tree() -> void:
	if Game.race == self:
		Game.race = null


func _physics_process(delta: float) -> void:
	if _car == null or Game.state != Game.State.PLAYING:
		return
	if not running and not finished:
		for action in START_ACTIONS:
			if Input.is_action_pressed(action):
				_start()
				break
	if running:
		_record_frame()
		lap_time += delta

	track._find_nearest(_car.global_position.x, _car.global_position.z)
	if track._nearest_dist > _track_half_width + 20.0:
		return   # far off the road: keep the last known progress
	var n: int = track.samples.size()
	var rel: int = (track._nearest_index - line_index + n) % n

	if running:
		for i in CHECKPOINTS.size():
			var at := int(CHECKPOINTS[i] * n)
			if not _passed[i] and rel >= at and rel < at + n / 10:
				_passed[i] = true
	# crossing the line forward = progress wraps from the end of the loop to its start
	if _last_rel >= 0 and _last_rel > n * 0.9 and rel < n * 0.1:
		_cross_line()
	_last_rel = rel


func _record_frame() -> void:
	if lap_time < _next_frame or lap_time > GHOST_MAX_TIME:
		return
	var p := _car.global_position
	var q := _car.global_basis.get_rotation_quaternion()
	ghost_frames.append_array([p.x, p.y, p.z, q.x, q.y, q.z, q.w])
	_next_frame += GHOST_RATE


func _cross_line() -> void:
	if not running:
		return
	if not _passed.all(func(p): return p):
		return   # did not go around the whole loop (shortcut or reversing over the line)
	running = false
	finished = true
	var previous_best: float = Game.best_time(Game.current_map)
	var rank := Game.add_lap_time(Game.current_map, lap_time)
	if rank == 1:
		Game.save_ghost(Game.current_map, ghost_frames)
	Game.lap_completed.emit(lap_time, rank, previous_best)


func _start() -> void:
	running = true
	finished = false
	lap_time = 0.0
	_passed.fill(false)
	ghost_frames.clear()
	_next_frame = 0.0
	Game.race_started.emit()


func _reset() -> void:
	running = false
	finished = false
	lap_time = 0.0
	_passed.fill(false)
	_last_rel = -1
	ghost_frames.clear()
	_next_frame = 0.0
	Game.race_reset.emit()
