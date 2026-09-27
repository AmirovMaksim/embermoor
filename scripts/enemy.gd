class_name Enemy
extends CharacterBody3D
## Враги: slime (прыгает), skeleton (рубит), golem (босс, слэм по площади).

const CFG := {
	"slime": {"hp": 26.0, "speed": 3.2, "dmg": 9.0, "aggro": 10.0, "atk_r": 1.25, "cd": 1.1, "xp": 12.0, "coins": 2, "windup": 0.0},
	"swamp": {"hp": 48.0, "speed": 3.4, "dmg": 12.0, "aggro": 11.0, "atk_r": 1.35, "cd": 1.2, "xp": 30.0, "coins": 4, "windup": 0.0},
	"skeleton": {"hp": 55.0, "speed": 3.6, "dmg": 14.0, "aggro": 13.0, "atk_r": 1.7, "cd": 1.6, "xp": 22.0, "coins": 4, "windup": 0.45},
	"golem": {"hp": 420.0, "speed": 2.4, "dmg": 30.0, "aggro": 18.0, "atk_r": 3.4, "cd": 3.2, "xp": 150.0, "coins": 50, "windup": 0.8},
	"guardian": {"hp": 320.0, "speed": 2.6, "dmg": 26.0, "aggro": 15.0, "atk_r": 3.2, "cd": 2.8, "xp": 200.0, "coins": 60, "windup": 0.8},
	"imp": {"hp": 34.0, "speed": 4.0, "dmg": 10.0, "aggro": 12.0, "atk_r": 1.2, "cd": 1.0, "xp": 26.0, "coins": 4, "windup": 0.0},
	"frost_slime": {"hp": 60.0, "speed": 2.4, "dmg": 12.0, "aggro": 11.0, "atk_r": 1.3, "cd": 2.4, "xp": 34.0, "coins": 5, "windup": 0.0},
	"magma_golem": {"hp": 380.0, "speed": 2.5, "dmg": 32.0, "aggro": 16.0, "atk_r": 3.4, "cd": 3.0, "xp": 250.0, "coins": 80, "windup": 0.8},
	"frost_golem": {"hp": 380.0, "speed": 2.3, "dmg": 28.0, "aggro": 16.0, "atk_r": 3.2, "cd": 3.0, "xp": 250.0, "coins": 80, "windup": 0.8},
	"shade": {"hp": 48.0, "speed": 4.2, "dmg": 13.0, "aggro": 14.0, "atk_r": 1.7, "cd": 1.4, "xp": 30.0, "coins": 4, "windup": 0.4},
	"shadow_lord": {"hp": 520.0, "speed": 2.6, "dmg": 34.0, "aggro": 18.0, "atk_r": 3.6, "cd": 2.6, "xp": 400.0, "coins": 120, "windup": 0.7},
}

const BOSS_FAMILY := ["golem", "guardian", "magma_golem", "frost_golem", "shadow_lord"]
const BOSS_NAMES := {
	"golem": "Каменный Голем", "guardian": "Хранитель Топей",
	"magma_golem": "Магмовый Голем", "frost_golem": "Морозный Голем",
	"shadow_lord": "Повелитель Мрака",
}

var kind := "slime"
var hp := 30.0
var max_hp := 30.0
var speed := 3.0
var dmg := 8.0
var aggro_r := 10.0
var atk_r := 1.4
var atk_cd := 0.0
var atk_cd_max := 1.2
var windup_time := 0.0
var windup := 0.0
var xp_reward := 10.0
var coin_reward := 2

var spitting := false
var throwing := false
var leaping := false
var leap_cd := 0.0
var lunge_t := 0.0
var lunged := false
var t := 0.0
var dead := false
var wander_dir := Vector3.ZERO
var wander_t := 0.0
var home := Vector3.ZERO
var knock := Vector3.ZERO
var flash_t := 0.0

var vis: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var sword_pivot: Node3D
var flash_mats: Array = []
var hp_bar: Node3D
var hp_fill: MeshInstance3D
var col_shape: CollisionShape3D
var bar_y := 1.9
var num_y := 1.6
var hop_cd := 0.0

