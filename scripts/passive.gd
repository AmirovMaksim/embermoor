class_name PassiveMob
extends CharacterBody3D
## Пассивные звери: олень и кролик. Бегают, убегают, дают мясо и рога.

var ptype := "deer"  # deer | rabbit
var kind := "deer"
var hp := 20.0
var dead := false
var flee_t := 0.0
var flee_dir := Vector3.ZERO
var wander_t := 0.0
var wander_dir := Vector3.ZERO
var t := 0.0
var vis: Node3D
var legs: Array = []

static func spawn(parent: Node, ptype: String, pos: Vector3) -> PassiveMob:
	var m := PassiveMob.new()
	m.ptype = ptype
	m.position = pos
	parent.add_child(m)
	return m

func _ready() -> void:
	add_to_group("enemies")
	kind = ptype
	collision_layer = 4
	collision_mask = 1
	vis = Node3D.new()
	add_child(vis)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	if ptype == "deer":
		hp = 20.0
		cap.radius = 0.3
		cap.height = 1.0
		cs.position = Vector3(0, 0.65, 0)
		_build_deer()
	else:
		hp = 8.0
		cap.radius = 0.2
		cap.height = 0.5
		cs.position = Vector3(0, 0.3, 0)
		_build_rabbit()
	cs.shape = cap
	add_child(cs)

func _build_deer() -> void:
	var coat := Color("#a5754a")
	vis.add_child(Assets.box(Vector3(0.34, 0.4, 0.8), coat, Vector3(0, 0.75, 0)))
	vis.add_child(Assets.box(Vector3(0.18, 0.3, 0.22), coat, Vector3(0, 1.1, -0.42)))
	vis.add_child(Assets.box(Vector3(0.14, 0.14, 0.26), coat.lightened(0.1), Vector3(0, 1.32, -0.58)))
	vis.add_child(Assets.box(Vector3(0.04, 0.24, 0.04), Color("#d8c8a8"), Vector3(-0.07, 1.52, -0.55)))
	vis.add_child(Assets.box(Vector3(0.04, 0.24, 0.04), Color("#d8c8a8"), Vector3(0.07, 1.52, -0.55)))
	vis.add_child(Assets.box(Vector3(0.03, 0.16, 0.03), Color("#e8dcc0"), Vector3(-0.07, 1.66, -0.58)))
	vis.add_child(Assets.box(Vector3(0.03, 0.16, 0.03), Color("#e8dcc0"), Vector3(0.07, 1.66, -0.58)))
	_leg(vis, Vector3(-0.12, 0.55, -0.28), Vector3(0.08, 0.6, 0.08), coat)
	_leg(vis, Vector3(0.12, 0.55, -0.28), Vector3(0.08, 0.6, 0.08), coat)
	_leg(vis, Vector3(-0.12, 0.55, 0.28), Vector3(0.08, 0.6, 0.08), coat)
	_leg(vis, Vector3(0.12, 0.55, 0.28), Vector3(0.08, 0.6, 0.08), coat)

func _build_rabbit() -> void:
	var coat := Color("#e8e4dc")
	vis.add_child(Assets.sph(0.16, coat, Vector3(0, 0.22, 0), 7, 4))
	vis.add_child(Assets.sph(0.1, coat, Vector3(0, 0.3, -0.14), 6, 3))
	vis.add_child(Assets.box(Vector3(0.04, 0.16, 0.03), coat, Vector3(-0.05, 0.44, -0.14)))
	vis.add_child(Assets.box(Vector3(0.04, 0.16, 0.03), coat, Vector3(0.05, 0.44, -0.14)))
	_leg(vis, Vector3(-0.08, 0.12, -0.06), Vector3(0.05, 0.14, 0.05), coat)
	_leg(vis, Vector3(0.08, 0.12, -0.06), Vector3(0.05, 0.14, 0.05), coat)

func _leg(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	pivot.add_child(Assets.box(size, color, Vector3(0, -size.y * 0.5, 0)))
	legs.append(pivot)
	return pivot

func _physics_process(delta: float) -> void:
	if dead:
		return
	t += delta
	flee_t = maxf(flee_t - delta, 0.0)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	var spd := 0.0
	var dir := Vector3.ZERO
	if flee_t > 0.0:
		dir = flee_dir
		spd = 4.5
	else:
		if G.player and is_instance_valid(G.player):
			var to_p: Vector3 = G.player.global_position - global_position
			to_p.y = 0
			if to_p.length() < 5.0:
				flee_t = 2.0
				flee_dir = -to_p.normalized()
				dir = flee_dir
				spd = 4.5
		if spd == 0.0:
			wander_t -= delta
			if wander_t <= 0.0:
				wander_t = G.rng.randf_range(2.0, 5.0)
				wander_dir = Vector3(G.rng.randf_range(-1, 1), 0, G.rng.randf_range(-1, 1)).normalized() if G.rng.randf() < 0.6 else Vector3.ZERO
			dir = wander_dir
			spd = 1.4
	velocity.x = lerpf(velocity.x, dir.x * spd, minf(8.0 * delta, 1.0))
	velocity.z = lerpf(velocity.z, dir.z * spd, minf(8.0 * delta, 1.0))
	move_and_slide()
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(8.0 * delta, 1.0))
	var hs := Vector2(velocity.x, velocity.z).length()
	var c := sin(t * (14.0 if flee_t > 0.0 else 8.0)) * minf(hs * 0.1, 0.5) if hs > 0.3 else 0.0
	for i in legs.size():
		legs[i].rotation.x = lerpf(legs[i].rotation.x, c * (1.0 if i % 2 == 0 else -1.0), minf(14.0 * delta, 1.0))

func take_hit(dmg: float, dir: Vector3, _from) -> void:
	if dead:
		return
	hp -= dmg
	flee_t = 3.0
	flee_dir = dir
	G.dmg_number(global_position + Vector3(0, 1.0, 0), str(int(dmg)), Color(1, 1, 1))
	G.sfx("hit", -12.0, 1.4)
	if hp <= 0.0:
		_die()

func _die() -> void:
	dead = true
	G.kills += 1
	FX.burst(G.world, global_position + Vector3(0, 0.5, 0), Color(0.8, 0.4, 0.3), 10, 3.0, 0.5, 0.12)
	if ptype == "deer":
		Pickup.spawn(G.world, "meat", global_position + Vector3(0, 0.6, 0))
		Pickup.spawn(G.world, "meat", global_position + Vector3(0.3, 0.6, 0))
		if G.rng.randf() < 0.5:
			Pickup.spawn(G.world, "antler", global_position + Vector3(0, 0.6, 0))
	else:
		Pickup.spawn(G.world, "meat", global_position + Vector3(0, 0.5, 0))
	G.sfx("hit", -8.0, 0.8)
	var tw := create_tween()
	tw.tween_property(vis, "scale", Vector3(1.2, 0.1, 1.2), 0.3)
	tw.tween_callback(queue_free)
