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
	"shadow_stalker": {"hp": 700.0, "speed": 3.8, "dmg": 26.0, "aggro": 30.0, "atk_r": 2.4, "cd": 1.8, "xp": 500.0, "coins": 150, "windup": 0.5},
	"stalker_clone": {"hp": 1.0, "speed": 4.6, "dmg": 6.0, "aggro": 26.0, "atk_r": 1.4, "cd": 1.7, "xp": 4.0, "coins": 0, "windup": 0.0},
}

const BOSS_FAMILY := ["golem", "guardian", "magma_golem", "frost_golem", "shadow_lord", "shadow_stalker"]
const BOSS_NAMES := {
	"golem": "Каменный Голем", "guardian": "Хранитель Топей",
	"magma_golem": "Магмовый Голем", "frost_golem": "Морозный Голем",
	"shadow_lord": "Повелитель Мрака", "shadow_stalker": "Охотник Теней",
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
var phase := 1
var burn_t := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var slow_t := 0.0
var t := 0.0
var dead := false
var wander_dir := Vector3.ZERO
var wander_t := 0.0
var home := Vector3.ZERO
var knock := Vector3.ZERO
var flash_t := 0.0

# Шкала оглушения (stagger): тяжёлые удары, идеальные перекаты и посох копят очки;
# при 100% босс/элита входит в 'stunned' на 3.5 с и получает +50% урона.
var stagger_max := 0.0
var stagger_current := 0.0
var stunned_t := 0.0
# Статус FREEZE (лёд): полностью обездвиживает; огонь по замороженному = «Термошок».
var frozen_t := 0.0
var _frozen_vis := false
# Охотник Теней: рывок с телеграфом, дымовая завеса с копиями, ярость-телепорты.
var dash_cd := 0.0
var dash_pending := false
var dashing := false
var dash_t := 0.0
var dash_hit := false
var dash_dir := Vector3.ZERO
var veil_cd := 6.0
var veiled_t := 0.0
var blink_cd := 0.0
var clones: Array = []

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
	if kind in BOSS_FAMILY:
		stagger_max = 120.0 if kind == "shadow_stalker" else 100.0
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
		"shadow_stalker":
			_build_stalker(false)
		"stalker_clone":
			_build_stalker(true)
	_build_hp_bar()
	if elite != "":
		_make_elite()

func _make_elite() -> void:
	max_hp = max_hp * 1.35
	hp = max_hp
	dmg = dmg * 1.15
	stagger_max = 80.0
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

## Охотник Теней: жилистый рогатый силуэт в рваном плаще; копии — бледнее и мельче.
func _build_stalker(clone := false) -> void:
	var sc := 0.55 if clone else 1.0
	col_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42 * sc
	cap.height = 1.7 * sc
	col_shape.shape = cap
	col_shape.position = Vector3(0, 0.95 * sc, 0)
	add_child(col_shape)
	vis = Node3D.new()
	vis.scale = Vector3(sc, sc, sc)
	add_child(vis)
	var coat := Color("#3a2b52") if clone else Color("#241c30")
	var coat_d := coat.darkened(0.25)
	leg_l = _limb(vis, Vector3(-0.18, 1.15, 0), Vector3(0.13, 1.15, 0.13), coat_d)
	leg_r = _limb(vis, Vector3(0.18, 1.15, 0), Vector3(0.13, 1.15, 0.13), coat_d)
	vis.add_child(Assets.box(Vector3(0.55, 0.9, 0.32), coat, Vector3(0, 1.7, 0)))
	var cloak := Assets.box(Vector3(0.72, 1.0, 0.1), coat_d, Vector3(0, 1.55, 0.24))
	cloak.rotation_degrees.x = 8
	vis.add_child(cloak)
	vis.add_child(Assets.box(Vector3(0.34, 0.3, 0.36), coat, Vector3(0, 2.32, 0)))
	for s in [-1.0, 1.0]:
		var horn := Assets.box(Vector3(0.07, 0.4, 0.07), coat_d, Vector3(0.13 * s, 2.62, 0))
		horn.rotation_degrees.z = -18.0 * s
		vis.add_child(horn)
	var eye := Color("#b28aff") if clone else Color("#8ef4ff")
	for s2 in [-0.09, 0.09]:
		var e := Assets.sph(0.05, eye, Vector3(s2, 2.34, -0.19), 6, 3)
		e.material_override = Assets.glow_mat(eye, 1.7)
		vis.add_child(e)
	arm_l = _limb(vis, Vector3(-0.38, 2.05, 0), Vector3(0.11, 0.85, 0.11), coat)
	arm_r = _limb(vis, Vector3(0.38, 2.05, 0), Vector3(0.11, 0.85, 0.11), coat)
	for arm in [arm_l, arm_r]:
		for f in 3:
			arm.add_child(Assets.box(Vector3(0.03, 0.22, 0.03), Assets.C_BONE.darkened(0.2), Vector3(-0.05 + 0.05 * f, -0.95, -0.03)))
	vis.add_child(Assets.box(Vector3(0.2, 0.34, 0.2), coat_d, Vector3(-0.42, 2.2, 0)))
	vis.add_child(Assets.box(Vector3(0.2, 0.34, 0.2), coat_d, Vector3(0.42, 2.2, 0)))
	bar_y = 2.95 * sc
	num_y = 2.6 * sc
	_gather_mats(vis)

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
	dash_cd = maxf(dash_cd - delta, 0.0)
	veil_cd = maxf(veil_cd - delta, 0.0)
	blink_cd = maxf(blink_cd - delta, 0.0)
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0 and stunned_t <= 0.0 and frozen_t <= 0.0:
			for m in flash_mats:
				m.emission_enabled = false
	# ОГЛУШЕНИЕ: враг беспомощен, получает +50% урона
	if stunned_t > 0.0:
		_process_stunned(delta)
		return
	# ЗАМОРОЗКА: обездвижен, ждёт огня (Термошок) или разморозки
	if frozen_t > 0.0:
		_process_frozen(delta)
		return
	# дымовая завеса Охотника
	if veiled_t > 0.0:
		veiled_t -= delta
		if veiled_t <= 0.0:
			_end_veil()
	# рывок Охотника: фиксированный импульс, урон в полёте
	if dashing:
		_process_dash(delta)
		return
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
				self._hit_player(dmg * 1.3)
	# горение и замедление
	if burn_t > 0.0:
		burn_t -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.7
			hp -= burn_dps
			G.dmg_number(global_position + Vector3(0, num_y, 0), str(int(burn_dps)), Color(1.0, 0.5, 0.2))
			FX.burst(G.world, global_position + Vector3(0, 0.8, 0), Color(1.0, 0.5, 0.15), 5, 2.0, 0.3, 0.08, -2.0, true)
			_update_hp_bar()
			if hp <= 0.0 and not dead:
				_die()
				return
	if slow_t > 0.0:
		slow_t -= delta

	# урон рывка скелета
	if lunge_t > 0.0:
		lunge_t -= delta
		if not lunged and player and is_instance_valid(player) and not player.dead:
			if player.global_position.distance_to(global_position) < 1.9:
				lunged = true
				self._hit_player(dmg)
				G.sfx("hit", -4.0)

	if player and is_instance_valid(player) and not player.dead and G.game_started:
		var to_p: Vector3 = player.global_position - global_position
		to_p.y = 0
		dist = to_p.length()
		var leashed := global_position.distance_to(home) < 26.0  # не убегаем далеко от дома
		if has_meta("ritual_minion") or dist < aggro_r or (hp < max_hp and leashed):
			chasing = dist > atk_r * 0.7
			dir = to_p.normalized()
			# миньоны ритуала игнорируют героя и бьют Алтарь Моры
			if G.ritual_node != null and is_instance_valid(G.ritual_node) and has_meta("ritual_minion"):
				var to_a: Vector3 = G.ritual_node.altar_pos - global_position
				to_a.y = 0
				dist = to_a.length()
				dir = to_a.normalized()
				chasing = dist > 1.8
				if dist < 2.2 and atk_cd <= 0.0:
					atk_cd = atk_cd_max
					G.ritual_node.damage_altar(dmg * 0.7)
					G.sfx("hit", -12.0, 0.8)
			else:
				match kind:
					"slime", "imp", "frost_slime":
						if dist < 1.2 and atk_cd <= 0.0:
							atk_cd = atk_cd_max
							self._hit_player(dmg)
						if not leaping and leap_cd <= 0.0 and dist > 3.0 and dist < 9.0 and is_on_floor():
							leap_cd = 5.5
							leaping = true
							velocity = dir * 7.0 + Vector3(0, 8.0, 0)
							G.sfx("roll", -8.0, 0.7)
					"swamp":
						if dist < 1.2 and atk_cd <= 0.0:
							atk_cd = atk_cd_max
							self._hit_player(dmg)
						if dist > 2.5 and dist < 10.0 and atk_cd <= 0.0 and windup <= 0.0:
							windup = 0.55
							atk_cd = atk_cd_max
							spitting = true
							G.sfx("swing", -12.0, 1.8)
					"skeleton":
						if dist < atk_r and atk_cd <= 0.0 and windup <= 0.0:
							windup = windup_time
							_telegraph()
					"stalker_clone":
						if dist < atk_r and atk_cd <= 0.0:
							atk_cd = atk_cd_max
							self._hit_player(dmg)
					"shadow_stalker":
						if dist < atk_r and atk_cd <= 0.0 and windup <= 0.0 and veiled_t <= 0.0:
							windup = windup_time
							_telegraph()
						elif not dashing and not dash_pending and dist > 5.0 and dist < 17.0 and dash_cd <= 0.0 and windup <= 0.0 and veiled_t <= 0.0:
							dash_cd = 7.5
							dash_pending = true
							dash_hit = false
							dash_dir = dir
							windup = 0.85
							_telegraph_dash()
						if veiled_t <= 0.0 and veil_cd <= 0.0 and dist < 15.0 and windup <= 0.0 and not dash_pending:
							veil_cd = 13.0
							_start_veil()
						if phase == 2 and veiled_t <= 0.0 and blink_cd <= 0.0 and windup <= 0.0 and not dash_pending:
							blink_cd = 3.6
							_blink_behind()
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
		if slow_t > 0.0:
			spd *= 0.55
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

	if elite == "fire" and Vector2(velocity.x, velocity.z).length() > 1.0 and G.rng.randf() < 0.25:
		FX.burst(G.world, global_position + Vector3(0, 0.2, 0), Color(1.0, 0.5, 0.15), 2, 1.0, 0.35, 0.08, -2.0, true)
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
		"shadow_stalker", "stalker_clone":
			var hs2 := Vector2(velocity.x, velocity.z).length()
			var c2 := sin(t * 7.0)
			vis.position.y = sin(t * 2.0) * 0.06
			if hs2 > 0.4:
				leg_l.rotation.x = c2 * 0.45
				leg_r.rotation.x = -c2 * 0.45
			else:
				leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, 8.0 * delta)
				leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, 8.0 * delta)
			if windup <= 0.0:
				arm_l.rotation.x = lerpf(arm_l.rotation.x, -0.3, 6.0 * delta)
				arm_r.rotation.x = lerpf(arm_r.rotation.x, -0.3, 6.0 * delta)

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
		"shadow_stalker":
			G.sfx("swing", -6.0, 0.6)
			if is_instance_valid(arm_l):
				var tw2 := create_tween()
				tw2.tween_property(arm_l, "rotation:x", -2.2, windup_time)
				tw2.parallel().tween_property(arm_r, "rotation:x", -2.2, windup_time)

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
		"shadow_stalker":
			if dash_pending:
				# рывок: направление зафиксировано при телеграфе — уходи перекатом
				dash_pending = false
				dashing = true
				dash_t = 0.34
				G.sfx("roar", -6.0, 1.7)
			else:
				if is_instance_valid(arm_l):
					var tw3 := create_tween()
					tw3.tween_property(arm_l, "rotation:x", 1.0, 0.1)
					tw3.parallel().tween_property(arm_r, "rotation:x", 1.0, 0.1)
				if dist < atk_r + 0.4:
					self._hit_player(dmg)
				G.sfx("swing", -4.0, 0.7)
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
			if dist < atk_r + (1.2 if phase == 2 else 0.0):
				self._hit_player(dmg)
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