var elite := ""

static func spawn(parent: Node, k: String, pos: Vector3, elite_affix := "") -> Enemy:
	var e := Enemy.new()
	e.kind = k
	e.position = pos
	e.elite = elite_affix
	parent.add_child(e)
	return e

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	var c: Dictionary = CFG[kind]
	max_hp = c["hp"] * G.diff_mult_hp()
	hp = max_hp
	speed = c["speed"]
	dmg = c["dmg"] * G.diff_mult_dmg()
	aggro_r = c["aggro"]
	atk_r = c["atk_r"]
	atk_cd_max = c["cd"]
	windup_time = c["windup"]
	xp_reward = c["xp"]
	coin_reward = c["coins"]
	home = global_position
	match kind:
		"slime":
			_build_slime(Assets.C_SLIME)
		"swamp":
			_build_slime(Color("#8a5fb8"))
		"imp":
			_build_slime(Color("#ff7a2a"))
		"frost_slime":
			_build_slime(Color("#9adcf0"))
		"skeleton":
			_build_skeleton(Assets.C_BONE)
		"shade":
			_build_skeleton(Color("#6a5f78"))
		"golem":
			_build_golem(Assets.C_STONE, 1.0)
		"guardian":
			_build_golem(Color("#5f7d63"), 0.8)
		"magma_golem":
			_build_golem(Color("#4a332c"), 1.05)
		"frost_golem":
			_build_golem(Color("#b8cede"), 1.0)
		"shadow_lord":
			_build_golem(Color("#2c2438"), 0.95)
	_build_hp_bar()
	if elite != "":
		_make_elite()

func _make_elite() -> void:
	max_hp = max_hp * 1.35
	hp = max_hp
	dmg = dmg * 1.15
	vis.scale = vis.scale * 1.12
	var aura_col := Color(1.0, 0.5, 0.15)
	if elite == "frost":
		aura_col = Color(0.45, 0.8, 1.0)
	elif elite == "vampire":
		aura_col = Color(0.8, 0.15, 0.25)
	var aura := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.8
	tor.outer_radius = 0.95
	aura.mesh = tor
	aura.material_override = Assets.unshaded(aura_col, false, true, true)
	aura.position = Vector3(0, 0.15, 0)
	add_child(aura)

func _gather_mats(node: Node) -> void:
	for ch in node.get_children():
		if ch is MeshInstance3D and ch.mesh:
			for si in ch.mesh.get_surface_count():
				var m = ch.mesh.surface_get_material(si)
				if m is StandardMaterial3D:
					flash_mats.append(m)
		_gather_mats(ch)

# ---------------- ВИЗУАЛ ----------------

func _build_slime(body_color: Color) -> void:
	col_shape = CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.45
	col_shape.shape = s
	col_shape.position = Vector3(0, 0.45, 0)
	add_child(col_shape)
	vis = Node3D.new()
	add_child(vis)
	var body := Assets.sph(0.5, body_color, Vector3(0, 0.42, 0), 8, 4)
	body.scale = Vector3(1.0, 0.75, 1.0)
	vis.add_child(body)
	vis.add_child(Assets.sph(0.05, Color("#1a2a12"), Vector3(-0.16, 0.5, -0.4), 6, 3))
	vis.add_child(Assets.sph(0.05, Color("#1a2a12"), Vector3(0.16, 0.5, -0.4), 6, 3))
	if kind == "swamp":
		vis.scale = Vector3(1.15, 1.15, 1.15)
	bar_y = 1.35
	num_y = 1.1
	_gather_mats(vis)

