extends Node
## O'yinning bosh boshqaruvchisi: menyu, kampaniya, qahramonlar zali, sozlamalar, mualliflar,
## tezkor jang, yuklanish ekrani, kino-sahnalar, saqlangan o'yinni davom ettirish.
## Bog'liqlik: MainMenu, CampaignScreen, HeroesHall, SettingsScreen, CreditsScreen, SkirmishSetup,
## LoadingScreen, CutscenePlayer, Battle, GameData, SaveSystem, Settings.

var _current: Node = null
var _busy: bool = false


func _ready() -> void:
	Settings.load_settings()
	Settings.apply_to_viewport(get_viewport())
	add_child(Audio.new())
	show_menu()


func _clear() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null


func show_menu() -> void:
	_clear()
	var menu := MainMenu.new()
	Audio.music("menu")
	_current = menu
	add_child(menu)
	menu.continue_pressed.connect(_continue_saved)
	menu.campaign_pressed.connect(show_campaign)
	menu.quick_pressed.connect(show_skirmish_setup)
	menu.heroes_pressed.connect(show_heroes)
	menu.settings_pressed.connect(show_settings)
	menu.credits_pressed.connect(show_credits)
	menu.intro_pressed.connect(_watch_intro)


func show_campaign() -> void:
	_clear()
	var cs := CampaignScreen.new()
	_current = cs
	add_child(cs)
	cs.back.connect(show_menu)
	cs.play.connect(_start_campaign)


func show_heroes() -> void:
	_clear()
	var hh := HeroesHall.new()
	_current = hh
	add_child(hh)
	hh.back.connect(show_menu)


func show_settings() -> void:
	_clear()
	var st := SettingsScreen.new()
	_current = st
	add_child(st)
	st.back.connect(show_menu)
	st.lang_changed.connect(_on_lang_changed)


func _on_lang_changed() -> void:
	call_deferred("show_settings")


func show_credits() -> void:
	_clear()
	var cr := CreditsScreen.new()
	_current = cr
	add_child(cr)
	cr.back.connect(show_menu)


func show_skirmish_setup() -> void:
	_clear()
	var ss := SkirmishSetup.new()
	_current = ss
	add_child(ss)
	ss.back.connect(show_menu)
	ss.start.connect(_start_skirmish)


func _skirmish_def(pf: String, ef: String, env: String, diff: String) -> Dictionary:
	var m: Dictionary = GameData.mission_def("quick").duplicate(true)
	m["player_faction"] = pf
	m["enemy_faction"] = ef
	m["env"] = env
	m["difficulty"] = diff
	m["auto_start"] = true
	return m


func _start_skirmish(pf: String, ef: String, env: String, diff: String = "orta") -> void:
	start_battle_def(_skirmish_def(pf, ef, env, diff), "quick", false)


func play_cutscene(id: String) -> void:
	var data := GameData.cutscene_def(id)
	if data.is_empty():
		return
	_clear()
	var cs := CutscenePlayer.new()
	Audio.music("menu")
	_current = cs
	add_child(cs)
	cs.play(data)
	await cs.finished


func _watch_intro() -> void:
	if _busy:
		return
	_busy = true
	await play_cutscene("intro")
	_busy = false
	show_menu()


func _start_campaign(mission_id: String) -> void:
	if _busy:
		return
	_busy = true
	var m: Dictionary = GameData.mission_def(mission_id).duplicate(true)
	# Tanlovlar (masalan, finalda saltanat va yakun)
	var choices = m.get("choices", [])
	if choices is Array:
		for c in choices:
			if not (c is Dictionary):
				continue
			var opts: Array = c.get("options", [])
			if opts.is_empty():
				continue
			_clear()
			var cs := ChoiceScreen.new()
			_current = cs
			add_child(cs)
			cs.setup(str(c.get("question", "")), opts)
			var idx: int = await cs.chosen
			var pick = opts[clampi(idx, 0, opts.size() - 1)]
			if pick is Dictionary and pick.get("set", null) is Dictionary:
				var st: Dictionary = pick["set"]
				for k in st.keys():
					m[k] = st[k]
	var intro := str(m.get("intro", ""))
	if intro != "":
		await play_cutscene(intro)
	_busy = false
	start_battle_def(m, mission_id, true)


func start_battle(mission_id: String, campaign: bool) -> void:
	start_battle_def(GameData.mission_def(mission_id), mission_id, campaign)


func start_battle_def(m: Dictionary, mission_id: String, campaign: bool, state: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	_clear()
	var ls := LoadingScreen.new()
	add_child(ls)
	ls.setup(str(m.get("title", "")))
	# Yuklanish ekrani chizilishi uchun ikki kadr kutamiz
	await get_tree().process_frame
	await get_tree().process_frame
	var b := Battle.new()
	b.mission_id = mission_id
	b.campaign_mode = campaign
	_current = b
	add_child(b)
	b.setup(m, state)
	var from_save: bool = not state.is_empty()
	b.finished.connect(func(victory: bool): _on_battle_finished(victory, mission_id, campaign, from_save))
	b.end_choice.connect(func(choice: String): _on_end_choice(choice, mission_id, campaign, m))
	await get_tree().process_frame
	ls.close()
	_busy = false


func _on_battle_finished(victory: bool, mission_id: String, campaign: bool, from_save: bool) -> void:
	if victory and campaign:
		SaveSystem.mark_completed(mission_id)
	if from_save:
		SaveSystem.delete_save()


func _continue_saved() -> void:
	var st := SaveSystem.read_save()
	if st.is_empty():
		SaveSystem.delete_save()
		show_menu()
		return
	var mid: String = str(st.get("mission_id", "quick"))
	var m: Dictionary = GameData.mission_def(mid).duplicate(true)
	if m.is_empty():
		SaveSystem.delete_save()
		show_menu()
		return
	var ov = st.get("overrides", {})
	if ov is Dictionary:
		for k in ov.keys():
			m[k] = ov[k]
	if mid == "quick":
		m["title"] = Loc.t("Tezkor jang")
	start_battle_def(m, mid, bool(st.get("campaign", false)), st)


func _on_end_choice(choice: String, mission_id: String, campaign: bool, m_def: Dictionary = {}) -> void:
	if _busy:
		return
	match choice:
		"continue":
			_busy = true
			var m: Dictionary = m_def if not m_def.is_empty() else GameData.mission_def(mission_id)
			var outro := str(m.get("outro", ""))
			if outro != "":
				await play_cutscene(outro)
			_busy = false
			var next_id := str(m.get("next", ""))
			if campaign and next_id != "" and not GameData.mission_def(next_id).is_empty():
				_start_campaign(next_id)
			else:
				show_menu()
		"retry":
			if not m_def.is_empty():
				start_battle_def(m_def, mission_id, campaign)
			else:
				start_battle(mission_id, campaign)
		_:
			show_menu()
