class_name Minimap
extends Control
## Mini-xarita: birliklar nuqta sifatida (ko'k — biz, qizil — dushman), kamera ko'rayotgan joy belgisi.
## Bosish/surish — kamerani o'sha joyga olib boradi.
## Bog'liqlik: Battle, RtsCamera.

const WORLD_HALF := 60.0

var battle: Battle


func _ready() -> void:
	custom_minimum_size = Vector2(170, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	return Vector2((p.x + WORLD_HALF) / (WORLD_HALF * 2.0) * size.x, (p.z + WORLD_HALF) / (WORLD_HALF * 2.0) * size.y)


func _to_world(m: Vector2) -> Vector3:
	return Vector3(m.x / size.x * WORLD_HALF * 2.0 - WORLD_HALF, 0, m.y / size.y * WORLD_HALF * 2.0 - WORLD_HALF)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.24, 0.13, 0.92), true)
	draw_rect(Rect2(size * 0.5 - size * 0.22, size * 0.44), Color(0.25, 0.34, 0.18, 0.9), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.83, 0.65, 0.23), false, 2.0)
	if battle == null or battle.sim == null:
		return
	if battle.fog != null and battle.fog.texture != null:
		draw_texture_rect(battle.fog.texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.85))
	for n in battle.sim.res_nodes:
		if not n.alive or not n.visible:
			continue
		if n.kind == "gold":
			draw_rect(Rect2(_to_map(n.sim_pos) - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.85, 0.2), true)
		else:
			draw_rect(Rect2(_to_map(n.sim_pos) - Vector2(1, 1), Vector2(2, 2)), Color(0.1, 0.35, 0.12), true)
	for u in battle.sim.units:
		if not u.alive or not u.visible:
			continue
		var c: Color = Color(0.35, 0.6, 1.0) if u.team == 0 else Color(1.0, 0.3, 0.25)
		if u.team == 2:
			c = Color(1.0, 0.75, 0.3) if u.invulnerable else Color(0.9, 0.55, 0.2)
		if u.is_hero():
			c = c.lightened(0.4)
		if u.selected:
			c = Color(0.6, 1.0, 0.6)
		var half: float = 2.5
		if u.is_building():
			half = max(3.5, u.radius * size.x / (WORLD_HALF * 2.0))
		draw_rect(Rect2(_to_map(u.sim_pos) - Vector2(half, half), Vector2(half, half) * 2.0), c, true)
	if battle.cam:
		var cp := _to_map(battle.cam.target)
		var view_half := Vector2(18, 12) * (battle.cam.distance / 24.0)
		draw_rect(Rect2(cp - view_half, view_half * 2.0), Color(1, 1, 1, 0.85), false, 1.5)


func _gui_input(event: InputEvent) -> void:
	if battle == null or battle.cam == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		battle.cam.focus(_to_world(event.position))
		accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		battle.cam.focus(_to_world(event.position))
		accept_event()
