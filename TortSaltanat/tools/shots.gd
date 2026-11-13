extends SceneTree
## CI uchun: o'yinni ochib, asosiy ekranlarning skrinshotlarini oladi (user://shots/*.png → ./shots).
## Ishga tushirish: xvfb-run godot --path . --rendering-driver opengl3 --script res://tools/shots.gd

var main: Node


func _init() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://shots")
	img.save_png("res://shots/%s.png" % name)
	print("SHOT ", name)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var ps: PackedScene = load("res://scenes/main.tscn")
	main = ps.instantiate()
	root.add_child(main)
	await _wait(90)
	await _shot("01_menu")
	main.show_campaign()
	await _wait(20)
	await _shot("02_campaign")
	main.show_skirmish_setup()
	await _wait(20)
	await _shot("03_skirmish")
	main.show_heroes()
	await _wait(30)
	var hh = main._current
	hh._pick_faction("trollar")
	await _wait(30)
	await _shot("04_heroes_troll")
	main._start_skirmish("trollar", "odamlar", "day", "orta")
	await _wait(200)
	var b = main._current
	if b != null and b.get("cam") != null:
		b.cam.focus(Vector3(-30, 0, 32), true)
		b.cam.distance = 14.0
	await _wait(30)
	await _shot("05_battle_troll")
	if b != null:
		var c := Vector3(-20, 0, 20)
		var ids := ["lava_ajdari", "zumrad_ajdar", "suyak_ajdar", "yovvoyi_ajdar", "tosh_manjaniq", "ildiz_manjaniq", "suyak_manjaniq", "ballista", "jang_fili", "kulrang_bori", "ulkan_ilon"]
		for i in ids.size():
			b.spawn_unit(ids[i], 0, c + Vector3((i % 4) * 4.0 - 6.0, 0, (i / 4) * 4.5 - 4.0))
		if b.fog != null:
			b.fog.reveal_all(0)
		b.cam.focus(c, true)
		b.cam.distance = 22.0
		await _wait(60)
		await _shot("07_new_units")
	main.show_settings()
	await _wait(20)
	await _shot("06_settings")
	quit(0)
