class_name Pickup
extends Node3D
## Дропы: сферы опыта, монеты, зелья, реликвия.

var type := "orb"
var value := 5.0
var no_gravity := false
var _vel := Vector3.ZERO
var _t := 0.0
var _magnet := false
var _home_y := 0.0
var _started := false

static func spawn(parent: Node, ptype: String, pos: Vector3, pvalue := 5.0) -> Pickup:
	var p := Pickup.new()
	p.type = ptype
	p.value = pvalue
	p.position = pos
	parent.add_child(p)
	return p

func _ready() -> void:
	add_to_group("pickups")
	_t = G.rng.randf_range(0.0, TAU)
	_home_y = global_position.y
	match type:
		"orb":
			var s := Assets.sph(0.13, Color(0.5, 0.95, 1.0), Vector3.ZERO, 6, 3)
			s.material_override = Assets.glow_mat(Color(0.4, 0.85, 1.0), 1.4)
			add_child(s)
		"coin":
			var c := Assets.cyl(0.14, 0.14, 0.05, 8, Assets.C_GOLD)
			c.rotation_degrees.x = 90
			c.material_override = Assets.glow_mat(Assets.C_GOLD, 0.6)
			add_child(c)
		"potion":
			add_child(Assets.cyl(0.09, 0.12, 0.22, 7, Color(0.9, 0.25, 0.3), Vector3(0, 0.12, 0)))
			add_child(Assets.cyl(0.045, 0.045, 0.1, 6, Color("#8a5a33"), Vector3(0, 0.28, 0)))
		"stone":
			var rar := int(value)
			var rc: Color = G.RARITY_COLORS[rar]
			var st := Assets.sph(0.15, rc, Vector3(0, 0.18, 0), 6, 4)
			st.material_override = Assets.glow_mat(rc, 1.6)
			add_child(st)
			if rar >= 2:
				var beam := Assets.box(Vector3(0.14, 7.0, 0.14), rc, Vector3(0, 3.6, 0))
				beam.material_override = Assets.unshaded(rc, false, true, true)
				add_child(beam)
		"meat":
			add_child(Assets.box(Vector3(0.14, 0.1, 0.2), Color("#c05050"), Vector3(0, 0.12, 0)))
			add_child(Assets.box(Vector3(0.05, 0.14, 0.05), Color("#e8dcc0"), Vector3(0.04, 0.22, 0)))
		"antler":
			var ant := Assets.box(Vector3(0.04, 0.3, 0.04), Color("#d8c8a8"), Vector3(0, 0.16, 0))
			ant.rotation_degrees.z = 20
			add_child(ant)
			add_child(Assets.box(Vector3(0.03, 0.12, 0.03), Color("#d8c8a8"), Vector3(0.05, 0.3, 0)))
		"rune":
			var rtc: Color = G.RUNE_COLORS[G.RUNE_TYPES[int(value)]]
			var rn := Assets.box(Vector3(0.14, 0.22, 0.05), rtc, Vector3(0, 0.16, 0))
			rn.material_override = Assets.glow_mat(rtc, 1.7)
			add_child(rn)
		"relic":
			var r := Assets.sph(0.2, Assets.C_MAGIC, Vector3(0, 0.3, 0), 6, 3)
			r.material_override = Assets.glow_mat(Assets.C_MAGIC, 2.2)
			add_child(r)
			add_child(Assets.cyl(0.05, 0.05, 0.2, 5, Assets.C_GOLD, Vector3(0, 0.05, 0)))
		"shadow_core":
			# Легендарное теневое ядро с Охотника Теней — материал для Теневой руны
			var core := Assets.sph(0.24, Color(0.45, 0.25, 0.85), Vector3(0, 0.35, 0), 8, 5)
			core.material_override = Assets.glow_mat(Color(0.6, 0.35, 1.0), 2.6)
			add_child(core)
			add_child(Assets.cyl(0.05, 0.05, 0.24, 5, Color("#3a2b52"), Vector3(0, 0.06, 0)))
			var beam := Assets.box(Vector3(0.14, 7.0, 0.14), Color(0.6, 0.35, 1.0), Vector3(0, 3.6, 0))
			beam.material_override = Assets.unshaded(Color(0.6, 0.35, 1.0, 0.5), false, true, true)
			add_child(beam)
	if G.current_dungeon != null:
		no_gravity = true
	_vel = Vector3(G.rng.randf_range(-1.5, 1.5), 3.0, G.rng.randf_range(-1.5, 1.5))

