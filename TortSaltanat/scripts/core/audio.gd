class_name Audio
extends Node
## Ovoz tizimi: effektlar (SFX) va musiqa. Main bir marta yaratadi; boshqa skriptlar
## statik funksiyalar orqali chaqiradi: Audio.play("hit"), Audio.play_at("sword", pos), Audio.music("elflar").
## Ovozlar assets/audio ichida (tools/synth.py bilan noldan sintez qilingan, original).
## Bir xil ovoz juda tez-tez takrorlanmaydi (telefonda 50 askar urishsa ham quloq charchamaydi).
## Bog'liqlik: Settings (Music va SFX shinalari).

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL := 10
const MIN_GAP := {"hit": 0.07, "sword": 0.07, "arrow": 0.09, "death": 0.12, "magic": 0.12, "explosion": 0.15, "click": 0.03}
const MUSIC_VOL := {"menu": 0.0, "odamlar": -2.0, "trollar": -2.0, "elflar": -4.0, "yalmogiz": 0.0}

static var inst: Audio = null

var _players: Array = []
var _next: int = 0
var _streams: Dictionary = {}
var _last_play: Dictionary = {}
var _music: AudioStreamPlayer
var _music_name: String = ""


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music.finished.connect(_on_music_finished)


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	_streams[path] = s
	return s


func _play(snd: String, vol_db: float, pitch: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var gap: float = float(MIN_GAP.get(snd, 0.05))
	if now - float(_last_play.get(snd, -10.0)) < gap:
		return
	_last_play[snd] = now
	var s := _stream(SFX_DIR + snd + ".wav")
	if s == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## Interfeys va umumiy ovozlar.
static func play(snd: String, vol_db: float = 0.0) -> void:
	if inst == null:
		return
	inst._play(snd, vol_db, randf_range(0.96, 1.04))


## Jang ovozi: faqat kamera yaqinida va o'yinchi ko'rib turgan joyda eshitiladi.
static func play_at(snd: String, pos: Vector3, sim = null) -> void:
	if inst == null:
		return
	if sim != null and sim.fog != null and not sim.fog.sees(0, pos):
		return
	var cam := inst.get_viewport().get_camera_3d()
	var vol: float = -2.0
	if cam != null:
		var flat := Vector2(cam.global_position.x - pos.x, cam.global_position.z - pos.z).length()
		if flat > 55.0:
			return
		vol = -2.0 - flat * 0.25
	inst._play(snd, vol, randf_range(0.9, 1.1))


static func music(track: String) -> void:
	if inst == null or inst._music_name == track:
		return
	inst._music_name = track
	var s := inst._stream(MUSIC_DIR + track + ".wav")
	if s == null:
		inst._music.stop()
		return
	inst._music.stream = s
	inst._music.volume_db = float(MUSIC_VOL.get(track, 0.0)) - 6.0
	inst._music.play()


func _on_music_finished() -> void:
	if _music.stream != null:
		_music.play()
