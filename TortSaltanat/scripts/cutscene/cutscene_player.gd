class_name CutscenePlayer
extends Node3D
## Kichik kino-sahnalar (filmchalar) o'ynatgichi. Sahna JSON fayldan o'qiladi (res://data/cutscenes/*.json):
## har bir "shot" — kamera harakati, aktyorlar (birliklar, kristall, tuman), harakatlar (yurish, hujum,
## parchalanish, chaqnash, silkinish, kulish), subtitrli dialoglar va katta sarlavhalar.
## Kino ko'rinishi uchun yuqori/pastki qora chiziqlar, qorong'ilashish va «O'tkazib yuborish» tugmasi bor.
## Bog'liqlik: WorldBuilder, UnitVisual, BuildingVisual, ResourceNode, GameData, UiStyle.

signal finished

const SHARD_COLORS := ["#3e7d3a", "#6a2c8a", "#2f8f7a", "#2d5fa8"]

var world: Dictionary = {}
var cam: Camera3D
var actors: Dictionary = {}

var _ui: CanvasLayer
var _fade: ColorRect
var _flash: ColorRect
var _title: Label
var _subtitle: Label
var _title_box: VBoxContainer
var _line_box: PanelContainer
var _speaker: Label
var _line: Label
var _skip: Button

var _skipped: bool = false
var _done: bool = false
var _shot_time: float = 0.0
var _pending: Array = []
var _cam_anim: Dictionary = {}
var _shake: float = 0.0
var _title_tween: Tween
var _line_tween: Tween


func play(data: Dictionary) -> void:
	_build_ui()
	world = WorldBuilder.build_environment(self, "dark")
	WorldBuilder.build_ground(self, world, 120.0, "dark", 3, true, 16.0)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 5, 12)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	_fade.color = Color(0, 0, 0, 1)
	_tween_fade(0.0, 0.9)
	var shots = data.get("shots", [])
	if shots is Array:
		for shot in shots:
			if _skipped or not is_inside_tree():
				break
			if shot is Dictionary:
				await _play_shot(shot)
	_end()


func skip() -> void:
	_skipped = true


func _end() -> void:
	if _done:
		return
	_done = true
	finished.emit.call_deferred()


# ---------------- Shot ----------------

func _play_shot(shot: Dictionary) -> void:
	_pending.clear()
	_shot_time = 0.0
	if shot.get("clear", true):
		_clear_actors()
	if shot.has("env"):
		WorldBuilder.apply_preset(world, str(shot["env"]))
	var spawns = shot.get("spawn", [])
	if spawns is Array:
		for s in spawns:
			if s is Dictionary:
				_spawn(s)
	var dur: float = float(shot.get("duration", 4.0))
	var c = shot.get("cam", {})
	if not (c is Dictionary):
		c = {}
	var from := GameData.vec3(c.get("from", null), Vector3(0, 5, 12))
	var look := GameData.vec3(c.get("look", null), Vector3(0, 1, 0))
	_cam_anim = {
		"from": from,
		"to": GameData.vec3(c.get("to", null), from),
		"look": look,
		"look_to": GameData.vec3(c.get("look_to", null), look),
		"fov": float(c.get("fov", 50.0)),
		"dur": max(dur, 0.1),
	}
	_update_cam()
	for key in ["actions", "lines"]:
		var arr = shot.get(key, [])
		if arr is Array:
			for item in arr:
				if item is Dictionary:
					_pending.append({"t": float(item.get("t", 0.0)), "kind": key, "data": item})
	var title = shot.get("title", null)
	if title is Dictionary:
		_pending.append({"t": float(title.get("t", 0.0)), "kind": "title", "data": title})
	_hide_line()
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	if _title_box:
		_title_box.modulate.a = 0.0
	if shot.get("fade_in", false):
		_fade.color.a = 1.0
		_tween_fade(0.0, 0.7)
	elif _fade.color.a > 0.5:
		_tween_fade(0.0, 0.5)
	_fire_due()
	while _shot_time < dur and not _skipped and is_inside_tree():
		await get_tree().process_frame
	if shot.get("fade_out", false) and not _skipped and is_inside_tree():
		_tween_fade(1.0, 0.6)
		var t := 0.0
		while t < 0.6 and not _skipped and is_inside_tree():
			await get_tree().process_frame
			t += get_process_delta_time()


