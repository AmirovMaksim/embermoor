extends Node3D
## Главный сценарий: собирает мир, меню, цикл дня/ночи, взаимодействия.

var world: GameWorld
var player: PlayerRig
var hud: HUD
var menu_cam: Camera3D
var menu := true
var menu_angle := 0.0
var time_of_day := 0.16  # 0..1; ~0.25 полдень
const DAY_LEN := 300.0
var slime_respawn_t := 30.0
var paused := false
var world_built_sig := []
var loaded_chests: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	G.reset()
	G.main = self
	G.world_seed = randi()
	G.rng.seed = G.world_seed
	world = GameWorld.new()
	add_child(world)
	G.world = world
	hud = HUD.new()
	add_child(hud)
	G.hud = hud
	spawn_player()
	spawn_npcs()
	spawn_enemies()
	spawn_chests()
	spawn_lore()
	spawn_board()
	G.apply_gfx()
	world_built_sig = [G.world_size, G.difficulty]
	G.start_music()
	hud.show_menu()
	menu = true
	G.game_started = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_cam = Camera3D.new()
	menu_cam.fov = 58
	add_child(menu_cam)
	menu_cam.current = true
	var args := OS.get_cmdline_user_args()
	if args.has("--smoke"):
		_smoke()
	elif args.has("--shots"):
		_shots()
	elif args.has("--play"):
		_play()

func spawn_player() -> void:
	player = PlayerRig.new()
	world.add_child(player)
	player.global_position = world.spawn_point

func spawn_npcs() -> void:
	var c := world.village_center
	NPC.spawn(world, "elder", Vector3(c.x + 1.8, world.height(c.x + 1.8, c.z + 0.2), c.z + 0.2))
	var sx := c.x - 4.5
	var sz := c.z - 1.5
	NPC.spawn(world, "smith", Vector3(sx, world.height(sx, sz), sz))
	# ведьма у башни в Топком лесу
	var tp: Vector3 = world.swamp_center + Vector3(-3, 0, 1.5)
	NPC.spawn(world, "witch", Vector3(tp.x, world.height(tp.x, tp.z), tp.z))

func spawn_enemies() -> void:
	var meadow: Vector3 = world.meadow_center
	for i in 8:
		var a := TAU * i / 8.0 + 0.4
		var r := G.rng.randf_range(3.0, 14.0)
		var p := meadow + Vector3(cos(a) * r, 0, sin(a) * r)
		Enemy.spawn(world, "slime", Vector3(p.x, world.height(p.x, p.z) + 0.3, p.z))
	for i in 3:
		var p := _rand_forest_pos()
		if p != Vector3.INF:
			Enemy.spawn(world, "slime", p)
	var ruins: Vector3 = world.ruins_center
	for i in 4:
		var a := TAU * i / 4.0 + 0.8
		var p := ruins + Vector3(cos(a) * 5.5, 0, sin(a) * 5.5)
		Enemy.spawn(world, "skeleton", Vector3(p.x, world.height(p.x, p.z) + 0.3, p.z))
	if not G.defeated_bosses.has("golem"):
		Enemy.spawn(world, "golem", Vector3(ruins.x + 1.5, world.height(ruins.x + 1.5, ruins.z + 1.5) + 0.5, ruins.z + 1.5))
	# Топкий лес: болотные твари, скелеты и Хранитель
	var swamp: Vector3 = world.swamp_center
	for i in 4:
		var a2 := TAU * i / 4.0 + 0.5
		var r2 := G.rng.randf_range(8.0, 15.0)
		var p2 := swamp + Vector3(cos(a2) * r2, 0, sin(a2) * r2)
		Enemy.spawn(world, "swamp", Vector3(p2.x, world.height(p2.x, p2.z) + 0.3, p2.z))
	for i in 2:
		var a3 := TAU * i / 2.0 + 1.2
		var p3 := swamp + Vector3(cos(a3) * 11.0, 0, sin(a3) * 11.0)
		Enemy.spawn(world, "skeleton", Vector3(p3.x, world.height(p3.x, p3.z) + 0.3, p3.z))
	var gp := swamp + Vector3(6, 0, 7)
	if not G.defeated_bosses.has("guardian"):
		Enemy.spawn(world, "guardian", Vector3(gp.x, world.height(gp.x, gp.z) + 0.5, gp.z))
	# Пепельные пустоши: огненные бесы и Магмовый Голем
	var ash: Vector3 = world.ashen_center
	for i in 3:
		var a5 := TAU * i / 3.0 + 0.3
		var p5 := ash + Vector3(cos(a5) * 10.0, 0, sin(a5) * 10.0)
		Enemy.spawn(world, "imp", Vector3(p5.x, world.height(p5.x, p5.z) + 0.3, p5.z))
	if not G.defeated_bosses.has("magma_golem"):
		Enemy.spawn(world, "magma_golem", Vector3(ash.x, world.height(ash.x, ash.z) + 0.5, ash.z))
	# Ледяные пики: ледяные слизни и Морозный Голем
	var fr: Vector3 = world.frost_center
	for i in 3:
		var a6 := TAU * i / 3.0 + 1.1
		var p6 := fr + Vector3(cos(a6) * 11.0, 0, sin(a6) * 11.0)
		Enemy.spawn(world, "frost_slime", Vector3(p6.x, world.height(p6.x, p6.z) + 0.3, p6.z))
	if not G.defeated_bosses.has("frost_golem"):
		Enemy.spawn(world, "frost_golem", Vector3(fr.x + 2, world.height(fr.x + 2, fr.z + 2) + 0.5, fr.z + 2))
	# квестовые светогрибы у башни Моры
	var tp2: Vector3 = swamp + Vector3(-3, 0, -3)
	for i in 3:
		var a4 := TAU * i / 3.0 + 0.9
		var r4 := G.rng.randf_range(7.0, 13.0)
		var p4 := tp2 + Vector3(cos(a4) * r4, 0, sin(a4) * r4)
		GlowShroom.spawn(world, Vector3(p4.x, world.height(p4.x, p4.z), p4.z), true)