# ---------------- СТАН, ЗАМОРОЗКА, РЫВОК ОХОТНИКА ----------------

func _process_stunned(delta: float) -> void:
	stunned_t -= delta
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	velocity.x = lerpf(velocity.x, 0.0, minf(10.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, 0.0, minf(10.0 * delta, 1.0))
	move_and_slide()
	if G.rng.randf() < 0.22:
		FX.burst(G.world, global_position + Vector3(0, num_y + 0.5, 0), Color(1.0, 0.9, 0.3), 3, 1.6, 0.5, 0.1, -1.0, true)
	if stunned_t <= 0.0:
		stagger_current = 0.0
		for m in flash_mats:
			m.emission_enabled = false
		_update_hp_bar()

func _process_frozen(delta: float) -> void:
	frozen_t -= delta
	if not _frozen_vis:
		_frozen_vis = true
		for m in flash_mats:
			m.emission_enabled = true
			m.emission = Color(0.5, 0.8, 1.0)
			m.emission_energy_multiplier = 0.8
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	velocity.x = lerpf(velocity.x, 0.0, minf(10.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, 0.0, minf(10.0 * delta, 1.0))
	move_and_slide()
	if G.rng.randf() < 0.14:
		FX.burst(G.world, global_position + Vector3(0, 0.9, 0), Color(0.7, 0.9, 1.0), 2, 1.2, 0.4, 0.08, 3.0)
	if frozen_t <= 0.0:
		_frozen_vis = false
		for m in flash_mats:
			m.emission_enabled = false

func _process_dash(delta: float) -> void:
	dash_t -= delta
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	velocity.x = dash_dir.x * 26.0
	velocity.z = dash_dir.z * 26.0
	rotation.y = lerp_angle(rotation.y, atan2(-dash_dir.x, -dash_dir.z), minf(14.0 * delta, 1.0))
	move_and_slide()
	if not dash_hit and player_valid() and not G.player.dead:
		if G.player.global_position.distance_to(global_position) < 1.9:
			dash_hit = true
			self._hit_player(dmg * 1.25)
			G.sfx("hit", -2.0, 0.8)
	if dash_t <= 0.0:
		dashing = false
		velocity.x = dash_dir.x * 3.0
		velocity.z = dash_dir.z * 3.0

func player_valid() -> bool:
	return G.player != null and is_instance_valid(G.player)

## Накопление шкалы оглушения; на 100% — стан на 3.5 с.
func _apply_stagger(v: float) -> void:
	if stagger_max <= 0.0 or dead or stunned_t > 0.0 or v <= 0.0:
		return
	stagger_current = minf(stagger_current + v, stagger_max)
	if stagger_current >= stagger_max:
		_enter_stunned()

func _enter_stunned() -> void:
	stunned_t = 3.5
	stagger_current = stagger_max
	windup = 0.0
	dashing = false
	dash_pending = false
	if veiled_t > 0.0:
		_end_veil()
	G.hitstop(0.08)
	G.sfx("roar", -2.0, 1.6)
	G.shake(0.9)
	G.hud.notify(str(BOSS_NAMES.get(kind, "Элитный враг")) + " ОГЛУШЁН! Бей со всей силы!", Color(1.0, 0.9, 0.3))
	FX.burst(G.world, global_position + Vector3(0, num_y + 0.5, 0), Color(1.0, 0.9, 0.3), 26, 5.0, 0.8, 0.18, -1.0, true)
	for m in flash_mats:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.9, 0.3)
		m.emission_energy_multiplier = 1.2

## FREEZE: лёд обездвиживает цель (боссы — вдвое короче).
func freeze(dur: float) -> void:
	if dead:
		return
	frozen_t = maxf(frozen_t, dur * (0.5 if kind in BOSS_FAMILY else 1.0))

## Термошок: огонь по замороженному — взрыв, чистый урон, снятие обоих статусов.
func _thermal_shock(base: float) -> void:
	var shock := maxf(base * 2.0, 30.0)
	frozen_t = 0.0
	_frozen_vis = false
	burn_t = 0.0
	burn_dps = 0.0
	for m in flash_mats:
		m.emission_enabled = false
	hp -= shock
	G.dmg_number(global_position + Vector3(0, num_y + 0.4, 0), "ТЕРМОШОК %d" % int(shock), Color(1.0, 0.5, 1.0))
	FX.burst(G.world, global_position + Vector3(0, 1.0, 0), Color(1.0, 0.55, 1.0), 30, 7.0, 0.7, 0.2, 2.0, true)
	FX.burst(G.world, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.8, 1.0), 20, 5.0, 0.6, 0.16, 2.0, true)
	G.sfx("magicboom", -2.0, 1.3)
	G.shake(0.7)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != self and not e.dead:
			if e.global_position.distance_to(global_position) < 4.0:
				e.take_hit(shock * 0.6, (e.global_position - global_position).normalized(), null)