func _physics_process(delta: float) -> void:
	_t += delta
	if G.player == null or not is_instance_valid(G.player):
		return
	var to_p: Vector3 = G.player.global_position + Vector3(0, 0.9, 0) - global_position
	var d := to_p.length()
	if d < 3.8:
		_magnet = true
	if _magnet:
		var step := minf(d * 9.0 * delta + 3.0 * delta, d)
		global_position += to_p.normalized() * step
		if d < 0.65:
			_collect()
		return
	if type == "orb" or no_gravity:
		global_position.y = _home_y + sin(_t * 2.4) * 0.09
	else:
		_vel.y -= 14.0 * delta
		global_position += _vel * delta
		var gh: float = G.world.height(global_position.x, global_position.z) + 0.2
		if global_position.y < gh:
			global_position.y = gh
			_vel.y = 0.0
			_vel.x *= 0.8
			_vel.z *= 0.8

func _collect() -> void:
	match type:
		"orb":
			G.add_xp(value)
			G.sfx("pickup", -8.0, G.rng.randf_range(0.9, 1.15))
		"coin":
			G.add_coins(int(value))
		"potion":
			G.potions += 1
			G.sfx("pickup", -4.0)
			G.hud.notify("Зелье подобрано [R] — выпить")
		"stone":
			var rar2 := int(value)
			G.stone_bonus += G.RARITY_MULTS[rar2]
			G.sfx("pickup", -2.0, 1.2)
			G.hud.notify("Оружейный камень (%s): +%d к урону" % [G.RARITY_NAMES[rar2], int(G.RARITY_MULTS[rar2])], G.RARITY_COLORS[rar2])
		"meat":
			add_child(Assets.box(Vector3(0.14, 0.1, 0.2), Color("#c05050"), Vector3(0, 0.12, 0)))
			add_child(Assets.box(Vector3(0.05, 0.14, 0.05), Color("#e8dcc0"), Vector3(0.04, 0.22, 0)))
		"antler":
			var ant := Assets.box(Vector3(0.04, 0.3, 0.04), Color("#d8c8a8"), Vector3(0, 0.16, 0))
			ant.rotation_degrees.z = 20
			add_child(ant)
			add_child(Assets.box(Vector3(0.03, 0.12, 0.03), Color("#d8c8a8"), Vector3(0.05, 0.3, 0)))
		"meat":
			G.meat += 1
			G.sfx("pickup", -8.0)
			G.hud.notify("Оленина (+1) — можно приручить волка", Color(0.9, 0.7, 0.5))
		"antler":
			G.antlers += 1
			G.sfx("pickup", -8.0)
			G.hud.notify("Олений рог (%d/3 для охотника)" % G.antlers, Color(0.9, 0.8, 0.5))
		"rune":
			var rt: String = G.RUNE_TYPES[int(value)]
			G.runes.append(rt)
			G.sfx("levelup", -8.0, 1.3)
			G.hud.notify(G.RUNE_NAMES[rt] + " — вставь у кузнеца!", G.RUNE_COLORS[rt])
		"relic":
			G.relic = true
			G.sfx("levelup", -4.0)
			G.hud.notify("Древняя реликвия собрана!")
			FX.sparkle(G.world, global_position, Assets.C_MAGIC)
		"shadow_core":
			G.shadow_core = true
			G.sfx("levelup", -2.0, 0.9)
			G.hud.notify("Легендарное Теневое ядро! Кузнец выкует из него руну уклонения", Color(0.7, 0.45, 1.0))
			FX.sparkle(G.world, global_position, Color(0.6, 0.35, 1.0))
	FX.burst(G.world, global_position, Color(1, 1, 0.7), 8, 3.0, 0.4, 0.09, 0.0, true)
	queue_free()