func _build_skeleton(bone_color: Color) -> void:
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.2
	col_shape.shape = cap
	col_shape.position = Vector3(0, 0.9, 0)
	add_child(col_shape)
	vis = Node3D.new()
	add_child(vis)
	leg_l = _limb(vis, Vector3(-0.11, 0.6, 0), Vector3(0.11, 0.58, 0.11), bone_color)
	leg_r = _limb(vis, Vector3(0.11, 0.6, 0), Vector3(0.11, 0.58, 0.11), bone_color)
	vis.add_child(Assets.box(Vector3(0.36, 0.5, 0.2), bone_color, Vector3(0, 0.9, 0)))
	vis.add_child(Assets.box(Vector3(0.4, 0.08, 0.24), bone_color.darkened(0.15), Vector3(0, 0.82, 0)))
	vis.add_child(Assets.sph(0.17, bone_color, Vector3(0, 1.32, 0), 8, 4))
	vis.add_child(Assets.sph(0.035, Color("#151013"), Vector3(-0.06, 1.34, -0.14), 6, 3))
	vis.add_child(Assets.sph(0.035, Color("#151013"), Vector3(0.06, 1.34, -0.14), 6, 3))
	arm_l = _limb(vis, Vector3(-0.26, 1.12, 0), Vector3(0.09, 0.46, 0.09), bone_color)
	arm_r = _limb(vis, Vector3(0.26, 1.12, 0), Vector3(0.09, 0.46, 0.09), bone_color)
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0, -0.4, 0)
	arm_r.add_child(sword_pivot)
	sword_pivot.add_child(Assets.box(Vector3(0.06, 0.55, 0.02), Assets.C_METAL, Vector3(0, 0.32, 0)))
	sword_pivot.add_child(Assets.box(Vector3(0.18, 0.04, 0.05), Assets.C_TRUNK, Vector3(0, 0.03, 0)))
	bar_y = 1.95
	num_y = 1.7
	_gather_mats(vis)

func _build_golem(stone: Color, sc: float) -> void:
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.0 * sc
	cap.height = 3.0 * sc
	col_shape.shape = cap
	col_shape.position = Vector3(0, 1.9 * sc, 0)
	add_child(col_shape)
	vis = Node3D.new()
	vis.scale = Vector3(sc, sc, sc)
	add_child(vis)
	leg_l = _limb(vis, Vector3(-0.45, 1.75, 0), Vector3(0.5, 1.75, 0.5), stone.darkened(0.1))
	leg_r = _limb(vis, Vector3(0.45, 1.75, 0), Vector3(0.5, 1.75, 0.5), stone.darkened(0.1))
	vis.add_child(Assets.box(Vector3(1.1, 0.6, 0.8), stone.darkened(0.05), Vector3(0, 1.95, 0)))
	vis.add_child(Assets.box(Vector3(1.5, 1.4, 1.0), stone, Vector3(0, 2.9, 0)))
	var moss := Assets.C_LEAF if kind == "golem" else Color("#8f6fff")
	vis.add_child(Assets.box(Vector3(0.35, 0.12, 1.02), moss.darkened(0.1), Vector3(0, 3.3, 0)))
	vis.add_child(Assets.box(Vector3(0.55, 0.45, 0.5), stone.lightened(0.05), Vector3(0, 3.85, 0)))
	var eye := Assets.C_EMBER
	if kind == "guardian":
		eye = Color("#7cff6a")
	elif kind == "magma_golem":
		eye = Color("#ffb347")
	elif kind == "frost_golem":
		eye = Color("#7cd8ff")
	elif kind == "shadow_lord":
		eye = Color("#b06aff")
	vis.add_child(Assets.sph(0.07, eye, Vector3(-0.14, 3.87, -0.26), 6, 3))
	vis.add_child(Assets.sph(0.07, eye, Vector3(0.14, 3.87, -0.26), 6, 3))
	arm_l = _limb(vis, Vector3(-1.0, 3.35, 0), Vector3(0.45, 1.6, 0.45), stone.darkened(0.08))
	arm_l.add_child(Assets.sph(0.32, stone, Vector3(0, -0.85, 0), 6, 3))
	arm_r = _limb(vis, Vector3(1.0, 3.35, 0), Vector3(0.45, 1.6, 0.45), stone.darkened(0.08))
	arm_r.add_child(Assets.sph(0.32, stone, Vector3(0, -0.85, 0), 6, 3))
	bar_y = 4.7 * sc
	num_y = 4.2 * sc
	_gather_mats(vis)

