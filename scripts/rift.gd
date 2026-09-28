class_name RiftZone
extends Node3D
## Инстанс-зона «Разлом»: парящая обсидиановая платформа в пустоте за Порталом.
## Арена Охотника Теней; враги-миньоны, сундук после победы, портал возврата.

const CENTER := Vector3(1200, -160, 800)
const PLATFORM_R := 21.0

var start_global := Vector3.ZERO
var cleared := false
var boss: Node = null
var shards: Array = []
var t := 0.0

static func spawn(parent: Node) -> RiftZone:
	var r := RiftZone.new()
	r.position = CENTER
	parent.add_child(r)
	return r

func _ready() -> void:
	cleared = G.rift_cleared
	_build_platform()
	start_global = global_position + Vector3(0, 1.4, PLATFORM_R - 4.0)
	ReturnPortal.spawn(self, Vector3(0, 0.3, PLATFORM_R - 4.0))
	spawn_boss()
	FX.mist(self, global_position + Vector3(0, 1.0, 0), PLATFORM_R * 1.2)

func _build_platform() -> void:
	var rock := Assets.mat(Color("#2a2138"))
	add_child(Assets.mesh_node(Assets.flat(_cyl_mesh(PLATFORM_R, PLATFORM_R + 2.2, 2.6, 26), rock), Vector3(0, -1.3, 0)))
	Assets.add_static_cyl(self, PLATFORM_R + 1.0, 2.6, Vector3(0, -1.3, 0))
	# купол пустоты: изнутри не видно ни неба, ни океана — только бездна
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 70.0
	dm.height = 140.0
	dm.radial_segments = 24
	dm.rings = 12
	dome.mesh = dm
	var dome_m := StandardMaterial3D.new()
	dome_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dome_m.albedo_color = Color(0.045, 0.035, 0.08)
	dome_m.cull_mode = BaseMaterial3D.CULL_FRONT
	dome.material_override = dome_m
	dome.position = Vector3(0, 6.0, 0)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dome)
	# светящиеся круги рун
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var p := Vector3(cos(a) * 8.0, 0.06, sin(a) * 8.0)
		var rune := Assets.box(Vector3(1.1, 0.04, 1.1), Color(0.6, 0.35, 1.0), p, a)
		rune.material_override = Assets.glow_mat(Color(0.6, 0.35, 1.0), 0.8)
		add_child(rune)
	# обелиски по краю арены
	for i in 6:
		var a2 := TAU * i / 6.0
		var pp := Vector3(cos(a2) * (PLATFORM_R - 2.0), 0, sin(a2) * (PLATFORM_R - 2.0))
		add_child(Assets.box(Vector3(0.9, 4.6, 0.9), Color("#241c30"), pp + Vector3(0, 2.3, 0), a2))
		var g := Assets.sph(0.2, Color(0.6, 0.35, 1.0), pp + Vector3(0, 4.8, 0), 6, 3)
		g.material_override = Assets.glow_mat(Color(0.6, 0.35, 1.0), 1.8)
		add_child(g)
	# невидимые барьеры по кругу (12 сегментов)
	for i in 12:
		var a3 := TAU * i / 12.0
		var seg := 2.0 * (PLATFORM_R + 1.0) * sin(PI / 12.0) + 1.0
		var bp := Vector3(cos(a3) * (PLATFORM_R + 0.9), 3.0, sin(a3) * (PLATFORM_R + 0.9))
		Assets.add_static_box(self, Vector3(seg, 6.0, 1.2), bp, a3 + PI * 0.5)
		# низкий парапет
		add_child(Assets.box(Vector3(seg, 0.9, 0.9), Color("#150f1e"), bp + Vector3(0, -2.55, 0), a3 + PI * 0.5))
	# парящие осколки пустоты вокруг платформы
	for i in 10:
		var a4 := TAU * i / 10.0 + G.rng.randf_range(0, 0.6)
		var rr := G.rng.randf_range(28.0, 40.0)
		var sp := Vector3(cos(a4) * rr, G.rng.randf_range(-5.0, 8.0), sin(a4) * rr)
		var sh := Assets.box(Vector3(G.rng.randf_range(1.0, 2.6), G.rng.randf_range(0.4, 1.0), G.rng.randf_range(1.0, 2.4)), Color("#2a2138"), sp, G.rng.randf_range(0, TAU))
		add_child(sh)
		shards.append(sh)
	# восходящая пыль пустоты
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.position = Vector3(0, 2.0, 0)
	p.visibility_aabb = AABB(Vector3(-PLATFORM_R, -4, -PLATFORM_R), Vector3(PLATFORM_R * 2, 16, PLATFORM_R * 2))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = PLATFORM_R
	pm.gravity = Vector3(0, 0.7, 0)
	pm.direction = Vector3.UP
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.7
	pm.scale_min = 0.4
	pm.scale_max = 1.0
	pm.color = Color(0.62, 0.4, 1.0, 0.7)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	quad.material = FX._particle_mat(Color.WHITE, true)
	p.draw_pass_1 = quad
	add_child(p)
	# призрачный свет арены
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.4, 1.0)
	light.light_energy = 1.4
	light.omni_range = 40.0
	light.position = Vector3(0, 9.0, 0)
	light.shadow_enabled = false
	add_child(light)

func spawn_boss() -> void:
	if boss != null and is_instance_valid(boss) and not boss.dead:
		return
	boss = Enemy.spawn(self, "shadow_stalker", global_position + Vector3(0, 0.8, -5.0))
	if G.rift_cleared:
		boss.set_meta("no_core", true)
	FX.burst(self, boss.global_position + Vector3(0, 1.6, 0) - global_position, Color(0.6, 0.3, 1.0), 24, 6.0, 0.8, 0.2, 2.0, true)

func on_boss_down() -> void:
	if cleared:
		return
	cleared = true
	Chest.spawn(self, Vector3(2.0, 0.4, -4.0), 250, 2)
	FX.burst(self, Vector3(0, 2.0, -5.0), Color(0.7, 0.4, 1.0), 40, 8.0, 1.0, 0.24, 3.0, true)
	G.hud.notify("Разлом очищен! Забирай добычу и вернись через портал", Color(0.8, 0.6, 1.0))

func _process(delta: float) -> void:
	t += delta
	for i in shards.size():
		var s: Node3D = shards[i]
		s.rotate_y(delta * 0.3)
		s.position.y += sin(t * 0.8 + float(i) * 1.3) * delta * 0.4
	# выпали из мира (смерть/падение) — возвращаем героя к Порталу
	if G.current_dungeon == self and G.player and is_instance_valid(G.player):
		if G.player.dead or global_position.distance_to(G.player.global_position) > 90.0:
			G.main.exit_dungeon()

func _cyl_mesh(rt: float, rb: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c