# --- Охотник Теней ---

func _telegraph_dash() -> void:
	G.sfx("swing", -8.0, 0.5)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.06, 18.0)
	beam.mesh = Assets.flat(bm)
	var m := Assets.unshaded(Color(1.0, 0.18, 0.12, 0.0), false, true, true)
	beam.material_override = m
	beam.position = global_position + dash_dir * 10.0 + Vector3(0, 0.12, 0)
	beam.rotation.y = atan2(dash_dir.x, dash_dir.z)
	G.world.add_child(beam)
	var tw := beam.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.6, 0.55)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(beam.queue_free)

func _start_veil() -> void:
	veiled_t = 4.0
	vis.visible = false
	hp_bar.visible = false
	G.sfx("roll", -4.0, 0.6)
	FX.burst(G.world, global_position + Vector3(0, 1.2, 0), Color(0.35, 0.25, 0.5), 22, 5.0, 0.7, 0.2, 1.0, true)
	clones.clear()
	for i in 2:
		var a := TAU * float(i) / 2.0 + G.rng.randf_range(0.0, 1.0)
		var gp := global_position + Vector3(cos(a) * 3.0, 0.4, sin(a) * 3.0)
		clones.append(Enemy.spawn(G.world, "stalker_clone", gp))
	G.hud.notify("Охотник растворился в дыму! Бей его копии!", Color(0.8, 0.6, 1.0))

