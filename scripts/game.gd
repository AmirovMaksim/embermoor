extends Node
## Автозагрузка: состояние игры, ввод, процедурный звук и музыка.

signal stats_changed
signal quest_changed
signal toast(text: String)

var main: Node3D
var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer

var rng := RandomNumberGenerator.new()

var max_hp := 100.0
var hp := 100.0
var max_st := 100.0
var st := 100.0
var xp := 0.0
var level := 1
var coins := 0
var potions := 2
var sword_tier := 0
var relic := false
var kills := 0

# Квесты: 0 нет, 1 слаймы, 2 возврат, 3 голем, 4 возврат, 5 победа
var quest_state := 0
var quest_kills := 0
var slime_goal := 6
var golem_dead := false

var dialogue_open := false
var shop_open := false
var skills_open := false
var game_started := false
var start_time_ms := 0
var dlg_closed_ms := 0
var shake_amt := 0.0

# Древо навыков
var skill_points := 0
var skills := {"wind": 0, "fury": 0, "life": 0}
const SKILL_TREE := {
	"wind": {"name": "ВЕТЕР", "desc": "+8% к скорости за уровень"},
	"fury": {"name": "ЯРОСТЬ", "desc": "+10% к урону за уровень"},
	"life": {"name": "ЖИЗНЬ", "desc": "+15 к здоровью за уровень"},
}

# Продолжение сюжета: 6 найди Мору, 7 светогрибы, 8 Хранитель, 9 финал
# Тайна портала: 10 магма, 11 мороз, 12 к Море, 13 портал, 14 легенда
var mush_collected := 0
var grove_shrine_taken := false
var guardian_dead := false
var witch_rewarded := false

# Настройки нового мира и графики
var difficulty := "normal"
var player_class := "warrior"
var world_size := 1.0
var world_seed := 0
var gfx := {"shadows": 2, "msaa": 2, "glow": true, "ssao": true, "fog": true, "view_distance": 2, "fullscreen": false}
var defeated_bosses: Array = []

# Охота (доска заданий)
var bounty_kind := ""
var bounty_goal := 0
var bounty_count := 0
var bounties_done := 0
const BOUNTY_NAMES := {"slime": "слаймов", "imp": "огненных бесов", "swamp": "болотных тварей", "frost_slime": "ледяных слизней", "skeleton": "скелетов"}
var lore_found := 0

const LORE_STONES := {
	"village": ["ОСТРОВ ЭМБЕРМУР", "Остров Эмбермур держится на равновесии четырёх стихий: Огня, Льда, Болота и Земли. Древние каменотёсы заперли их силы в сердцах-кристаллах и поставили Големов стражами. Пока сердца спят — остров жив."],
	"meadow": ["ЭХО СТИХИЙ", "Слаймы — не звери, а эхо стихий, сошедшее с гор. Чем ярче их окрас, тем чище была стихия в месте их рождения. Зелёные помнят траву, фиолетовые — шёпот топей."],
	"ruins": ["КАМЕНОТЁСЫ", "Здесь древние каменотёсы лепили Големов из живого камня. Их последний шедевр — Каменный Голем — должен был охранять руины вечно. Вечность оказалась длиннее их памяти."],
	"swamp": ["МОРА И ХРАНИТЕЛЬ", "Мора — последняя ведьма Эмбермура. Она слепила Хранителя Топей из болотной тины и грибного мицелия, чтобы тот берёг светогрибы. Иногда она называет его «моей самой большой ошибкой»."],
	"ashen": ["ОКО ОГНЯ", "Когда-то сюда упало Око Огня — осколок сердца стихии. Пепел здесь не остывает сотню лет, а Магмовый Голем вылез из земли сам, без всякого мастера. Огонь помнит, что его разбудили."],
	"frost": ["СЕРДЦЕ ЛЬДА", "В толще Ледяных пиков бьётся Сердце Льда. Старики говорили: положи ладонь на лёд — и услышишь медленный стук, раз в полночь. Морозный Голем не пускает к нему даже ветер."],
	"portal": ["ВРАТА МЕЖДУМИРЬЯ", "Врата стояли до острова. Каменотёсы не строили их — они нашли. Когда равновесие стихий нарушено, вуаль истончается, и сквозь неё дует ветром из чужих миров."],
}

