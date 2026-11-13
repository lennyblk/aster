extends Node3D
## Transparent copy of the car replaying a lap recorded by race.gd, with the player's name above it. It runs on the
## player's lap clock: it waits at the spawn until the first input, drives along, and goes back to the spawn on a reset.
## Hidden once its lap or the player's lap is over. No collision: the player drives through it.

const Race := preload("res://scripts/race.gd")
const COLOR := Color(0.45, 0.85, 1.0, 0.35)

var _race: Node
var _frames: PackedFloat32Array
var _count := 0


func setup(car: Node3D, race: Node, ghost: Dictionary) -> void:
	_race = race
	_frames = ghost.frames
	_count = _frames.size() / Race.GHOST_STRIDE
	top_level = true
	# moved every frame from the lap clock, which already gives smooth motion
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# the depth pre-pass keeps the inner faces hidden: a clean see-through silhouette instead of layered parts
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.albedo_color = COLOR
	var meshes: Array[Node] = car.get_node("aster").find_children("*", "MeshInstance3D", true, false)
	for wheel in car.get_children():
		if wheel is VehicleWheel3D:
			for child in wheel.get_children():
				if child is MeshInstance3D:
					meshes.append(child)
	var to_car := car.global_transform.affine_inverse()
	for source: MeshInstance3D in meshes:
		var copy := MeshInstance3D.new()
		copy.mesh = source.mesh
		copy.transform = to_car * source.global_transform
		copy.material_override = material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(copy)

	var label := Label3D.new()
	label.text = ghost.name
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3.UP * 1.5
	label.pixel_size = 0.008
	label.font = UIStyle.font(400, 2)
	label.font_size = 48
	label.outline_size = 0
	label.modulate = Color(COLOR, 0.8)
	add_child(label)

	Game.ghost_changed.connect(func(): if Game.ghost.is_empty(): queue_free())


func _process(_delta: float) -> void:
	if _count < 2 or not is_instance_valid(_race):
		visible = false
		return
	var t: float = _race.lap_time
	if _race.running:
		# the player's car is drawn between its last two physics steps (physics interpolation): match it
		t -= (1.0 - Engine.get_physics_interpolation_fraction()) / Engine.physics_ticks_per_second
	var f := maxf(t, 0.0) / Race.GHOST_RATE
	visible = not _race.finished and f <= _count - 1
	if not visible:
		return
	var i := mini(int(f), _count - 2)
	var w := f - i
	var a := i * Race.GHOST_STRIDE
	var b := a + Race.GHOST_STRIDE
	var pos := Vector3(_frames[a], _frames[a + 1], _frames[a + 2]).lerp(Vector3(_frames[b], _frames[b + 1], _frames[b + 2]), w)
	var qa := Quaternion(_frames[a + 3], _frames[a + 4], _frames[a + 5], _frames[a + 6]).normalized()
	var qb := Quaternion(_frames[b + 3], _frames[b + 4], _frames[b + 5], _frames[b + 6]).normalized()
	global_transform = Transform3D(Basis(qa.slerp(qb, w)), pos)
