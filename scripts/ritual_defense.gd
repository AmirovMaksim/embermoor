class_name RitualDefense
extends Node3D
## Миссия «Ритуал Стабилизации»: оборона Алтаря Моры у Древа.
## Три волны нечисти с таймером-передышкой; алтарь имеет запас прочности.

const ALTAR_MAX := 300.0
const WAVE_BREAK := 10.0
const SPAWN_R := 17.0
const WAVES := [
	["shade", "shade", "shade"],
	["shade", "shade", "skeleton", "skeleton", "imp"],
	["skeleton", "shade", "shade", "imp", "skeleton"],
]

var altar_hp := ALTAR_MAX
var wave_idx := 0
var phase := "countdown"  # countdown | fight | done | failed
var cd_t := WAVE_BREAK
var fast_mode := false    # ускоренные передышки (для тестов)
var altar_pos := Vector3.ZERO
var gem: MeshInstance3D
var bar_fill: MeshInstance3D
var t := 0.0

static func spawn(parent: Node, pos: Vector3) -> RitualDefense:
	var r := RitualDefense.new()
	r.position = pos
	parent.add_child(r)
	return r

func _ready() -> void:
	altar_pos = global_position
	_build_altar()
	G.hud.notify("Ритуал начался! Защищай алтарь Моры!", Color(0.8, 0.6, 1.0))
	G.sfx("levelup", -4.0, 0.8)