const PORTAL_FINALE := "Вуаль расходится, и ты видишь: за порталом — тот же остров, но живой. Сердца стихий пульсируют в лад, Големы спят мирным сном, а Врата Междумирья наконец-то молчат.\n\nТы вложил четыре сердца в равновесие. Древние назвали бы тебя Хранителем Эмбермура.\n\nСпасибо, что играл. Остров запомнит."

const DIFFS := {
	"easy": {"name": "Легко", "dmg": 0.7, "hp": 0.8, "coins": 1.4},
	"normal": {"name": "Нормально", "dmg": 1.0, "hp": 1.0, "coins": 1.0},
	"hard": {"name": "Сложно", "dmg": 1.35, "hp": 1.35, "coins": 0.9},
}
const CLASSES := {
	"warrior": {"name": "Воин", "dmg": 1.15, "hp": 1.0, "speed": 1.0, "st": 1.0},
	"rogue": {"name": "Разбойник", "dmg": 0.9, "hp": 0.85, "speed": 1.12, "st": 1.35},
	"paladin": {"name": "Паладин", "dmg": 0.95, "hp": 1.3, "speed": 0.95, "st": 1.1},
}
const SWORD_NAMES := ["Ржавый клинок", "Железный клинок", "Стальной клинок", "Клинок углей"]
const SWORD_COLORS := [Color("#8a6a4a"), Color("#b9c2cc"), Color("#dfe8f2"), Color("#ff9d3b")]
const SWORD_COSTS := [25, 60, 120]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	load_settings()
	_setup_input()
	_setup_audio()

func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"gfx": gfx, "difficulty": difficulty, "player_class": player_class, "world_size": world_size}))

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data == null or not data is Dictionary:
		return
	if data.has("gfx") and data["gfx"] is Dictionary:
		for k in gfx:
			if data["gfx"].has(k):
				gfx[k] = data["gfx"][k]
	if data.has("difficulty") and DIFFS.has(data["difficulty"]):
		difficulty = data["difficulty"]
	if data.has("player_class") and CLASSES.has(data["player_class"]):
		player_class = data["player_class"]
	if data.has("world_size"):
		world_size = float(data["world_size"])

func reset() -> void:
	max_hp = 100.0
	hp = 100.0
	max_st = 100.0
	st = 100.0
	xp = 0.0
	level = 1
	coins = 0
	potions = 2
	sword_tier = 0
	relic = false
	kills = 0
	quest_state = 0
	quest_kills = 0
	golem_dead = false
	dialogue_open = false
	shop_open = false
	skills_open = false
	game_started = false
	shake_amt = 0.0
	skill_points = 0
	skills = {"wind": 0, "fury": 0, "life": 0}
	mush_collected = 0
	grove_shrine_taken = false
	guardian_dead = false
	witch_rewarded = false
	lore_found = 0
	defeated_bosses = []
	bounty_kind = ""
	bounty_goal = 0
	bounty_count = 0
	bounties_done = 0

func buy_skill(branch: String) -> bool:
	var lvl: int = skills[branch]
	if lvl >= 3 or skill_points < 1:
		return false
	skill_points -= 1
	skills[branch] = lvl + 1
	if branch == "life":
		max_hp += 15.0
		heal(15.0)
	sfx("levelup", -10.0, 1.35)
	stats_changed.emit()
	return true

func diff_mult_dmg() -> float: return DIFFS[difficulty]["dmg"]
func diff_mult_hp() -> float: return DIFFS[difficulty]["hp"]
func diff_mult_coins() -> float: return DIFFS[difficulty]["coins"]
func class_mult(stat: String) -> float: return CLASSES[player_class][stat]

func apply_class_stats() -> void:
	max_hp = 100.0 * class_mult("hp")
	max_st = 100.0 * class_mult("st")
	hp = max_hp
	st = max_st
	stats_changed.emit()

