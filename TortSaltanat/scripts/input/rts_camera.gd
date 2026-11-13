class_name RtsCamera
extends Node3D
## Izometrik RTS kamerasi: nishon nuqta atrofida burchak ostida turadi, siljitish (pan),
## yaqinlashtirish (zoom), silliq harakat va xarita chegaralari. Ekran nuqtasini yerga proyeksiya qiladi.
## Bog'liqlik: yo'q (TouchController va Minimap boshqaradi).

var cam: Camera3D
var target: Vector3 = Vector3.ZERO
var distance: float = 24.0
var min_distance: float = 9.0
var max_distance: float = 48.0
var pitch_deg: float = 52.0
var yaw_deg: float = 40.0
var bound: float = 52.0

var _shown_target: Vector3 = Vector3.ZERO
var _shown_distance: float = 24.0
var _shake: float = 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_shown_target = target
	_shown_distance = distance
	_apply()


func focus(pos: Vector3, instant: bool = false) -> void:
	target = _clamp(pos)
	if instant:
		_shown_target = target


func pan_by_world(delta_world: Vector3) -> void:
	target = _clamp(target + Vector3(delta_world.x, 0, delta_world.z))
	_shown_target = target
	_apply()


func zoom_by(factor: float) -> void:
	distance = clamp(distance * factor, min_distance, max_distance)


func shake(amount: float) -> void:
	_shake = max(_shake, amount)


func ground_point(screen_pos: Vector2):
	if cam == null:
		return null
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)


## Barmoq bilan surishda: oldingi va hozirgi ekran nuqtalari orasidagi yer farqi.
func drag_pan(prev_screen: Vector2, cur_screen: Vector2) -> void:
	var a = ground_point(prev_screen)
	var b = ground_point(cur_screen)
	if a == null or b == null:
		return
	pan_by_world(a - b)


func _process(delta: float) -> void:
	_shown_target = _shown_target.lerp(target, clamp(delta * 12.0, 0.0, 1.0))
	_shown_distance = lerp(_shown_distance, distance, clamp(delta * 10.0, 0.0, 1.0))
	_shake = max(0.0, _shake - delta * 2.0)
	_apply()


func _apply() -> void:
	if cam == null:
		return
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _shown_distance
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.4
	cam.position = _shown_target + offset + jitter
	cam.look_at(_shown_target + jitter, Vector3.UP)


func _clamp(p: Vector3) -> Vector3:
	return Vector3(clamp(p.x, -bound, bound), 0.0, clamp(p.z, -bound, bound))
