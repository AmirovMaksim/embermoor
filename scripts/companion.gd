class_name Companion
extends CharacterBody3D
## Компаньоны: приручаемый волк (качается, умеет выть и кусать) и ездовая лошадь.

var ctype := "wolf"  # wolf | horse
var tamed := true
var level := 1
var xp := 0.0
var riding := false
var t := 0.0
var bite_cd := 0.0
var howl_cd := 0.0
var wander_dir := Vector3.ZERO
var wander_t := 0.0
var vis: Node3D
var legs: Array = []
var head_parts: Array = []

const GRAV := 22.0

static func spawn(parent: Node, ctype: String, pos: Vector3, tamed := true, lvl := 1) -> Companion:
	var c := Companion.new()
	c.ctype = ctype
	c.tamed = tamed
	c.level = lvl
	c.position = pos
	parent.add_child(c)
	return c

func _ready() -> void:
	add_to_group("companions")
	collision_layer = 4
	collision_mask = 1
	vis = Node3D.new()
	add_child(vis)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if ctype == "wolf":
		cap.radius = 0.32
		cap.height = 0.8
		cs.position = Vector3(0, 0.5, 0)
		_build_wolf()
	else:
		cap.radius = 0.45
		cap.height = 1.7
		cs.position = Vector3(0, 0.95, 0)
		_build_horse()
	cs.shape = cap
	add_child(cs)