## Настройки графики применяются к живому миру.
func apply_gfx() -> void:
	if world and is_instance_valid(world):
		if world.sun:
			match int(gfx["shadows"]):
				0:
					world.sun.shadow_enabled = false
				1:
					world.sun.shadow_enabled = true
					world.sun.directional_shadow_max_distance = 55.0
				2:
					world.sun.shadow_enabled = true
					world.sun.directional_shadow_max_distance = 90.0
				_:
					world.sun.shadow_enabled = true
					world.sun.directional_shadow_max_distance = 145.0
		if world.env:
			world.env.glow_enabled = bool(gfx["glow"])
			world.env.ssao_enabled = bool(gfx["ssao"])
			world.env.fog_enabled = bool(gfx["fog"])
	if world and is_instance_valid(world) and world.sky_mat:
		pass
	get_viewport().msaa_3d = int(gfx["msaa"])
	if bool(gfx["fullscreen"]):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	apply_view_distance()

func apply_view_distance() -> void:
	var dists := [45.0, 72.0, 110.0]
	var d: float = dists[int(gfx["view_distance"])]
	for n in get_tree().get_nodes_in_group("cull_small"):
		Assets._apply_cull_rec(n, d)

# --- сохранения ---
func has_save() -> bool:
	return FileAccess.file_exists("user://save.json")

func save_game(player_pos: Vector3, tod: float, chests_opened: Array) -> void:
	var data := {
		"seed": world_seed, "pos": [player_pos.x, player_pos.y, player_pos.z], "tod": tod,
		"hp": hp, "max_hp": max_hp, "st": st, "max_st": max_st, "xp": xp, "level": level,
		"coins": coins, "potions": potions, "sword_tier": sword_tier, "skill_points": skill_points,
		"skills": skills, "quest_state": quest_state, "quest_kills": quest_kills,
		"mush_collected": mush_collected, "grove_shrine_taken": grove_shrine_taken,
		"golem_dead": golem_dead, "guardian_dead": guardian_dead,
		"witch_rewarded": witch_rewarded, "lore_found": lore_found, "kills": kills,
		"bounty_kind": bounty_kind, "bounty_goal": bounty_goal, "bounty_count": bounty_count,
		"bounties_done": bounties_done, "defeated": defeated_bosses, "chests": chests_opened,
		"difficulty": difficulty, "player_class": player_class, "world_size": world_size,
	}
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_save() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if data == null or not data is Dictionary:
		return {}
	return data

func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute("user://save.json")

# --- охота ---
func new_bounty() -> void:
	var pool := ["slime", "imp", "swamp", "frost_slime", "skeleton"]
	bounty_kind = pool[rng.randi() % pool.size()]
	bounty_goal = 3 + rng.randi() % 4
	bounty_count = 0

func speed_mult() -> float:
	return 1.0 + 0.08 * skills["wind"]

func dmg_mult() -> float:
	return 1.0 + 0.10 * skills["fury"]

func sword_damage() -> float:
	return (11.0 + 7.0 * sword_tier + 1.5 * (level - 1)) * dmg_mult()

func xp_next() -> float:
	return 30.0 + 22.0 * (level - 1)

func add_xp(v: float) -> void:
	xp += v
	while xp >= xp_next():
		xp -= xp_next()
		level += 1
		max_hp += 12.0
		hp = max_hp
		skill_points += 1
		if player and is_instance_valid(player) and player.has_method("level_up_fx"):
			player.level_up_fx()
		sfx("levelup", -2.0)
		notify("Уровень %d! +1 очко навыка [M]" % level)
	stats_changed.emit()

func add_coins(v: int) -> void:
	coins += v
	sfx("coin", -6.0, rng.randf_range(0.95, 1.08))
	stats_changed.emit()

func heal(v: float) -> void:
	hp = minf(hp + v, max_hp)
	stats_changed.emit()

func spend_st(v: float) -> bool:
	if st < v:
		return false
	st = maxf(st - v, 0.0)
	return true

func damage_player(dmg: float, from: Vector3) -> void:
	if player and is_instance_valid(player) and player.has_method("hurt"):
		player.hurt(dmg, from)