func spawn_lore() -> void:
	var L: Dictionary = G.LORE_STONES
	var spots := {
		"village": world.village_center + Vector3(3.5, 0, -6.5),
		"meadow": world.meadow_center + Vector3(3, 0, 2),
		"ruins": world.ruins_center + Vector3(-3, 0, 3),
		"swamp": world.swamp_center + Vector3(4, 0, -1),
		"ashen": world.ashen_center + Vector3(2, 0, 2),
		"frost": world.frost_center + Vector3(0, 0, 3),
		"portal": world.portal_center + Vector3(7, 0, 0),
	}
	for key in spots:
		var p: Vector3 = spots[key]
		LoreStone.spawn(world, Vector3(p.x, world.height(p.x, p.z) + 0.05, p.z), L[key][0], L[key][1])

func _rand_forest_pos() -> Vector3:
	for attempt in 20:
		var a := G.rng.randf_range(0, TAU)
		var r := G.rng.randf_range(20.0, 45.0)
		var c := world.village_center + Vector3(-20, 0, -30)
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		if Vector2(p.x - world.village_center.x, p.z - world.village_center.z).length() < 32.0:
			continue  # лесные слизни не должны стартовать у деревни
		var h := world.height(p.x, p.z)
		if h > 1.5 and h < 11.0 and world.slope_ny(p.x, p.z) > 0.85:
			return Vector3(p.x, h + 0.3, p.z)
	return Vector3.INF

func spawn_chests() -> void:
	var c := world.village_center
	if not loaded_chests.has(0):
		var ch0 := Chest.spawn(world, Vector3(c.x + 8.5, world.height(c.x + 8.5, c.z + 6.5) + 0.1, c.z + 6.5), 25, 1)
		ch0.cid = 0
	var r := world.ruins_center
	if not loaded_chests.has(1):
		var ch1 := Chest.spawn(world, Vector3(r.x - 6.0, world.height(r.x - 6.0, r.z + 2.0) + 0.1, r.z + 2.0), 60, 2)
		ch1.cid = 1
	var a := world.ashen_center
	if not loaded_chests.has(2):
		var ch2 := Chest.spawn(world, Vector3(a.x - 3.0, world.height(a.x - 3.0, a.z - 3.0) + 0.1, a.z - 3.0), 80, 2)
		ch2.cid = 2
	var f := world.frost_center
	if not loaded_chests.has(3):
		var ch3 := Chest.spawn(world, Vector3(f.x + 4.0, world.height(f.x + 4.0, f.z - 2.0) + 0.1, f.z - 2.0), 80, 2)
		ch3.cid = 3

