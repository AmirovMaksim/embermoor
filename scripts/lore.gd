class_name LoreStone
extends Node3D
## Лорный камень с рунами и Древний портал.

var is_portal := false
var shrine := false
var taken := false
var title := "Древний камень"
var text := ""
var activated := false
var _gem: MeshInstance3D
var _t := 0.0

static func spawn(parent: Node, pos: Vector3, ptitle: String, ptext: String, portal := false) -> LoreStone:
	var l := LoreStone.new()
	l.position = pos
	l.title = ptitle
	l.text = ptext
	l.is_portal = portal
	parent.add_child(l)
	return l

static func spawn_shrine(parent: Node, pos: Vector3) -> LoreStone:
	var l := LoreStone.new()
	l.position = pos
	l.shrine = true
	parent.add_child(l)
	return l

func _ready() -> void:
	add_to_group("portals" if is_portal else "lore")
	if is_portal:
		_build_portal()
	elif shrine:
		_build_shrine()
	else:
		_build_stone()

func _build_shrine() -> void:
	add_child(Assets.cyl(0.5, 0.65, 1.0, 8, Assets.C_STONE, Vector3(0, 0.5, 0)))
	_gem = Assets.sph(0.3, Assets.C_MAGIC, Vector3(0, 1.5, 0), 8, 5)
	_gem.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.8)
	add_child(_gem)
	var light := OmniLight3D.new()
	light.light_color = Assets.C_MAGIC
	light.light_energy = 0.8
	light.omni_range = 5.0
	light.position = Vector3(0, 1.8, 0)
	light.shadow_enabled = false
	add_child(light)

func _process(delta: float) -> void:
	if shrine and _gem and not taken:
		_t += delta
		_gem.position.y = 1.5 + sin(_t * 1.8) * 0.15
		_gem.rotation.y += delta * 1.2

func _build_stone() -> void:
	var rock_m := Assets.mat(Color("#5a5a64"))
	if G.world.use_tex:
		rock_m = Assets.tex_mat(Color("#9a9aa4"), G.world._tex["rock"], 1.0, 0.5)
	add_child(Assets.mesh_node(Assets.flat(_box_m(Vector3(1.0, 1.7, 0.45)), rock_m), Vector3(0, 0.85, 0)))
	var rune := Assets.box(Vector3(0.5, 0.9, 0.06), Assets.C_MAGIC, Vector3(0, 0.95, -0.24))
	rune.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.4)
	add_child(rune)
	rotation.y = G.rng.randf_range(0, TAU)
	Assets.add_static_box(self, Vector3(1.0, 1.8, 0.5), Vector3(0, 0.9, 0))

func _build_portal() -> void:
	# кольцо из камней
	for i in 8:
		var a := TAU * i / 8.0
		var p := Vector3(cos(a) * 5.5, 0, sin(a) * 5.5)
		var h := G.rng.randf_range(1.4, 2.6)
		add_child(Assets.mesh_node(Assets.flat(_cyl_m(0.4, 0.5, h, 7), Assets.mat(Color("#5a5a64"))), p + Vector3(0, h * 0.5, 0)))
		Assets.add_static_cyl(self, 0.55, h, p + Vector3(0, h * 0.5, 0))
	# арка портала
	add_child(Assets.mesh_node(Assets.flat(_cyl_m(0.45, 0.55, 4.6, 8), Assets.mat(Color("#6a6a74"))), Vector3(-1.8, 2.3, 0)))
	add_child(Assets.mesh_node(Assets.flat(_cyl_m(0.45, 0.55, 4.6, 8), Assets.mat(Color("#6a6a74"))), Vector3(1.8, 2.3, 0)))
	add_child(Assets.mesh_node(Assets.flat(_box_m(Vector3(4.6, 0.6, 1.0)), Assets.mat(Color("#6a6a74"))), Vector3(0, 4.9, 0)))
	# вуаль портала (активируется по сюжету)
	var veil := Assets.sph(1.5, Assets.C_MAGIC, Vector3(0, 2.2, 0), 10, 6)
	veil.scale = Vector3(1.0, 1.4, 0.25)
	veil.material_override = Assets.glow_mat(Assets.C_MAGIC, 1.1)
	veil.name = "Veil"
	veil.visible = false
	add_child(veil)
	var swirl := GPUParticles3D.new()
	swirl.amount = 24
	swirl.lifetime = 2.0
	swirl.position = Vector3(0, 2.2, 0)
	swirl.emitting = false
	swirl.name = "Swirl"
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.2
	pm.gravity = Vector3.ZERO
	pm.orbit_velocity_min = 0.4
	pm.orbit_velocity_max = 0.9
	pm.scale_min = 0.3
	pm.scale_max = 0.8
	pm.color = Color(0.6, 0.5, 1.0)
	swirl.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.14, 0.14)
	quad.material = Assets.unshaded(Color.WHITE, true, false, true)
	swirl.draw_pass_1 = quad
	add_child(swirl)
	Assets.add_static_box(self, Vector3(1.6, 3.0, 0.8), Vector3(0, 1.5, 0))

func activate() -> void:
	if activated:
		return
	activated = true
	get_node("Veil").visible = true
	get_node("Swirl").emitting = true
	FX.sparkle(G.world, global_position + Vector3(0, 2.2, 0), Assets.C_MAGIC)
	G.sfx("levelup", 0.0, 0.8)
	G.shake(0.6)

func prompt_text() -> String:
	if is_portal:
		return "Древний портал" if not activated else "Войти в портал"
	if shrine:
		return "Алтарь Древа"
	return "Прочесть древние руны"

func interact() -> void:
	if shrine:
		if taken or G.grove_shrine_taken:
			G.hud.notify("Алтарь уже отдал свою силу")
			return
		G.grove_shrine_taken = true
		taken = true
		G.skill_points += 1
		G.sfx("levelup", -4.0)
		G.hud.notify("Древо делится силой: +1 очко навыка!")
		FX.sparkle(G.world, global_position + Vector3(0, 1.5, 0), Assets.C_MAGIC)
		G.stats_changed.emit()
		var tw := create_tween()
		tw.tween_property(_gem, "scale", Vector3.ONE * 0.01, 0.8).set_trans(Tween.TRANS_CUBIC)
		return
	if is_portal:
		if activated and G.quest_state == 13:
			G.hud.show_lore("ТАЙНА ЭМБЕРМУРА", G.PORTAL_FINALE)
			G.set_quest(14)
			G.coins += 300
			G.potions += 3
			G.skill_points += 2
			G.sfx("levelup")
			G.stats_changed.emit()
		elif not activated:
			G.hud.notify("Портал спит. Равновесие стихий нарушено...")
		else:
			G.hud.notify("Портал открыт. Тайна уже раскрыта.")
	else:
		G.hud.show_lore(title, text)
		if not has_meta("read"):
			set_meta("read", true)
			G.lore_found += 1
			G.hud.notify("Лор Эмбермура: %d/7" % G.lore_found)

func _box_m(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _cyl_m(rt: float, rb: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c