func _build_altar() -> void:
	add_child(Assets.cyl(1.6, 2.0, 0.5, 9, Assets.C_STONE, Vector3(0, 0.25, 0)))
	Assets.add_static_cyl(self, 1.7, 1.0, Vector3(0, 0.5, 0))
	gem = Assets.sph(0.34, Assets.C_MAGIC, Vector3(0, 1.45, 0), 8, 5)
	gem.material_override = Assets.glow_mat(Assets.C_MAGIC, 2.0)
	add_child(gem)
	# обелиски по углам
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := Vector3(cos(a) * 2.2, 0, sin(a) * 2.2)
		add_child(Assets.cyl(0.14, 0.24, 1.9, 6, Assets.C_ROCK_DARK, p + Vector3(0, 0.95, 0)))
		var g := Assets.sph(0.1, Assets.C_MAGIC, p + Vector3(0, 2.0, 0), 6, 3)
		g.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.6)
		add_child(g)
	var light := OmniLight3D.new()
	light.light_color = Assets.C_MAGIC
	light.light_energy = 1.1
	light.omni_range = 9.0
	light.position = Vector3(0, 2.2, 0)
	light.shadow_enabled = false
	add_child(light)
	# фиолетовое пламя ритуала
	var p := GPUParticles3D.new()
	p.amount = 16
	p.lifetime = 1.1
	p.position = Vector3(0, 0.7, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.9
	pm.initial_velocity_max = 1.9
	pm.gravity = Vector3(0, 1.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color(0.6, 0.4, 1.0)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.26)
	quad.material = FX._particle_mat(Color.WHITE, true)
	p.draw_pass_1 = quad
	add_child(p)
	# полоса прочности алтаря
	var bar := Node3D.new()
	bar.position = Vector3(0, 3.1, 0)
	add_child(bar)
	var bg := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(2.6, 0.32)
	bg.mesh = bq
	bg.material_override = Assets.unshaded(Color(0.05, 0.05, 0.08, 0.7), true, true)
	bar.add_child(bg)
	bar_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(2.4, 0.2)
	fq.center_offset = Vector3(-1.2, 0, 0)
	bar_fill.mesh = fq
	bar_fill.material_override = Assets.unshaded(Color(0.7, 0.4, 1.0), true, true)
	bar_fill.position.z = -0.01
	bar.add_child(bar_fill)

func damage_altar(v: float) -> void:
	if phase == "done" or phase == "failed":
		return
	altar_hp = maxf(altar_hp - v, 0.0)
	_update_bar()
	FX.burst(G.world, altar_pos + Vector3(0, 1.2, 0), Assets.C_MAGIC, 6, 3.0, 0.4, 0.1, 2.0, true)
	if altar_hp <= 0.0:
		_fail()

func _process(delta: float) -> void:
	t += delta
	if gem:
		gem.position.y = 1.45 + sin(t * 2.2) * 0.12
		gem.rotation.y += delta * 1.1
	if phase == "done" or phase == "failed":
		return
	if G.player and is_instance_valid(G.player) and G.player.dead:
		return
	match phase:
		"countdown":
			cd_t -= delta * (6.0 if fast_mode else 1.0)
			_quest_label("Ритуал: волна %d/3 через %d с — отойди и залечись!" % [wave_idx + 1, int(ceilf(maxf(cd_t, 0.0)))])
			if cd_t <= 0.0:
				_start_wave()
		"fight":
			var alive := 0
			for e in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(e) and not e.dead and e.has_meta("ritual_minion"):
					alive += 1
			_quest_label("Оборона алтаря: волна %d/3 — врагов осталось: %d" % [wave_idx, alive])
			if alive == 0:
				if wave_idx >= WAVES.size():
					_succeed()
				else:
					phase = "countdown"
					cd_t = WAVE_BREAK
					altar_hp = minf(altar_hp + 60.0, ALTAR_MAX)
					_update_bar()
					G.hud.notify("Волна отбита! Передышка — алтарь частично восстановлен", Color(0.7, 1.0, 0.5))

func _start_wave() -> void:
	wave_idx += 1
	phase = "fight"
	var comp: Array = WAVES[wave_idx - 1]
	G.hud.notify("ВОЛНА %d из %d!" % [wave_idx, WAVES.size()], Color(1.0, 0.5, 0.3))
	G.sfx("roar", -4.0, 1.25)
	for i in comp.size():
		var k: String = comp[i]
		var a := TAU * float(i) / float(comp.size()) + float(wave_idx) * 0.7
		var p := altar_pos + Vector3(cos(a) * SPAWN_R, 0, sin(a) * SPAWN_R)
		var elite := ""
		if wave_idx == WAVES.size() and i == 0:
			elite = "fire"
		var e := Enemy.spawn(G.world, k, Vector3(p.x, G.world.height(p.x, p.z) + 0.4, p.z), elite)
		e.set_meta("ritual_minion", true)
		e.home = e.global_position
		FX.burst(G.world, e.global_position + Vector3(0, 0.9, 0), Color(0.6, 0.3, 0.9), 12, 4.0, 0.5, 0.15, 2.0, true)

func _succeed() -> void:
	phase = "done"
	G.hud.notify("Ритуал завершён! Вуаль стабильна — иди к Порталу!", Color(0.7, 1.0, 0.5))
	G.sfx("levelup", 0.0, 0.9)
	FX.sparkle(G.world, altar_pos + Vector3(0, 1.6, 0), Assets.C_MAGIC)
	G.set_quest(20)
	G.ritual_node = null
	# алтарь остаётся как памятная декорация
	set_process(false)

func _fail() -> void:
	phase = "failed"
	G.hud.notify("Алтарь разрушен! Ритуал сорван... Поговори с Морой снова", Color(1.0, 0.4, 0.3))
	G.sfx("magicboom", 0.0, 0.7)
	G.shake(1.2)
	FX.burst(G.world, altar_pos + Vector3(0, 1.0, 0), Assets.C_MAGIC, 40, 9.0, 1.0, 0.25, 4.0, true)
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.has_meta("ritual_minion"):
			e.queue_free()
	G.ritual_node = null
	queue_free()

func _update_bar() -> void:
	var ratio := clampf(altar_hp / ALTAR_MAX, 0.0, 1.0)
	bar_fill.scale.x = maxf(ratio, 0.01)
	bar_fill.material_override.albedo_color = Color(1.0, 0.25, 0.2).lerp(Color(0.7, 0.4, 1.0), ratio)

func _quest_label(txt: String) -> void:
	if G.hud and G.quest_state == 19:
		G.hud.quest_obj.text = txt
