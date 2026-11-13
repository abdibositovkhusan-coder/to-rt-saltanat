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
	main.show_settings()
	await _wait(20)
	await _shot("06_settings")
	quit(0)