func _process(delta: float) -> void:
	if _done:
		return
	_shot_time += delta
	_fire_due()
	_update_cam()
	_shake = max(0.0, _shake - delta * 1.5)
	for id in actors.keys():
		for n in actors[id]:
			if is_instance_valid(n) and n.has_meta("spin"):
				n.rotate_y(float(n.get_meta("spin")) * delta)


func _fire_due() -> void:
	var keep: Array = []
	for p in _pending:
		if float(p["t"]) <= _shot_time:
			match str(p["kind"]):
				"actions":
					_do_action(p["data"])
				"lines":
					_show_line(p["data"])
				"title":
					_show_title(p["data"])
		else:
			keep.append(p)
	_pending = keep


func _update_cam() -> void:
	if cam == null or _cam_anim.is_empty():
		return
	var k: float = clamp(_shot_time / float(_cam_anim["dur"]), 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)  # silliq (smoothstep)
	var from: Vector3 = _cam_anim["from"]
	var to: Vector3 = _cam_anim["to"]
	var la: Vector3 = _cam_anim["look"]
	var lb: Vector3 = _cam_anim["look_to"]
	var jitter := Vector3.ZERO
	if _shake > 0.0:
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	cam.position = from.lerp(to, k) + jitter
	cam.fov = float(_cam_anim["fov"])
	var target := la.lerp(lb, k)
	if cam.position.distance_to(target) > 0.01:
		cam.look_at(target, Vector3.UP)


# ---------------- Aktyorlar ----------------

func _clear_actors() -> void:
	for id in actors.keys():
		for n in actors[id]:
			if is_instance_valid(n):
				n.queue_free()
	actors.clear()


func _spawn(s: Dictionary) -> void:
	var kind := str(s.get("kind", "unit"))
	var id := str(s.get("id", kind))
	var pos := GameData.vec3(s.get("pos", null), Vector3.ZERO)
	var list: Array = []
	match kind:
		"unit":
			var look: Dictionary = {}
			var team_color := Color(0.8, 0.8, 0.8)
			if s.has("unit"):
				var d := GameData.unit_def(str(s["unit"]))
				var lk = d.get("look", {})
				if lk is Dictionary:
					look = lk.duplicate()
				var fd := GameData.faction_def(str(d.get("faction", "")))
				team_color = GameData.color(fd.get("color", ""), team_color)
			if s.has("faction"):
				var fd2 := GameData.faction_def(str(s["faction"]))
				team_color = GameData.color(fd2.get("color", ""), team_color)
			var extra = s.get("look", {})
			if extra is Dictionary:
				look.merge(extra, true)
			look["base"] = false
			var count := int(s.get("count", 1))
			var cols := int(s.get("cols", 4))
			var spacing := float(s.get("spacing", 1.6))
			for i in count:
				var v := UnitVisual.new()
				add_child(v)
				v.build(look, team_color, int(s.get("team", 0)))
				var row := i / cols
				var col := i % cols
				var n_cols: int = min(cols, count)
				v.position = pos + Vector3((col - (n_cols - 1) * 0.5) * spacing, 0, -row * spacing)
				list.append(v)
		"crystal":
			var cr := _make_crystal(float(s.get("size", 1.0)), GameData.color(s.get("color", ""), Color(1.0, 0.9, 0.55)))
			cr.position = pos
			list.append(cr)
		"mist":
			list.append(_make_mist(pos, float(s.get("radius", 6.0)), GameData.color(s.get("color", ""), Color(0.45, 0.2, 0.6))))
		"building":
			var bd := GameData.building_def(str(s.get("building", "")))
			var fdb := GameData.faction_def(str(bd.get("faction", "")))
			var bc := GameData.color(fdb.get("color", ""), Color(0.6, 0.6, 0.6))
			var bv := BuildingVisual.new()
			add_child(bv)
			bv.build_building(str(bd.get("style", "")), bc, int(s.get("team", 0)), float(bd.get("radius", 2.0)), str(bd.get("model", "")), float(bd.get("model_scale", 1.0)), float(bd.get("model_yaw", 0.0)), str(bd.get("tint", "")))
			bv.set_progress(float(s.get("progress", 1.0)))
			bv.position = pos
			list.append(bv)
		"gold":
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var gm := ResourceNode.new()
			add_child(gm)
			gm.setup("gold", pos, 1000, rng)
			list.append(gm)
		"forest":
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = int(s.get("seed", 9))
			var fr := float(s.get("radius", 5.0))
			for i in int(s.get("count", 12)):
				var a := rng2.randf() * TAU
				var rr := sqrt(rng2.randf()) * fr
				var t := ResourceNode.new()
				add_child(t)
				t.setup("wood", pos + Vector3(cos(a) * rr, 0, sin(a) * rr), 50, rng2)
				list.append(t)
		"light":
			var l := OmniLight3D.new()
			l.light_color = GameData.color(s.get("color", ""), Color(1, 0.9, 0.7))
			l.light_energy = float(s.get("energy", 2.0))
			l.omni_range = float(s.get("range", 10.0))
			add_child(l)
			l.position = pos
			list.append(l)
	if s.has("face"):
		var f := GameData.vec3(s["face"], Vector3.ZERO)
		for n in list:
			_face_node(n, f)
	elif s.has("yaw"):
		for n in list:
			n.rotation.y = deg_to_rad(float(s["yaw"]))
	if s.has("spin"):
		for n in list:
			n.set_meta("spin", float(s["spin"]))
	actors[id] = list