func on_enemy_killed(kind: String) -> void:
	kills += 1
	if kind == "slime" and quest_state == 1:
		quest_kills += 1
		if quest_kills >= slime_goal:
			set_quest(2)
		else:
			quest_changed.emit()
	if kind == "golem":
		golem_dead = true
		notify("Каменный Голем повержен!")
		if quest_state == 3:
			set_quest(4)
	if kind == "guardian":
		guardian_dead = true
		if quest_state == 8:
			set_quest(9)
			notify("Хранитель повержен! Вернись к Море")
	if kind == "magma_golem":
		if quest_state == 10:
			set_quest(11)
			notify("Огненное сердце добыто! Теперь — Морозный Голем")
	if kind == "frost_golem":
		if quest_state == 11:
			set_quest(12)
			notify("Ледяное сердце добыто! Вернись к Море")
	if bounty_kind != "" and kind == bounty_kind and bounty_count < bounty_goal:
		bounty_count += 1
		if bounty_count >= bounty_goal:
			notify("Охота выполнена! Вернись к доске заданий")

func set_quest(s: int) -> void:
	quest_state = s
	match s:
		1: notify("Задание: убей %d слаймов на лугу" % slime_goal)
		2: notify("Задание выполнено! Вернись к старейшине")
		3: notify("Задание: победи Каменного Голема в руинах")
		4: notify("Вернись к старейшине с победой")
		6: notify("Найди ведьму Мору на северо-западе")
		7: notify("Собери светогрибы для Моры")
		8: notify("Победи Хранителя Топей в глубине леса")
		9: notify("Ты — легенда Эмбермура!")
		10: notify("Победи Магмового Голема в Пепельных пустошах (восток)")
		11: notify("Победи Морозного Голема в Ледяных пиках (север)")
		12: notify("Вернись к Море с сердцами стихий")
		13: notify("Портал активен! Иди к Вратам на юге")
		14: notify("Ты — Хранитель Эмбермура!")
	quest_changed.emit()
	if game_started and main and is_instance_valid(main) and main.has_method("save_now"):
		main.save_now()

## Микрозамедление времени для сочности ударов.
func hitstop(t := 0.05) -> void:
	Engine.time_scale = 0.12
	var tw := create_tween()
	tw.tween_interval(t)
	tw.tween_callback(func(): Engine.time_scale = 1.0)

func drink_potion() -> bool:
	if potions <= 0:
		return false
	if hp >= max_hp:
		return false
	potions -= 1
	heal(45.0)
	sfx("potion", -3.0)
	return true

func notify(t: String) -> void:
	toast.emit(t)

func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)

func _process(delta: float) -> void:
	shake_amt = maxf(shake_amt - delta * 2.6, 0.0)

func dmg_number(pos: Vector3, text: String, color := Color.WHITE) -> void:
	if world == null or not is_instance_valid(world):
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.font_size = 56
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(rng.randf_range(-0.3, 0.3), 0.1, 0)
	world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

# ---------------- ВВОД ----------------

func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT], "roll": [KEY_Q], "interact": [KEY_E],
		"potion": [KEY_R], "pause": [KEY_ESCAPE], "skills": [KEY_M], "view": [KEY_V],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)

# ---------------- ЗВУК ----------------

var _sfx: Dictionary = {}
var _sfx_db: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const RATE := 22050

# Скачанные CC0-звуки (Kenney.nl), раскладываются в res://audio под этими именами.
const FILE_MAP := {
	"swing": "swing.ogg", "hit": "hit.ogg", "coin": "coin.ogg", "pickup": "pickup.ogg",
	"levelup": "levelup.ogg", "hurt": "hurt.ogg", "potion": "potion.ogg", "roll": "roll.ogg",
	"slam": "slam.ogg", "die": "die.ogg", "step": "step.ogg", "open": "open.ogg", "buy": "buy.ogg",
}
const FILE_BASE_DB := {"coin": -4.0, "step": -11.0, "swing": -5.0, "roll": -7.0, "pickup": -6.0, "buy": -6.0}