func spawn_board() -> void:
	var c := world.village_center
	BountyBoard.spawn(world, Vector3(c.x - 3.2, world.height(c.x - 3.2, c.z + 5.4) + 0.05, c.z + 5.4))

# ---------------- ИГРОВОЙ ЦИКЛ ----------------

func start_game() -> void:
	menu = false
	G.game_started = true
	hud.hide_menu()
	if menu_cam:
		menu_cam.queue_free()
		menu_cam = null
	player.cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func start_new_game() -> void:
	G.reset()
	G.apply_class_stats()
	if world_built_sig != [G.world_size, G.difficulty]:
		G.world_seed = randi()
		rebuild_world()
	start_game()
	hud.notify("Поговори со Старейшиной у костра  [E]")

func rebuild_world() -> void:
	if world and is_instance_valid(world):
		world.queue_free()
	if player and is_instance_valid(player):
		player.queue_free()
	G.rng.seed = G.world_seed
	world = GameWorld.new()
	add_child(world)
	G.world = world
	spawn_player()
	spawn_npcs()
	spawn_enemies()
	spawn_chests()
	spawn_lore()
	spawn_board()
	G.apply_gfx()
	world_built_sig = [G.world_size, G.difficulty]

func continue_game() -> void:
	var data: Dictionary = G.load_save()
	if data.is_empty():
		start_new_game()
		return
	G.reset()
	G.difficulty = str(data["difficulty"]) if data.has("difficulty") else "normal"
	G.player_class = str(data["player_class"]) if data.has("player_class") else "warrior"
	G.world_size = float(data["world_size"]) if data.has("world_size") else 1.0
	G.world_seed = int(data["seed"])
	loaded_chests = data.get("chests", [])
	G.defeated_bosses = data.get("defeated", [])
	rebuild_world()
	G.max_hp = float(data["max_hp"])
	G.hp = float(data["hp"])
	G.max_st = float(data["max_st"])
	G.st = float(data["st"])
	G.xp = float(data["xp"])
	G.level = int(data["level"])
	G.coins = int(data["coins"])
	G.potions = int(data["potions"])
	G.sword_tier = int(data["sword_tier"])
	G.skill_points = int(data["skill_points"])
	var sk: Dictionary = data["skills"]
	for k in sk:
		G.skills[k] = int(sk[k])
	G.quest_state = int(data["quest_state"])
	G.quest_kills = int(data["quest_kills"])
	G.mush_collected = int(data["mush_collected"])
	G.grove_shrine_taken = bool(data.get("grove_shrine_taken", false))
	G.golem_dead = bool(data["golem_dead"])
	G.guardian_dead = bool(data["guardian_dead"])
	G.witch_rewarded = bool(data["witch_rewarded"])
	G.lore_found = int(data["lore_found"])
	G.kills = int(data["kills"])
	G.bounty_kind = str(data.get("bounty_kind", ""))
	G.bounty_goal = int(data.get("bounty_goal", 0))
	G.bounty_count = int(data.get("bounty_count", 0))
	G.bounties_done = int(data.get("bounties_done", 0))
	time_of_day = float(data.get("tod", 0.16))
	if data.has("pos"):
		player.global_position = Vector3(float(data["pos"][0]), float(data["pos"][1]), float(data["pos"][2]))
	# срезаем уже собранные светогрибы
	var taken := 0
	for m in get_tree().get_nodes_in_group("mushrooms"):
		if taken >= G.mush_collected:
			break
		m.queue_free()
		taken += 1
	# активируем портал, если сюжет дошёл
	if G.quest_state >= 13:
		for n in get_tree().get_nodes_in_group("portals"):
			n.activate()
	G.stats_changed.emit()
	G.quest_changed.emit()
	start_game()

func save_now() -> void:
	var opened: Array = []
	for chst in get_tree().get_nodes_in_group("chests"):
		if chst.get("opened"):
			opened.append(int(chst.get("cid")))
	G.save_game(player.global_position, time_of_day, opened)