func _limb(parent: Node3D, pivot_pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)
	pivot.add_child(Assets.box(size, color, Vector3(0, -size.y * 0.5, 0)))
	return pivot

func _build_hp_bar() -> void:
	hp_bar = Node3D.new()
	hp_bar.position = Vector3(0, bar_y, 0)
	add_child(hp_bar)
	var bg := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(1.0, 0.14)
	bg.mesh = bq
	bg.material_override = Assets.unshaded(Color(0.05, 0.05, 0.08, 0.7), true, true)
	hp_bar.add_child(bg)
	hp_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.92, 0.08)
	fq.center_offset = Vector3(-0.46, 0, 0)
	hp_fill.mesh = fq
	hp_fill.material_override = Assets.unshaded(Color(0.35, 0.9, 0.35), true, true)
	hp_fill.position.z = -0.01
	hp_bar.add_child(hp_fill)
	hp_bar.visible = false

# ---------------- ИИ ----------------

func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	atk_cd = maxf(atk_cd - delta, 0.0)
	hop_cd = maxf(hop_cd - delta, 0.0)
	leap_cd = maxf(leap_cd - delta, 0.0)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0:
			for m in flash_mats:
				m.emission_enabled = false
	if not is_on_floor():
		velocity.y -= 24.0 * delta

	var player = G.player
	var dist := 999.0
	var dir := Vector3.ZERO
	var chasing := false
	# приземление прыжка-салютa (вне блока агро — чтобы не зависало)
	if leaping and is_on_floor() and velocity.y <= 0.0:
		leaping = false
		var splat := Assets.C_SLIME
		if kind == "imp":
			splat = Color("#ff7a2a")
		elif kind == "frost_slime":
			splat = Color("#9adcf0")
		FX.burst(G.world, global_position, splat, 14, 5.0, 0.5, 0.16)
		G.sfx("slam", -10.0, 1.5)
		G.shake(0.35)
		if player and is_instance_valid(player) and not player.dead:
			if player.global_position.distance_to(global_position) < 2.6:
				G.damage_player(dmg * 1.3, global_position)
	# урон рывка скелета
	if lunge_t > 0.0:
		lunge_t -= delta
		if not lunged and player and is_instance_valid(player) and not player.dead:
			if player.global_position.distance_to(global_position) < 1.9:
				lunged = true
				G.damage_player(dmg, global_position)
				G.sfx("hit", -4.0)

	if player and is_instance_valid(player) and not player.dead and G.game_started:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
		var leashed := global_position.distance_to(home) < 26.0  # не убегаем далеко от дома
		if dist < aggro_r or (hp < max_hp and leashed):
			chasing = dist > atk_r * 0.7
			dir = to_p.normalized()
			match kind:
				"slime", "imp", "frost_slime":
					if dist < 1.2 and atk_cd <= 0.0:
						atk_cd = atk_cd_max
						G.damage_player(dmg, global_position)
					if not leaping and leap_cd <= 0.0 and dist > 3.0 and dist < 9.0 and is_on_floor():
						leap_cd = 5.5
						leaping = true
						velocity = dir * 7.0 + Vector3(0, 8.0, 0)
						G.sfx("roll", -8.0, 0.7)
				"swamp":
					if dist < 1.2 and atk_cd <= 0.0:
						atk_cd = atk_cd_max
						G.damage_player(dmg, global_position)
					if dist > 2.5 and dist < 10.0 and atk_cd <= 0.0 and windup <= 0.0:
						windup = 0.55
						atk_cd = atk_cd_max
						spitting = true
						G.sfx("swing", -12.0, 1.8)
				"skeleton":
					if dist < atk_r and atk_cd <= 0.0 and windup <= 0.0:
						windup = windup_time
						_telegraph()
			if kind in ["golem", "guardian", "magma_golem", "frost_golem"]:
				if dist < atk_r and atk_cd <= 0.0 and windup <= 0.0:
					windup = windup_time
					throwing = false
					_telegraph()
				elif dist > 6.0 and dist < 32.0 and atk_cd <= 0.0 and windup <= 0.0:
					windup = windup_time
					atk_cd = atk_cd_max
					throwing = true
					_telegraph()

	if windup > 0.0:
		windup -= delta
		_anim_windup()
		if windup <= 0.0:
			_strike(dist)
			atk_cd = atk_cd_max
		velocity.x = lerpf(velocity.x, 0.0, 8.0 * delta)
		velocity.z = lerpf(velocity.z, 0.0, 8.0 * delta)
	else:
		var spd := 0.0
		if chasing:
			spd = speed
		else:
			wander_t -= delta
			if wander_t <= 0.0:
				wander_t = G.rng.randf_range(2.0, 4.5)
				if G.rng.randf() < 0.6:
					wander_dir = Vector3(G.rng.randf_range(-1, 1), 0, G.rng.randf_range(-1, 1)).normalized()
				else:
					wander_dir = Vector3.ZERO
			var to_home: Vector3 = home - global_position
			to_home.y = 0
			if to_home.length() > 9.0:
				wander_dir = to_home.normalized()
			dir = wander_dir
			spd = speed * 0.35
		if leaping and not is_on_floor():
			pass  # сохраняем импульс прыжка
		elif lunge_t > 0.0:
			pass  # сохраняем импульс рывка
		elif kind in ["slime", "imp", "swamp", "frost_slime"]:
			if is_on_floor() and dir.length() > 0.1 and hop_cd <= 0.0:
				velocity = dir * spd * 1.7 + Vector3(0, 5.0, 0)
				hop_cd = 0.7
			velocity.x = lerpf(velocity.x, dir.x * spd, 3.0 * delta)
			velocity.z = lerpf(velocity.z, dir.z * spd, 3.0 * delta)
		else:
			velocity.x = lerpf(velocity.x, dir.x * spd, 6.0 * delta)
			velocity.z = lerpf(velocity.z, dir.z * spd, 6.0 * delta)

	velocity += knock * delta * 9.0
	knock = knock.move_toward(Vector3.ZERO, delta * 22.0)
	move_and_slide()

	if dir.length() > 0.1 and kind != "slime":
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(9.0 * delta, 1.0))

	_animate(delta, chasing)