func _end_veil() -> void:
	veiled_t = 0.0
	if dead:
		return
	vis.visible = true
	for c in clones:
		if is_instance_valid(c) and not c.dead:
			c.dissolve()
	clones.clear()
	FX.burst(G.world, global_position + Vector3(0, 1.2, 0), Color(0.5, 0.35, 0.7), 18, 4.0, 0.6, 0.18, 1.0, true)
	G.sfx("roar", -8.0, 1.5)

## Ярость (фаза 2): телепорт за спину героя — успей свернуть перекатом.
func _blink_behind() -> void:
	if not player_valid() or G.player.dead:
		return
	var dst: Vector3 = G.player.global_position + G.player.vis.global_transform.basis.z * 1.9
	dst.y = global_position.y
	FX.burst(G.world, global_position + Vector3(0, 1.2, 0), Color(0.55, 0.3, 0.85), 14, 4.0, 0.5, 0.16, 1.0, true)
	global_position = dst
	rotation.y = atan2(G.player.global_position.x - dst.x, G.player.global_position.z - dst.z)
	FX.burst(G.world, global_position + Vector3(0, 1.2, 0), Color(0.55, 0.3, 0.85), 14, 4.0, 0.5, 0.16, 1.0, true)
	G.sfx("roll", -6.0, 0.5)
	windup = 0.55
	if blink_count < 2:
		blink_count += 1
		G.hud.notify("Охотник за спиной — перекат!", Color(0.9, 0.5, 1.0))