func respawn_player() -> void:
	player.respawn(world.spawn_point)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skills"):
		if G.skills_open:
			hud.close_skills()
		elif not menu and not G.dialogue_open and not G.shop_open and not get_tree().paused and not player.dead:
			hud.open_skills()
		return
	if event.is_action_pressed("pause"):
		if G.skills_open:
			hud.close_skills()
		elif G.dialogue_open:
			hud.close_dialogue()
		elif G.shop_open:
			hud.close_shop()
		elif not menu and not get_tree().paused:
			get_tree().paused = true
			hud.show_pause()
		elif get_tree().paused:
			get_tree().paused = false
			hud.pause_root.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_day_night(delta)
	_clouds_drift(delta)
	_fire_flicker()
	if menu and menu_cam:
		menu_angle += delta * 0.07
		var c := world.village_center
		var fy := world.height(c.x, c.z)
		var px := c.x + cos(menu_angle) * 11.0
		var pz := c.z + sin(menu_angle) * 11.0
		menu_cam.global_position = Vector3(px, fy + 4.5, pz)
		menu_cam.look_at(Vector3(c.x, fy + 1.6, c.z + 2.5))
		return
	if get_tree().paused:
		return
	_interactions()
	_slime_respawn(delta)

func _day_night(delta: float) -> void:
	if not menu:
		time_of_day = fmod(time_of_day + delta / DAY_LEN, 1.0)
	var dayness := clampf(sin(time_of_day * TAU) * 1.3 + 0.2, 0.0, 1.0)
	world.sun.light_energy = 0.05 + dayness * 0.78
	var sunset_t := clampf(1.0 - absf(dayness - 0.25) * 3.0, 0.0, 1.0)
	var day_col := Color(1.0, 0.96, 0.88)
	var sunset_col := Color(1.0, 0.55, 0.3)
	var night_col := Color(0.4, 0.5, 0.8)
	var col := day_col.lerp(sunset_col, sunset_t)
	col = col.lerp(night_col, clampf((0.35 - dayness) * 3.0, 0.0, 1.0))
	world.sun.light_color = col
	world.sun.rotation_degrees = Vector3(-lerpf(12.0, 65.0, dayness), -30.0 + time_of_day * 120.0, 0)
	world.env.ambient_light_energy = 0.18 + dayness * 0.42
	world.sky_mat.sky_top_color = Color("#0d1430").lerp(Color("#2e63b8"), dayness)
	world.sky_mat.sky_horizon_color = Color("#2a2540").lerp(Color("#bfe0ec"), dayness).lerp(Color("#ff9a5c"), sunset_t * 0.6)
	world.env.fog_light_color = world.sky_mat.sky_horizon_color
	var night := dayness < 0.3
	if world.fireflies_node:
		world.fireflies_node.emitting = night

func _clouds_drift(delta: float) -> void:
	for cl in world.clouds:
		cl.position.x += delta * 0.7
		if cl.position.x > 170.0:
			cl.position.x = -170.0

func _fire_flicker() -> void:
	var lights := get_tree().get_nodes_in_group("fire_light")
	var now := Time.get_ticks_msec()
	for i in lights.size():
		if lights[i].has_meta("light"):
			var l: OmniLight3D = lights[i].get_meta("light")
			l.light_energy = 1.15 + sin(now * 0.011 + i * 2.1) * 0.3 + sin(now * 0.027 + i * 0.7) * 0.12
	var lant := get_tree().get_nodes_in_group("lantern_light")
	for i in lant.size():
		var l2: OmniLight3D = lant[i]
		var base: float = l2.get_meta("base") if l2.has_meta("base") else 0.85
		l2.light_energy = base + sin(now * 0.006 + i * 1.7) * 0.1 + sin(now * 0.017 + i) * 0.05

func _interactions() -> void:
	if not G.game_started or G.dialogue_open or G.shop_open or player.dead:
		hud.hide_hint()
		return
	var best: Node = null
	var best_d := 2.7
	for n in get_tree().get_nodes_in_group("npcs"):
		var d: float = n.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = n
	for ch in get_tree().get_nodes_in_group("chests"):
		var d: float = ch.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = ch
	for group_name in ["mushrooms", "lore", "portals"]:
		for it in get_tree().get_nodes_in_group(group_name):
			var d: float = it.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = it
	if best and best.has_method("prompt_text"):
		hud.show_hint("[E]  " + best.prompt_text())
		if Input.is_action_just_pressed("interact") and Time.get_ticks_msec() - G.dlg_closed_ms > 200:
			if best is NPC:
				if best.kind == "smith":
					hud.show_shop(best)
				else:
					hud.open_dialogue(best)
			elif best.has_method("interact"):
				best.interact()
	else:
		hud.hide_hint()