func _make_crystal(size: float, c: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6 * size
	sm.height = 1.2 * size
	sm.radial_segments = 4
	sm.rings = 2
	mi.mesh = sm
	mi.scale = Vector3(1, 1.7, 1)
	mi.material_override = UnitVisual.mat(c, 2.5)
	root.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 2.5
	l.omni_range = 9.0 * size
	root.add_child(l)
	return root


func _make_mist(pos: Vector3, r: float, c: Color) -> Node3D:
	var p := CPUParticles3D.new()
	p.amount = 70
	p.lifetime = 4.0
	p.preprocess = 4.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(r, 0.4, r)
	p.direction = Vector3(0, 1, 0)
	p.spread = 40.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.05, 0)
	p.scale_amount_min = 1.2
	p.scale_amount_max = 3.0
	p.mesh = UnitVisual.sphere(0.5, 6)
	p.material_override = UnitVisual.mat(Color(c.r, c.g, c.b, 0.22), 0.6, true, true)
	add_child(p)
	p.position = pos
	return p


func _face_node(n: Node3D, target: Vector3) -> void:
	var d := target - n.position
	if Vector2(d.x, d.z).length() > 0.01:
		n.rotation.y = atan2(d.x, d.z)


func _center(nodes: Array) -> Vector3:
	var c := Vector3.ZERO
	if nodes.is_empty():
		return c
	for n in nodes:
		c += n.position
	return c / nodes.size()


func _do_action(a: Dictionary) -> void:
	var id := str(a.get("actor", ""))
	var nodes: Array = actors.get(id, [])
	var dur: float = float(a.get("dur", 1.5))
	match str(a.get("do", "")):
		"walk_to", "fly_to":
			var to := GameData.vec3(a.get("to", null), Vector3.ZERO)
			var center := _center(nodes)
			var walking: bool = str(a.get("do", "")) == "walk_to"
			for n in nodes:
				if not is_instance_valid(n):
					continue
				var dest: Vector3 = to + (n.position - center)
				if walking:
					_face_node(n, dest)
				if n is UnitVisual and walking:
					n.moving = true
				var tw: Tween = n.create_tween()
				tw.tween_property(n, "position", dest, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT if not walking else Tween.EASE_OUT)
				if n is UnitVisual:
					var v: UnitVisual = n
					tw.tween_callback(func(): v.moving = false)
		"face":
			var to2 := GameData.vec3(a.get("to", null), Vector3.ZERO)
			for n in nodes:
				if is_instance_valid(n):
					_face_node(n, to2)
		"attack":
			var times := int(a.get("times", 1))
			for n in nodes:
				if is_instance_valid(n) and n is UnitVisual:
					var v2: UnitVisual = n
					var tw2 := v2.create_tween()
					tw2.tween_interval(randf_range(0.0, 0.25))
					for i in times:
						tw2.tween_callback(func(): v2.play_attack(false))
						tw2.tween_interval(0.75)
		"die":
			for n in nodes:
				if is_instance_valid(n) and n is UnitVisual:
					n.play_death()
		"spin":
			for n in nodes:
				if is_instance_valid(n):
					n.set_meta("spin", float(a.get("speed", 1.0)))
		"rise":
			for n in nodes:
				if is_instance_valid(n):
					n.create_tween().tween_property(n, "position:y", float(a.get("y", 2.0)), dur).set_trans(Tween.TRANS_SINE)
		"hide":
			for n in nodes:
				if is_instance_valid(n):
					n.visible = false
		"show":
			for n in nodes:
				if is_instance_valid(n):
					n.visible = true
		"laugh":
			for n in nodes:
				if is_instance_valid(n):
					var tw3: Tween = n.create_tween()
					var base: Vector3 = n.scale
					for i in 4:
						tw3.tween_property(n, "scale", base * Vector3(1.04, 1.1, 1.04), 0.14)
						tw3.tween_property(n, "scale", base, 0.14)
			_shake = max(_shake, 0.25)
		"shatter":
			for n in nodes:
				if is_instance_valid(n):
					n.visible = false
					_shatter_from(n.position)
			_flash_screen()
			_shake = max(_shake, 1.2)
		"flash":
			_flash_screen()
		"shake":
			_shake = max(_shake, float(a.get("amount", 0.6)))