var blink_count := 0

## Копии из дымовой завесы: 1 HP, рассыпаются от любого удара или с концом завесы.
func dissolve() -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	col_shape.set_deferred("disabled", true)
	hp_bar.visible = false
	FX.burst(G.world, global_position + Vector3(0, 1.0, 0), Color(0.5, 0.35, 0.7), 10, 3.0, 0.5, 0.14, 1.0, true)
	var tw := create_tween()
	tw.tween_property(vis, "scale", Vector3(0.05, 0.05, 0.05), 0.35)
	get_tree().create_timer(0.5).timeout.connect(queue_free)

# ---------------- УРОН И СМЕРТЬ ----------------

func ignite(t: float, dps: float) -> void:
	burn_t = maxf(burn_t, t)
	burn_dps = maxf(burn_dps, dps)

func apply_slow(t: float) -> void:
	slow_t = maxf(slow_t, t)

func _hit_player(amount: float, is_splash := false) -> void:
	# идеальный перекат (Q в момент удара): урон предотвращён неуязвимостью, враг копит стан
	if player_valid() and not G.player.dead and G.player.rolling:
		if G.player.roll_t <= 0.25:
			_apply_stagger(25.0)
			G.hud.notify("Идеальный перекат!", Color(1.0, 0.9, 0.4))
			G.hitstop(0.06)
			G.sfx("roll", -6.0, 1.4)
			return
		_apply_stagger(5.0)
	var dmg_out := amount * (1.1 if elite == "fire" else 1.0)
	G.damage_player(dmg_out, global_position)
	if elite == "vampire" and player_valid() and not G.player.dead:
		hp = minf(hp + amount * 0.25, max_hp)
		_update_hp_bar()
	if elite == "frost" and player_valid():
		G.player.apply_slow(2.0)

