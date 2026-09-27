class_name Dungeon
extends Node3D
## Процедурное подземелье: цепь комнат, коридоры, ловушки, факелы, босс.

var dungeon_id := 0
var cleared := false
var boss: Node = null
var start_global := Vector3.ZERO
var rock_spots: Array = []
var rock_cd: Array = []
var _tex := {}

static func spawn(parent: Node, id: int, pos: Vector3, cleared: bool) -> Dungeon:
	var d := Dungeon.new()
	d.dungeon_id = id
	d.cleared = cleared
	d.position = pos
	parent.add_child(d)
	return d

func _ready() -> void:
	if G.world and is_instance_valid(G.world):
		_tex = G.world._tex
	var rng := RandomNumberGenerator.new()
	rng.seed = 9137 + dungeon_id * 4177
	var dirs := [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 0, 1)]
	var cur := Vector3.ZERO
	var sizes: Array = [10.0, rng.randf_range(8.0, 11.0), rng.randf_range(8.0, 11.0), 12.0, rng.randf_range(8.0, 11.0), 18.0]
	var centers: Array = []
	for i in sizes.size():
		var size: float = sizes[i]
		if i > 0:
			var d3: Vector3 = dirs[i % 4]
			var gap := rng.randf_range(3.0, 5.0)
			cur = cur + d3 * (sizes[i - 1] * 0.5 + gap + size * 0.5)
			var c_len := gap + 2.0
			var c_center := cur - d3 * (size * 0.5 + c_len * 0.5)
			_corridor(c_center, d3, c_len + 1.5)
			if i >= 2:
				var trap_pos := c_center + Vector3(0, 0.3, 0)
				if i % 2 == 0:
					var trap := SpikeTrap.new()
					trap.position = trap_pos
					add_child(trap)
				else:
					rock_spots.append(trap_pos + Vector3(0, 0.1, 0))
					rock_cd.append(0.0)
		_room(cur, size, rng)
		centers.append(cur)
	start_global = global_position + Vector3(0, 1.1, 0)
	# потолок-мешок, чтобы внутрь не попадал солнечный свет
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	for cc in centers:
		min_v = min_v.min(cc - Vector3(13, 0, 13))
		max_v = max_v.max(cc + Vector3(13, 0, 13))
	var span := max_v - min_v
	add_child(Assets.box(Vector3(span.x + 16, 0.8, span.z + 16), Color("#120e18"), Vector3((min_v.x + max_v.x) * 0.5, 8.2, (min_v.z + max_v.z) * 0.5)))
	var slab_count := int(span.x * span.z / 30.0)
	for i in slab_count:
		var px := rng.randf_range(min_v.x, max_v.x)
		var pz := rng.randf_range(min_v.z, max_v.z)
		var h := rng.randf_range(0.9, 2.4)
		add_child(Assets.cyl(0.05, rng.randf_range(0.22, 0.45), h, 6, Color("#241d2c"), Vector3(px, 7.8 - h * 0.5, pz)))
	# факелы в комнатах
	for cc in centers:
		for off in [Vector3(3.0, 0, 3.0), Vector3(-3.0, 0, -3.0)]:
			var tp: Vector3 = cc + off
			add_child(Assets.cyl(0.05, 0.07, 1.1, 5, Color("#3a3028"), tp + Vector3(0, 1.2, 0)))
			FX.fire(self, tp + Vector3(0, 1.75, 0), 0.35)
	# сундук со средней комнаты
	Chest.spawn(self, centers[2] + Vector3(0, 0.35, 0), 60, 2)
	# босс и свита в последней комнате
	var last: Vector3 = centers[centers.size() - 1]
	if not cleared:
		boss = Enemy.spawn(self, "shadow_lord", last + Vector3(0, 0.5, 0))
		boss.set_meta("dungeon_id", dungeon_id)
		for i in 2:
			var a := TAU * i / 2.0
			Enemy.spawn(self, "shade", last + Vector3(cos(a) * 5.5, 0.5, sin(a) * 5.5))
	for i in centers.size() - 2:
		Enemy.spawn(self, "shade", centers[i + 1] + Vector3(rng.randf_range(-2, 2), 0.5, rng.randf_range(-2, 2)))
	# портал-возврат в стартовой комнате
	ReturnPortal.spawn(self, Vector3(1.5, 0.5, 1.5))
	set_process(true)

func _process(delta: float) -> void:
	# падающие камни над коридорами
	if G.player == null or not is_instance_valid(G.player):
		return
	if respawn_t > 0.0:
		respawn_t -= delta
		if respawn_t <= 0.0:
			respawn_t = -1.0
			boss = Enemy.spawn(self, "shadow_lord", Vector3(0, 0.5, 0))
			boss.set_meta("dungeon_id", dungeon_id)
			for i in 2:
				var a2 := TAU * i / 2.0
				Enemy.spawn(self, "shade", Vector3(0, 0.5, 0) + Vector3(cos(a2) * 5.0, 0, sin(a2) * 5.0))
			G.hud.notify("Повелитель Мрака возродился в подземелье...", Color(0.8, 0.5, 1.0))
	for i in rock_spots.size():
		rock_cd[i] = maxf(rock_cd[i] - delta, 0.0)
		if rock_cd[i] <= 0.0 and G.player.global_position.distance_to(global_position + rock_spots[i]) < 7.0:
			rock_cd[i] = 5.0
			_drop_rock(rock_spots[i])