func _animate(delta: float, chasing: bool) -> void:
	match kind:
		"slime":
			var stretch := 1.0 + sin(t * 6.0) * 0.1
			if not is_on_floor():
				stretch = 1.25
			vis.scale = vis.scale.lerp(Vector3(2.0 - stretch, stretch, 2.0 - stretch), minf(10.0 * delta, 1.0))
		"imp", "frost_slime", "swamp":
			var stretch := 1.0 + sin(t * 6.0) * 0.1
			if not is_on_floor():
				stretch = 1.25
			vis.scale = vis.scale.lerp(Vector3(2.0 - stretch, stretch, 2.0 - stretch) * (1.15 if kind == "swamp" else 1.0), minf(10.0 * delta, 1.0))
		"skeleton":
			var hs := Vector2(velocity.x, velocity.z).length()
			var c := sin(t * 8.0)
			if hs > 0.4:
				leg_l.rotation.x = c * 0.5
				leg_r.rotation.x = -c * 0.5
				if windup <= 0.0:
					arm_l.rotation.x = -c * 0.35
					arm_r.rotation.x = c * 0.35
			else:
				leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 8.0 * delta)
				leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 8.0 * delta)
				if windup <= 0.0:
					arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 8.0 * delta)
					arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, 8.0 * delta)
		"golem", "guardian", "magma_golem", "frost_golem":
			var hs := Vector2(velocity.x, velocity.z).length()
			var c := sin(t * 3.2)
			if hs > 0.4:
				leg_l.rotation.x = c * 0.35
				leg_r.rotation.x = -c * 0.35
			if windup <= 0.0:
				arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, 6.0 * delta)
				arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, 6.0 * delta)

