class_name Projectile
extends Node3D
## Вражеский снаряд (кислота, огонь, лёд, камень).

var vel := Vector3.ZERO
var dmg := 10.0
var life := 3.5
var _dead := false
var friendly := false
var burn := 0.0
var slow := 0.0
var splash := 0.0
var gravity_mult := 1.0
var is_arrow := false

static func spawn(parent: Node, pos: Vector3, dir: Vector3, speed: float, pdmg: float, color: Color, size := 0.15) -> Projectile:
	var p := Projectile.new()
	p.position = pos
	p.vel = dir.normalized() * speed
	p.dmg = pdmg
	parent.add_child(p)
	if p.is_arrow:
		var shaft := Assets.box(Vector3(0.03, 0.03, 0.5), Color("#c8b090"), Vector3.ZERO)
		p.add_child(shaft)
		var tip := Assets.cyl(0.01, 0.05, 0.12, 5, Assets.C_METAL, Vector3(0, 0, -0.3))
		tip.rotation_degrees.x = -90
		p.add_child(tip)
	else:
		var s := Assets.sph(size, color, Vector3.ZERO, 6, 3)
		s.material_override = Assets.glow_mat(color, 1.6)
		p.add_child(s)
	return p

func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += vel * delta
	vel.y -= 2.0 * gravity_mult * delta
	if is_arrow:
		look_at(global_position + vel)
	else:
		rotate_y(delta * 6.0)
	life -= delta
	var ground: float = G.world.height(global_position.x, global_position.z)
	if G.current_dungeon != null:
		ground = -9999.0
	if life <= 0.0 or global_position.y < ground - 1.0:
		_explode()
		return
	if friendly:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead:
				continue
			var to_e: Vector3 = e.global_position + Vector3(0, 0.8, 0) - global_position
			if to_e.length() < 1.15:
				e.take_hit(dmg, vel.normalized(), null)
				if burn > 0.0:
					e.ignite(2.5, burn)
				if slow > 0.0:
					e.apply_slow(slow)
				FX.hit_spark(G.world, global_position)
				if splash > 0.0:
					for e2 in get_tree().get_nodes_in_group("enemies"):
						if is_instance_valid(e2) and e2 != e and not e2.dead:
							if e2.global_position.distance_to(global_position) < 2.5:
								e2.take_hit(splash, (e2.global_position - global_position).normalized(), null)
					FX.burst(G.world, global_position, Color(1.0, 0.45, 0.15), 16, 5.0, 0.5, 0.16, 6.0, true)
					G.sfx("magicboom", -8.0)
				_explode()
				return
	else:
		if G.player and is_instance_valid(G.player) and not G.player.dead:
			var to_p: Vector3 = (G.player.global_position + Vector3(0, 1.0, 0)) - global_position
			if to_p.length() < 0.85:
				G.damage_player(dmg, global_position)
				_explode()
				return

func _explode() -> void:
	_dead = true
	FX.burst(G.world, global_position, Color(1, 1, 1), 8, 3.0, 0.3, 0.1, 2.0, true)
	queue_free()