func _setup_audio() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -13.0
	add_child(_music_player)
	# сначала процедурные (фолбэк), потом перекрываем скачанными, если файлы есть
	_sfx["swing"] = _wav_synth(_t_swing())
	_sfx["hit"] = _wav_synth(_t_hit())
	_sfx["coin"] = _wav_synth(_t_coin())
	_sfx["pickup"] = _wav_synth(_t_pickup())
	_sfx["levelup"] = _wav_synth(_t_levelup())
	_sfx["hurt"] = _wav_synth(_t_hurt())
	_sfx["potion"] = _wav_synth(_t_potion())
	_sfx["roll"] = _wav_synth(_t_roll())
	_sfx["slam"] = _wav_synth(_t_slam())
	_sfx["die"] = _wav_synth(_t_die())
	_sfx["step"] = _wav_synth(_t_step())
	_sfx["open"] = _wav_synth(_t_open())
	for sname in FILE_MAP:
		var path: String = "res://audio/" + FILE_MAP[sname]
		if ResourceLoader.exists(path):
			_sfx[sname] = load(path)
			_sfx_db[sname] = FILE_BASE_DB.get(sname, -8.0)
	print("AUDIO: file sounds loaded: ", _sfx_db.size(), "of", FILE_MAP.size())

func sfx(sname: String, vol_db := 0.0, pitch := 1.0) -> void:
	if not _sfx.has(sname):
		return
	var target: AudioStreamPlayer = null
	for p in _sfx_players:
		if not p.playing:
			target = p
			break
	if target == null:
		target = _sfx_players[0]
	target.stream = _sfx[sname]
	target.volume_db = vol_db + float(_sfx_db.get(sname, 0.0))
	target.pitch_scale = pitch
	target.play()

func start_music() -> void:
	if _music_player.stream == null:
		_music_player.stream = _wav_synth(_t_music(), true)
	if not _music_player.playing:
		_music_player.play()