func _telegraph() -> void:
	match kind:
		"skeleton":
			lunged = false
			G.sfx("swing", -10.0, 0.8)
			var tw := create_tween()
			tw.tween_property(arm_r, "rotation:x", -2.4, windup_time)
		"golem", "guardian", "magma_golem", "frost_golem":
			G.sfx("swing", -6.0, 0.55 if not throwing else 1.2)
			var tw := create_tween()
			tw.tween_property(arm_l, "rotation:x", -2.6, windup_time)
			tw.parallel().tween_property(arm_r, "rotation:x", -2.6, windup_time)
			if not throwing:
				var ring := MeshInstance3D.new()
				var tor := TorusMesh.new()
				tor.inner_radius = 0.86
				tor.outer_radius = 1.0
				ring.mesh = tor
				ring.material_override = Assets.unshaded(Color(1.0, 0.3, 0.15, 0.7), false, true)
				ring.position = global_position + Vector3(0, 0.25, 0)
				ring.scale = Vector3.ONE * 0.5
				G.world.add_child(ring)
				var rt := ring.create_tween()
				rt.tween_property(ring, "scale", Vector3.ONE * 4.6, windup_time + 0.15)
				rt.tween_property(ring, "material_override:albedo_color:a", 0.0, 0.2)
				rt.tween_callback(ring.queue_free)

func _anim_windup() -> void:
	pass

func _spit(count: int, pdmg: float, col: Color, speed: float, spread_deg := 0.0) -> void:
	if not (G.player and is_instance_valid(G.player)):
		return
	var origin := global_position + Vector3(0, 0.55, 0)
	var target: Vector3 = G.player.global_position + Vector3(0, 1.0, 0)
	var base := (target - origin).normalized()
	for i in count:
		var off := (float(i) - (count - 1) * 0.5) * deg_to_rad(spread_deg)
		Projectile.spawn(G.world, origin, base.rotated(Vector3.UP, off), speed, pdmg, col)
	G.sfx("swing", -6.0, 1.7)

func _strike(dist: float) -> void:
	var slam_col := Assets.C_ROCK_DARK
	match kind:
		"swamp":
			_spit(3, dmg, Color("#8fff5a"), 9.0, 14.0)
		"frost_slime":
			_spit(1, dmg, Color("#a0e8ff"), 11.0)
		"skeleton":
			if is_instance_valid(arm_r):
				var tw := create_tween()
				tw.tween_property(arm_r, "rotation:x", 1.2, 0.09)
			if G.player and is_instance_valid(G.player):
				var ldir: Vector3 = (G.player.global_position - global_position)
				ldir.y = 0
				velocity += ldir.normalized() * 8.5
			lunge_t = 0.3
			lunged = false
			G.sfx("swing", -4.0, 1.25)
		"golem", "guardian", "magma_golem", "frost_golem":
			if kind == "guardian":
				slam_col = Color("#7a9a5a")
			elif kind == "magma_golem":
				slam_col = Color("#ff7a2a")
			elif kind == "frost_golem":
				slam_col = Color("#a0e8ff")
			if is_instance_valid(arm_l):
				var tw := create_tween()
				tw.tween_property(arm_l, "rotation:x", 0.9, 0.12)
				tw.parallel().tween_property(arm_r, "rotation:x", 0.9, 0.12)
			FX.burst(G.world, global_position + Vector3(0, 0.3, 0), slam_col, 24, 7.0, 0.6, 0.2)
			G.shake(1.0)
			G.sfx("slam", 0.0)
			if dist < atk_r + 1.2:
				G.damage_player(dmg, global_position)
			if throwing and G.player and is_instance_valid(G.player):
				var origin := global_position + Vector3(0, 3.2 * vis.scale.y, 0)
				var target: Vector3 = G.player.global_position + Vector3(0, 1.0, 0)
				var bdir := (target - origin).normalized()
				match kind:
					"golem":
						Projectile.spawn(G.world, origin, bdir + Vector3(0, 0.25, 0), 13.0, 22.0, Color("#8b8b93"), 0.26)
					"guardian":
						for i in 8:
							var a := TAU * i / 8.0
							Projectile.spawn(G.world, origin, Vector3(cos(a), 0.1, sin(a)), 7.5, 13.0, Color("#8fff5a"), 0.13)
					"magma_golem":
						for i in 3:
							var off := (float(i) - 1.0) * deg_to_rad(10.0)
							Projectile.spawn(G.world, origin, bdir.rotated(Vector3.UP, off), 12.0, 20.0, Color("#ff7a2a"), 0.16)
					"frost_golem":
						for i in 5:
							var off := (float(i) - 2.0) * deg_to_rad(9.0)
							Projectile.spawn(G.world, origin, bdir.rotated(Vector3.UP, off), 11.0, 17.0, Color("#a0e8ff"), 0.15)
	spitting = false
	throwing = false