var lava_cd := 0.0
var frost_hint_done := false

func _physics_process(delta: float) -> void:
	if not G.game_started or player == null or not is_instance_valid(player) or player.dead:
		return
	lava_cd -= delta
	if lava_cd > 0.0:
		return
	if not frost_hint_done and G.quest_state == 11 and player.global_position.distance_to(world.frost_center) < 55.0:
		frost_hint_done = true
		G.hud.notify("На Ледяные пики можно подняться с любой стороны — ищи ледяные фонари")
		G.sfx("pickup", -6.0)
	for spot in world.lava_spots:
		if player.global_position.distance_to(spot["pos"]) < spot["r"]:
			lava_cd = 0.9
			G.damage_player(14.0, spot["pos"] + Vector3(0, 0.5, 0))
			G.hud.notify("Лава! Отскочи!")
			FX.hit_spark(G.world, player.global_position + Vector3(0, 0.5, 0))
			break

func _slime_respawn(delta: float) -> void:
	slime_respawn_t -= delta
	if slime_respawn_t > 0.0:
		return
	slime_respawn_t = 25.0
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "slime":
			count += 1
	if count >= 10:
		return
	var a := G.rng.randf_range(0, TAU)
	var r := G.rng.randf_range(3.0, 14.0)
	var p: Vector3 = world.meadow_center + Vector3(cos(a) * r, 0, sin(a) * r)
	Enemy.spawn(world, "slime", Vector3(p.x, world.height(p.x, p.z) + 0.3, p.z))

# ---------------- ТЕСТОВЫЕ РЕЖИМЫ ----------------

func _smoke() -> void:
	print("SMOKE: start")
	start_game()
	await _frames(30)
	var elder: Node = null
	var smith: Node = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.kind == "elder":
			elder = n
		elif n.kind == "smith":
			smith = n
	hud.open_dialogue(elder)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE quest after elder: ", G.quest_state)
	var killed := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "slime" and killed < 6:
			e.take_hit(999.0, Vector3.FORWARD, null)
			killed += 1
	await _frames(10)
	print("SMOKE after kills: quest ", G.quest_state, " kills ", G.quest_kills)
	hud.open_dialogue(elder)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE after reward: quest ", G.quest_state, " coins ", G.coins)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "golem":
			e.take_hit(99999.0, Vector3.FORWARD, null)
	await _frames(10)
	hud.open_dialogue(elder)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE final: quest ", G.quest_state, " coins ", G.coins, " level ", G.level, " potions ", G.potions)
	G.coins += 200
	hud.show_shop(smith)
	hud._on_sword_buy()
	hud._on_potion_buy()
	hud.close_shop()
	print("SMOKE shop: sword ", G.sword_tier, " coins ", G.coins, " potions ", G.potions)
	G.damage_player(99999.0, Vector3.ZERO)
	await _frames(20)
	respawn_player()
	await _frames(20)
	print("SMOKE death: hp ", G.hp, " dead ", player.dead)
	# ведьма и продолжение сюжета
	G.quest_state = 5
	var witch: Node = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.kind == "witch":
			witch = n
	hud.open_dialogue(elder)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE elder quest6: ", G.quest_state)
	hud.open_dialogue(witch)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE witch quest: ", G.quest_state)
	for m in get_tree().get_nodes_in_group("mushrooms"):
		m.interact()
	await _frames(5)
	print("SMOKE mush: ", G.mush_collected)
	hud.open_dialogue(witch)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE after mush: ", G.quest_state, " points ", G.skill_points)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "guardian":
			e.take_hit(99999.0, Vector3.FORWARD, null)
	await _frames(10)
	hud.open_dialogue(witch)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE final2: quest ", G.quest_state, " coins ", G.coins, " rewarded ", G.witch_rewarded)
	G.skill_points = 5
	G.buy_skill("wind")
	G.buy_skill("wind")
	G.buy_skill("life")
	print("SMOKE skills: wind ", G.skills["wind"], " speed ", G.speed_mult(), " life ", G.skills["life"])
	G.quest_state = 9
	hud.open_dialogue(elder)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE elder quest10: ", G.quest_state)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "magma_golem":
			e.take_hit(99999.0, Vector3.FORWARD, null)
	await _frames(5)
	print("SMOKE magma: ", G.quest_state)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "frost_golem":
			e.take_hit(99999.0, Vector3.FORWARD, null)
	await _frames(5)
	print("SMOKE frost: ", G.quest_state)
	hud.open_dialogue(witch)
	for i in 14:
		hud.advance_dialogue()
	print("SMOKE portal activated: ", G.quest_state)
	for n in get_tree().get_nodes_in_group("portals"):
		n.interact()
	await _frames(5)
	print("SMOKE finale: ", G.quest_state, " lore_open ", hud.lore_open)
	hud.close_lore()
	# сохранения
	G.quest_state = 14
	save_now()
	var has_sv: bool = G.has_save()
	var data: Dictionary = G.load_save()
	var save_ok: bool = has_sv and int(data.get("quest_state", -1)) == 14 and int(data.get("seed", -2)) == G.world_seed
	print("SMOKE save: has ", has_sv, " quest ", data.get("quest_state"), " seed ok ", save_ok)
	# охота
	G.new_bounty()
	var bkind: String = G.bounty_kind
	var b_target: Node = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.kind == bkind:
			b_target = e
			break
	if b_target == null:
		b_target = Enemy.spawn(world, bkind, Vector3(0, 10, 0))
	b_target.take_hit(9999.0, Vector3.FORWARD, null)
	await _frames(5)
	print("SMOKE bounty: kind ", bkind, " count ", G.bounty_count, "/", G.bounty_goal)
	# классы
	G.player_class = "rogue"
	G.apply_class_stats()
	print("SMOKE class: max_st ", G.max_st, " (ожидание 135)")
	# настройки графики применяются
	G.gfx["ssao"] = false
	G.apply_gfx()
	print("SMOKE gfx: applied ok")
	print("SMOKE OK")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)

