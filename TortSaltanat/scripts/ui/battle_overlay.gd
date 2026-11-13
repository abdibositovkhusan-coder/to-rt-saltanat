class_name BattleOverlay
extends Control
## Ekran ustiga chiziladigan qatlam: birliklarning sog'liq chiziqlari va ramka bilan tanlash to'rtburchagi.
## Bog'liqlik: Battle (birliklar ro'yxati va kamera).

var battle: Battle
var box: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if battle == null or battle.sim == null or battle.cam == null or battle.cam.cam == null:
		return
	var c3: Camera3D = battle.cam.cam
	var w: float = clamp(1100.0 / max(battle.cam.distance, 1.0), 26.0, 64.0)
	var h: float = 6.0
	for u in battle.sim.units:
		if not u.alive or not u.visible:
			continue
		if u.team != 0 and not u.fog_visible:
			continue
		if u.invulnerable:
			continue
		var wp: Vector3 = u.global_position + Vector3(0, u.bar_height, 0)
		if c3.is_position_behind(wp):
			continue
		var sp: Vector2 = c3.unproject_position(wp)
		var bw: float = w * 2.0 if u.is_building() else w
		var r := Rect2(sp.x - bw * 0.5, sp.y - h * 0.5, bw, h)
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.7), true)
		var ratio: float = u.hp_ratio()
		var col: Color = Color(0.35, 0.9, 0.3) if u.team == 0 else Color(0.95, 0.3, 0.25)
		if u.team == 0 and ratio < 0.35:
			col = Color(1.0, 0.75, 0.2)
		draw_rect(Rect2(r.position, Vector2(bw * ratio, h)), col, true)
		if u.selected:
			draw_rect(r.grow(2.5), Color(1, 1, 1, 0.9), false, 1.5)
		if u.is_hero():
			var mr := Rect2(r.position + Vector2(0, h + 2), Vector2(bw, 4))
			draw_rect(mr.grow(1.0), Color(0, 0, 0, 0.7), true)
			draw_rect(Rect2(mr.position, Vector2(bw * clamp(u.mana / max(u.max_mana, 1.0), 0.0, 1.0), 4)), Color(0.35, 0.55, 1.0), true)
			draw_string(ThemeDB.fallback_font, Vector2(r.position.x - 16, r.position.y + 8), str(u.level), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.9, 0.4))
		if u.is_building() and u.team == 0:
			var extra: float = -1.0
			var ec := Color(1.0, 0.8, 0.25)
			if not u.complete:
				extra = u.progress
			elif not u.queue.is_empty():
				extra = u.current_train_ratio()
				ec = Color(0.45, 0.75, 1.0)
			if extra >= 0.0:
				var r2 := Rect2(r.position + Vector2(0, h + 3), Vector2(bw, 5))
				draw_rect(r2.grow(1.0), Color(0, 0, 0, 0.7), true)
				draw_rect(Rect2(r2.position, Vector2(bw * extra, 5)), ec, true)
	if box.size.x > 2 and box.size.y > 2:
		draw_rect(box, Color(0.4, 1.0, 0.4, 0.15), true)
		draw_rect(box, Color(0.5, 1.0, 0.5, 0.95), false, 2.0)