# ---------------- УРОН И СМЕРТЬ ----------------

func take_hit(dmg: float, dir: Vector3, _from) -> void:
	if dead:
		return
	hp -= dmg
	flash_t = 0.12
	for m in flash_mats:
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 0.9
	G.dmg_number(global_position + Vector3(0, num_y, 0), str(int(dmg)), Color(1.0, 0.9, 0.4))
	var k := dir * (2.0 if kind == "golem" else 5.0)
	knock += k
	if kind == "golem":
		aggro_r = 40.0
	G.sfx("hit", -4.0, G.rng.randf_range(0.9, 1.1))
	_update_hp_bar()
	if hp <= 0.0:
		_die()

func _update_hp_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	hp_bar.visible = ratio < 0.999 and not dead
	hp_fill.scale.x = maxf(ratio, 0.001)
	hp_fill.material_override.albedo_color = Color(0.9, 0.25, 0.2).lerp(Color(0.35, 0.9, 0.35), ratio)

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	col_shape.set_deferred("disabled", true)
	hp_bar.visible = false
	G.on_enemy_killed(kind)
	G.sfx("die", -4.0, G.rng.randf_range(0.9, 1.1) if kind != "golem" else 0.7)
	# дропы
	var orb_count := int(xp_reward / 8.0)
	for i in orb_count:
		Pickup.spawn(G.world, "orb", global_position + Vector3(0, 0.8, 0), xp_reward / orb_count)
	for i in coin_reward:
		Pickup.spawn(G.world, "coin", global_position + Vector3(0, 0.8, 0), 1)
	if G.rng.randf() < 0.22 or kind == "golem" or kind == "guardian":
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 0.8, 0))
	if kind == "golem":
		Pickup.spawn(G.world, "relic", global_position + Vector3(0, 1.2, 0))
		G.shake(1.2)
		FX.burst(G.world, global_position + Vector3(0, 2, 0), Assets.C_EMBER, 40, 8.0, 1.0, 0.25, 8.0, true)
	if kind == "guardian":
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 1.0, 0))
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 1.0, 0))
		G.shake(1.2)
		FX.burst(G.world, global_position + Vector3(0, 2, 0), Color("#8f6fff"), 40, 8.0, 1.0, 0.25, 8.0, true)
	# анимация смерти
	var tw := create_tween()
	if kind == "slime":
		tw.tween_property(vis, "scale", Vector3(1.6, 0.05, 1.6), 0.3).set_trans(Tween.TRANS_CUBIC)
	else:
		tw.tween_property(vis, "rotation:z", deg_to_rad(-90), 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_fade_out(0.9)
	get_tree().create_timer(1.4).timeout.connect(queue_free)

func _fade_out(dur: float) -> void:
	var mats := []
	_collect_mats(vis, mats)
	for m in mats:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tw := create_tween()
	for m in mats:
		tw.parallel().tween_property(m, "albedo_color:a", 0.0, dur).set_delay(0.5)

func _collect_mats(node: Node, arr: Array) -> void:
	for ch in node.get_children():
		if ch is MeshInstance3D and ch.mesh:
			for si in ch.mesh.get_surface_count():
				var m = ch.mesh.surface_get_material(si)
				if m is StandardMaterial3D:
					arr.append(m)
		_collect_mats(ch, arr)