func _release(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = false
	Input.parse_input_event(e)

func _tap(action: String) -> void:
	_press(action)
	await _frames(3)
	_release(action)

func _check(name: String, ok: bool) -> void:
	print("PLAYTEST [%s]: %s" % [name.to_upper(), "PASS" if ok else "FAIL"])

func _play() -> void:
	print("PLAYTEST: start")
	start_game()
	await _frames(30)
	# 0. рядом со спавном не должно быть врагов
	var min_d := 999.0
	for e in get_tree().get_nodes_in_group("enemies"):
		min_d = minf(min_d, e.global_position.distance_to(world.spawn_point))
	_check("spawn_is_safe", min_d > 14.0)
	# 1. ходьба вперёд — камера не должна крутиться
	player.cam_yaw.global_rotation = Vector3(0, deg_to_rad(180), 0)
	var yaw_before: float = player.cam_yaw.global_rotation.y
	var root_yaw_before: float = player.rotation.y
	var pos_before: Vector3 = player.global_position
	player.set_process_unhandled_input(false)  # изолируем тест от реальной мыши
	_press("move_forward")
	await get_tree().create_timer(1.5).timeout
	_release("move_forward")
	player.set_process_unhandled_input(true)
	_check("walk_moved", (player.global_position - pos_before).length() > 2.0)
	var yaw_after: float = player.cam_yaw.global_rotation.y
	_check("camera_stable_while_walking", absf(wrapf(yaw_after - yaw_before, -PI, PI)) < 0.05 and absf(wrapf(player.rotation.y - root_yaw_before, -PI, PI)) < 0.05)
	# 2. мышь крутит камеру
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(300, 0)
	Input.parse_input_event(mm)
	await _frames(3)
	_check("mouse_turns_camera", absf(wrapf(player.cam_yaw.global_rotation.y - yaw_after, -PI, PI)) > 0.3)
	# 3. прыжок
	var y0: float = player.global_position.y
	await _tap("jump")
	await _frames(5)
	_check("jump", player.global_position.y > y0 + 0.2 or player.velocity.y > 1.0)
	await _frames(40)
	# 4. перекат
	await _tap("roll")
	await _frames(4)
	_check("roll", player.rolling or player.invuln > 0.0)
	await _frames(40)
	# 5. атака: спавним слайма прямо перед игроком
	var fwd: Vector3 = -player.cam_yaw.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	var sp: Vector3 = player.global_position + fwd * 2.0
	var target: Node = Enemy.spawn(world, "slime", Vector3(sp.x, world.height(sp.x, sp.z) + 0.3, sp.z))
	target.home = target.global_position
	player.vis.rotation.y += 2.5  # модель смотрит мимо цели — проверяем автоприцел
	await _frames(10)
	for i in 4:
		await _tap("attack")
		await _frames(30)
	var hit_ok := false
	if is_instance_valid(target):
		hit_ok = target.hp < target.max_hp or target.dead
	else:
		hit_ok = true
	_check("attack_hits_enemy", hit_ok)
	await _frames(30)
	# 6. зелье
	G.hp = 40.0
	var pot_before: int = G.potions
	await _tap("potion")
	await _frames(5)
	_check("potion_heals", G.potions == pot_before - 1 and G.hp > 40.0)
	# 7. диалог: открыть E, листать пробелом и E
	var elder: Node = null
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.kind == "elder":
			elder = n
	player.global_position = elder.global_position + Vector3(0, 0.5, 1.8)
	await _frames(10)
	await _tap("interact")
	await _frames(5)
	_check("dialogue_opens", G.dialogue_open)
	await _tap("jump")
	await _frames(2)
	for i in 12:
		await _tap("interact")
		await _frames(3)
		if not G.dialogue_open:
			break
	await _frames(5)
	_check("dialogue_advances_quest", not G.dialogue_open and G.quest_state == 1)
	# 8. пауза
	await _tap("pause")
	await _frames(3)
	var was_paused: bool = get_tree().paused
	await _tap("pause")
	await _frames(3)
	_check("pause_toggles", was_paused and not get_tree().paused)
	# 9. смерть и возрождение
	G.damage_player(99999.0, Vector3.ZERO)
	await _frames(15)
	_check("death_works", player.dead)
	respawn_player()
	await _frames(5)
	_check("respawn_works", not player.dead and G.hp > 0.0)
	# 10. вид от первого лица
	await _tap("view")
	await _frames(5)
	var fp_ok: bool = player.first_person and not player.vis.visible
	await _tap("view")
	await _frames(5)
	_check("first_person_toggle", fp_ok and not player.first_person)
	# 10b. лорный камень
	var stone: Node = null
	for n in get_tree().get_nodes_in_group("lore"):
		if not n.is_portal and not n.shrine:
			stone = n
			break
	if stone:
		player.global_position = stone.global_position + Vector3(0, 1.0, 2.0)
		player.velocity = Vector3.ZERO
		await _frames(10)
		await _tap("interact")
		await _frames(5)
		var opened: bool = get_tree().paused and hud.lore_open
		await _tap("interact")
		await _frames(5)
		_check("lore_stone_works", opened and not hud.lore_open and not get_tree().paused)
	else:
		_check("lore_stone_works", false)
	# 9b. миникарта видима в игре
	_check("minimap_shown", hud.mm_container != null and hud.mm_container.visible and hud.mm_viewport != null)
	# 10c. подъём в гору: игрок стоит на склоне на высоте ~14 м
	var up_ang := 2.2
	var up_pos := Vector3(world.frost_center.x + cos(up_ang) * 22.0, 0, world.frost_center.z + sin(up_ang) * 22.0)
	var up_h: float = world.height(up_pos.x, up_pos.z)
	player.global_position = Vector3(up_pos.x, up_h + 0.8, up_pos.z)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.8).timeout
	var stood := player.is_on_floor() and absf(player.global_position.y - up_h) < 1.5
	_check("frost_climbable_mid", stood)
	# 10d. гора проходима: максимальный уклон склона
	var max_slope := 0.0
	var worst := ""
	for prof in 12:
		var pa := TAU * prof / 12.0
		var prev_h := world.height(world.frost_center.x + cos(pa) * 10.0, world.frost_center.z + sin(pa) * 10.0)
		for rr in range(11, 50):
			var cx: float = world.frost_center.x + cos(pa) * float(rr)
			var cz: float = world.frost_center.z + sin(pa) * float(rr)
			var nh := world.height(cx, cz)
			if absf(nh - prev_h) > max_slope:
				max_slope = absf(nh - prev_h)
				worst = "angle %d r %d" % [int(rad_to_deg(pa)), rr]
			prev_h = nh
	_check("mountain_climbable", max_slope < 1.19)
	print("MOUNTAINDBG max slope per meter: ", max_slope, " at ", worst)
	# 11. коллизии построек: стена дома останавливает
	var hut_pos: Vector3 = world.village_center + Vector3(-6.5, 0, -4)
	var from := hut_pos + Vector3(0, 0, 4.5)
	player.global_position = Vector3(from.x, world.height(from.x, from.z) + 1.0, from.z)
	player.velocity = Vector3.ZERO
	player.vis.rotation.y = 0.0
	await _frames(5)
	_press("move_forward")
	await get_tree().create_timer(1.2).timeout
	_release("move_forward")
	var wall_d: float = player.global_position.distance_to(Vector3(hut_pos.x, 0, hut_pos.z))
	_check("building_collision", wall_d > 1.6)
	print("PLAYTEST DONE")
	get_tree().quit()