func _leg(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	pivot.add_child(Assets.box(size, color, Vector3(0, -size.y * 0.5, 0)))
	legs.append(pivot)
	return pivot

func _build_wolf() -> void:
	var fur := Color("#9aa0ac") if tamed else Color("#787882")
	var fur_d := fur.darkened(0.2)
	vis.add_child(Assets.box(Vector3(0.34, 0.32, 0.78), fur, Vector3(0, 0.52, 0)))
	vis.add_child(Assets.box(Vector3(0.24, 0.22, 0.26), fur, Vector3(0, 0.66, -0.46)))
	vis.add_child(Assets.box(Vector3(0.2, 0.2, 0.2), fur_d, Vector3(0, 0.4, -0.44)))
	vis.add_child(Assets.box(Vector3(0.07, 0.12, 0.04), fur_d, Vector3(-0.08, 0.84, -0.46)))
	vis.add_child(Assets.box(Vector3(0.07, 0.12, 0.04), fur_d, Vector3(0.08, 0.84, -0.46)))
	vis.add_child(Assets.box(Vector3(0.09, 0.09, 0.03), Assets.C_MAGIC if tamed else Color("#3a2a2a"), Vector3(-0.08, 0.68, -0.6)))
	vis.add_child(Assets.box(Vector3(0.09, 0.09, 0.03), Assets.C_MAGIC if tamed else Color("#3a2a2a"), Vector3(0.08, 0.68, -0.6)))
	var tail := Assets.box(Vector3(0.08, 0.08, 0.34), fur_d, Vector3(0, 0.62, 0.5))
	tail.rotation_degrees.x = 25
	vis.add_child(tail)
	_leg(vis, Vector3(-0.13, 0.36, -0.26), Vector3(0.09, 0.4, 0.09), fur_d)
	_leg(vis, Vector3(0.13, 0.36, -0.26), Vector3(0.09, 0.4, 0.09), fur_d)
	_leg(vis, Vector3(-0.13, 0.36, 0.26), Vector3(0.09, 0.4, 0.09), fur)
	_leg(vis, Vector3(0.13, 0.36, 0.26), Vector3(0.09, 0.4, 0.09), fur)

func _build_horse() -> void:
	var coat := Color("#8a5f3a")
	var coat_d := coat.darkened(0.25)
	vis.add_child(Assets.box(Vector3(0.52, 0.52, 1.5), coat, Vector3(0, 1.05, 0)))
	var neck := Assets.box(Vector3(0.3, 0.5, 0.3), coat, Vector3(0, 1.5, -0.7))
	vis.add_child(neck)
	var head := Assets.box(Vector3(0.26, 0.26, 0.5), coat, Vector3(0, 1.78, -0.92))
	vis.add_child(head)
	var ear1 := Assets.box(Vector3(0.08, 0.16, 0.05), coat_d, Vector3(-0.09, 1.94, -0.88))
	vis.add_child(ear1)
	var ear2 := Assets.box(Vector3(0.08, 0.16, 0.05), coat_d, Vector3(0.09, 1.94, -0.88))
	vis.add_child(ear2)
	var mane := Assets.box(Vector3(0.1, 0.3, 0.3), Color("#3a2c1e"), Vector3(0, 1.42, -0.66))
	vis.add_child(mane)
	head_parts = [neck, head, ear1, ear2, mane]
	var tail := Assets.box(Vector3(0.1, 0.5, 0.12), coat_d, Vector3(0, 1.15, 0.82))
	tail.rotation_degrees.x = -20
	vis.add_child(tail)
	_leg(vis, Vector3(-0.2, 0.85, -0.55), Vector3(0.14, 0.9, 0.14), coat)
	_leg(vis, Vector3(0.2, 0.85, -0.55), Vector3(0.14, 0.9, 0.14), coat)
	_leg(vis, Vector3(-0.2, 0.85, 0.55), Vector3(0.14, 0.9, 0.14), coat_d)
	_leg(vis, Vector3(0.2, 0.85, 0.55), Vector3(0.14, 0.9, 0.14), coat_d)
	if tamed:
		vis.add_child(Assets.box(Vector3(0.36, 0.1, 0.5), Color("#5a3a22"), Vector3(0, 1.36, 0.1)))
		vis.add_child(Assets.box(Vector3(0.4, 0.05, 0.1), Assets.C_TRUNK, Vector3(0, 1.44, -0.3)))

func set_head_visible(v: bool) -> void:
	for m in head_parts:
		if is_instance_valid(m):
			m.visible = v

func xp_next() -> float:
	return 40.0 + 30.0 * level

func add_kill_xp(v: float) -> void:
	if not tamed or ctype != "wolf":
		return
	xp += v
	if xp >= xp_next():
		xp -= xp_next()
		level += 1
		G.hud.notify("Волк подрос: уровень %d!" % level, Color(0.7, 0.9, 1.0))
		FX.sparkle(G.world, global_position + Vector3(0, 1.0, 0), Color(0.7, 0.9, 1.0))
		G.sfx("levelup", -8.0, 1.4)

func _physics_process(delta: float) -> void:
	t += delta
	bite_cd = maxf(bite_cd - delta, 0.0)
	howl_cd = maxf(howl_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y -= GRAV * delta
	var pl := G.player
	if pl == null or not is_instance_valid(pl):
		return
	var to_p: Vector3 = pl.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()

	if riding:
		# жёсткая привязка к игроку: никакой собственной физики
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		rotation.y = pl.vis.rotation.y
		global_position = pl.global_position
		var hs := Vector2(pl.velocity.x, pl.velocity.z).length()
		var c := sin(pl.t * 12.0) * minf(hs * 0.09, 0.5)
		for i in legs.size():
			legs[i].rotation.x = c * (1.0 if i % 2 == 0 else -1.0)
		return
	collision_layer = 4
	collision_mask = 1

	var spd := 0.0
	var dir := Vector3.ZERO
	# волк: бой рядом с хозяином
	if ctype == "wolf" and tamed and not pl.dead and G.game_started:
		var prey: Node = null
		var best := 12.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var d: float = e.global_position.distance_to(pl.global_position)
			if d < best:
				best = d
				prey = e
		if prey and bite_cd <= 0.0:
			var to_e: Vector3 = prey.global_position - global_position
			to_e.y = 0
			if to_e.length() < 1.6:
				bite_cd = 1.3
				prey.take_hit(6.0 + level * 3.0, to_e.normalized(), null)
				if level >= 5:
					prey.apply_slow(1.2)
				G.sfx("hit", -10.0, 1.3)
			else:
				dir = to_e.normalized()
				spd = 7.0
		if level >= 3 and howl_cd <= 0.0 and prey != null:
			howl_cd = 24.0
			G.howl_t = 10.0
			G.sfx("roar", -6.0, 1.8)
			G.hud.notify("Волк воет: +15% к урону на 10 секунд!", Color(0.7, 0.9, 1.0))
			FX.burst(G.world, global_position + Vector3(0, 0.8, 0), Color(0.7, 0.9, 1.0), 14, 4.0, 0.6, 0.12, -2.0, true)
	# следование
	if spd == 0.0 and dist > 6.0 and tamed:
		dir = to_p.normalized()
		spd = (9.0 if ctype == "horse" else 6.5) * minf(1.0 + (dist - 6.0) * 0.06, 2.0)
	elif spd == 0.0 and not tamed:
		wander_t -= delta
		if wander_t <= 0.0:
			wander_t = G.rng.randf_range(2.0, 4.0)
			wander_dir = Vector3(G.rng.randf_range(-1, 1), 0, G.rng.randf_range(-1, 1)).normalized()
		dir = wander_dir
		spd = 1.2
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(8.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(8.0 * delta, 1.0))
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(8.0 * delta, 1.0))
	# лапки
	var hs := Vector2(velocity.x, velocity.z).length()
	var c := sin(t * 10.0) * minf(hs * 0.08, 0.45) if hs > 0.3 else 0.0
	for i in legs.size():
		legs[i].rotation.x = lerpf(legs[i].rotation.x, c * (1.0 if i % 2 == 0 else -1.0), minf(12.0 * delta, 1.0))

func prompt_text() -> String:
	if ctype == "horse":
		return "Оседлать лошадь" if not riding else "Слезть с лошади"
	if not tamed:
		return "Приручить волка (нужна оленина)"
	return "Верный волк"

func interact() -> void:
	if ctype == "horse":
		G.main.toggle_mount(self)
		return
	if not tamed:
		if G.meat > 0:
			G.meat -= 1
			tamed = true
			G.wolf_tamed = true
			G.sfx("levelup", -4.0, 1.2)
			G.hud.notify("Волк приручен! Он будет сражаться за тебя", Color(0.7, 0.9, 1.0))
			FX.sparkle(G.world, global_position + Vector3(0, 1.0, 0), Color(0.7, 0.9, 1.0))
			if G.quest_state == 15:
				G.set_quest(16)
		else:
			G.hud.notify("Волк голоден: добудь оленину (охоться на оленей)", Color(1.0, 0.6, 0.4))