func _drop_rock(spot: Vector3) -> void:
	var rock := Node3D.new()
	rock.position = spot + Vector3(0, 7.0, 0)
	add_child(rock)
	var mesh := Assets.sph(rng_hint(), Assets.C_ROCK.darkened(0.2), Vector3.ZERO, 6, 3)
	rock.add_child(mesh)
	var body := StaticBody3D.new()
	body.collision_layer = 0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape = sh
	body.add_child(cs)
	rock.add_child(body)
	var vel := Vector3(0, -14.0, 0)
	var t := 0.0
	var floor_y := spot.y
	while t < 2.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not is_instance_valid(rock):
			return
		vel.y -= 20.0 * get_physics_process_delta_time()
		rock.global_position += vel * get_physics_process_delta_time()
		rock.rotate_x(0.15)
		if G.player and is_instance_valid(G.player) and G.player.global_position.distance_to(rock.global_position) < 1.4 and not G.player.dead:
			G.damage_player(16.0, rock.global_position)
			break
		if rock.global_position.y <= floor_y:
			break
	if is_instance_valid(rock):
		FX.burst(self, rock.global_position, Assets.C_ROCK_DARK, 10, 4.0, 0.4, 0.15)
		G.sfx("slam", -14.0, 1.6)
		rock.queue_free()

var respawn_t := -1.0

func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func on_boss_defeated() -> void:
	respawn_t = 90.0
	cleared = false
	Chest.spawn(self, Vector3(1.5, 0.4, 0), 150, 2)
	var big := Chest.spawn(self, Vector3(-1.5, 0.4, 0), 80, 1)
	big.rune_count = 2
	FX.burst(self, Vector3(0, 1.5, 0), Assets.C_MAGIC, 30, 6.0, 0.9, 0.2, 4.0, true)
	ReturnPortal.spawn(self, Vector3(0, 0.5, 4.0))

func rng_hint() -> float:
	return G.rng.randf_range(0.3, 0.45)

func _room(center: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var half := size * 0.5
	var floor_mesh := Assets.box(Vector3(size + 1.0, 0.6, size + 1.0), Color("#2a2230"), center + Vector3(0, -0.3, 0))
	add_child(floor_mesh)
	Assets.add_static_box(self, Vector3(size + 1.0, 0.6, size + 1.0), center + Vector3(0, -0.3, 0))
	# низкие бортики по периметру с проходами по осям зигзага
	var rim_h := 0.9
	var rim_c := Color("#1c1622")
	var floor_m := Assets.mat(Color("#332b3a"))
	if _tex.has("gravel"):
		floor_m = Assets.tex_mat(Color("#9a92a6"), _tex["gravel"], 1.0, 0.45)
	var fm := Assets.mesh_node(Assets.flat(_box_mesh(Vector3(size + 1.0, 0.6, size + 1.0)), floor_m), center + Vector3(0, -0.3, 0))
	add_child(fm)
	Assets.add_static_box(self, Vector3(size + 1.0, 0.6, size + 1.0), center + Vector3(0, -0.3, 0))
	for side in 4:
		var axis := Vector3(1, 0, 0) if side % 2 == 0 else Vector3(0, 0, 1)
		var seg_len := size - 2.4
		var seg_off := (half + 1.2) * 0.5
		var a := center - axis * seg_off + Vector3(0, rim_h * 0.5, 0)
		var b := center + axis * seg_off + Vector3(0, rim_h * 0.5, 0)
		var sz := Vector3(seg_len, rim_h, 0.5) if side % 2 == 0 else Vector3(0.5, rim_h, seg_len)
		for seg in [a, b]:
			add_child(Assets.box(sz, rim_c, seg))
			Assets.add_static_box(self, sz, seg)
		var bsz := Vector3(seg_len, 5.0, 0.4) if side % 2 == 0 else Vector3(0.4, 5.0, seg_len)
		var bmid := center + axis * seg_off + Vector3(0, 2.6, 0)
		Assets.add_barrier_box(self, bsz, bmid)
	# светящиеся руны-полосы на полу
	for i in 3:
		var rp := center + Vector3(rng.randf_range(-half * 0.5, half * 0.5), 0.02, rng.randf_range(-half * 0.5, half * 0.5))
		var rune := Assets.box(Vector3(0.7, 0.04, 0.7), Assets.C_MAGIC, rp)
		rune.material_override = Assets.glow_mat(Assets.C_MAGIC, 0.9)
		add_child(rune)

func _corridor(center: Vector3, dir: Vector3, length: float) -> void:
	var along := Vector3(length, 0.6, 3.0) if absf(dir.x) > 0.5 else Vector3(3.0, 0.6, length)
	var floor_m := Assets.mat(Color("#2a2432"))
	if _tex.has("gravel"):
		floor_m = Assets.tex_mat(Color("#8a8296"), _tex["gravel"], 1.0, 0.45)
	var cm := Assets.mesh_node(Assets.flat(_box_mesh(along), floor_m), center + Vector3(0, -0.3, 0))
	add_child(cm)
	Assets.add_static_box(self, along, center + Vector3(0, -0.3, 0))
	var rim_c := Color("#1c1622")
	var rim_h := 0.8
	var side_off := Vector3(0, 0, 1.6) if absf(dir.x) > 0.5 else Vector3(1.6, 0, 0)
	for s2 in [-1.0, 1.0]:
		var sz := Vector3(length, rim_h, 0.4) if absf(dir.x) > 0.5 else Vector3(0.4, rim_h, length)
		add_child(Assets.box(sz, rim_c, center + side_off * s2 + Vector3(0, rim_h * 0.5, 0)))
		Assets.add_static_box(self, sz, center + side_off * s2 + Vector3(0, rim_h * 0.5, 0))
		Assets.add_barrier_box(self, Vector3(length, 5.0, 0.4) if absf(dir.x) > 0.5 else Vector3(0.4, 5.0, length), center + side_off * s2 + Vector3(0, 2.6, 0))
