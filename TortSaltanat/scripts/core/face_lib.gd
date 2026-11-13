class_name FaceLib
extends RefCounted
## Do'stlar yuzlari: rasm qo'yilsa, qahramon ustida dumaloq portret (medalyon) va
## Qahramonlar Zalida ko'rinadi. Rasm qayerdan olinadi (birinchi topilgani):
##   1) telefonda: user://faces/<qahramon_id>.png yoki .jpg
##   2) loyihada:  res://assets/faces/<qahramon_id>.png yoki .jpg
## Masalan: assets/faces/husan.png, saidxon.png, ulugbek.png, olimxon.png.
## Bog'liqlik: yo'q.

const SIZE := 128
static var _cache: Dictionary = {}


static func _load_image(id: String) -> Image:
	for base in ["user://faces/", "res://assets/faces/"]:
		for ext in [".png", ".jpg", ".jpeg"]:
			var path: String = base + id + ext
			if base.begins_with("user://"):
				if FileAccess.file_exists(path):
					var img := Image.load_from_file(path)
					if img != null and not img.is_empty():
						return img
			elif ResourceLoader.exists(path):
				var tex = load(path)
				if tex is Texture2D:
					var im: Image = tex.get_image()
					if im != null and not im.is_empty():
						return im
	return null


## Dumaloq, oltin hoshiyali portret. Rasm bo'lmasa null.
static func face(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var src := _load_image(id)
	if src == null:
		_cache[id] = null
		return null
	if src.is_compressed():
		src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var side: int = mini(src.get_width(), src.get_height())
	var crop := src.get_region(Rect2i((src.get_width() - side) / 2, (src.get_height() - side) / 4, side, side))
	crop.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	var c: float = (SIZE - 1) * 0.5
	var r_out: float = SIZE * 0.5 - 1.0
	var r_in: float = r_out - 6.0
	var gold := Color(0.83, 0.65, 0.23)
	for y in SIZE:
		for x in SIZE:
			var d: float = Vector2(x - c, y - c).length()
			if d > r_out:
				crop.set_pixel(x, y, Color(0, 0, 0, 0))
			elif d > r_in:
				crop.set_pixel(x, y, gold)
	var tex := ImageTexture.create_from_image(crop)
	_cache[id] = tex
	return tex


## Qahramon ustiga medalyon qo'yadi (Sprite3D, doim kameraga qaragan).
static func attach_badge(u: Node3D, id: String, height: float) -> void:
	var tex := face(id)
	if tex == null:
		return
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = 0.0075
	s.no_depth_test = false
	s.position = Vector3(0, height + 0.75, 0)
	s.name = "FaceBadge"
	u.add_child(s)