func _wav_synth(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var n := samples.size()
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := int(clampf(samples[i], -1.0, 1.0) * 31500.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = n
	return w

func _env(tt: float, curve := 3.0, attack := 0.05) -> float:
	var a := minf(tt / maxf(attack, 0.001), 1.0)
	return a * pow(maxf(1.0 - tt, 0.0), curve)

func _t_swing() -> PackedFloat32Array:
	var dur := 0.20
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var tt := float(i) / n
		var noiz := rng.randf_range(-1.0, 1.0)
		var cut := 0.05 + 0.55 * sin(tt * PI)
		lp += (noiz - lp) * cut
		out[i] = lp * 2.4 * _env(tt, 2.0)
	return out

func _t_roll() -> PackedFloat32Array:
	var dur := 0.3
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var tt := float(i) / n
		var noiz := rng.randf_range(-1.0, 1.0)
		var cut := 0.03 + 0.25 * sin(tt * PI)
		lp += (noiz - lp) * cut
		out[i] = lp * 1.7 * _env(tt, 2.0)
	return out

func _t_hit() -> PackedFloat32Array:
	var dur := 0.16
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var tt := float(i) / n
		var ft := float(i) / RATE
		var v := sin(TAU * 95.0 * ft) * 0.9
		if tt < 0.3:
			v += rng.randf_range(-1.0, 1.0) * 0.35 * (1.0 - tt / 0.3)
		out[i] = v * _env(tt, 4.0)
	return out

func _t_slam() -> PackedFloat32Array:
	var dur := 0.55
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var tt := float(i) / n
		var ft := float(i) / RATE
		var v := sin(TAU * 55.0 * (1.0 - tt * 0.5) * ft) * 0.95
		if tt < 0.25:
			v += rng.randf_range(-1.0, 1.0) * 0.3 * (1.0 - tt / 0.25)
		out[i] = v * _env(tt, 2.5)
	return out

func _t_coin() -> PackedFloat32Array:
	var dur := 0.18
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ft := float(i) / RATE
		var tt := ft / dur
		if tt < 0.35:
			out[i] = sin(TAU * 1318.0 * ft) * 0.5 * _env(tt / 0.35, 2.0)
		else:
			out[i] = sin(TAU * 1760.0 * ft) * 0.5 * _env((tt - 0.35) / 0.65, 2.0)
	return out

func _t_pickup() -> PackedFloat32Array:
	var dur := 0.16
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var ft := float(i) / RATE
		var tt := ft / dur
		if tt < 0.4:
			out[i] = sin(TAU * 880.0 * ft) * 0.4 * _env(tt / 0.4, 2.0)
		else:
			out[i] = sin(TAU * 1174.0 * ft) * 0.4 * _env((tt - 0.4) / 0.6, 2.0)
	return out

func _t_levelup() -> PackedFloat32Array:
	var dur := 0.62
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for j in notes.size():
		var start := j * 0.1
		for i in range(int(start * RATE), n):
			var lt := float(i) / RATE - start
			out[i] += sin(TAU * notes[j] * float(i) / RATE) * 0.35 * pow(maxf(1.0 - lt / 0.5, 0.0), 2.0) * minf(lt * 80.0, 1.0)
	return out

func _t_hurt() -> PackedFloat32Array:
	var dur := 0.25
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var tt := float(i) / n
		ph += (300.0 - 240.0 * tt) / RATE
		var saw := 2.0 * fmod(ph, 1.0) - 1.0
		out[i] = saw * 0.45 * _env(tt, 2.0)
	return out

func _t_die() -> PackedFloat32Array:
	var dur := 0.6
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [392.0, 311.13, 233.08]
	for j in notes.size():
		var start := j * 0.18
		for i in range(int(start * RATE), n):
			var lt := float(i) / RATE - start
			out[i] += (2.0 * fmod(notes[j] * float(i) / RATE, 1.0) - 1.0) * 0.3 * pow(maxf(1.0 - lt / 0.35, 0.0), 1.5)
	return out

func _t_potion() -> PackedFloat32Array:
	var dur := 0.3
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var starts := [0.0, 0.09, 0.18]
	for s in starts:
		var s0: float = s
		var f := 380.0 + rng.randf_range(0.0, 260.0)
		for i in range(int(s0 * RATE), n):
			var lt := float(i) / RATE - s0
			out[i] += sin(TAU * f * float(i) / RATE) * 0.4 * pow(maxf(1.0 - lt / 0.1, 0.0), 2.0)
	return out

func _t_step() -> PackedFloat32Array:
	var dur := 0.06
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		var tt := float(i) / n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.05
		out[i] = lp * 1.4 * _env(tt, 5.0)
	return out

func _t_open() -> PackedFloat32Array:
	var dur := 0.25
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var tt := float(i) / n
		ph += (80.0 + 30.0 * sin(tt * 20.0)) / RATE
		var saw := 2.0 * fmod(ph, 1.0) - 1.0
		out[i] = (saw * 0.5 + rng.randf_range(-1.0, 1.0) * 0.15) * _env(tt, 2.0)
	return out

func _t_music() -> PackedFloat32Array:
	var dur := 16.0
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [
		[220.00, 261.63, 329.63, 440.00],
		[174.61, 220.00, 261.63, 349.23],
		[130.81, 196.00, 261.63, 329.63],
		[196.00, 246.94, 293.66, 392.00],
	]
	var seg := dur / 4.0
	for i in n:
		var ft := float(i) / RATE
		var ci := int(ft / seg) % 4
		var lt := fmod(ft, seg)
		var fade := minf(minf(lt / 0.9, (seg - lt) / 0.9), 1.0)
		var v := 0.0
		for f in chords[ci]:
			v += sin(TAU * f * ft + sin(ft * 0.7) * 0.3)
		out[i] = v * 0.055 * fade
	var melody := [
		[0.5, 440.0], [1.5, 523.25], [2.5, 587.33], [3.25, 523.25],
		[4.5, 659.25], [5.5, 587.33], [6.5, 523.25],
		[8.0, 659.25], [9.0, 783.99], [10.0, 659.25], [10.75, 587.33],
		[12.0, 523.25], [13.0, 440.0], [14.0, 392.0], [14.75, 440.0],
	]
	for m in melody:
		var start: float = m[0]
		var f: float = m[1]
		for i in range(int(start * RATE), n):
			var lt := float(i) / RATE - start
			if lt > 1.2:
				break
			out[i] += sin(TAU * f * float(i) / RATE) * 0.10 * pow(1.0 - lt / 1.2, 2.5) * minf(lt * 60.0, 1.0)
	var echo := int(0.375 * RATE)
	for i in range(echo, n):
		out[i] += out[i - echo] * 0.3
	return out