func _snap(sname: String) -> void:
	for i in 14:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % sname)
	print("SNAP OK ", sname)

func _shots() -> void:
	DirAccess.open("user://").make_dir_recursive("shots")
	await _snap("01_menu")
	start_game()
	G.coins = 75
	await _snap("02_village")
	var meadow: Vector3 = world.meadow_center
	var mp := meadow + Vector3(-3, 0, 3)
	player.global_position = Vector3(mp.x, world.height(mp.x, mp.z) + 1.3, mp.z)
	player.velocity = Vector3.ZERO
	var d1: Vector3 = meadow - player.global_position
	player.vis.rotation.y = atan2(-d1.x, -d1.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	player.try_attack()
	await _snap("03_combat")
	var ruins: Vector3 = world.ruins_center
	var rp := ruins + Vector3(-4.5, 0, 8.0)
	player.global_position = Vector3(rp.x, world.height(rp.x, rp.z) + 1.3, rp.z)
	player.velocity = Vector3.ZERO
	var d2: Vector3 = ruins - player.global_position
	player.vis.rotation.y = atan2(-d2.x, -d2.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	await _snap("04_ruins")
	var wp := world.swamp_center + Vector3(4, 0, 9)
	player.global_position = Vector3(wp.x, world.height(wp.x, wp.z) + 1.3, wp.z)
	player.velocity = Vector3.ZERO
	var d4: Vector3 = world.swamp_center - player.global_position
	player.vis.rotation.y = atan2(-d4.x, -d4.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	await _snap("06_swamp")
	time_of_day = 0.47
	var vp := world.village_center + Vector3(7, 0, 11)
	player.global_position = Vector3(vp.x, world.height(vp.x, vp.z) + 1.3, vp.z)
	player.velocity = Vector3.ZERO
	var d3: Vector3 = world.village_center + Vector3(0, 0, 2.5) - player.global_position
	player.vis.rotation.y = atan2(-d3.x, -d3.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	await _snap("05_sunset")
	for loc in [["08_ashen", world.ashen_center], ["09_frost", world.frost_center]]:
		var lp: Vector3 = loc[1] + Vector3(6, 0, 9)
		player.global_position = Vector3(lp.x, world.height(lp.x, lp.z) + 1.3, lp.z)
		player.velocity = Vector3.ZERO
		var dd: Vector3 = loc[1] - player.global_position
		player.vis.rotation.y = atan2(-dd.x, -dd.z)
		player.cam_yaw.rotation.y = player.vis.rotation.y
		await _snap(String(loc[0]))
	var ramp_pt: Dictionary = world._spiral[30]
	player.global_position = Vector3(ramp_pt["p"].x, world.height(ramp_pt["p"].x, ramp_pt["p"].y) + 1.3, ramp_pt["p"].y)
	player.velocity = Vector3.ZERO
	var dup: Vector3 = Vector3(world.frost_center.x, world.frost_center.y + 14.0, world.frost_center.z) - player.global_position
	player.vis.rotation.y = atan2(-dup.x, -dup.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	player.cam_pitch.rotation.x = deg_to_rad(-18)
	await _snap("11_ramp")
	var pp: Vector3 = world.portal_center + Vector3(5, 0, 7)
	player.global_position = Vector3(pp.x, world.height(pp.x, pp.z) + 1.3, pp.z)
	player.velocity = Vector3.ZERO
	var d5: Vector3 = world.portal_center - player.global_position
	player.vis.rotation.y = atan2(-d5.x, -d5.z)
	player.cam_yaw.rotation.y = player.vis.rotation.y
	await _snap("10_portal")
	G.skill_points = 4
	hud.open_skills()
	await _snap("07_skills")
	hud.close_skills()
	print("SHOTS DONE")
	get_tree().quit()