func _shatter_from(origin: Vector3) -> void:
	var shards: Array = []
	for i in 4:
		var c := Color.html(SHARD_COLORS[i])
		var sh := _make_crystal(0.4, c)
		sh.position = origin
		sh.set_meta("spin", 3.0)
		var ang := TAU * i / 4.0 + PI * 0.25
		var dest := origin + Vector3(cos(ang) * 14.0, 3.0, sin(ang) * 14.0)
		var tw := sh.create_tween()
		tw.tween_property(sh, "position", dest, 2.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		shards.append(sh)
	actors["shards"] = shards


# ---------------- Interfeys ----------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.theme = UiStyle.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := ColorRect.new()
	top.color = Color.BLACK
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	var bottom := ColorRect.new()
	bottom.color = Color.BLACK
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -64

	_title_box = VBoxContainer.new()
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title_box)
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title = UiStyle.label("", 54, Color(1.0, 0.84, 0.35))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override("outline_size", 10)
	_subtitle = UiStyle.label("", 26, Color(0.95, 0.92, 0.85))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(_title)
	_title_box.add_child(_subtitle)
	_title_box.modulate.a = 0.0

	_line_box = PanelContainer.new()
	_line_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_line_box)
	_line_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_line_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_line_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_line_box.offset_bottom = -80
	var vb := VBoxContainer.new()
	_line_box.add_child(vb)
	_speaker = UiStyle.label("", 22, Color(1.0, 0.82, 0.3))
	_line = UiStyle.label("", 23)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(860, 0)
	vb.add_child(_speaker)
	vb.add_child(_line)
	_line_box.visible = false

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_skip = UiStyle.button("O'tkazib yuborish »", Vector2(230, 48))
	root.add_child(_skip)
	_skip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -12
	_skip.offset_top = 8
	_skip.pressed.connect(skip)


func _tween_fade(alpha: float, time: float) -> void:
	if _fade == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)


func _flash_screen() -> void:
	if _flash == null:
		return
	_flash.color.a = 0.9
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.8)


func _show_line(l: Dictionary) -> void:
	var speaker := str(l.get("speaker", ""))
	var text := str(l.get("text", ""))
	_line_box.visible = true
	_speaker.text = Loc.t(speaker)
	_speaker.visible = speaker != ""
	_line.text = text
	_line.visible_ratio = 0.0
	if _line_tween and _line_tween.is_valid():
		_line_tween.kill()
	_line_tween = create_tween()
	_line_tween.tween_property(_line, "visible_ratio", 1.0, clamp(text.length() * 0.028, 0.3, 3.0))


func _hide_line() -> void:
	if _line_box:
		_line_box.visible = false


func _show_title(t: Dictionary) -> void:
	_title.text = Loc.t(str(t.get("text", "")))
	_subtitle.text = Loc.t(str(t.get("sub", "")))
	var hold := float(t.get("hold", 2.5))
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	_title_box.modulate.a = 0.0
	_title_tween = create_tween()
	_title_tween.tween_property(_title_box, "modulate:a", 1.0, 0.7)
	_title_tween.tween_interval(hold)
	_title_tween.tween_property(_title_box, "modulate:a", 0.0, 0.7)