func _enter_phase2() -> void:
	phase = 2
	speed *= 1.3
	dmg *= 1.2
	atk_cd_max *= 0.7
	for m in flash_mats:
		m.emission_enabled = true
		if kind == "shadow_stalker":
			m.emission = Color(0.6, 0.3, 1.0)
		else:
			m.emission = Color(0.5, 0.85, 1.0) if kind == "frost_golem" else Assets.C_EMBER
		m.emission_energy_multiplier = 1.3
	G.sfx("roar", -2.0)
	G.shake(0.8)
	G.hud.notify(str(BOSS_NAMES.get(kind, kind)) + " в ярости!")

func take_hit(dmg: float, dir: Vector3, _from, element: String = "", stagger_gain: float = 0.0) -> void:
	if dead:
		return
	var dmg_out := dmg
	if stunned_t > 0.0:
		dmg_out *= 1.5  # оглушённый враг получает +50% урона
	if frozen_t > 0.0 and element == "fire":
		_thermal_shock(dmg_out)
	_apply_stagger(stagger_gain)
	hp -= dmg_out
	if phase == 1 and kind in BOSS_FAMILY and hp <= max_hp * 0.5:
		_enter_phase2()
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
	hp_bar.visible = ratio < 0.999 and not dead and veiled_t <= 0.0
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
	if kind in BOSS_FAMILY:
		var rr: int = 2 if G.rng.randf() < 0.6 else 3
		Pickup.spawn(G.world, "stone", global_position + Vector3(0, 1.0, 0), float(rr))
		Pickup.spawn(G.world, "rune", global_position + Vector3(0, 1.0, 0), float(G.rng.randi() % 3))
	elif G.rng.randf() < 0.18:
		var roll := G.rng.randf()
		var rar: int = 0 if roll < 0.55 else (1 if roll < 0.85 else 2)
		Pickup.spawn(G.world, "stone", global_position + Vector3(0, 1.0, 0), float(rar))
	if elite != "":
		Pickup.spawn(G.world, "rune", global_position + Vector3(0, 1.0, 0), float(G.rng.randi() % 3))
		G.shake(1.2)
		FX.burst(G.world, global_position + Vector3(0, 2, 0), Assets.C_EMBER, 40, 8.0, 1.0, 0.25, 8.0, true)
	if kind == "guardian":
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 1.0, 0))
		Pickup.spawn(G.world, "potion", global_position + Vector3(0, 1.0, 0))
		G.shake(1.2)
		FX.burst(G.world, global_position + Vector3(0, 2, 0), Color("#8f6fff"), 40, 8.0, 1.0, 0.25, 8.0, true)
	if kind == "shadow_stalker":
		for c in clones:
			if is_instance_valid(c) and not c.dead:
				c.dissolve()
		clones.clear()
		if not has_meta("no_core"):
			Pickup.spawn(G.world, "shadow_core", global_position + Vector3(0, 1.4, 0))
		Pickup.spawn(G.world, "stone", global_position + Vector3(0, 1.0, 0), 3.0)
		G.shake(1.4)
		FX.burst(G.world, global_position + Vector3(0, 2, 0), Color(0.6, 0.3, 1.0), 50, 9.0, 1.1, 0.26, 4.0, true)
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
